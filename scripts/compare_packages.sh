#!/bin/bash

# 软件包比较脚本：智能诊断和修复配置问题

# 导入日志和工具函数
source "$(dirname "$0")/logger.sh"
source "$(dirname "$0")/utils.sh"

# 检查软件包是否存在于feeds中
check_package_exists() {
    local package=$1
    local openwrt_dir=$2
    
    # 检查软件包是否在临时索引中
    if [ -f "$openwrt_dir/tmp/.packageinfo" ]; then
        if grep -q "^$package$" "$openwrt_dir/tmp/.packageinfo" 2>/dev/null; then
            return 0  # 软件包存在
        fi
    fi
    
    # 检查软件包是否在feeds中定义
    if find "$openwrt_dir/package/feeds" -name "Makefile" -exec grep -l "Package: $package" {} \; 2>/dev/null | grep -q .; then
        return 0  # 软件包存在
    fi
    
    return 1  # 软件包不存在
}

# 获取软件包的依赖
get_package_dependencies() {
    local package=$1
    local openwrt_dir=$2
    
    # 从临时索引中获取依赖
    if [ -f "$openwrt_dir/tmp/.packageinfo" ]; then
        # 查找软件包的依赖信息
        awk -v pkg="$package" '
            $0 == pkg { 
                in_pkg = 1 
                next 
            } 
            in_pkg && /^Depends:/ { 
                gsub(/^Depends: /, ""); 
                gsub(/,/, "\n"); 
                for (i = 1; i <= NF; i++) print $i 
            } 
            in_pkg && /^$/ { 
                in_pkg = 0 
            } 
        ' "$openwrt_dir/tmp/.packageinfo" 2>/dev/null
    fi
    
    # 如果临时索引中没有，尝试从Makefile中提取
    local makefile=$(find "$openwrt_dir/package" -name "Makefile" -exec grep -l "Package: $package" {} \; 2>/dev/null | head -1)
    if [ -n "$makefile" ]; then
        grep "^DEPENDS:=" "$makefile" 2>/dev/null | sed 's/^DEPENDS:=//g' | sed 's/+//g' | tr ' ' '\n'
    fi
}

