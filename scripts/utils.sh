#!/bin/bash

# 函数库：包含常用的工具函数

# 日志函数
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查命令是否执行成功
check_status() {
    if [ $? -ne 0 ]; then
        log_error "$1 执行失败"
        exit 1
    else
        log_info "$1 执行成功"
    fi
}

# 获取配置文件中的luci软件包列表（修复版）
get_luci_packages() {
    local config_file=$1
    
    # 修复：只选择以CONFIG_PACKAGE_luci-开头且以=y结尾的行
    # 然后提取包名（去掉CONFIG_PACKAGE_前缀和=y后缀）
    grep "^CONFIG_PACKAGE_luci-.*=y$" "$config_file" 2>/dev/null | \
    sed 's/^CONFIG_PACKAGE_//g' | \
    sed 's/=y$//g' | \
    sort
}

# 合并配置文件（完全重写 - 简单直接的方式）
merge_configs() {
    local base_config=$1
    local immwrt_config=$2
    local variant_config=$3
    local output_config=$4
    
    log_info "合并配置文件: $base_config + $immwrt_config + $variant_config -> $output_config"
    
    # 创建临时合并文件
    local temp_config=$(mktemp)
    
    # 方法：简单拼接所有配置文件
    # OpenWrt的make defconfig会自动处理重复项，后面的会覆盖前面的
    
    # 1. 先添加基础配置
    if [ -f "$base_config" ]; then
        log_info "添加基础配置: $base_config"
        cat "$base_config" >> "$temp_config"
    else
        log_error "基础配置文件 $base_config 不存在"
        exit 1
    fi
    
    # 2. 添加ImmortalWrt配置
    if [ -f "$immwrt_config" ]; then
        log_info "添加ImmortalWrt配置: $immwrt_config"
        cat "$immwrt_config" >> "$temp_config"
    else
        log_error "ImmortalWrt配置文件 $immwrt_config 不存在"
        exit 1
    fi
    
    # 3. 添加变体配置（会覆盖前面的同名配置）
    if [ -f "$variant_config" ]; then
        log_info "添加变体配置: $variant_config"
        cat "$variant_config" >> "$temp_config"
    else
        log_error "变体配置文件 $variant_config 不存在"
        exit 1
    fi
    
    # 移动到最终位置
    mv "$temp_config" "$output_config"
    check_status "创建合并配置文件 $output_config"
    
    # 立即显示合并后的luci软件包
    log_info "=== 合并后的luci软件包列表（用户配置） ==="
    local luci_count=0
    grep "^CONFIG_PACKAGE_luci-.*=y$" "$output_config" 2>/dev/null | while read -r line; do
        local pkg=$(echo "$line" | sed 's/^CONFIG_PACKAGE_//g' | sed 's/=y$//g')
        log_info "  - $pkg"
        luci_count=$((luci_count + 1))
    done
    log_info "=== 用户配置的luci软件包总数: $(grep "^CONFIG_PACKAGE_luci-.*=y$" "$output_config" 2>/dev/null | wc -l) ==="
}

# 计算文件哈希值
calc_file_hash() {
    local file=$1
    if [ -f "$file" ]; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}

# 检查缓存是否有效（修复版）
is_cache_valid() {
    local cache_dir=$1
    local max_age_days=${2:-7}  # 默认缓存有效期为7天
    
    if [ ! -d "$cache_dir" ]; then
        return 1  # 缓存目录不存在
    fi
    
    # 检查缓存目录是否为空
    if [ -z "$(ls -A "$cache_dir" 2>/dev/null)" ]; then
        log_warn "缓存目录为空: $cache_dir"
        return 1
    fi
    
    # 检查缓存目录的最后修改时间
    local cache_age=$(find "$cache_dir" -type f -printf "%T@" | sort -n | tail -1)
    local current_time=$(date +%s)
    local age_days=$(( (current_time - cache_age) / 86400 ))
    
    if [ $age_days -gt $max_age_days ]; then
        log_warn "缓存已过期，年龄: $age_days 天"
        return 1
    fi
    
    log_info "缓存有效，年龄: $age_days 天"
    return 0
}

