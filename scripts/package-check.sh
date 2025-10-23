#!/bin/bash
# LUCI软件包检查和自动修复脚本

set -e

# 参数解析
CONFIG_FILE=$1
REPORT_NAME=${2:-"luci-check"}
AUTO_FIX=${3:-"true"}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_REPAIR="🔧"
ICON_PACKAGE="📦"

# 日志函数
log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${ICON_ERROR} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING} $1${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
LUCI软件包检查和自动修复脚本

用法: $0 <配置文件> [报告名称] [修复模式]

参数:
  配置文件    OpenWrt配置文件路径
  报告名称    报告文件名前缀 (默认: luci-check)
 修复模式    是否自动修复 (true/false, 默认: true)

示例:
  $0 .config "基础系统检查" true
  $0 .config.user "最终检查" false

EOF
}

# 检查参数
check_params() {
    if [ -z "$CONFIG_FILE" ]; then
        log_error "请提供配置文件路径"
        show_help
        exit 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    
    # 设置报告文件
    REPORT_FILE="${REPORT_NAME}.md"
    
    log_info "开始检查LUCI软件包..."
    log_info "配置文件: $CONFIG_FILE"
    log_info "报告文件: $REPORT_FILE"
    log_info "自动修复: $AUTO_FIX"
}

# 提取LUCI软件包
extract_luci_packages() {
    # 修复：使用更可靠的方法提取软件包
    grep "^CONFIG_PACKAGE_luci-" "$CONFIG_FILE" 2>/dev/null | \
    sed -n 's/^CONFIG_PACKAGE_luci-\([^=]*)=\(.*\)/\1=\2/' | \
    grep -v '^$' | sort
}

# 主检查函数
check_packages() {
    log_info "提取LUCI软件包列表..."
    
    local luci_packages=$(extract_luci_packages)
    local total_packages=$(echo "$luci_packages" | grep -c '.' || echo 0)
    
    if [ $total_packages -eq 0 ]; then
        log_warning "配置文件中没有LUCI软件包"
        cat > "$REPORT_FILE" << EOF
# $REPORT_NAME

**检查时间**: $(date)  
**配置文件**: $CONFIG_FILE  

ℹ️ 配置文件中没有LUCI软件包
EOF
        return 0
    fi
    
    log_info "发现 $total_packages 个LUCI软件包"
    
    # 调试输出
    log_info "软件包列表:"
    echo "$luci_packages" | sed 's/^/  /'
    
    # 生成报告头部
    generate_report_header $total_packages
    
    # 检查每个软件包
    while IFS= read -r pkg_line; do
        if [ -n "$pkg_line" ]; then
            # 修复：正确解析软件包名称和状态
            pkg=$(echo "$pkg_line" | cut -d'=' -f1)
            status=$(echo "$pkg_line" | cut -d'=' -f2)
            
            log_info "检查软件包: $pkg (状态: $status)"
            
            local location=$(get_package_location "$pkg")
            
            if [ "$location" != "缺失" ]; then
                log_success "$pkg - 可用 ($location)"
                printf '| %s | ✅ 可用 | %s | - |\n' "$pkg" "$location" >> "$REPORT_FILE"
                ((FOUND_COUNT++))
            else
                log_error "$pkg - 缺失"
                printf '| %s | ❌ 缺失 | - | 需要修复 |\n' "$pkg" >> "$REPORT_FILE"
                ((MISSING_COUNT++))
                MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
            fi
        fi
    done <<< "$luci_packages"
    
    log_info "检查完成: 找到 $FOUND_COUNT 个，缺失 $MISSING_COUNT 个"
    
    # 自动修复
    if [ "$AUTO_FIX" = "true" ] && [ $MISSING_COUNT -gt 0 ]; then
        log_repair "开始自动修复缺失的软件包..."
        
        for pkg in $MISSING_PACKAGES; do
            if try_fix_package "$pkg"; then
                ((REPAIRED_COUNT++))
            fi
        done
        
        # 修复后更新配置
        if [ $REPAIRED_COUNT -gt 0 ]; then
            log_repair "修复后更新配置..."
            make defconfig
        fi
        
        # 最终检查
        log_info "验证修复结果..."
        FINAL_MISSING_COUNT=0
        for pkg in $MISSING_PACKAGES; do
            if check_package_exists "$pkg"; then
                log_success "$pkg - 已修复"
            else
                log_error "$pkg - 仍然缺失"
                ((FINAL_MISSING_COUNT++))
            fi
        done
        
        # 生成报告统计
        generate_report_stats $total_packages $FOUND_COUNT $MISSING_COUNT $REPAIRED_COUNT $FINAL_MISSING_COUNT
        
        # 输出报告摘要
        echo ""
        log_info "报告摘要:"
        echo "  - 总软件包数: $total_packages"
        echo "  - 找到软件包: $FOUND_COUNT"
        echo "  - 缺失软件包: $MISSING_COUNT"
        if [ "$AUTO_FIX" = "true" ] && [ $MISSING_COUNT -gt 0 ]; then
            echo "  - 成功修复: $REPAIRED_COUNT"
            echo "  - 仍然缺失: $FINAL_MISSING_COUNT"
        fi
        
        # 输出报告内容
        echo ""
        log_info "详细报告内容:"
        echo "=========================="
        cat "$REPORT_FILE"
        echo "=========================="
        
        # 返回结果
        if [ $FINAL_MISSING_COUNT -gt 0 ]; then
            log_error "仍有 $FINAL_MISSING_COUNT 个软件包无法修复"
            return 1
        else
            log_success "所有LUCI软件包检查通过！"
            return 0
        fi
}

