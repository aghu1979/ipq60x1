#!/bin/bash
# scripts/check_luci.sh
# 功能: 检查 LuCI 软件包在 defconfig 前后是否一致，确保依赖被正确解析
# 作者: Mary

# 设置严格模式
set -euo pipefail

# 定义颜色和图标
COLOR_ERROR='\033[1;31m'
COLOR_WARN='\033[1;33m'
COLOR_INFO='\033[1;36m'
COLOR_SUCCESS='\033[1;32m'
COLOR_RESET='\033[0m'
ICON_ERROR='❌'
ICON_WARN='⚠️'
ICON_INFO='ℹ️'
ICON_SUCCESS='✅'

# 检查是否传入了配置文件路径
if [ -z "${1:-}" ]; then
    echo -e "${COLOR_ERROR}${ICON_ERROR} 错误: 请提供 .config 文件路径作为参数。${COLOR_RESET}"
    exit 1
fi

CONFIG_FILE="$1"
echo -e "${COLOR_INFO}${ICON_INFO} 正在检查配置文件: $CONFIG_FILE${COLOR_RESET}"

# 1. 提取 defconfig 前的 LuCI 包列表
echo -e "${COLOR_INFO}${ICON_INFO} 步骤 1: 提取 defconfig 前的 LuCI 软件包列表...${COLOR_RESET}"
LUCI_BEFORE=$(grep "^CONFIG_PACKAGE_luci-app-.*=y" "$CONFIG_FILE" | sed 's/CONFIG_PACKAGE_\(.*\)=y/\1/' | sort)
echo -e "${COLOR_INFO}defconfig 前指定的 LuCI 包:${COLOR_RESET}"
echo "$LUCI_BEFORE"

# 2. 运行 defconfig
echo -e "${COLOR_INFO}${ICON_INFO} 步骤 2: 运行 'make defconfig' 以解析依赖...${COLOR_RESET}"
make defconfig

# 3. 提取 defconfig 后的 LuCI 包列表
echo -e "${COLOR_INFO}${ICON_INFO} 步骤 3: 提取 defconfig 后的 LuCI 软件包列表...${COLOR_RESET}"
LUCI_AFTER=$(grep "^CONFIG_PACKAGE_luci-app-.*=y" "$CONFIG_FILE" | sed 's/CONFIG_PACKAGE_\(.*\)=y/\1/' | sort)
echo -e "${COLOR_INFO}defconfig 后实际包含的 LuCI 包:${COLOR_RESET}"
echo "$LUCI_AFTER"

# 4. 对比两个列表，找出缺失的包
echo -e "${COLOR_INFO}${ICON_INFO} 步骤 4: 对比软件包列表，检查是否有缺失...${COLOR_RESET}"
# 使用 comm 命令找出只在第一个列表中存在的行（即缺失的包）
MISSING_PACKAGES=$(comm -23 <(echo "$LUCI_BEFORE") <(echo "$LUCI_AFTER"))

if [ -n "$MISSING_PACKAGES" ]; then
    echo -e "${COLOR_ERROR}${ICON_ERROR} ==================== 错误报告 ==================== ${COLOR_RESET}"
    echo -e "${COLOR_ERROR}发现以下 LuCI 软件包在依赖解析后丢失，编译将终止！${COLOR_RESET}"
    echo -e "${COLOR_ERROR}这通常是因为其依赖项无法满足或软件包本身不存在于当前 feeds 中。${COLOR_RESET}"
    echo -e "${COLOR_ERROR}请检查您的配置文件和第三方软件源。${COLOR_RESET}"
    echo -e "${COLOR_WARN}------------------- 缺失的软件包列表 -------------------${COLOR_WARN}"
    echo "$MISSING_PACKAGES" | while read -r pkg; do
        echo -e "${COLOR_ERROR} - ${pkg}${COLOR_RESET}"
    done
    echo -e "${COLOR_WARN}------------------------------------------------------${COLOR_RESET}"
    echo -e "${COLOR_ERROR}======================================================${COLOR_RESET}"
    exit 1
else
    echo -e "${COLOR_SUCCESS}${ICON_SUCCESS} 成功: 所有指定的 LuCI 软件包均已成功解析依赖，无缺失。${COLOR_RESET}"
fi
