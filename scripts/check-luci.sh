#!/bin/bash
# LUCI软件包检查脚本

set -e

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

# 检查参数
if [ -z "$CONFIG_FILE" ]; then
    log_error "请提供配置文件路径"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

REPORT_FILE="${REPORT_NAME}.md"

log_info "开始检查LUCI软件包..."
log_info "配置文件: $CONFIG_FILE"
log_info "报告文件: $REPORT_FILE"

# 提取LUCI软件包
extract_luci_packages() {
    grep "^CONFIG_PACKAGE_luci-" "$CONFIG_FILE" 2>/dev/null | \
    sed 's/^CONFIG_PACKAGE_\(.*\)=\(.*\)/\1=\2/' | sort
}

# 主检查函数
main() {
    local luci_packages=$(extract_luci_packages)
    local total_packages=$(echo "$luci_packages" | grep -c '.' || echo 0)
    
    if [ $total_packages -eq 0 ]; then
        log_info "配置文件中没有LUCI软件包"
        return 0
    fi
    
    log_info "发现 $total_packages 个LUCI软件包"
    
    # 生成报告
    cat > "$REPORT_FILE" << EOF
# $REPORT_NAME

**检查时间**: $(date)  
**配置文件**: $CONFIG_FILE  
**总软件包数**: $total_packages  

## 📦 软件包列表

| 软件 | 状态 | 位置 |
|--------|------|------|
EOF
    
    local found_count=0
    local missing_count=0
    local missing_packages=""
    
    # 检查每个软件包
    while IFS= read -r pkg_line; do
        if [ -n "$pkg_line" ]; then
            pkg=$(echo "$pkg_line" | cut -d'=' -f1)
            status=$(echo "$pkg_line" | cut -d'=' -f2)
            
            # 检查软件包位置
            if [ -d "package/feeds/packages/$pkg" ]; then
                location="packages"
            elif [ -d "package/feeds/luci/$pkg" ]; then
                location="luci"
            elif [ -d "package/$pkg" ]; then
                location="local"
            else
                location="缺失"
            fi
            
            if [ "$location" != "缺失" ]; then
                echo "| $pkg | $status | $location |" >> "$REPORT_FILE"
                ((found_count++))
            else
                echo "| $pkg | $status | 缺失 |" >> "$REPORT_FILE"
                ((missing_count++))
                missing_packages="$missing_packages $pkg"
            fi
        fi
    done <<< "$luci_packages"
    
    # 自动修复
    if [ "$AUTO_FIX" = "true" ] && [ $missing_count -gt 0 ]; then
        log_info "尝试修复缺失的软件包..."
        for pkg in $missing_packages; do
            ./scripts/feeds install "$pkg" 2>/dev/null || log_error "修复失败: $pkg"
        done
        make defconfig
    fi
    
    # 添加统计信息
    cat >> "$REPORT_FILE" << EOF

## 📊 统计信息

- 找到软件包: $found_count
- 缺失软件包: $missing_count
EOF
    
    if [ $total_packages -gt 0 ]; then
        echo "- 成功率: $(( found_count * 100 / total_packages ))%" >> "$REPORT_FILE"
    fi
    
    log_success "LUCI软件包检查完成！"
    log_info "找到: $found_count, 缺失: $missing_count"
}

main