# 获取软件包位置
get_package_location() {
    local pkg=$1
    if [ -d "package/feeds/packages/$pkg" ]; then
        echo "packages"
    elif [ -d "package/feeds/luci/$pkg" ]; then
        echo "luci"
    elif [ -d "package/$pkg" ]; then
        echo "local"
    else
        echo "缺失"
    fi
}

# 尝试修复软件包
try_fix_package() {
    local pkg=$1
    
    log_repair "尝试修复软件包: $pkg"
    
    # 查找相似软件包
    local similar=$(find_similar_packages "$pkg")
    if [ -n "$similar" ]; then
        log_info " 找到相似的软件包:"
        echo "$similar" | sed 's/^/    /'
    fi
    
    # 尝试重新安装feeds
    log_info " 尝试重新安装feeds..."
    if ./scripts/feeds install "$pkg" 2>/dev/null; then
        log_success " $pkg - 成功安装"
        return 0
    else
        log_error "修复失败: $pkg"
        return 1
    fi
}

# 生成报告头部
generate_report_header() {
    local total_packages=$1
    cat > "$REPORT_FILE" << EOF
# $REPORT_NAME

**检查时间**: $(date)  
**配置文件**: $CONFIG_FILE  
**总软件包数**: $total_packages  

## 📦 软件可用性检查

| 软件 | 状态 | 位置 | 备注 |
|--------|------|------|
EOF
}

# 生成报告统计
generate_report_stats() {
    local total=$1
    local found=$2
    local missing=$3
    local repaired=$4
    local final_missing=$5
    
    cat >> "$REPORT_FILE" << EOF
## 📊� 统计信息

- 总软件包数: $total
- 找到软件包: $found
- 缺失软件包: $missing
EOF
    
    # 修复：避免除零错误
    if [ $total -gt 0 ]; then
        echo "- 成功率: $(( found * 100 / total ))%" >> "$REPORT_FILE"
    else
        echo "- 成功率: 0%" >> "$REPORT_FILE"
    fi
    
    if [ "$AUTO_FIX" = "true" ] && [ $missing -gt 0 ]; then
        cat >> "$REPORT_FILE" << EOF
## 🔧 自动修复结果

- 尝试修复: $missing
- 成功修复: $repaired
- 仍然缺失: $final_missing
EOF
    fi
}

# 主函数
main() {
    # 检查是否在OpenWrt目录
    if [ ! -f "rules.mk" ] || [ ! -d "package" ]; then
        log_error "请在OpenWrt源码目录中运行此脚本"
        exit 1
    fi
    
    # 检查参数
    check_params
    
    # 执行检查
    if check_packages; then
        log_success "LUCI软件包检查完成！"
        exit 0
    else
        log_error "LUCI软件包检查失败"
        exit 1
    fi
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
