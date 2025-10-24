#!/bin/bash

# DIY脚本：修改默认IP和密码

# 导入日志函数
source "$(dirname "$0")/logger.sh"

# 修改默认IP地址
change_default_ip() {
    local new_ip=${1:-"192.168.111.1"}
    local openwrt_dir=${2:-"."}
    
    log_info "修改默认IP地址为: $new_ip"
    
    # 查找并修改网络配置文件
    local network_config="$openwrt_dir/package/base-files/files/bin/config_generate"
    
    if [ -f "$network_config" ]; then
        # 备份原文件
        cp "$network_config" "$network_config.bak"
        
        # 修改IP地址
        sed -i "s/192.168.1.1/$new_ip/g" "$network_config"
        
        log_info "成功修改默认IP地址为: $new_ip"
    else
        log_error "未找到网络配置文件: $network_config"
        return 1
    fi
}

# 设置默认密码为空
set_empty_password() {
    local openwrt_dir=${1:-"."}
    
    log_info "设置默认密码为空"
    
    # 查找并修改密码配置文件
    local password_config="$openwrt_dir/package/base-files/files/etc/shadow"
    
    if [ -f "$password_config" ]; then
        # 备份原文件
        cp "$password_config" "$password_config.bak"
        
        # 修改root密码为空
        sed -i 's/root:x:0:0:root:\/root:\/bin\/ash/root::0:0:root:\/root:\/bin\/ash/g' "$password_config"
        
        log_info "成功设置默认密码为空"
    else
        log_error "未找到密码配置文件: $password_config"
        return 1
    fi
}

# 主函数
main() {
    local openwrt_dir=${1:-"."}
    local new_ip=${2:-"192.168.111.1"}
    
    log_info "开始执行DIY脚本"
    
    change_default_ip "$new_ip" "$openwrt_dir"
    set_empty_password "$openwrt_dir"
    
    log_info "DIY脚本执行完成"
}

# 执行主函数
main "$@"
