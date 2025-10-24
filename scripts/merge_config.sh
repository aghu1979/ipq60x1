#!/bin/bash

# 配置合并脚本：合并多个配置文件

# 导入日志和工具函数
source "$(dirname "$0")/logger.sh"
source "$(dirname "$0")/utils.sh"

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

# 主函数
main() {
    local base_config=$1
    local immwrt_config=$2
    local variant_config=$3
    local output_config=$4
    
    if [ $# -ne 4 ]; then
        log_error "参数数量不正确，需要4个参数"
        log_info "用法: $0 <base_config> <immwrt_config> <variant_config> <output_config>"
        exit 1
    fi
    
    log_info "开始合并配置文件"
    
    merge_configs "$base_config" "$immwrt_config" "$variant_config" "$output_config"
    
    log_info "配置文件合并完成"
}

# 执行主函数
main "$@"
