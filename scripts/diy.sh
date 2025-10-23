#!/bin/bash
# 系统初始化脚本
# 功能：修改初始IP、密码、主机名

echo "🔧 开始系统初始化配置..."

# 修改初始IP为192.168.111.1
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate

# 设置密码为空
sed -i 's/root::0:0:99999:7:::/root:$1$empty$6bDqUu1yQh4x9tDZfyCae1:19604:0:99999:7:::/g' package/base-files/files/etc/shadow

# 设置主机名为WRT
sed -i 's/OpenWrt/WRT/g' package/base-files/files/bin/config_generate

echo "✅ 系统初始化完成！"
echo "📌 配置摘要："
echo "   - 默认IP: 192.168.111.1"
echo "   - root密码: 空"
echo "   - 主机名: WRT"
