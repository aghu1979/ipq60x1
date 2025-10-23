#!/bin/bash
# OpenWrt系统初始化脚本
# 功能：修改初始IP、密码、主机名等系统配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
ICON_SUCCESS="✅"
ICON_INFO="ℹ️"
ICON_CONFIG="🔧"

# 日志函数
log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

log_config() {
    echo -e "${YELLOW}${ICON_CONFIG} $1${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenWrt系统初始化脚本

功能:
  - 修改默认IP为192.168.111.1
  - 设置root密码为空
  - 设置主机名为WRT

用法: $0

EOF
}

# 检查是否在OpenWrt目录
check_openwrt_dir() {
    if [ ! -f "rules.mk" ] || [ ! -d "package" ]; then
        echo -e "${RED}❌ 请在OpenWrt源码目录中运行此脚本${NC}"
        exit 1
    fi
}

# 修改网络配置
modify_network_config() {
    log_config "修改默认IP地址..."
    
    # 修改config_generate中的IP
    if [ -f "package/base-files/files/bin/config_generate" ]; then
        sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
        log_success "默认IP已修改为: 192.168.111.1"
    else
        log_info "未找到config_generate文件，跳过IP修改"
    fi
}

# 修改密码配置
modify_password_config() {
    log_config "设置root密码为空..."
    
    # 修改shadow文件
    if [ -f "package/base-files/files/etc/shadow" ]; then
        sed -i 's/root:\$1\$/root::$1$empty$6bDqUu1yQh4x9tDZfyCae1:19604:0:99999:7:::/g' package/base-files/files/etc/shadow
        log_success "root密码已设置为空"
    else
        log_info "未找到shadow文件，跳过密码修改"
    fi
}

# 修改主机名配置
modify_hostname_config() {
    log_config "设置主机名为WRT..."
    
    # 修改config_generate中的主机名
    if [ -f "package/base-files/files/bin/config_generate" ]; then
        sed -i 's/OpenWrt/WRT/g' package/base-files/files/bin/config_generate
        log_success "主机名已设置为: WRT"
    else
        log_info "未找到config_generate文件，跳过主机名修改"
    fi
}

# 显示配置摘要
show_config_summary() {
    echo ""
    log_info "系统初始化配置摘要:"
    echo "  - 默认IP: 192.168.111.1"
    echo "  - root密码: 空"
    echo "  - 主机名: WRT"
    echo ""
    log_success "系统初始化完成！"
}

# 主函数
main() {
    log_info "开始OpenWrt系统初始化..."
    
    # 检查环境
    check_openwrt_dir
    
    # 执行配置修改
    modify_network_config
    modify_password_config
    modify_hostname_config
    
    # 显示摘要
    show_config_summary
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # 处理参数
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        "")
            main
            ;;
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
fi
