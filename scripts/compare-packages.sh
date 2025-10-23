#!/bin/bash
# OpenWrt软件包对比脚本

set -e

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

# 显示帮助信息
show_help() {
    cat << EOF
OpenWrt软件包对比脚本

用法: $0 <配置文件1> <配置文件2> [报告名称]

参数:
  配置文件1    第一个配置文件路径
  配置文件2    第二个配置文件路径
  报告名称    报告文件名前缀 (可选)

示例:
  $0 .config.old .config.new "配置变更"
  $0 .config.base .config.user "用户配置对比"

EOF
}

# 检查参数
check_params() {
    if [ $# -lt 2 ]; then
        log_error "请提供两个配置文件路径"
        show_help
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        log_error "配置文件1不存在: $1"
        exit 1
    fi
    
    if [ ! -f "$2" ]; then
        log_error "配置文件2不存在: $2"
        exit 1
    fi
}

# 提取LUCI软件包
extract_luci_packages() {
    local config_file=$1
    # 修复：使用更精确的正则表达式提取软件包
    grep "^CONFIG_PACKAGE_luci-" "$config_file" 2>/dev/null | \
    sed -n 's/^CONFIG_PACKAGE_luci-\([^=]*)=\(.*\)/\1=\2/' | \
    grep -v '^$' | sort
}

# 主对比函数
compare_packages() {
    local config1=$1
    local config2=$2
    local report_name=${3:-"软件包对比"}
    local report_file="${report_name}.md"
    
    log_info "开始对比LUCI软件包..."
    log_info "配置文件1: $config1"
    log_info "配置文件2: $config2"
    
    # 提取软件包
    local packages1=$(extract_luci_packages "$config1")
    local packages2=$(extract_luci_packages "$config2")
    
    local total1=$(echo "$packages1" | grep -c '.' || echo 0)
    local total2=$(echo "$packages2" | grep -c '.' || echo 0)
    
    log_info "配置1软件包数: $total1"
    log_info "配置2软件包数: $total2"
    
    # 调试输出
    log_info "配置1软件包列表:"
    echo "$packages1" | sed 's/^/  /'
    log_info "配置2软件包列表:"
    echo "$packages2" | sed 's/^/  /'
    
    # 创建临时文件
    local temp1=$(mktemp)
    local temp2=$(mktemp)
    trap "rm -f $temp1 $temp2" EXIT
    
    echo "$packages1" > "$temp1"
    echo "$packages2" > "$temp2"
    
    # 生成报告
    cat > "$report_file" << EOF
# $report_name

**对比时间**: $(date)  
**配置文件1**: $config1  
**配置文件2**: $config2  

## 📊 软件包统计

| 项目 | 软件包数量 |
|------|-----------|
| 配置1 | $total1 |
| 配置2 | $total2 |
| 差异 | $((total2 - total1)) |

## 📋 软件详细对比

EOF
    
    # 找出新增的软件包
    local added=$(comm -13 "$temp1" "$temp2")
    if [ -n "$added" ]; then
        log_info "新增的软件包:"
        echo "$added" | while IFS= read -r line; do
            local pkg=$(echo "$line" | cut -d'=' -f1)
            local status=$(echo "$line" | cut -d'=' -f2)
            echo "  + $pkg ($status)"
        done
        
        cat >> "$report_file" << EOF
### ✅ 新增的软件包

| 软件 | 状态 | 说明 |
|--------|------|------|
EOF
        echo "$added" | while IFS= read -r line; do
            local pkg=$(echo "$line" | cut -d'=' -f1)
            local status=$(echo "$line" | cut -d'=' -f2)
            echo "| $pkg | $status | 新增安装 |" >> "$report_file"
        done
        echo "" >> "$report_file"
    fi
    
    # 找出删除的软件包
    local removed=$(comm -23 "$temp1" "$temp2")
    if [ -n "$removed" ]; then
        log_info "删除的软件包:"
        echo "$removed" | while IFS= read -r line; do
            local pkg=$(echo "$line" | cut -d'=' -f1)
            local status=$(echo "$line" | cut -d'=' -f2)
            echo "  - $pkg ($status)"
        done
        
        cat >> "$report_file" << EOF
### ❌ 删除的软件包

| 软件 | 状态 | 说明 |
|--------|------|------|
EOF
        echo "$removed" | while IFS= read -r line; do
            local pkg=$(echo "$line" | cut -d'=' -f1)
            local status=$(echo "$line" | cut -d'=' -f2)
            echo "| $pkg | $status | 已移除 |" >> "$report_file"
        done
        echo "" >> "$report_file"
    fi
    
    # 找出状态改变的软件包
    local changed_count=0
    cat >> "$report_file" << EOF
### 🔄 状态改变的软件包

| 软件 | 状态 | 说明 |
|--------|------|------|
EOF
    
    # 创建状态映射
    declare -A status1 status2
    while IFS='=' read -r pkg status; do
        if [ -n "$pkg" ]; then
            status1["$pkg"]="$status"
        fi
    done < "$temp1"
    
    while IFS='=' read -r pkg status; do
        if [ -n "$pkg" ]; then
            status2["$pkg"]="$status"
        fi
    done < "$temp2"
    
    # 检查状态改变
    for pkg in "${!status1[@]}"; do
        if [[ -n "${status2[$pkg]}" && "${status1[$pkg]}" != "${status2[$pkg]}" ]]; then
            echo "  🔄 $pkg (${status1[$pkg]} → ${status2[$pkg]})"
            echo "| $pkg | ${status1[$pkg]} → ${status2[$pkg]} | 状态改变 |" >> "$report_file"
            ((changed_count++))
        fi
    done
    
    if [ $changed_count -eq 0 ]; then
        echo "| 无 | 无 | 无状态改变 |" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # 添加完整软件包列表
    cat >> "$report_file" << EOF
## 📦 完整软件包列表

### 配置1中的软件包
| 软件 | 状态 |
|--------|------|
EOF
    echo "$packages1" | while IFS='=' read -r pkg status; do
        echo "| $pkg | $status |" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

### 配置2中的软件包
| 软件 | 状态 |
|--------|------|------|
EOF
    echo "$packages2" | while IFS='=' read -r pkg status; do
        echo "| $pkg | $status |" >> "$report_file"
    done
    
    # 输出摘要
    local added_count=$(echo "$added" | grep -c '.' || echo 0)
    local removed_count=$(echo "$removed" | grep -c '.' || echo 0)
    
    log_info "对比摘要:"
    echo "  - 新增软件包: $added_count"
    echo "  - 删除软件包: $removed_count"
    echo "  - 状态改变: $changed_count"
    echo "  - 报告文件: $report_file"
    
    log_success "软件包对比完成！"
}

# 主函数
main() {
    # 检查参数
    check_params "$@"
    
    # 执行对比
    compare_packages "$@"
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
