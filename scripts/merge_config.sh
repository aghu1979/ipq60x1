#!/bin/bash
# 配置合并脚本 - 合并多个配置文件并生成报告
# 作者: Mary
# 最后更新: 2024-01-XX

# 加载依赖模块
source ./scripts/logger.sh
source ./scripts/utils.sh

# =============================================================================
# 配置合并函数
# =============================================================================

# 合并配置文件
# 参数: $1=SoC名称, $2=分支名称, $3=配置名称
merge_configs() {
    local soc="$1"
    local branch="$2"
    local config="$3"
    
    # 开始步骤
    step_start "合并配置文件: $soc-$branch-$config"
    
    # 定义配置文件路径
    local base_config="configs/base_${soc}.config"
    local branch_config="configs/base_${branch}.config"
    local app_config="configs/${config}.config"
    
    # 验证配置文件
    echo "📋 验证配置文件..."
    for cfg in "$base_config" "$branch_config" "$app_config"; do
        if ! validate_config "$cfg"; then
            log_error "配置文件验证失败: $cfg"
            exit 1
        fi
    done
    
    # 备份原始配置
    if [ -f ".config" ]; then
        cp .config .config.backup
        echo "💾 已备份原始配置"
    fi
    
    # 显示合并顺序
    echo "📝 合并顺序（优先级从低到高）:"
    echo "  1. $base_config (基础配置)"
    echo "  2. $branch_config (分支配置)"
    echo "  3. $app_config (应用配置，最高优先级)"
    echo ""
    
    # 执行合并
    echo "🔄 开始合并配置..."
    {
        echo "# 自动生成的配置文件"
        echo "# 生成时间: $(date)"
        echo "# 合并顺序: $base_config > $branch_config > $app_config"
        echo "# SoC: $soc"
        echo "# 分支: $branch"
        echo "# 配置: $config"
        echo ""
        
        # 合并基础配置
        if [ -f "$base_config" ]; then
            echo "# === $base_config ==="
            cat "$base_config"
            echo ""
        fi
        
        # 合并分支配置
        if [ -f "$branch_config" ]; then
            echo "# === $branch_config ==="
            cat "$branch_config"
            echo ""
        fi
        
        # 合并应用配置
        if [ -f "$app_config" ]; then
            echo "# === $app_config ==="
            cat "$app_config"
            echo ""
        fi
    } > .config
    
    # 格式化配置
    echo "🔧 格式化配置文件..."
    make defconfig
    
    # 提取设备列表
    echo "🔍 提取设备列表..."
    local devices=$(extract_devices .config)
    
    # 生成配置报告
    echo "📊 生成配置报告..."
    {
        echo "配置合并报告: $soc-$branch-$config"
        echo "生成时间: $(date)"
        echo ""
        echo "设备列表:"
        echo "$devices"
        echo ""
        echo "Luci应用列表:"
        grep "^CONFIG_PACKAGE_luci-app.*=y" .config | cut -d'=' -f1 | sort || echo "无"
        echo ""
        echo "内核配置:"
        grep "^CONFIG_KERNEL" .config | head -5 || echo "无"
        echo ""
        echo "配置统计:"
        echo "  - 总配置项数量: $(grep -c "^CONFIG_" .config)"
        echo "  - Luci应用数量: $(grep -c "^CONFIG_PACKAGE_luci-app.*=y" .config)"
        echo "  - 设备数量: $(echo "$devices" | wc -l)"
    } > config_report.txt
    
    # 显示合并后的关键信息
    echo ""
    echo "📊 合并结果摘要:"
    echo "  - 设备数量: $(echo "$devices" | wc -l)"
    echo "  - Luci应用数量: $(grep -c "^CONFIG_PACKAGE_luci-app.*=y" .config)"
    echo "  - 总配置项: $(grep -c "^CONFIG_" .config)"
    
    # 生成配置差异（如果有备份）
    if [ -f ".config.backup" ]; then
        echo ""
        echo "📋 生成配置差异报告..."
        generate_config_diff .config.backup .config config_diff.txt
        
        # 显示主要变更
        echo ""
        echo "📋 主要配置变更:"
        if [ -s "config_diff.txt" ]; then
            grep -E "^(新增|删除|修改)" config_diff.txt | head -10
        else
            echo "  无变更"
        fi
    fi
    
    # 结束步骤
    step_end "配置合并完成"
}

# =============================================================================
# 配置完整性检查函数
# =============================================================================

# 检查配置完整性
# 参数: $1=配置文件路径
# 返回: 0=完整, 1=不完整
check_config_integrity() {
    local config_file="$1"
    
    log_info "检查配置完整性: $config_file"
    
    # 定义必需的配置模式
    local required_patterns=(
        "CONFIG_TARGET_"
        "CONFIG_PACKAGE_"
    )
    
    local missing=()
    
    # 检查每个必需模式
    for pattern in "${required_patterns[@]}"; do
        if ! grep -q "^$pattern" "$config_file"; then
            missing+=("$pattern")
        fi
    done
    
    # 如果有缺失的模式
    if [ ${#missing[@]} -gt 0 ]; then
        log_warning "缺少必需的配置模式: ${missing[*]}"
        return 1
    fi
    
    log_success "配置完整性检查通过"
    return 0
}

# =============================================================================
# 配置优化函数
# =============================================================================

# 优化配置文件
# 参数: $1=配置文件路径
optimize_config() {
    local config_file="$1"
    
    log_info "优化配置文件: $config_file"
    
    # 移除重复的配置项
    local temp_file=$(mktemp)
    awk '!seen[$0]++' "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    # 排序配置项
    sort -o "$config_file" "$config_file"
    
    log_success "配置文件优化完成"
}

# =============================================================================
# 配置验证函数
# =============================================================================

# 验证配置语法
# 参数: $1=配置文件路径
# 返回: 0=有效, 1=无效
validate_config_syntax() {
    local config_file="$1"
    
    log_info "验证配置语法: $config_file"
    
    # 检查配置文件格式
    local invalid_count=0
    
    # 检查每行配置
    while IFS= read -r line; do
        # 跳过注释和空行
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        # 检查配置项格式
        if [[ ! "$line" =~ ^CONFIG_[A-Z0-9_]+=.+$ ]]; then
            echo "⚠️ 无效配置格式: $line"
            ((invalid_count++))
        fi
    done < "$config_file"
    
    # 返回验证结果
    if [ $invalid_count -gt 0 ]; then
        log_error "发现 $invalid_count 个无效配置项"
        return 1
    else
        log_success "配置语法验证通过"
        return 0
    fi
}

# =============================================================================
# 主函数
# =============================================================================

# 主函数
# 参数: $1=SoC名称, $2=分支名称, $3=配置名称
main() {
    # 检查参数
    if [ $# -ne 3 ]; then
        echo "❌ 用法错误"
        echo "用法: $0 <soc> <branch> <config>"
        echo "示例: $0 ipq60xx openwrt Pro"
        exit 1
    fi
    
    # 执行合并
    merge_configs "$1" "$2" "$3"
    
    # 检查完整性
    check_config_integrity .config
    
    # 验证语法
    validate_config_syntax .config
    
    # 优化配置
    optimize_config .config
    
    log_success "配置合并流程完成"
}

# =============================================================================
# 脚本入口点
# =============================================================================

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
