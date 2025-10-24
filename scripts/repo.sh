#!/bin/bash

# 仓库配置脚本：用于配置第三方软件源
# 作者：AI助手
# 用途：添加ImmortalWrt固件的第三方软件源

# 导入日志函数
source $(dirname "${BASH_SOURCE[0]}")/logger.sh

# 记录日志
log_info "开始执行仓库配置脚本"

# 添加第三方软件源
log_info "添加第三方软件源: https://github.com/kenzok8/small-package"

# 检查是否存在feeds.conf.default文件
if [ -f "feeds.conf.default" ]; then
    # 备份原始文件
    cp feeds.conf.default feeds.conf.default.bak
    
    # 添加第三方软件源
    echo "src-git small https://github.com/kenzok8/small-package" >> feeds.conf.default
    
    log_info "第三方软件源添加完成"
else
    log_error "feeds.conf.default文件不存在"
    exit 1
fi

# 添加自定义软件包（可选）
# log_info "添加自定义软件包"
# git clone https://github.com/kenzok8/small-package.git package/small-package

# 记录日志
log_info "仓库配置脚本执行完成"

exit 0
