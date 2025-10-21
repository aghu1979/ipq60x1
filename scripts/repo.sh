#!/bin/bash
# scripts/repo.sh
# 功能: 添加第三方软件源
# 作者: Mary

# 设置严格模式
set -euo pipefail

# 定义颜色和图标
COLOR_INFO='\033[1;36m'
COLOR_SUCCESS='\033[1;32m'
COLOR_RESET='\033[0m'
ICON_INFO='ℹ️'
ICON_SUCCESS='✅'

echo -e "${COLOR_INFO}${ICON_INFO} 开始添加第三方软件源...${COLOR_RESET}"

# 定义要添加的源
# 格式: src-git name url
REPO_LINE="src-git small_package https://github.com/kenzok8/small-package"

# 检查 feeds.conf.default 文件是否存在
if [ ! -f "feeds.conf.default" ]; then
    echo -e "${COLOR_ERROR}${ICON_ERROR} 错误: feeds.conf.default 文件不存在！${COLOR_RESET}"
    exit 1
fi

# 检查源是否已经存在，避免重复添加
if grep -qF "$REPO_LINE" feeds.conf.default; then
    echo -e "${COLOR_WARN}⚠️ 警告: 软件源 '$REPO_LINE' 已存在，跳过添加。${COLOR_RESET}"
else
    # 将源追加到文件末尾
    echo "$REPO_LINE" >> feeds.conf.default
    echo -e "${COLOR_SUCCESS}${ICON_SUCCESS} 成功添加软件源: $REPO_LINE${COLOR_RESET}"
fi

echo -e "${COLOR_SUCCESS}${ICON_SUCCESS} 第三方软件源添加完成。${COLOR_RESET}"
