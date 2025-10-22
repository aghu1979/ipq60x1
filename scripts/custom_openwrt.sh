#!/bin/bash
# ====================================================
# Description: Customization for OpenWrt
# License: MIT
# Author: Mary
# ====================================================

# --- Part 1: DIY (修改源码) ---
log_info ">>> 开始应用 OpenWrt DIY 自定义..."

# 1. 修改默认IP、主机名、密码
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/WRT/g' package/base-files/files/bin/config_generate
# 设置默认密码为空 (root:$1$empty$...)
sed -i 's/root::0:0:99999:7:::/root:$1$empty$6PzN4uVzq8bZ2z2x2z2x2:0:0:99999:7:::/g' package/base-files/files/etc/shadow

log_success ">>> OpenWrt DIY 自定义完成。"

# --- Part 2: Repo (管理软件源) ---
log_info ">>> 开始添加 OpenWrt 第三方软件源..."

# 添加 kenzok8/small-package 软件源
FEEDS_CONF="feeds.conf.default"
CUSTOM_FEED_URL="https://github.com/kenzok8/small-package"

if ! grep -q "$CUSTOM_FEED_URL" "$FEEDS_CONF"; then
    echo "src-git small_package $CUSTOM_FEED_URL" >> "$FEEDS_CONF"
    log_success ">>> 成功添加自定义软件源: ${CUSTOM_FEED_URL}"
else
    log_info ">>> 自定义软件源已存在，跳过添加。"
fi

log_success ">>> OpenWrt 软件源配置完成。"
