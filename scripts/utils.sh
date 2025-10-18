#!/bin/bash
# ==============================================================================
# 核心函数库
# 功能: 包含设备提取、配置合并、LUCI包对比、文件重命名等核心功能。
# 注意: 使用前需先 source logger.sh
# ==============================================================================

# 设置严格模式
set -euo pipefail

# ==============================================================================
# 函数: extract_devices
# 描述: 从基础配置文件中提取所有设备名称。
# 参数: $1 - 配置文件路径
# 返回: 空格分隔的设备名称字符串
# ==============================================================================
extract_devices() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    # 使用 grep 和 sed 提取 _DEVICE_ 到 =y 之间的设备名
    # 示例: CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y -> jdcloud_re-ss-01
    local devices
    devices=$(grep "CONFIG_TARGET_DEVICE.*_DEVICE_.*=y" "$config_file" | sed -E 's/.*_DEVICE_([^=]+)=y/\1/' | tr '\n' ' ')
    log_info "从 $config_file 提取到设备: $devices"
    echo "$devices"
}

# ==============================================================================
# 函数: merge_configs
# 描述: 按顺序合并多个配置文件，并格式化。
# 参数: $@ - 配置文件路径列表 (按优先级从低到高)
# ==============================================================================
merge_configs() {
    local final_config=".config"
    log_info "开始合并配置文件..."
    
    # 清空或创建最终的 .config
    > "$final_config"
    
    for config in "$@"; do
        if [[ -f "$config" ]]; then
            log_info "合并配置: $config"
            cat "$config" >> "$final_config"
        else
            log_warn "配置文件不存在，跳过: $config"
        fi
    done
    
    # 使用 OpenWrt 自带的脚本格式化并整理配置
    if [[ -f "scripts/config/conf" ]]; then
        make defconfig
    else
        log_warn "未找到 scripts/config/conf，无法执行 make defconfig，请确保在 OpenWrt 源码根目录执行。"
    fi
    
    log_success "配置文件合并并整理完成: $final_config"
}

# ==============================================================================
# 函数: compare_luci_packages
# 描述: 对比两个配置文件中的 LUCI 软件包，并高亮显示差异。
# 参数: $1 - 用户期望的 LUCI 包配置文件 (如 Pro.config)
#       $2 - 生成的完整配置文件 (如 .config)
# ==============================================================================
compare_luci_packages() {
    local user_config="$1"
    local generated_config="$2"
    
    log_info "开始对比 LUCI 软件包..."
    
    # 提取用户期望的 LUCI 包列表
    local user_packages
    user_packages=$(grep "^CONFIG_PACKAGE_luci-app-.*=y" "$user_config" | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/' | sort -u)
    
    # 提取生成配置中的 LUCI 包列表
    local generated_packages
    generated_packages=$(grep "^CONFIG_PACKAGE_luci-app-.*=y" "$generated_config" | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/' | sort -u)
    
    # 使用 comm 命令找出差异
    # comm -12 只显示两文件共有的行
    # comm -23 只显示第一个文件独有的行 (缺失的包)
    # comm -13 只显示第二个文件独有的行 (新增的包)
    
    local missing_packages
    missing_packages=$(comm -23 <(echo "$user_packages") <(echo "$generated_packages"))
    
    local added_packages
    added_packages=$(comm -13 <(echo "$user_packages") <(echo "$generated_packages"))
    
    local success_packages
    success_packages=$(comm -12 <(echo "$user_packages") <(echo "$generated_packages"))

    # --- 输出结果 ---
    if [[ -n "$success_packages" ]]; then
        log_success "成功包含的 LUCI 包:"
        echo "$success_packages" | sed 's/^/  - /' | tee -a "${FULL_LOG_PATH:-/dev/null}"
    fi

    if [[ -n "$added_packages" ]]; then
        log_warn "因依赖关系自动新增的 LUCI 包:"
        echo "$added_packages" | sed 's/^/  - /' | tee -a "${FULL_LOG_PATH:-/dev/null}"
    fi

    if [[ -n "$missing_packages" ]]; then
        log_error "缺失的 LUCI 包 (请检查 feeds 或包名是否正确):"
        echo -e "${RED}$missing_packages${NC}" | sed 's/^/  - /' | tee -a "${FULL_LOG_PATH:-/dev/null}"
        # 返回非零状态码表示有缺失
        return 1
    fi
    
    log_success "所有期望的 LUCI 包均已成功配置。"
    return 0
}

# ==============================================================================
# 函数: get_kernel_version
# 描述: 从编译产物中提取内核版本。
# 参数: $1 - 产物根目录路径
# 返回: 内核版本字符串
# ==============================================================================
get_kernel_version() {
    local artifacts_path="$1"
    # 尝试从任意一个 config.buildinfo 中提取
    local buildinfo_file
    buildinfo_file=$(find "$artifacts_path" -name "config.buildinfo" | head -n 1)
    if [[ -f "$buildinfo_file" ]]; then
        local kernel_version
        kernel_version=$(grep "^CONFIG_LINUX_VERSION=" "$buildinfo_file" | sed 's/CONFIG_LINUX_VERSION="\(.*\)"/\1/')
        echo "$kernel_version"
    else
        echo "Unknown"
    fi
}
