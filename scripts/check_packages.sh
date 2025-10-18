#!/bin/bash
# 软件包检查脚本 - 检查和修复软件包依赖
# 作者: Mary
# 最后更新: 2024-01-XX

# 加载依赖模块
source ./scripts/logger.sh
source ./scripts/utils.sh

# =============================================================================
# 软件包获取函数
# =============================================================================

# 获取配置中的软件包列表
# 参数: $1=配置文件路径, $2=软件包类型（默认luci-app）
# 返回: 软件包列表
get_config_packages() {
    local config_file="$1"
    local package_type="${2:-luci-app}"  # 默认检查luci-app
    
    # 从配置文件中提取软件包
    grep "^CONFIG_PACKAGE_${package_type}.*=y" "$config_file" | \
        cut -d'=' -f1 | \
        sed "s/CONFIG_PACKAGE_//" | \
        sort
}

# =============================================================================
# 软件包检查函数
# =============================================================================

# 检查软件包是否存在
# 参数: $1=软件包名称
# 返回: 0=存在, 1=不存在
check_package_exists() {
    local package_name="$1"
    
    # 定义搜索路径
    local search_paths=(
        "package/feeds/"
        "package/"
        "feeds/packages/"
        "feeds/luci/"
    )
    
    # 在各个路径中搜索
    for path in "${search_paths[@]}"; do
        if find "$path" -name "${package_name}*" -type d 2>/dev/null | grep -q .; then
            return 0
        fi
    done
    
    return 1
}

# =============================================================================
# 依赖检查函数
# =============================================================================

# 检查软件包依赖
# 参数: $1=软件包名称
# 返回: 0=成功, 1=失败
check_package_dependencies() {
    local package_name="$1"
    local depends_file=""
    
    log_info "检查软件包依赖: $package_name"
    
    # 查找依赖文件
    for path in "package/feeds/" "package/" "feeds/"; do
        depends_file=$(find "$path" -name "${package_name}" -type d -exec find {} -name "Makefile" \; 2>/dev/null | head -n1)
        if [ -n "$depends_file" ]; then
            break
        fi
    done
    
    # 如果没有找到Makefile
    if [ -z "$depends_file" ]; then
        echo "⚠️ 未找到软件包 $package_name 的Makefile"
        return 1
    fi
    
    # 提取依赖
    local depends=$(grep "^DEPENDS:=" "$depends_file" | sed 's/DEPENDS:=//')
    
    # 显示依赖信息
    if [ -n "$depends" ]; then
        echo "📦 $package_name 的依赖: $depends"
        
        # 检查每个依赖是否满足
        for dep in $depends; do
            # 清理依赖名称
            dep=$(echo "$dep" | sed 's/[+<>].*//')
            if [ -n "$dep" ] && [ "$dep" != "@" ]; then
                if grep -q "CONFIG_PACKAGE_${dep}=y" .config; then
                    echo "  ✅ $dep (已满足)"
                else
                    echo "  ❌ $dep (未满足)"
                fi
            fi
        done
    else
        echo "ℹ️ $package_name 无明确依赖"
    fi
    
    return 0
}

# =============================================================================
# 软件包修复函数
# =============================================================================

# 尝试修复缺失的软件包
# 参数: $1=软件包名称
# 返回: 0=成功, 1=失败
fix_missing_package() {
    local package_name="$1"
    
    log_info "尝试修复缺失的软件包: $package_name"
    
    # 步骤1: 更新feeds
    echo "  🔄 更新feeds..."
    if ./scripts/feeds update -a >/dev/null 2>&1; then
        echo "  ✅ feeds更新成功"
    else
        echo "  ⚠️ feeds更新失败，继续尝试..."
    fi
    
    # 步骤2: 安装软件包
    echo "  📦 安装软件包: $package_name"
    if ./scripts/feeds install "$package_name" 2>/dev/null; then
        echo "  ✅ 成功安装: $package_name"
        return 0
    fi
    
    # 步骤3: 尝试从官方源编译
    echo "  🔨 尝试编译软件包..."
    if make package/"$package_name"/compile 2>/dev/null; then
        echo "  ✅ 成功编译: $package_name"
        return 0
    fi
    
    # 步骤4: 尝试强制安装
    echo "  🔧 尝试强制安装..."
    if echo "CONFIG_PACKAGE_${package_name}=y" >> .config && make defconfig; then
        echo "  ✅ 强制启用配置: $package_name"
        return 0
    fi
    
    # 所有尝试都失败
    log_error "无法修复软件包: $package_name"
    return 1
}

