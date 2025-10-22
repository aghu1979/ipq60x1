#!/bin/bash
# ====================================================
# Description: OpenWrt Multi-Config Build - Common Functions
# Library: This script provides common functions for logging, error handling, caching, and artifact management.
# License: MIT
# Author: Mary
# ====================================================

# --- 颜色和图标定义 ---
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_WHITE='\033[1;37m'
export COLOR_RESET='\033[0m'

export ICON_SUCCESS="✅"
export ICON_ERROR="❌"
export ICON_WARNING="⚠️"
export ICON_INFO="ℹ️"
export ICON_RUNNING="🚀"

# --- 日志系统 ---
log_info() {
    echo -e "${COLOR_BLUE}${ICON_INFO} [INFO]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}${ICON_WARNING} [WARN]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}${ICON_ERROR} [ERROR]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}${ICON_SUCCESS} [SUCCESS]${COLOR_RESET} $1"
}

log_running() {
    echo -e "${COLOR_CYAN}${ICON_RUNNING} [RUNNING]${COLOR_RESET} $1"
}

# --- 步骤标记 ---
step_start() {
    log_running "开始执行: $1"
    echo "----------------------------------------"
}

step_end() {
    echo "----------------------------------------"
    log_success "完成执行: $1"
}

# --- 错误处理 ---
# 严格模式：遇到错误立即退出，使用未定义变量视为错误，管道中任一命令失败则整个管道失败
set -euo pipefail

# 错误捕获函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 ${line_number} 行发生错误，退出码: ${exit_code}"
    log_error "错误发生前的最后 1000 行日志："
    echo "----------------------------------------"
    # 打印最后1000行日志到控制台和日志文件
    tail -n 1000 "${LOG_FILE}" | tee -a "${LOG_FILE}.error"
    echo "----------------------------------------"
    log_error "详细错误日志已保存至: ${LOG_FILE}.error"
    exit $exit_code
}
# 设置 trap，在任何命令返回非零状态时调用 handle_error
trap 'handle_error $LINENO' ERR

# --- 磁盘空间检查 ---
check_disk_space() {
    log_info "当前磁盘空间使用情况:"
    df -hT
}

# --- 缓存哈希文件生成 ---
# $1: 输出文件路径
# $2-$n: 需要计算哈希的文件或目录
generate_hashes_file() {
    local output_file=$1
    shift
    local hashes=""
    log_info "正在生成缓存哈希文件: ${output_file}"
    for item in "$@"; do
        if [ -e "$item" ]; then
            local hash=$(find "$item" -type f -print0 | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
            hashes="${hashes}${hash}\n"
            log_info " - ${item} 的哈希值: ${hash}"
        else
            log_warn " - ${item} 不存在，跳过哈希计算。"
        fi
    done
    echo -e "$hashes" > "$output_file"
    log_success "缓存哈希文件生成完成。"
}

# --- LuCI 软件包对比 ---
# $1: 合并前的配置文件路径
# $2: 合并后的配置文件路径
compare_luci_packages() {
    local config_before=$1
    local config_after=$2
    log_info "开始对比 LuCI 软件包清单..."

    local luci_before=$(grep "^CONFIG_PACKAGE_luci-app-.*=y" "$config_before" | sed 's/CONFIG_PACKAGE_\(.*\)=y/\1/' | sort)
    local luci_after=$(grep "^CONFIG_PACKAGE_luci-app-.*=y" "$config_after" | sed 's/CONFIG_PACKAGE_\(.*\)=y/\1/' | sort)

    local added=$(comm -13 <(echo "$luci_before") <(echo "$luci_after"))
    local removed=$(comm -23 <(echo "$luci_before") <(echo "$luci_after"))

    if [ -n "$added" ]; then
        log_success "新增的 LuCI 软件包:"
        echo "$added" | while read -r pkg; do
            echo -e "  ${COLOR_GREEN}+ ${pkg}${COLOR_RESET}"
        done
    fi

    if [ -n "$removed" ]; then
        log_error "缺失的 LuCI 软件包 (这通常是配置错误或依赖问题):"
        echo "$removed" | while read -r pkg; do
            echo -e "  ${COLOR_RED}- ${pkg}${COLOR_RESET}"
        done
        # 如果有缺失的包，这是一个严重问题，应该退出
        return 1
    fi

    if [ -z "$added" ] && [ -z "$removed" ]; then
        log_info "LuCI 软件包清单无变化。"
    fi

    log_success "LuCI 软件包清单对比完成。"
    return 0
}

# --- 设备名提取 ---
# $1: 芯片基础配置文件路径
extract_device_names() {
    local base_config_file=$1
    log_info "从 ${base_config_file} 中提取设备名..."
    local devices=$(grep -oE '_DEVICE_[^=]+=y' "$base_config_file" | sed -E 's/_DEVICE_([^=]+)=y/\1/' | tr '\n' ' ')
    log_success "提取到的设备列表: ${devices}"
    echo "$devices"
}

# --- 产出物重命名和打包 ---
# $1: 源目录
# $2: 目标目录
# $3: 分支缩写
# $4: 芯片名
# $5: 配置名
# $6: 设备名列表 (空格分隔)
rename_and_package_artifacts() {
    local source_dir=$1
    local target_dir=$2
    local branch_short=$3
    local chipset=$4
    local config_name=$5
    local device_list=$6

    log_info "开始为 ${branch_short}-${config_name} 重命名和打包产出物..."
    mkdir -p "${target_dir}/configs" "${target_dir}/apps"

    for device in $device_list; do
        log_info "处理设备: ${device}"
        # 查找并重命名固件
        find "${source_dir}" -type f \( -name "*-squashfs-sysupgrade.bin" -o -name "*-squashfs-factory.bin" \) | while read -r firmware; do
            local type=$(echo "$firmware" | grep -oE "sysupgrade|factory")
            local new_name="${branch_short}-${device}-${type}-${config_name}.bin"
            cp "$firmware" "${target_dir}/${new_name}"
            log_success "  - 固件重命名: $(basename "$firmware") -> ${new_name}"
        done

        # 查找并重命名配置文件
        local config_file=$(find "${source_dir}" -name ".config" -print -quit)
        if [ -n "$config_file" ]; then
            local new_config_name="${branch_short}-${chipset}-${device}-${config_name}.config"
            cp "$config_file" "${target_dir}/configs/${new_config_name}"
        fi
        
        local manifest_file=$(find "${source_dir}" -name "*.manifest" -print -quit)
        if [ -n "$manifest_file" ]; then
            local new_manifest_name="${branch_short}-${chipset}-${device}-${config_name}.manifest"
            cp "$manifest_file" "${target_dir}/configs/${new_manifest_name}"
        fi

        local buildinfo_file=$(find "${source_dir}" -name "config.buildinfo" -print -quit)
        if [ -n "$buildinfo_file" ]; then
            local new_buildinfo_name="${branch_short}-${chipset}-${device}-${config_name}.config.buildinfo"
            cp "$buildinfo_file" "${target_dir}/configs/${new_buildinfo_name}"
        fi
    done

    # 收集所有编译的软件包
    local packages_dir=$(find "${source_dir}" -type d -name "packages" -print -quit)
    if [ -n "$packages_dir" ]; then
        log_info "收集编译的软件包到 ${target_dir}/apps..."
        cp -r -n "$packages_dir"/* "${target_dir}/apps/" # -n 允许覆盖
    fi
    
    log_success "产出物重命名和打包完成。"
}
