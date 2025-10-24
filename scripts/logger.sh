#!/bin/bash

# 日志脚本：提供模块化的日志功能
# 作者：AI助手
# 用途：为其他脚本提供统一的日志记录功能

# 日志级别定义
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_ERROR=3

# 默认日志级别
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# 日志颜色定义
readonly COLOR_DEBUG='\033[0;36m'    # 青色
readonly COLOR_INFO='\033[0;32m'     # 绿色
readonly COLOR_WARNING='\033[0;33m'  # 黄色
readonly COLOR_ERROR='\033[0;31m'    # 红色
readonly COLOR_RESET='\033[0m'       # 重置

# 日志文件路径
LOG_FILE=${LOG_FILE:-"/tmp/immortalwrt_build.log"}

# 函数：获取当前时间戳
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# 函数：记录日志
# 参数：$1 - 日志级别，$2 - 日志消息
log() {
    local level=$1
    local message=$2
    local timestamp=$(get_timestamp)
    
    # 输出到控制台
    case $level in
        $LOG_LEVEL_DEBUG)
            echo -e "${COLOR_DEBUG}[DEBUG]${COLOR_RESET} [${timestamp}] ${message}"
            ;;
        $LOG_LEVEL_INFO)
            echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} [${timestamp}] ${message}"
            ;;
        $LOG_LEVEL_WARNING)
            echo -e "${COLOR_WARNING}[WARNING]${COLOR_RESET} [${timestamp}] ${message}"
            ;;
        $LOG_LEVEL_ERROR)
            echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} [${timestamp}] ${message}"
            ;;
    esac
    
    # 输出到日志文件
    local level_name=""
    case $level in
        $LOG_LEVEL_DEBUG)
            level_name="DEBUG"
            ;;
        $LOG_LEVEL_INFO)
            level_name="INFO"
            ;;
        $LOG_LEVEL_WARNING)
            level_name="WARNING"
            ;;
        $LOG_LEVEL_ERROR)
            level_name="ERROR"
            ;;
    esac
    
    echo "[${timestamp}] [${level_name}] ${message}" >> "$LOG_FILE"
}

# 函数：记录调试日志
# 参数：$1 - 日志消息
log_debug() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        log $LOG_LEVEL_DEBUG "$1"
    fi
}

# 函数：记录信息日志
# 参数：$1 - 日志消息
log_info() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        log $LOG_LEVEL_INFO "$1"
    fi
}

# 函数：记录警告日志
# 参数：$1 - 日志消息
log_warning() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_WARNING ]; then
        log $LOG_LEVEL_WARNING "$1"
    fi
}

# 函数：记录错误日志
# 参数：$1 - 日志消息
log_error() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        log $LOG_LEVEL_ERROR "$1"
    fi
}

# 函数：设置日志级别
# 参数：$1 - 日志级别 (DEBUG/INFO/WARNING/ERROR)
set_log_level() {
    local level_name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    
    case $level_name in
        "DEBUG")
            LOG_LEVEL=$LOG_LEVEL_DEBUG
            ;;
        "INFO")
            LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
        "WARNING")
            LOG_LEVEL=$LOG_LEVEL_WARNING
            ;;
        "ERROR")
            LOG_LEVEL=$LOG_LEVEL_ERROR
            ;;
        *)
            log_warning "未知的日志级别: $1，使用默认级别 INFO"
            LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
    esac
    
    log_info "日志级别设置为: $level_name"
}

# 函数：设置日志文件路径
# 参数：$1 - 日志文件路径
set_log_file() {
    local log_file="$1"
    
    # 创建日志文件目录（如果不存在）
    local log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"
    
    LOG_FILE="$log_file"
    log_info "日志文件设置为: $log_file"
}

# 函数：清理日志文件
# 参数：$1 - 保留天数（可选，默认7天）
cleanup_log() {
    local retain_days=${1:-7}
    
    if [ -f "$LOG_FILE" ]; then
        # 创建备份文件
        local backup_file="${LOG_FILE}.$(date +"%Y%m%d_%H%M%S").bak"
        cp "$LOG_FILE" "$backup_file"
        
        # 清空当前日志文件
        > "$LOG_FILE"
        
        # 删除超过保留天数的备份文件
        find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE").*.bak" -mtime +$retain_days -delete
        
        log_info "日志文件已清理，备份文件保留 $retain_days 天"
    else
        log_warning "日志文件不存在: $LOG_FILE"
    fi
}

# 函数：上传日志文件（在CI环境中使用）
upload_log() {
    if [ -n "$GITHUB_ACTIONS" ]; then
        if [ -f "$LOG_FILE" ]; then
            echo "::group::上传日志文件"
            echo "日志文件路径: $LOG_FILE"
            echo "日志文件内容:"
            cat "$LOG_FILE"
            echo "::endgroup::"
        else
            echo "日志文件不存在: $LOG_FILE"
        fi
    fi
}

# 初始化日志
log_info "日志系统初始化完成"
log_info "日志级别: $LOG_LEVEL"
log_info "日志文件: $LOG_FILE"
