#!/bin/bash
# OpenWrt第三方软件源管理脚本
# 功能：添加和管理第三方软件源

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
ICON_WARNING="⚠️"
ICON_PACKAGE="📦"

# 默认配置
DEFAULT_REPO_URL="https://github.com/kenzok8/small-package"
DEFAULT_REPO_NAME="kenzok8"
DEFAULT_REPO_BRANCH="main"

# 日志函数
log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING} $1${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenWrt第三方软件源管理脚本

用法: $0 [选项] [参数]

选项:
  -h, --help              显示帮助信息
  -a, --add <url>         添加软件源
  -r, --remove <name>      移除软件源
  -l, --list              列出所有软件源
  -u, --update            更新所有软件源
  -i, --install <name>     安装指定软件源

示例:
  $0 --add https://github.com/example/packages
  $0 --list
  $0 --update

EOF
}

# 检查是否在OpenWrt目录
check_opnwrt_dir() {
    if [ ! -f "rules.mk" ] || [ ! -d "package" ]; then
        echo -e "${RED}❌ 请在OpenWrt源码目录中运行此脚本${NC}"
        exit 1
    fi
}

# 添加软件源
add_repo() {
    local repo_url=$1
    local repo_name=$2
    local repo_branch=${3:-$DEFAULT_REPO_BRANCH}
    
    log_info "添加软件源: $repo_url"
    
    # 如果没有提供名称，从URL提取
    if [ -z "$repo_name" ]; then
        repo_name=$(echo "$repo_url" | sed 's|.*/||' | sed 's|.git||')
    fi
    
    local feeds_dir="feeds/$repo_name"
    
    # 检查是否已存在
    if [ -d "$feeds_dir" ]; then
        log_warning "软件源已存在: $repo_name"
        log_info "更新软件源..."
        cd "$feeds_dir"
        git pull origin "$repo_branch"
        cd ../..
    else
        log_info "克隆软件源到: $feeds_dir"
        git clone -b "$repo_branch" "$repo_url" "$feeds_dir"
    fi
    
    log_success "软件源添加完成: $repo_name"
}

# 移除软件源
remove_repo() {
    local repo_name=$1
    local feeds_dir="feeds/$repo_name"
    
    if [ -d "$feeds_dir" ]; then
        log_info "移除软件源: $repo_name"
        rm -rf "$feeds_dir"
        log_success "软件源已移除: $repo_name"
    else
        log_warning "软件源不存在: $repo_name"
    fi
}

# 列出所有软件源
list_repos() {
    log_info "当前软件源列表:"
    
    if [ -d "feeds" ]; then
        local count=0
        for dir in feeds/*/; do
            if [ -d "$dir" ]; then
                local name=$(basename "$dir")
                local url=""
                local branch=""
                
                # 获取git信息
                if [ -d "$dir/.git" ]; then
                    cd "$dir"
                    url=$(git remote get-url origin 2>/dev/null || echo "未知")
                    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "未知")
                    cd ../..
                fi
                
                echo "  - $name"
                echo "    URL: $url"
                echo "    分支: $branch"
                echo ""
                ((count++))
            fi
        done
        
        if [ $count -eq 0 ]; then
            log_info "没有找到任何软件源"
        else
            log_success "共找到 $count 个软件源"
        fi
    else
        log_info "feeds目录不存在"
    fi
}

# 更新所有软件源
update_repos() {
    log_info "更新所有软件源..."
    
    if [ -d "feeds" ]; then
        local count=0
        for dir in feeds/*/; do
            if [ -d "$dir/.git" ]; then
                local name=$(basename "$dir")
                log_info "更新软件源: $name"
                cd "$dir"
                if git pull origin $(git rev-parse --abbrev-ref HEAD); then
                    log_success "更新成功: $name"
                    ((count++))
                else
                    log_warning "更新失败: $name"
                fi
                cd ../..
            fi
        done
        
        log_success "更新完成，成功更新 $count 个软件源"
    else
        log_warning "feeds目录不存在"
    fi
}

# 安装软件源
install_repo() {
    local repo_name=$1
    
    if [ -z "$repo_name" ]; then
        log_warning "请提供软件源名称"
        return 1
    fi
    
    log_info "安装软件源: $repo_name"
    
    # 更新feeds索引
    log_info "更新feeds索引..."
    ./scripts/feeds update -a
    
    # 安装软件包
    log_info "安装软件包..."
    ./scripts/feeds install -a
    
    log_success "软件源安装完成: $repo_name"
}

# 添加默认软件源
add_default_repo() {
    log_info "添加默认第三方软件源..."
    add_repo "$DEFAULT_REPO_URL" "$DEFAULT_REPO_NAME" "$DEFAULT_REPO_BRANCH"
}

# 主函数
main() {
    local action=""
    local param=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--add)
                action="add"
                param="$2"
                shift 2
                ;;
            -r|--remove)
                action="remove"
                param="$2"
                shift 2
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -u|--update)
                action="update"
                shift
                ;;
            -i|--install)
                action="install"
                param="$2"
                shift 2
                ;;
            *)
                echo "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查环境
    check_opnwrt_dir
    
    # 执行操作
    case $action in
        add)
            if [ -z "$param" ]; then
                log_warning "请提供软件源URL"
                exit 1
            fi
            add_repo "$param"
            ;;
        remove)
            if [ -z "$param" ]; then
                log_warning "请提供软件源名称"
                exit 1
            fi
            remove_repo "$param"
            ;;
        list)
            list_repos
            ;;
        update)
            update_repos
            ;;
        install)
            install_repo "$param"
            ;;
        "")
            # 默认操作：添加默认软件源
            add_default_repo
            ;;
    esac
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
