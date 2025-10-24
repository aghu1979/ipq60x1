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

# 获取配置文件中的luci软件包列表
get_luci_packages() {
    local config_file=$1
    grep "^CONFIG_PACKAGE_luci-" "$config_file" | sed 's/^CONFIG_PACKAGE_//g' | sed 's/=y$//g' | sed 's/=m$//g' | sort
}

# 合并配置文件
merge_configs() {
    local base_config=$1
    local immwrt_config=$2
    local variant_config=$3
    local output_config=$4
    
    log_info "合并配置文件: $base_config + $immwrt_config + $variant_config -> $output_config"
    
    # 创建临时合并文件
    local temp_config=$(mktemp)
    
    # 合并基础配置
    if [ -f "$base_config" ]; then
        cat "$base_config" > "$temp_config"
        check_status "合并基础配置 $base_config"
    else
        log_error "基础配置文件 $base_config 不存在"
        exit 1
    fi
    
    # 合并ImmortalWrt配置
    if [ -f "$immwrt_config" ]; then
        cat "$immwrt_config" >> "$temp_config"
        check_status "合并ImmortalWrt配置 $immwrt_config"
    else
        log_error "ImmortalWrt配置文件 $immwrt_config 不存在"
        exit 1
    fi
    
    # 合并变体配置
    if [ -f "$variant_config" ]; then
        cat "$variant_config" >> "$temp_config"
        check_status "合并变体配置 $variant_config"
    else
        log_error "变体配置文件 $variant_config 不存在"
        exit 1
    fi
    
    # 移动到最终位置
    mv "$temp_config" "$output_config"
    check_status "创建合并配置文件 $output_config"
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

# 检查缓存是否有效
is_cache_valid() {
    local cache_dir=$1
    local max_age_days=${2:-7}  # 默认缓存有效期为7天
    
    if [ ! -d "$cache_dir" ]; then
        return 1  # 缓存目录不存在
    fi
    
    # 检查缓存目录的最后修改时间
    local cache_age=$(find "$cache_dir" -type f -printf "%T@" | sort -n | tail -1)
    local current_time=$(date +%s)
    local age_days=$(( (current_time - cache_age) / 86400 ))
    
    if [ $age_days -gt $max_age_days ]; then
        log_warn "缓存已过期，年龄: $age_days 天"
        return 1
    fi
    
    return 0
}
