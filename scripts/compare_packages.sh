#!/bin/bash

# 软件包比较脚本：智能诊断和修复配置问题

# 导入日志和工具函数
source "$(dirname "$0")/logger.sh"
source "$(dirname "$0")/utils.sh"

# 检查软件包是否存在于feeds中
check_package_exists() {
    local package=$1
    local openwrt_dir=$2
    
    # 检查软件包是否在feeds中定义
    if [ -f "$openwrt_dir/feeds.conf.default" ]; then
        # 搜索软件包定义
        if grep -q "Package: $package" "$openwrt_dir/package/feeds/"*/*/Makefile 2>/dev/null; then
            return 0  # 软件包存在
        fi
    fi
    
    # 检查软件包是否在临时索引中
    if [ -f "$openwrt_dir/tmp/.packageinfo" ]; then
        if grep -q "^$package$" "$openwrt_dir/tmp/.packageinfo" 2>/dev/null; then
            return 0  # 软件包存在
        fi
    fi
    
    return 1  # 软件包不存在
}

# 获取软件包的依赖
get_package_dependencies() {
    local package=$1
    local openwrt_dir=$2
    
    # 从Makefile中提取依赖
    local makefile=$(find "$openwrt_dir/package" -name "Makefile" -exec grep -l "Package: $package" {} \; 2>/dev/null | head -1)
    if [ -n "$makefile" ]; then
        grep "^DEPENDS:=" "$makefile" 2>/dev/null | sed 's/^DEPENDS:=//g' | sed 's/+//g'
    fi
}

# 尝试自动修复依赖
fix_dependencies() {
    local missing_packages=$1
    local openwrt_dir=$2
    local config_file=$3
    
    log_info "尝试自动修复依赖关系..."
    
    # 创建临时配置文件
    local temp_config=$(mktemp)
    cp "$config_file" "$temp_config"
    
    # 添加缺失的依赖包
    while IFS= read -r package; do
        if [ -n "$package" ]; then
            # 检查是否是luci包
            if [[ "$package" == luci-* ]]; then
                log_info "添加缺失的依赖包: $package"
                echo "CONFIG_PACKAGE_$package=y" >> "$temp_config"
            fi
        fi
    done <<< "$missing_packages"
    
    # 应用修复后的配置
    cp "$temp_config" "$openwrt_dir/.config"
    rm "$temp_config"
    
    # 再次执行defconfig
    cd "$openwrt_dir"
    make defconfig > /dev/null 2>&1
    
    log_info "依赖修复完成，重新检查软件包..."
}

# 生成详细的诊断报告
generate_diagnostic_report() {
    local before_file=$1
    local after_file=$2
    local openwrt_dir=$3
    local variant=$4
    local output_dir=$5
    
    local report_file="$output_dir/${variant}_diagnostic_report.html"
    
    # 计算统计信息
    local before_count=$(wc -l < "$before_file")
    local after_count=$(wc -l < "$after_file")
    local removed_count=$(comm -23 "$before_file" "$after_file" | wc -l)
    
    # 生成HTML报告
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${variant} 变体配置诊断报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .summary { display: flex; justify-content: space-around; margin-bottom: 20px; }
        .summary-item { text-align: center; padding: 15px; background-color: #e9f7ef; border-radius: 5px; }
        .section { margin-bottom: 20px; }
        .section h2 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 5px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .error { color: #e74c3c; }
        .warning { color: #f39c12; }
        .success { color: #27ae60; }
        .package-name { font-family: monospace; background-color: #f8f9fa; padding: 2px 5px; border-radius: 3px; }
        .reason { font-size: 0.9em; color: #7f8c8d; }
        .fix-suggestion { background-color: #fff3cd; padding: 10px; border-radius: 5px; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>${variant} 变体配置诊断报告</h1>
        <p>生成时间: $(date)</p>
        <p>目标设备: IPQ60xx</p>
    </div>
    
    <div class="summary">
        <div class="summary-item">
            <h3>defconfig前</h3>
            <p class="success">$before_count 个软件包</p>
        </div>
        <div class="summary-item">
            <h3>defconfig后</h3>
            <p class="error">$after_count 个软件包</p>
        </div>
        <div class="summary-item">
            <h3>已删除</h3>
            <p class="warning">$removed_count 个软件包</p>
        </div>
    </div>
    
    <div class="section">
        <h2>诊断结果</h2>
EOF

    # 分析被删除的软件包
    local removed_packages=$(comm -23 "$before_file" "$after_file")
    
    if [ -n "$removed_packages" ]; then
        cat >> "$report_file" << EOF
        <p class="error">⚠️ 发现 $removed_count 个软件包被删除，这可能是由于以下原因：</p>
        <ul>
            <li>软件包不存在于当前源码或feeds中</li>
            <li>软件包的依赖关系未被满足</li>
            <li>软件包与当前配置冲突</li>
            <li>软件包仅适用于其他架构</li>
        </ul>
        
        <h3>被删除的软件包详情</h3>
        <table>
            <tr>
                <th>软件包名称</th>
                <th>状态</th>
                <th>可能原因</th>
                <th>建议</th>
            </tr>
EOF
        
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                local status="未知"
                local reason="未知"
                local suggestion="检查软件包名称是否正确"
                
                # 检查软件包是否存在
                if check_package_exists "$package" "$openwrt_dir"; then
                    status="存在"
                    reason="可能是依赖问题或配置冲突"
                    suggestion="尝试添加依赖包或检查配置冲突"
                else
                    status="不存在"
                    reason="软件包不存在于当前源码或feeds中"
                    suggestion="检查feeds配置或寻找替代软件包"
                fi
                
                cat >> "$report_file" << EOF
            <tr>
                <td class="package-name">$package</td>
                <td class="$([ "$status" = "存在" ] && echo "success" || echo "error")">$status</td>
                <td class="reason">$reason</td>
                <td>$suggestion</td>
            </tr>
EOF
            fi
        done <<< "$removed_packages"
        
        cat >> "$report_file" << EOF
        </table>
        
        <div class="fix-suggestion">
            <h3>🔧 自动修复建议</h3>
            <p>系统已尝试自动修复依赖关系，如果问题仍然存在，请考虑以下解决方案：</p>
            <ol>
                <li>检查 <code>configs/${variant}.config</code> 文件中的软件包名称是否正确</li>
                <li>运行 <code>./scripts/feeds update -a</code> 和 <code>./scripts/feeds install -a</code> 更新feeds</li>
                <li>检查软件包是否适用于IPQ60xx架构</li>
                <li>查看OpenWrt官方文档确认软件包名称和依赖关系</li>
            </ol>
        </div>
EOF
    else
        cat >> "$report_file" << EOF
        <p class="success">✅ 所有软件包配置正常，没有被删除的软件包。</p>
EOF
    fi
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>技术细节</h2>
        <p>配置文件: <code>configs/${variant}.config</code></p>
        <p>基础配置: <code>configs/base_ipq60xx.config</code> + <code>configs/base_immwrt.config</code></p>
        <p>合并配置: <code>/tmp/${variant}.config</code></p>
        <p>OpenWrt路径: <code>$openwrt_dir</code></p>
    </div>
</body>
</html>
EOF
    
    log_info "诊断报告已生成: $report_file"
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
    
    log_info "开始诊断 $variant 变体的软件包配置"
    
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
    
    # 获取defconfig后的luci软件包列表
    local after_file="$output_dir/${variant}_luci_after.txt"
    get_luci_packages "$openwrt_dir/.config" > "$after_file"
    
    log_info "defconfig后的luci软件包数量: $(wc -l < "$after_file")"
    
    # 检查是否有软件包被删除
    local removed_packages=$(comm -23 "$before_file" "$after_file")
    local removed_count=$(echo "$removed_packages" | grep -c .)
    
    if [ $removed_count -gt 0 ]; then
        log_warn "发现 $removed_count 个软件包被删除，尝试自动修复..."
        
        # 收集缺失的依赖
        local missing_deps=""
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                local deps=$(get_package_dependencies "$package" "$openwrt_dir")
                if [ -n "$deps" ]; then
                    missing_deps="$missing_deps$deps"$'\n'
                fi
            fi
        done <<< "$removed_packages"
        
        # 尝试修复依赖
        if [ -n "$missing_deps" ]; then
            fix_dependencies "$missing_deps" "$openwrt_dir" "$config_file"
            
            # 重新获取修复后的软件包列表
            local fixed_after_file="$output_dir/${variant}_luci_after_fixed.txt"
            get_luci_packages "$openwrt_dir/.config" > "$fixed_after_file"
            
            log_info "修复后的luci软件包数量: $(wc -l < "$fixed_after_file")"
            
            # 检查修复效果
            local fixed_removed_packages=$(comm -23 "$before_file" "$fixed_after_file")
            local fixed_removed_count=$(echo "$fixed_removed_packages" | grep -c .)
            
            if [ $fixed_removed_count -gt 0 ]; then
                log_error "自动修复后仍有 $fixed_removed_count 个软件包缺失"
                
                # 生成诊断报告
                generate_diagnostic_report "$before_file" "$fixed_after_file" "$openwrt_dir" "$variant" "$output_dir"
                
                # 输出缺失的软件包列表
                echo "缺失的软件包列表:" > "$output_dir/${variant}_missing_packages.txt"
                echo "$fixed_removed_packages" >> "$output_dir/${variant}_missing_packages.txt"
                
                log_error "编译终止，请查看诊断报告了解详情"
                exit 1
            else
                log_info "自动修复成功，所有软件包已恢复"
            fi
        else
            log_error "无法确定缺失的依赖，自动修复失败"
            
            # 生成诊断报告
            generate_diagnostic_report "$before_file" "$after_file" "$openwrt_dir" "$variant" "$output_dir"
            
            exit 1
        fi
    else
        log_info "所有软件包配置正常，继续编译..."
    fi
    
    log_info "软件包配置诊断完成"
}

# 执行主函数
main "$@"
