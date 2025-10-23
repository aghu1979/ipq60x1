#!/bin/bash
# OpenWrt配置管理脚本
# 功能：合并配置文件、检查软件包、生成报告

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_CONFIG="🔧"
ICON_PACKAGE="📦"

# 日志函数
log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${ICON_ERROR} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING} $1${NC}"
}

log_config() {
    echo -e "${YELLOW}${ICON_CONFIG} $1${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenWrt配置管理脚本

用法: $0 <命令> [参数]

命令:
  merge <base_config> <user_config> <output>    合并配置文件
  check <config_file> [report_name] [auto_fix]  检查LUCI软件包
  compare <config1> <config2> [report_name]     对比配置文件
  validate <config_file>                       验证配置文件

示例:
  $0 merge .config.base .config.user .config
  $0 check .config "最终检查" true
  $0 compare .config.old .config.new "配置对比"

EOF
}

# 检查是否在OpenWrt目录
check_opnwrt_dir() {
    if [ ! -f "rules.mk" ] || [ ! -d "package" ]; then
        log_error "请在OpenWrt源码目录中运行此脚本"
        exit 1
    fi
}

# 合并配置文件
merge_configs() {
    local base_config=$1
    local user_config=$2
    local output_config=$3
    
    log_config "合并配置文件..."
    log_info "基础配置: $base_config"
    log_info "用户配置: $user_config"
    log_info "输出配置: $output_config"
    
    # 检查文件是否存在
    if [ ! -f "$base_config" ]; then
        log_error "基础配置文件不存在: $base_config"
        exit 1
    fi
    
    if [ ! -f "$user_config" ]; then
        log_error "用户配置文件不存在: $user_config"
        exit 1
    fi
    
    # 复制基础配置
    cp "$base_config" "$output_config"
    
    # 统计配置项
    local base_count=$(grep -c '^CONFIG_' "$base_config" 2>/dev/null || echo 0)
    local user_count=$(grep -c '^CONFIG_' "$user_config" 2>/dev/null || echo 0)
    
    log_info "基础配置项数: $base_count"
    log_info "用户配置项数: $user_count"
    
    # 合并用户配置
    local merged_count=0
    local updated_count=0
    
    while IFS= read -r line; do
        if [[ $line =~ ^CONFIG_ ]]; then
            local key=$(echo "$line" | cut -d'=' -f1)
            
            if grep -q "^$key=" "$output_config"; then
                # 更新现有配置
                sed -i "s|^$key=.*|$line|" "$output_config"
                ((updated_count++))
            else
                # 添加新配置
                echo "$line" >> "$output_config"
                ((merged_count++))
            fi
        fi
    done < "$user_config"
    
    # 生成最终配置
    log_info "运行 make defconfig..."
    make defconfig
    
    local final_count=$(grep -c '^CONFIG_' "$output_config" 2>/dev/null || echo 0)
    
    log_success "配置合并完成！"
    log_info "合并统计:"
    echo "  - 新增配置项: $merged_count"
    echo "  - 更新配置项: $updated_count"
    echo "  - 最终配置项数: $final_count"
}

# 检查LUCI软件包（调用package-check.sh）
check_packages() {
    local config_file=$1
    local report_name=${2:-"软件包检查"}
    local auto_fix=${3:-"true"}
    
    # 查找package-check.sh脚本
    local check_script=""
    if [ -f "scripts/package-check.sh" ]; then
        check_script="scripts/package-check.sh"
    elif [ -f ".github/scripts/package-check.sh" ]; then
        check_script=".github/scripts/package-check.sh"
    else
        log_error "找不到package-check.sh脚本"
        exit 1
    fi
    
    log_info "执行LUCI软件包检查..."
    "$check_script" "$config_file" "$report_name" "$auto_fix"
}

# 对比配置文件
compare_configs() {
    local config1=$1
    local config2=$2
    local report_name=${3:-"配置对比"}
    
    log_config "对比配置文件..."
    log_info "配置文件1: $config1"
    log_info "配置文件2: $config2"
    
    # 查找compare-packages.sh脚本
    local compare_script=""
    if [ -f "scripts/compare-packages.sh" ]; then
        compare_script="scripts/compare-packages.sh"
    elif [ -f ".github/scripts/compare-packages.sh" ]; then
        compare_script=".github/scripts/compare-packages.sh"
    else
        log_error "找不到compare-packages.sh脚本"
        exit 1
    fi
    
    "$compare_script" "$config1" "$config2" "$report_name"
}

# 验证配置文件
validate_config() {
    local config_file=$1
    
    log_config "验证配置文件: $config_file"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        exit 1
    fi
    
    # 检查配置文件格式
    local invalid_lines=$(grep -v '^CONFIG_' "$config_file" | grep -v '^#' | grep -v '^$' | wc -l)
    if [ $invalid_lines -gt 0 ]; then
        log_warning "发现 $invalid_lines 行无效配置"
    fi
    
    # 检查配置项数量
    local config_count=$(grep -c '^CONFIG_' "$config_file" 2>/dev/null || echo 0)
    log_info "配置项总数: $config_count"
    
    # 检查是否有目标配置
    if ! grep -q '^CONFIG_TARGET_' "$config_file"; then
        log_warning "未找到目标配置（CONFIG_TARGET_*）"
    fi
    
    # 运行defconfig验证
    log_info "运行 make defconfig 验证..."
    if make defconfig; then
        log_success "配置文件验证通过！"
    else
        log_error "配置文件验证失败！"
        exit 1
    fi
}

# 主函数
main() {
    local command=""
    local param1=""
    local param2=""
    local param3=""
    
    # 解析参数
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    command=$1
    shift
    
    case $command in
        merge)
            if [ $# -lt 3 ]; then
                log_error "merge命令需要3个参数"
                show_help
                exit 1
            fi
            param1=$1
            param2=$2
            param3=$3
            shift 3
            ;;
        check)
            if [ $# -lt 1 ]; then
                log_error "check命令需要至少1个参数"
                show_help
                exit 1
            fi
            param1=$1
            param2=${2:-"软件包检查"}
            param3=${3:-"true"}
            shift 3
            ;;
        compare)
            if [ $# -lt 2 ]; then
                log_error "compare命令需要至少2个参数"
                show_help
                exit 1
            fi
            param1=$1
            param2=$2
            param3=${3:-"配置对比"}
            shift 3
            ;;
        validate)
            if [ $# -lt 1 ]; then
                log_error "validate命令需要1个参数"
                show_help
                exit 1
            fi
            param1=$1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
    
    # 检查环境
    check_opnwrt_dir
    
    # 执行命令
    case $command in
        merge)
            merge_configs "$param1" "$param2" "$param3"
            ;;
        check)
            check_packages "$param1" "$param2" "$param3"
            ;;
        compare)
            compare_configs "$param1" "$param2" "$param3"
            ;;
        validate)
            validate_config "$param1"
            ;;
    esac
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
