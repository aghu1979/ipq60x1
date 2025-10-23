#!/bin/bash
# 配置对比脚本

set -e

CONFIG1=$1
CONFIG2=$2
REPORT_NAME=${3:-"配置对比"}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
ICON_SUCCESS="✅"
ICON_INFO="ℹ️"

# 日志函数
log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

# 检查参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <配置文件1> <配置文件2> [报告名称]"
    exit 1
fi

if [ ! -f "$1" ] || [ ! -f "$2" ]; then
    echo "配置文件不存在"
    exit 1
fi

REPORT_FILE="${REPORT_NAME}.md"

log_info "开始对比配置..."
log_info "配置1: $1"
log_info "配置2: $2"

# 提取LUCI软件包
extract_luci() {
    grep "^CONFIG_PACKAGE_luci-" "$1" 2>/dev/null | \
    sed 's/^CONFIG_PACKAGE_\(.*\)=\(.*\)/\1=\2/' | sort
}

# 提取软件包
packages1=$(extract_luci "$1")
packages2=$(extract_luci "$2")

total1=$(echo "$packages1" | grep -c '.' || echo 0)
total2=$(echo "$packages2" | grep -c '.' || echo 0)

# 生成报告
cat > "$REPORT_FILE" << EOF
# $REPORT_NAME

**对比时间**: $(date)  
**配置文件1**: $1  
**配置文件2**: $2  

## 📊 统计信息

| 项目 | 软件包数量 |
|------|-----------|
| 配置1 | $total1 |
| 配置2 | $total2 |
| 差异 | $((total2 - total1)) |

## 📋 详细对比

### ✅ 新增的软件包

| 软件包 | 状态 |
|--------|------|
EOF

# 使用临时文件对比
temp1=$(mktemp)
temp2=$(mktemp)
trap "rm -f $temp1 $temp2" EXIT

echo "$packages1" > "$temp1"
echo "$packages2" > "$temp2"

# 新增的软件包
comm -13 "$temp1" "$temp2" | while IFS= read -r line; do
    pkg=$(echo "$line" | cut -d'=' -f1)
    status=$(echo "$line" | cut -d'=' -f2)
    echo "| $pkg | $status |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

### ❌ 删除的软件包

| 软件包 | 状态 |
|--------|------|
EOF

# 删除的软件包
comm -23 "$temp1" "$temp2" | while IFS= read -r line; do
    pkg=$(echo "$line" | cut -d'=' -f1)
    status=$(echo "$line" | cut -d'=' -f2)
    echo "| $pkg | $status |" >> "$REPORT_FILE"
done

log_success "配置对比完成！"
log_info "配置1: $total1 个软件包"
log_info "配置2: $total2 个软件包"
