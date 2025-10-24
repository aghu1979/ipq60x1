#!/bin/bash

# 软件包比较脚本：比较defconfig前后的luci软件包列表

# 导入日志和工具函数
source "$(dirname "$0")/logger.sh"
source "$(dirname "$0")/utils.sh"

# 比较软件包列表
compare_packages() {
    local config_file=$1
    local openwrt_dir=$2
    local variant=$3
    local output_dir=$4
    
    log_info "比较 $variant 变体的软件包列表"
    
    # 创建输出目录
    mkdir -p "$output_dir"
    
    # 获取defconfig前的luci软件包列表
    local before_file="$output_dir/${variant}_luci_before.txt"
    get_luci_packages "$config_file" > "$before_file"
    
    log_info "defconfig前的luci软件包数量: $(wc -l < "$before_file")"
    
    # 复制配置文件到OpenWrt目录
    cp "$config_file" "$openwrt_dir/.config"
    
    # 执行defconfig
    cd "$openwrt_dir"
    log_command "make defconfig" "执行defconfig"
    cd - > /dev/null
    
    # 获取defconfig后的luci软件包列表
    local after_file="$output_dir/${variant}_luci_after.txt"
    get_luci_packages "$openwrt_dir/.config" > "$after_file"
    
    log_info "defconfig后的luci软件包数量: $(wc -l < "$after_file")"
    
    # 比较差异
    local diff_file="$output_dir/${variant}_luci_diff.txt"
    diff -u "$before_file" "$after_file" > "$diff_file" || true
    
    # 生成差异报告
    local report_file="$output_dir/${variant}_luci_report.txt"
    {
        echo "===== $variant 变体 Luci 软件包差异报告 ====="
        echo "生成时间: $(date)"
        echo ""
        echo "defconfig前软件包数量: $(wc -l < "$before_file")"
        echo "defconfig后软件包数量: $(wc -l < "$after_file")"
        echo ""
        
        # 新增的软件包
        local new_packages=$(comm -13 "$before_file" "$after_file")
        if [ -n "$new_packages" ]; then
            echo "===== 新增的软件包 ====="
            echo "$new_packages"
            echo ""
        fi
        
        # 删除的软件包
        local removed_packages=$(comm -23 "$before_file" "$after_file")
        if [ -n "$removed_packages" ]; then
            echo "===== 删除的软件包 ====="
            echo "$removed_packages"
            echo ""
        fi
        
        # 未变化的软件包
        local unchanged_packages=$(comm -12 "$before_file" "$after_file")
        if [ -n "$unchanged_packages" ]; then
            echo "===== 未变化的软件包 (仅显示前20个) ====="
            echo "$unchanged_packages" | head -20
            if [ $(echo "$unchanged_packages" | wc -l) -gt 20 ]; then
                echo "... (还有 $(($(echo "$unchanged_packages" | wc -l) - 20)) 个未显示)"
            fi
        fi
    } > "$report_file"
    
    log_info "软件包比较完成，报告保存在: $report_file"
}

# 主函数
main() {
    local config_file=$1
    local openwrt_dir=$2
    local variant=$3
    local output_dir=$4
    
    if [ $# -ne 4 ]; then
        log_error "参数数量不正确，需要4个参数"
        log_info "用法: $0 <config_file> <openwrt_dir> <variant> <output_dir>"
        exit 1
    fi
    
    log_info "开始比较软件包列表"
    
    compare_packages "$config_file" "$openwrt_dir" "$variant" "$output_dir"
    
    log_info "软件包列表比较完成"
}

# 执行主函数
main "$@"
