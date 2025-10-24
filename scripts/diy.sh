#!/bin/bash

# DIY脚本：用于修改默认IP地址和密码
# 作者：AI助手
# 用途：修改ImmortalWrt固件的默认设置

# 导入日志函数
source $(dirname "${BASH_SOURCE[0]}")/logger.sh

# 记录日志
log_info "开始执行DIY脚本"

# 修改默认IP地址
log_info "修改默认IP地址为192.168.111.1"
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate

# 修改默认密码为空
log_info "修改默认密码为空"
sed -i 's/root::0:0:99999:7:::/root::$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

# 添加自定义主题（可选）
# log_info "添加自定义主题"
# git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# 添加自定义软件包（可选）
# log_info "添加自定义软件包"
# git clone https://github.com/kenzok8/small-package.git package/small-package

# 记录日志
log_info "DIY脚本执行完成"

exit 0