# =============================================================================
# 报告生成函数
# =============================================================================

# 生成软件包报告
# 参数: $1=配置文件路径, $2=输出文件路径
generate_package_report() {
    local config_file="$1"
    local output_file="package_report.txt"
    
    log_info "生成软件包报告: $output_file"
    
    # 生成报告
    {
        echo "# 软件包检查报告"
        echo "生成时间: $(date)"
        echo "配置文件: $config_file"
        echo ""
        
        echo "## 配置中的Luci应用"
        get_config_packages "$config_file" "luci-app" | while read pkg; do
            echo "- $pkg"
        done
        echo ""
        
        echo "## 配置中的其他软件包"
        grep "^CONFIG_PACKAGE_.*=y" "$config_file" | \
            grep -v "luci-app" | \
            cut -d'=' -f1 | \
            sed "s/CONFIG_PACKAGE_//" | \
            sort | \
            while read pkg; do
                echo "- $pkg"
            done
        echo ""
        
        echo "## 检查结果"
        echo "详见日志输出"
        echo ""
        
        echo "## 统计信息"
        echo "- Luci应用数量: $(get_config_packages "$config_file" "luci-app" | wc -l)"
        echo "- 其他软件包数量: $(grep "^CONFIG_PACKAGE_.*=y" "$config_file" | grep -v "luci-app" | wc -l)"
        echo "- 总软件包数量: $(grep "^CONFIG_PACKAGE_.*=y" "$config_file" | wc -l)"
    } > "$output_file"
    
    log_success "软件包报告已生成: $output_file"
}

# =============================================================================
# 主检查函数
# =============================================================================

