#!/bin/bash
# scripts/diy.sh
# 功能: 定制固件的初始设置
# 作者: Mary

# 设置严格模式
set -euo pipefail

# 定义颜色和图标
COLOR_INFO='\033[1;36m'
COLOR_SUCCESS='\033[1;32m'
COLOR_RESET='\033[0m'
ICON_INFO='ℹ️'
ICON_SUCCESS='✅'

echo -e "${COLOR_INFO}${ICON_INFO} 开始执行 DIY 脚本...${COLOR_RESET}"

# 1. 修改默认 IP 为 192.168.111.1
# OpenWrt 的网络配置在 package/base-files/files/etc/config/network
# 我们使用 sed 命令来查找并替换
echo -e "${COLOR_INFO}${ICON_INFO} 正在设置默认 IP 为 192.168.111.1...${COLOR_RESET}"
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/etc/config/network

# 2. 设置默认主机名为 WRT
# 主机名配置在 package/base-files/files/etc/sysinfo.conf
echo -e "${COLOR_INFO}${ICON_INFO} 正在设置默认主机名为 WRT...${COLOR_RESET}"
sed -i 's/OpenWrt/WRT/g' package/base-files/files/etc/sysinfo.conf

# 3. 设置默认密码为空
# 密码存储在 /etc/shadow。root 用户的密码哈希字段在第一个冒号和第二个冒号之间。
# 将其设置为空，即可实现无密码登录。
# 注意：这个文件在编译时会被处理，我们修改的是源码模板
echo -e "${COLOR_INFO}${ICON_INFO} 正在设置 root 密码为空...${COLOR_RESET}"
# 查找包含 'root:' 的行，并将第一个和第二个冒号之间的内容替换为空
sed -i 's/root:\$[a-zA-Z0-9\$.\/]*:/root::/g' package/base-files/files/etc/shadow

# 4. 设置默认 WiFi 密码 (如果需要)
# WiFi 配置在 package/kernel/mac80211/files/lib/wifi/mac80211.sh
# 这个比较复杂，通常在编译后通过 LuCI 修改更安全。
# 这里提供一个示例，但可能因版本而异，需要测试。
# echo -e "${COLOR_INFO}${ICON_INFO} 正在设置默认 WiFi 密码...${COLOR_RESET}"
# sed -i 's/ssid=OpenWrt/ssid=ImmortalWrt/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# sed -i 's/#key=passphrase/key=12345678/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

echo -e "${COLOR_SUCCESS}${ICON_SUCCESS} DIY 脚本执行完成。${COLOR_RESET}"
