#!/bin/bash

# ==========================================
# 脚本功能：扫描并分析 JD Coding 代码库 AI Coding 工具的使用情况
# ==========================================

# 临时文件定义（格式：repo_dir|commit_count）
JD_REPOS_LIST="/tmp/jd_repos_list.txt"
TIME_RANGE="3 months ago" # 可选：1 year ago
HIGH_FREQUENCY_THRESHOLD=5 # TIME_RANGE时间范围内对应提交次数

rm -f "$JD_REPOS_LIST"

# ---------------------------------------------------------
# 步骤 1: 扫描与筛选
# ---------------------------------------------------------
printf "正在扫描本地仓库..."

find ~ -type d \( \
    -name "node_modules" -o \
    -name "dist" -o \
    -name "Library" -o \
    -name "Movies" -o \
    -name "Pictures" -o \
    -name "Music" -o \
    -name "Applications" -o \
    -name ".Trash" -o \
    -name "Public" \
\) -prune -o -name ".git" -type d -prune -print0 | while IFS= read -r -d '' git_path; do
    repo_dir=$(dirname "$git_path")
    remote_url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null)
    
    if [[ "$remote_url" == *"coding.jd.com"* ]]; then
        commit_count=$(git -C "$repo_dir" rev-list --count --since="$TIME_RANGE" --no-merges HEAD 2>/dev/null)
        # 保存 repo_dir 和 commit_count，避免后续重复获取
        if [[ -n "$commit_count" && "$commit_count" -gt HIGH_FREQUENCY_THRESHOLD ]]; then
            echo "$repo_dir|$commit_count" >> "$JD_REPOS_LIST"
        fi
    fi
done

printf "\r%-40s\n" "扫描完成"

# 检查结果
if [ ! -f "$JD_REPOS_LIST" ]; then
    echo "未发现任何符合条件的 coding.jd.com 仓库"
    exit 0
fi

total_jd_repos=$(wc -l < "$JD_REPOS_LIST")

# ---------------------------------------------------------
# 步骤 2: Git Log 分析
# ---------------------------------------------------------
total_commits_all=0
total_commits_with_body_all=0
final_count=0
current_idx=0

echo "接入 AI Coding 提效工具的仓库："

while IFS='|' read -r repo_dir repo_commits; do
    ((current_idx++))
    repo_name=$(basename "$repo_dir")
    
    printf "\r[%d/%d] 分析中: %-30s" "$current_idx" "$total_jd_repos" "$repo_name"

    # 直接使用步骤1中保存的 repo_commits，无需重复获取
    total_commits_all=$((total_commits_all + repo_commits))

    # 统计包含 body 的提交数（使用 \x01 作为分隔符）
    repo_commits_with_body=$(git -C "$repo_dir" log --since="$TIME_RANGE" --no-merges --format="%b%x01" 2>/dev/null | awk 'BEGIN {RS="\x01"; count=0} { if ($0 ~ /[^[:space:]]/) count++ } END { printf "%d", count }')
    total_commits_with_body_all=$((total_commits_with_body_all + repo_commits_with_body))

    # 如果包含 body 的提交数 > 0，直接打印
    if [ "$repo_commits_with_body" -gt 0 ]; then
        ((final_count++))
        printf "\r  • %-45s\n" "$repo_name"
    fi
done < "$JD_REPOS_LIST"

printf "\r%-50s\n" ""

# ---------------------------------------------------------
# 步骤 3: 结果统计与展示
# ---------------------------------------------------------
echo "╔════════════════════════════════════════╗"
echo "║      AI Coding 使用情况分析            ║"
echo "╚════════════════════════════════════════╝"
printf "%-24s %10s \n" "高频仓库数" "$total_jd_repos"
printf "%-24s %10s \n" "AI Coding 接入仓库数" "$final_count"
printf "%-24s %10s \n" "提交总数" "$total_commits_all"
printf "%-24s %10s \n" "AI Coding 辅助提交数" "$total_commits_with_body_all"


# 清理临时文件
rm -f "$JD_REPOS_LIST"
