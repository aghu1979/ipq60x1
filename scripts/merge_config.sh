#!/bin/bash
# 配置文件合并脚本
# 用法: merge-config.sh <基础配置> <用户配置> <输出文件>

BASE_CONFIG=$1
USER_CONFIG=$2
OUTPUT=$3

echo "🔧 开始合并配置文件..."
echo "📌 基础配置: $BASE_CONFIG"
echo "📌 用户配置: $USER_CONFIG"
echo "📌 输出文件: $OUTPUT"

# 创建临时工作目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 复制基础配置
cp "$BASE_CONFIG" "$TEMP_DIR/base.config"

# 合并用户配置
while IFS= read -r line; do
  if [[ $line =~ ^CONFIG_ ]]; then
    key=$(echo "$line" | cut -d'=' -f1)
    if grep -q "^$key=" "$TEMP_DIR/base.config"; then
      sed -i "s|^$key=.*|$line|" "$TEMP_DIR/base.config"
    else
      echo "$line" >> "$TEMP_DIR/base.config"
    fi
  fi
done < "$USER_CONFIG"

# 生成最终配置
cp "$TEMP_DIR/base.config" "$OUTPUT"

echo "✅ 配置合并完成！"
echo "📊 合并统计："
echo "   - 基础配置项: $(grep -c '^CONFIG_' "$BASE_CONFIG")"
echo "   - 用户配置项: $(grep -c '^CONFIG_' "$USER_CONFIG")"
echo "   - 最终配置项: $(grep -c '^CONFIG_' "$OUTPUT")"
