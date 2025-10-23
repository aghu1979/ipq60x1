#!/bin/bash
# 软件包对比脚本
# 用法: compare-packages.sh <配置文件1> <配置文件2> <阶段名称>

CONFIG1=$1
CONFIG2=$2
STAGE=$3
REPORT_FILE="luci-packages-${STAGE}.md"

echo "🔍 开始对比LUCI软件包 - $STAGE 阶段"

# 创建报告文件
cat > "$REPORT_FILE" << EOF
# LUCI软件包对比报告 - $STAGE 阶段

**对比时间**: $(date)  
**配置文件1**: $CONFIG1  
**配置文件2**: $CONFIG2  

## 📊 软件包统计

EOF

# 提取LUCI软件包
extract_luci_packages() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        grep "^CONFIG_PACKAGE_luci-" "$config_file" 2>/dev/null | \
        sed 's/^CONFIG_PACKAGE_\(.*\)=\(.*\)/\1=\2/' | \
        sort
    fi
}

# 获取两个配置的软件包
PACKAGES1=$(extract_luci_packages "$CONFIG1")
PACKAGES2=$(extract_luci_packages "$CONFIG2")

# 统计数量
TOTAL1=$(echo "$PACKAGES1" | wc -l)
TOTAL2=$(echo "$PACKAGES2" | wc -l)

echo "📦 配置1 LUCI软件包数: $TOTAL1"
echo "📦 配置2 LUCI软件包数: $TOTAL2"

# 写入统计信息
cat >> "$REPORT_FILE" << EOF
| 项目 | 软件包数量 |
|------|-----------|
| 配置1 | $TOTAL1 |
| 配置2 | $TOTAL2 |
| 差异 | $((TOTAL2 - TOTAL1)) |

## 📋 软件包详细对比

EOF

# 创建临时文件
TEMP1=$(mktemp)
TEMP2=$(mktemp)
trap "rm -f $TEMP1 $TEMP2" EXIT

# 保存软件包列表
echo "$PACKAGES1" > "$TEMP1"
echo "$PACKAGES2" > "$TEMP2"

# 找出新增的软件包（在配置2中但不在配置1中）
echo "🔍 检查新增的软件包..."
ADDED=$(comm -13 "$TEMP1" "$TEMP2")
if [ -n "$ADDED" ]; then
    echo "✅ 新增的LUCI软件包:"
    echo "$ADDED" | while IFS= read -r line; do
        pkg=$(echo "$line" | cut -d'=' -f1)
        status=$(echo "$line" | cut -d'=' -f2)
        echo "  + 🟢 $pkg (状态: $status)"
    done
    
    cat >> "$REPORT_FILE" << EOF
### ✅ 新增的软件包

| 软件包 | 状态 | 说明 |
|--------|------|------|
EOF
    echo "$ADDED" | while IFS= read -r line; do
        pkg=$(echo "$line" | cut -d'=' -f1)
        status=$(echo "$line" | cut -d'=' -f2)
        echo "| $pkg | $status | 新增安装 |" >> "$REPORT_FILE"
    done
    echo "" >> "$REPORT_FILE"
else
    echo "ℹ️ 无新增软件包"
    echo "ℹ️ 无新增软件包" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# 找出删除的软件包（在配置1中但不在配置2中）
echo "🔍 检查删除的软件包..."
REMOVED=$(comm -23 "$TEMP1" "$TEMP2")
if [ -n "$REMOVED" ]; then
    echo "❌ 删除的LUCI软件包:"
    echo "$REMOVED" | while IFS= read -r line; do
        pkg=$(echo "$line" | cut -d'=' -f1)
        status=$(echo "$line" | cut -d'=' -f2)
        echo "  - 🔴 $pkg (状态: $status)"
    done
    
    cat >> "$REPORT_FILE" << EOF
### ❌ 删除的软件包

| 软件包 | 状态 | 说明 |
|--------|------|------|
EOF
    echo "$REMOVED" | while IFS= read -r line; do
        pkg=$(echo "$line" | cut -d'=' -f1)
        status=$(echo "$line" | cut -d'=' -f2)
        echo "| $pkg | $status | 已移除 |" >> "$REPORT_FILE"
    done
    echo "" >> "$REPORT_FILE"
else
    echo "ℹ️ 无删除软件包"
    echo "ℹ️ 无删除软件包" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# 找出状态改变的软件包
echo "🔍 检查状态改变的软件包..."
echo "🔄 状态改变的软件包:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 创建状态映射
declare -A status1 status2
while IFS='=' read -r pkg status; do
    status1["$pkg"]="$status"
done < "$TEMP1"

while IFS='=' read -r pkg status; do
    status2["$pkg"]="$status"
done < "$TEMP2"

CHANGED_COUNT=0
for pkg in "${!status1[@]}"; do
    if [[ -n "${status2[$pkg]}" && "${status1[$pkg]}" != "${status2[$pkg]}" ]]; then
        echo "  🔄 🟡 $pkg (${status1[$pkg]} → ${status2[$pkg]})"
        echo "| $pkg | ${status1[$pkg]} → ${status2[$pkg]} | 状态改变 |" >> "$REPORT_FILE"
        ((CHANGED_COUNT++))
    fi
done

if [ $CHANGED_COUNT -eq 0 ]; then
    echo "ℹ️ 无状态改变"
    echo "ℹ️ 无状态改变" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 生成完整的软件包列表
echo "📋 生成完整软件包列表..."
cat >> "$REPORT_FILE" << EOF
## 📦 完整软件包列表

### 配置1中的软件包
| 软件包 | 状态 |
|--------|------|
EOF
echo "$PACKAGES1" | while IFS='=' read -r pkg status; do
    echo "| $pkg | $status |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

### 配置2中的软件包
| 软件包 | 状态 |
|--------|------|
EOF
echo "$PACKAGES2" | while IFS='=' read -r pkg status; do
    echo "| $pkg | $status |" >> "$REPORT_FILE"
done

# 输出报告摘要
echo ""
echo "📊 对比摘要:"
echo "  - 新增软件包: $(echo "$ADDED" | grep -c '.' || echo 0)"
echo "  - 删除软件包: $(echo "$REMOVED" | grep -c '.' || echo 0)"
echo "  - 状态改变: $CHANGED_COUNT"
echo "  - 报告文件: $REPORT_FILE"

# 显示报告内容
echo ""
echo "📄 详细报告内容:"
echo "=========================="
cat "$REPORT_FILE"
echo "=========================="