# 在控制台显示诊断摘要
print_diagnostic_summary() {
    local before_file=$1
    local after_file=$2
    local openwrt_dir=$3
    local variant=$4
    
    local before_count=$(wc -l < "$before_file")
    local after_count=$(wc -l < "$after_file")
    local removed_packages=$(comm -23 "$before_file" "$after_file")
    local removed_count=$(echo "$removed_packages" | grep -c .)
    
    echo ""
    echo "================================================================================"
    echo "🔍 $variant 变体软件包配置诊断摘要"
    echo "================================================================================"
    echo "📊 统计信息:"
    echo "   - 用户配置的luci软件包数量: $before_count"
    echo "   - defconfig后保留的软件包数量: $after_count"
    echo "   - 被删除的软件包数量: $removed_count"
    echo ""
    
    if [ $removed_count -gt 0 ]; then
        echo "❌ 发现问题: $removed_count 个软件包被删除"
        echo ""
        echo "📋 被删除的软件包详情:"
        echo "----------------------------------------"
        
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                local status="未知"
                local reason="未知"
                
                # 检查软件包是否存在
                if check_package_exists "$package" "$openwrt_dir"; then
                    status="存在"
                    reason="可能是依赖问题或配置冲突"
                else
                    status="不存在"
                    reason="软件包不存在于当前源码或feeds中"
                fi
                
                printf "   %-30s | %-8s | %s\n" "$package" "$status" "$reason"
            fi
        done <<< "$removed_packages"
        
        echo "----------------------------------------"
        echo ""
        echo "🔧 可能的解决方案:"
        echo "   1. 检查 configs/${variant}.config 文件中的软件包名称是否正确"
        echo "   2. 确认软件包适用于IPQ60xx架构"
        echo "   3. 检查软件包的依赖关系是否满足"
        echo "   4. 查看完整的HTML诊断报告获取更多详情"
        echo ""
    else
        echo "✅ 所有软件包配置正常"
    fi
    
    echo "================================================================================"
    echo ""
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
        .console-output { background-color: #2d3748; color: #e2e8f0; padding: 15px; border-radius: 5px; font-family: monospace; white-space: pre-wrap; }
        .config-section { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .config-title { font-weight: bold; color: #495057; margin-bottom: 10px; }
        .package-list { background-color: #e9ecef; padding: 10px; border-radius: 5px; font-family: monospace; }
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
            <h3>用户配置</h3>
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
        <h2>软件包对比</h2>
        <div class="config-section">
            <div class="config-title">用户配置的luci软件包（defconfig前）</div>
            <div class="package-list">
EOF

    # 添加用户配置的软件包列表
    if [ -s "$before_file" ]; then
        cat "$before_file" | sed 's/^/  - /' >> "$report_file"
    else
        echo "  （无）" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
            </div>
        </div>
        <div class="config-section">
            <div class="config-title">defconfig后保留的luci软件包</div>
            <div class="package-list">
EOF

    # 添加defconfig后的软件包列表
    if [ -s "$after_file" ]; then
        cat "$after_file" | sed 's/^/  - /' >> "$report_file"
    else
        echo "  （无）" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>控制台输出摘要</h2>
        <div class="console-output">
EOF

    # 添加控制台输出到报告
    print_diagnostic_summary "$before_file" "$after_file" "$openwrt_dir" "$variant" >> "$report_file"

    cat >> "$report_file" << EOF
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
    
    # 调试：显示输入的配置文件路径
    log_info "输入的配置文件: $config_file"
    log_info "配置文件大小: $(du -h "$config_file" 2>/dev/null | cut -f1 || echo "未知")"
    log_info "配置文件行数: $(wc -l < "$config_file" 2>/dev/null || echo "未知")"
    
    # 调试：显示合并后的配置文件内容（前20行）
    log_info "=== 合并后的配置文件内容（前20行） ==="
    head -20 "$config_file" 2>/dev/null | while read -r line; do
        log_info "  $line"
    done
    log_info "=== 配置文件内容结束 ==="
    
    # 获取defconfig前的luci软件包列表（从用户配置）
    local before_file="$output_dir/${variant}_luci_before.txt"
    get_luci_packages "$config_file" > "$before_file"
    
    local before_count=$(wc -l < "$before_file")
    log_info "用户配置的luci软件包数量: $before_count"
    
    if [ $before_count -gt 0 ]; then
        log_info "用户配置的luci软件包列表："
        cat "$before_file" | while read -r pkg; do
            log_info "  - $pkg"
        done
    else
        log_warn "用户配置中没有找到luci软件包"
        
        # 调试：显示配置文件中所有包含luci的行
        log_info "=== 调试：配置文件中所有包含luci的行 ==="
        grep -i "luci" "$config_file" 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
        log_info "=== 调试结束 ==="
    fi
    
    # 保存原始配置文件（defconfig前的）
    local original_config="$output_dir/${variant}_original.config"
    cp "$config_file" "$original_config"
    log_info "已保存原始配置文件: $original_config"
    
    # 复制配置文件到OpenWrt目录
    cp "$config_file" "$openwrt_dir/.config"
    
    # 执行defconfig
    cd "$openwrt_dir"
    log_command "make defconfig" "执行defconfig"
    
    # 保存defconfig后的配置文件
    local defconfig_config="$output_dir/${variant}_defconfig.config"
    cp "$openwrt_dir/.config" "$defconfig_config"
    log_info "已保存defconfig后的配置文件: $defconfig_config"
    
    # 获取defconfig后的luci软件包列表
    local after_file="$output_dir/${variant}_luci_after.txt"
    get_luci_packages "$openwrt_dir/.config" > "$after_file"
    
    local after_count=$(wc -l < "$after_file")
    log_info "defconfig后的luci软件包数量: $after_count"
    
    if [ $after_count -gt 0 ]; then
        log_info "defconfig后的luci软件包列表："
        cat "$after_file" | while read -r pkg; do
            log_info "  - $pkg"
        done
    else
        log_warn "defconfig后没有找到luci软件包"
    fi
    
    # 在控制台显示诊断摘要
    print_diagnostic_summary "$before_file" "$after_file" "$openwrt_dir" "$variant"
    
    # 检查是否有软件包被删除
    local removed_packages=$(comm -23 "$before_file" "$after_file")
    local removed_count=$(echo "$removed_packages" | grep -c .)
    
    if [ $removed_count -gt 0 ]; then
        log_warn "发现 $removed_count 个软件包被删除，尝试自动修复..."
        
        # 收集所有可能的依赖
        local all_deps=""
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                local deps=$(get_package_dependencies "$package" "$openwrt_dir")
                if [ -n "$deps" ]; then
                    all_deps="$all_deps$deps"$'\n'
                    log_info "软件包 $package 的依赖: $deps"
                else
                    log_warn "无法获取软件包 $package 的依赖信息"
                fi
            fi
        done <<< "$removed_packages"
        
        # 尝试修复依赖
        if [ -n "$all_deps" ]; then
            log_info "发现的依赖包: $all_deps"
            fix_dependencies "$all_deps" "$openwrt_dir" "$config_file"
            
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
            
            # 输出缺失的软件包列表
            echo "缺失的软件包列表:" > "$output_dir/${variant}_missing_packages.txt"
            echo "$removed_packages" >> "$output_dir/${variant}_missing_packages.txt"
            
            exit 1
        fi
    else
        log_info "所有软件包配置正常，继续编译..."
    fi
    
    log_info "软件包配置诊断完成"
}

# 执行主函数
main "$@"