# 主检查函数
# 参数: $1=配置文件路径（默认.config）
check_packages() {
    local config_file="${1:-.config}"
    
    # 开始步骤
    step_start "检查软件包"
    
    # 获取配置中的软件包
    local config_packages=$(get_config_packages "$config_file")
    local missing_packages=()
    local conflict_packages=()
    local fixed_packages=()
    local failed_packages=()
    
    # 如果没有找到软件包
    if [ -z "$config_packages" ]; then
        log_warning "配置中未找到Luci应用软件包"
        step_end "软件包检查完成"
        return 0
    fi
    
    # 显示检查信息
    local package_count=$(echo "$config_packages" | wc -l)
    log_info "检查 $package_count 个软件包..."
    
    # 检查每个软件包
    local current=0
    while IFS= read -r package; do
        ((current++))
        show_progress $current $package_count "检查软件包"
        
        # 检查软件包是否存在
        if check_package_exists "$package"; then
            echo "  ✅ $package (存在)"
            # 检查依赖
            check_package_dependencies "$package"
        else
            echo "  ❌ $package (缺失)"
            missing_packages+=("$package")
            
            # 尝试修复
            if fix_missing_package "$package"; then
                fixed_packages+=("$package")
            else
                failed_packages+=("$package")
            fi
        fi
    done <<< "$config_packages"
    
    # 生成报告
    generate_package_report "$config_file"
    
    # 输出摘要
    echo ""
    echo "📊 检查摘要:"
    echo "  - 总软件包数: $package_count"
    echo "  - 缺失软件包: ${#missing_packages[@]}"
    echo "  - 修复成功: ${#fixed_packages[@]}"
    echo "  - 修复失败: ${#failed_packages[@]}"
    
    # 检查是否还有缺失的软件包
    local still_missing=()
    for pkg in "${missing_packages[@]}"; do
        if ! check_package_exists "$pkg"; then
            still_missing+=("$pkg")
        fi
    done
    
    # 如果还有缺失的软件包
    if [ ${#still_missing[@]} -gt 0 ]; then
        log_error "仍有 ${#still_missing[@]} 个软件包缺失:"
        for pkg in "${still_missing[@]}"; do
            echo "    - $pkg"
        done
        
        # 生成详细错误报告
        {
            echo "# 软件包缺失错误报告"
            echo "时间: $(date)"
            echo "配置文件: $config_file"
            echo ""
            echo "缺失的软件包:"
            for pkg in "${still_missing[@]}"; do
                echo "- $pkg"
            done
            echo ""
            echo "可能的解决方案:"
            echo "1. 检查软件包名称是否正确"
            echo "2. 更新软件源 (./scripts/feeds update -a)"
            echo "3. 检查网络连接"
            echo "4. 确认软件包适用于当前架构"
            echo "5. 查看软件包是否已被弃用"
            echo ""
            echo "详细日志:"
            echo "- 完整日志: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
            echo "- 错误日志: 查看Actions日志"
        } > package_missing_error.md
        
        echo ""
        echo "📄 详细错误报告: package_missing_error.md"
        echo "🔗 查看完整日志: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
        
        step_end "软件包检查完成（有错误）"
        return 1
    else
        log_success "所有软件包检查通过"
        step_end "软件包检查完成"
        return 0
    fi
}

# =============================================================================
# 冲突检查函数
# =============================================================================

# 检查软件包冲突
# 参数: $1=配置文件路径
check_package_conflicts() {
    local config_file="$1"
    
    log_info "检查软件包冲突..."
    
    # 定义常见的冲突软件包对
    local conflicts=(
        "luci-app-passwall:luci-app-openclash"
        "luci-app-adguardhome:luci-app-adguardhome"
        "luci-app-shadowsocks-libev:luci-app-v2ray-pro"
        "luci-app-turboacc:luci-app-flowoffload"
    )
    
    local conflict_count=0
    
    # 检查每个冲突对
    for conflict in "${conflicts[@]}"; do
        local pkg1=$(echo "$conflict" | cut -d':' -f1)
        local pkg2=$(echo "$conflict" | cut -d':' -f2)
        
        # 检查是否同时启用了冲突的软件包
        local has_pkg1=$(grep "^CONFIG_PACKAGE_${pkg1}=y" "$config_file" >/dev/null && echo "1" || echo "0")
        local has_pkg2=$(grep "^CONFIG_PACKAGE_${pkg2}=y" "$config_file" >/dev/null && echo "1" || echo "0")
        
        if [ "$has_pkg1" = "1" ] && [ "$has_pkg2" = "1" ]; then
            log_warning "检测到潜在的软件包冲突: $pkg1 与 $pkg2"
            echo "  ⚠️ 建议只选择其中一个"
            ((conflict_count++))
        fi
    done
    
    # 输出冲突检查结果
    if [ $conflict_count -gt 0 ]; then
        log_warning "发现 $conflict_count 个潜在冲突"
    else
        log_success "未发现软件包冲突"
    fi
}

# =============================================================================
# 主函数
# =============================================================================

# 主函数
# 参数: $1=配置文件路径（默认.config）
main() {
    local config_file="${1:-.config}"
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        exit 1
    fi
    
    # 执行软件包检查
    check_packages "$config_file"
    
    # 检查软件包冲突
    check_package_conflicts "$config_file"
    
    log_success "软件包检查流程完成"
}

# =============================================================================
# 脚本入口点
# =============================================================================

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
