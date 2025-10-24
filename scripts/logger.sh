#!/bin/bash

# 日志脚本：模块化设置日志

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别，可通过环境变量LOG_LEVEL设置
CURRENT_LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# 日志文件路径
LOG_FILE=${LOG_FILE:-"/tmp/openwrt_build.log"}

# 初始化日志文件
init_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "===== OpenWrt Build Log - $(date) =====" > "$LOG_FILE"
}

# 写入日志
write_log() {
    local level=$1
    local level_name=$2
    local message=$3
    
    if [ $level -ge $CURRENT_LOG_LEVEL ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local log_entry="[$timestamp] [$level_name] $message"
        
        # 输出到控制台
        echo "$log_entry"
        
        # 写入日志文件
        echo "$log_entry" >> "$LOG_FILE"
    fi
}

# 调试日志
log_debug() {
    write_log $LOG_LEVEL_DEBUG "DEBUG" "$1"
}

# 信息日志
log_info() {
    write_log $LOG_LEVEL_INFO "INFO" "$1"
}

# 警告日志
log_warn() {
    write_log $LOG_LEVEL_WARN "WARN" "$1"
}

# 错误日志
log_error() {
    write_log $LOG_LEVEL_ERROR "ERROR" "$1"
}

# 记录命令执行
log_command() {
    local cmd="$1"
    local description="${2:-执行命令}"
    
    log_info "$description: $cmd"
    eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -ne 0 ]; then
        log_error "$description 失败，退出码: $exit_code"
        return $exit_code
    else
        log_info "$description 成功"
        return 0
    fi
}

# 记录系统状态
log_system_status() {
    log_info "===== 系统状态 ====="
    
    # CPU信息
    log_info "CPU信息:"
    log_command "cat /proc/cpuinfo | grep 'model name' | uniq" "获取CPU型号"
    
    # 内存信息
    log_info "内存信息:"
    log_command "free -h" "获取内存使用情况"
    
    # 磁盘信息
    log_info "磁盘信息:"
    log_command "df -h" "获取磁盘使用情况"
    
    # 负载信息
    log_info "系统负载:"
    log_command "uptime" "获取系统负载"
}

# 记录编译状态
log_build_status() {
    local build_dir=$1
    local variant=$2
    
    log_info "===== $variant 编译状态 ====="
    
    if [ -d "$build_dir" ]; then
        # 检查构建目录大小
        log_command "du -sh $build_dir" "获取构建目录大小"
        
        # 检查输出目录
        if [ -d "$build_dir/bin/targets" ]; then
            log_command "find $build_dir/bin/targets -name '*.img' -o -name '*.bin' | head -10" "查找生成的固件文件"
        else
            log_warn "未找到输出目录 $build_dir/bin/targets"
        fi
    else
        log_error "构建目录 $build_dir 不存在"
    fi
}

# 上传日志文件
upload_log() {
    if [ -f "$LOG_FILE" ]; then
        log_info "上传日志文件: $LOG_FILE"
        # 这里可以添加上传日志到云存储的逻辑
    fi
}