# 调试函数：显示配置文件中的所有luci相关配置
debug_luci_configs() {
    local config_file=$1
    local label=${2:-"配置文件"}
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件 $config_file 不存在"
        return 1
    fi
    
    log_info "=== 调试 $label 中的luci配置 ==="
    log_info "文件路径: $config_file"
    
    local total_luci=$(grep "luci" "$config_file" 2>/dev/null | wc -l)
    log_info "所有包含luci的配置项: $total_luci 个"
    
    local package_luci=$(grep "^CONFIG_PACKAGE_luci-" "$config_file" 2>/dev/null | wc -l)
    log_info "所有CONFIG_PACKAGE_luci-开头的配置项: $package_luci 个"
    
    local enabled_luci=$(grep "^CONFIG_PACKAGE_luci-.*=y$" "$config_file" 2>/dev/null | wc -l)
    log_info "所有CONFIG_PACKAGE_luci-开头且=y的配置项: $enabled_luci 个"
    
    local disabled_luci=$(grep "^CONFIG_PACKAGE_luci-.*=n$" "$config_file" 2>/dev/null | wc -l)
    log_info "所有CONFIG_PACKAGE_luci-开头且=n的配置项: $disabled_luci 个"
    
    if [ $enabled_luci -gt 0 ]; then
        log_info "启用的luci软件包列表："
        grep "^CONFIG_PACKAGE_luci-.*=y$" "$config_file" 2>/dev/null | while read -r line; do
            local pkg=$(echo "$line" | sed 's/^CONFIG_PACKAGE_//g' | sed 's/=y$//g')
            log_info "  - $pkg"
        done
    fi
    
    if [ $disabled_luci -gt 0 ]; then
        log_info "禁用的luci软件包列表："
        grep "^CONFIG_PACKAGE_luci-.*=n$" "$config_file" 2>/dev/null | while read -r line; do
            local pkg=$(echo "$line" | sed 's/^CONFIG_PACKAGE_//g' | sed 's/=n$//g')
            log_info "  - $pkg"
        done
    fi
    
    log_info "=== 调试结束 ==="
}

# 验证配置文件格式
validate_config_format() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件 $config_file 不存在"
        return 1
    fi
    
    # 检查是否有无效的配置行
    local invalid_lines=$(grep -v "^#" "$config_file" | grep -v "^$" | grep -v "^CONFIG_")
    if [ -n "$invalid_lines" ]; then
        log_warn "发现可能的无效配置行："
        echo "$invalid_lines" | while read -r line; do
            log_warn "  $line"
        done
    fi
    
    # 检查是否有未闭合的引号
    local unclosed_quotes=$(grep "'" "$config_file" | grep -v "'" | wc -l)
    if [ $unclosed_quotes -gt 0 ]; then
        log_warn "发现可能的未闭合引号"
    fi
    
    return 0
}

# 统计配置文件信息
get_config_stats() {
    local config_file=$1
    local label=${2:-"配置文件"}
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件 $config_file 不存在"
        return 1
    fi
    
    echo "=== $label 统计信息 ==="
    echo "文件大小: $(du -h "$config_file" | cut -f1)"
    echo "总行数: $(wc -l < "$config_file")"
    echo "非空非注释行数: $(grep -v "^#" "$config_file" | grep -v "^$" | wc -l)"
    echo "CONFIG_开头的行数: $(grep "^CONFIG_" "$config_file" | wc -l)"
    echo "PACKAGE_相关的行数: $(grep "PACKAGE" "$config_file" | wc -l)"
    echo "luci相关的行数: $(grep "luci" "$config_file" | wc -l)"
    echo "启用的软件包数: $(grep "=y$" "$config_file" | wc -l)"
    echo "禁用的软件包数: $(grep "=n$" "$config_file" | wc -l)"
    echo "========================"
}
