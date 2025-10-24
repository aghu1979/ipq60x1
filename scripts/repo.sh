#!/bin/bash

# 仓库配置脚本：配置第三方软件元仓库

# 导入日志函数
source "$(dirname "$0")/logger.sh"

# 添加第三方软件源
add_custom_feeds() {
    local openwrt_dir=${1:-"."}
    local feeds_conf="$openwrt_dir/feeds.conf.default"
    
    log_info "添加第三方软件源"
    
    if [ -f "$feeds_conf" ]; then
        # 备份原文件
        cp "$feeds_conf" "$feeds_conf.bak"
        
        # 添加kenzok8的small-package仓库
        echo "src-git small https://github.com/kenzok8/small-package" >> "$feeds_conf"
        
        # 添加其他常用仓库
        echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall" >> "$feeds_conf"
        echo "src-git openclash https://github.com/vernesong/OpenClash" >> "$feeds_conf"
        
        log_info "成功添加第三方软件源"
    else
        log_error "未找到feeds配置文件: $feeds_conf"
        return 1
    fi
}

# 更新feeds
update_feeds() {
    local openwrt_dir=${1:-"."}
    
    log_info "更新feeds"
    
    cd "$openwrt_dir"
    
    # 更新所有feeds
    log_command "./scripts/feeds update -a" "更新所有feeds"
    
    # 安装所有feeds
    log_command "./scripts/feeds install -a" "安装所有feeds"
    
    cd - > /dev/null
}

# 主函数
main() {
    local openwrt_dir=${1:-"."}
    
    log_info "开始配置第三方软件元仓库"
    
    add_custom_feeds "$openwrt_dir"
    update_feeds "$openwrt_dir"
    
    log_info "第三方软件元仓库配置完成"
}

# 执行主函数
main "$@"
