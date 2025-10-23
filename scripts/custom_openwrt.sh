#!/bin/bash
# 软件包检查脚本
# 功能：验证LUCI软件包完整性

CONFIG_FILE=$1
echo "🔍 开始检查LUCI软件包..."

# 提取所有LUCI软件包
LUCI_PACKAGES=$(grep "^CONFIG_PACKAGE_luci-" "$CONFIG_FILE" | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/')

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 生成软件包列表
echo "$LUCI_PACKAGES" > "$TEMP_DIR/requested.list"

# 检查软件包可用性
echo "📦 检查软件包可用性..."
while IFS= read -r pkg; do
  if [ -d "package/feeds/packages/$pkg" ] || [ -d "package/feeds/luci/$pkg" ]; then
    echo "✅ $pkg - 可用"
  else
    echo "❌ $pkg - 缺失" | tee -a "$TEMP_DIR/missing.log"
  fi
done < "$TEMP_DIR/requested.list"

# 生成报告
if [ -f "$TEMP_DIR/missing.log" ]; then
  echo ""
  echo "🚨 发现缺失软件包！"
  echo "缺失软件包列表："
  cat "$TEMP_DIR/missing.log"
  echo ""
  echo "💡 修复建议："
  echo "1. 检查软件包名称是否正确"
  echo "2. 更新第三方软件源：./scripts/repo.sh"
  echo "3. 确认软件包在当前分支中可用"
  exit 1
else
  echo ""
  echo "✅ 所有LUCI软件包检查通过！"
  echo "📊 软件包统计："
  echo "   - 总软件包数: $(wc -l < "$TEMP_DIR/requested.list")"
  echo "   - 可用软件包: $(grep -c '✅' "$TEMP_DIR/check.log")"
fi
