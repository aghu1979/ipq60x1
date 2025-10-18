#!/bin/bash
# 日志模块 - 提供统一的日志输出格式和错误处理
# 作者: Mary
# 最后更新: 2025-10-18

# =============================================================================
# 颜色定义 - 用于控制台输出的颜色控制
# =============================================================================

# 基础颜色
RED='\033[0;31m'      # 红色 - 用于错误信息
GREEN='\033[0;32m'    # 绿色 - 用于成功信息
YELLOW='\033[1;33m'   # 黄色 - 用于警告信息
BLUE='\033[0;34m'     # 蓝色 - 用于一般信息
PURPLE='\033[0;35m'   # 紫色 - 用于步骤标记
CYAN='\033[0;36m'     # 青色 - 用于调试信息
WHITE='\033[1;37m'    # 白色 - 用于强调
NC='\033[0m'          # 无颜色 - 重置颜色

# =============================================================================
# 图标定义 - 用于增强日志的可读性
# =============================================================================

ICON_INFO="ℹ️"        # 信息图标
ICON_SUCCESS="✅"     # 成功图标
ICON_WARNING="⚠️"     # 譾告图标
ICON_ERROR="❌"       # 错误图标
ICON_START="🚀"       # 开始图标
ICON_END="🏁"         # 结束图标
ICON_DEBUG="🔍"       # 调试图标
ICON_PROGRESS="⏳"     # 进行中图标

# =============================================================================
# 日志级别定义 - 用于控制日志输出的详细程度
# =============================================================================

LOG_LEVEL_INFO=1       # 信息级别
LOG_LEVEL_SUCCESS=2    # 成功级别
LOG_LEVEL_WARNING=3    # 證告级别
LOG_LEVEL_ERROR=4      # 错误级别
LOG_LEVEL_DEBUG=5      # 调试级别

# 当前日志级别（可通过环境变量LOG_LEVEL控制）
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# =============================================================================
# 日志文件定义
# =============================================================================

# 主日志文件
LOG_FILE="build.log"
# 错误日志文件
ERROR_LOG="error.log"
# 摘要日志文件
SUMMARY_LOG="summary.log"

# =============================================================================
# 初始化日志系统
# =============================================================================

# 初始化日志文件
init_log() {
    # 创建主日志文件
    {
        echo "========================================"
        echo "OpenWrt Build Log"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        echo ""
    } > $LOG_FILE
    
    # 创建错误日志文件
    {
        echo "========================================"
        echo "OpenWrt Error Log"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        echo ""
    } > $ERROR_LOG
    
    # 创建摘要日志文件
    {
        echo "========================================"
        echo "OpenWrt Build Summary"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        echo ""
    } > $SUMMARY_LOG
}

# =============================================================================
# 通用日志输出函数
# =============================================================================

# 通用日志输出函数
# 参数: $1=级别, $2=颜色, $3=图标, $4=消息
log() {
    local level=$1
    local color=$2
    local icon=$3
    local message=$4
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 控制台输出（带颜色和图标）
    echo -e "${color}[${icon}]${NC} ${timestamp} - ${message}"
    
    # 文件输出（不带颜色）
    echo "[${level}] ${timestamp} - ${message}" >> $LOG_FILE
}

# =============================================================================
# 具体级别的日志函数
# =============================================================================

# 信息日志
log_info() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        log "INFO" "$BLUE" "$ICON_INFO" "$1"
    fi
}

# 成功日志
log_success() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_SUCCESS ]; then
        log "SUCCESS" "$GREEN" "$ICON_SUCCESS" "$1"
    fi
}

# 譾告日志
log_warning() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARNING ]; then
        log "WARNING" "$YELLOW" "$ICON_WARNING" "$1"
    fi
}

# 错误日志
log_error() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        log "ERROR" "$RED" "$ICON_ERROR" "$1"
        
        # 记录到错误日志
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> $ERROR_LOG
        
        # 记录错误上下文（前1000行）
        if [ -f "$LOG_FILE" ]; then
            {
                echo ""
                echo "========================================"
                echo "错误上下文（前1000行）"
                echo "========================================"
                tail -n 1000 $LOG_FILE >> $ERROR_LOG
            }
        fi
        
        # 生成错误摘要
        generate_error_summary "$1"
    fi
}

# 调试日志
log_debug() {
    if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        log "DEBUG" "$CYAN" "$ICON_DEBUG" "$1"
    fi
}

# =============================================================================
# 步骤标记函数
# =============================================================================

# 步骤开始标记
# 参数: $1=步骤名称
step_start() {
    local message=$1
    
    # 控制台输出
    echo -e "\n${PURPLE}========== ${ICON_START} 开始: $1 ==========${NC}" | tee -a $LOG_FILE
    
    # 日志记录
    log_info "开始执行: $1"
    
    # 记录开始时间到环境变量
    echo "STEP_START_TIME=$(date +%s)" >> $GITHUB_ENV
    
    # 记录到摘要日志
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始: $1" >> $SUMMARY_LOG
}

# 步骤结束标记
# 参数: $1=步骤名称
step_end() {
    local message=$1
    local end_time=$(date +%s)
    local start_time=${STEP_START_TIME:-0}
    local duration=$((end_time - start_time))
    
    # 格式化持续时间
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    local duration_str=""
    
    if [ $hours -gt 0 ]; then
        duration_str="${hours}小时${minutes}分钟${seconds}秒"
    elif [ $minutes -gt 0 ]; then
        duration_str="${minutes}分钟${seconds}秒"
    else
        duration_str="${seconds}秒"
    fi
    
    # 控制台输出
    echo -e "${PURPLE}========== ${ICON_END} 完成: $1 (耗时: ${duration_str}) ==========${NC}\n" | tee -a $LOG_FILE
    
    # 日志记录
    log_success "完成执行: $1 (耗时: ${duration_str})"
    
    # 记录到摘要日志
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 完成: $1 (耗时: ${duration_str})" >> $SUMMARY_LOG
}

# =============================================================================
# 错误处理函数
# =============================================================================

# 生成错误摘要
# 参数: $1=错误消息
generate_error_summary() {
    local error_msg=$1
    local summary_file="error_summary.md"
    
    # 生成Markdown格式的错误摘要
    cat > $summary_file << EOF
# 🚨 编译错误摘要

## 错误信息
\`\`\`
 $error_msg
\`\`\`

## 时间戳
 $(date '+%Y-%m-%d %H:%M:%S')

## 详细日志
- 🔗 [完整日志]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)
- 🔗 [错误日志查看]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)

## 知识信息
- Runner: ${{ runner.os }}
- Workflow: $GITHUB_WORKFLOW
- Job: $GITHUB_JOB
- 分支: $GITHUB_REF_NAME

## 建议解决方案
1. 检查配置文件是否正确
2. 知道网络连接正常
3. 查看详细日志获取更多信息
4. 如果问题持续，请提交Issue

EOF
    
    echo "📄 错误摘要已生成: $summary_file"
}

# =============================================================================
# 初始化日志系统
# =============================================================================

# 脚本加载时自动初始化
init_log
