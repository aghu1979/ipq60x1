#!/bin/bash
# ==============================================================================
# 日志模块
# 功能: 提供格式化、带颜色和图标的日志输出函数。
# ==============================================================================

# --- 颜色定义 ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# --- 图标定义 ---
export ICON_SUCCESS="✅"
export ICON_ERROR="❌"
export ICON_WARN="⚠️"
export ICON_INFO="ℹ️"
export ICON_START="🚀"
export ICON_END="🏁"
export ICON_PACKAGE="📦"
export ICON_DEBUG="🐞"

# --- 日志函数 ---
log_info() {
    echo -e "${CYAN}${ICON_INFO} [INFO]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
}

log_warn() {
    echo -e "${YELLOW}${ICON_WARN} [WARN]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
}

log_error() {
    echo -e "${RED}${ICON_ERROR} [ERROR]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} [SUCCESS]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
}

log_debug() {
    # 仅在 DEBUG 模式下输出
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}${ICON_DEBUG} [DEBUG]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
    fi
}

# --- 步骤标记函数 ---
step_start() {
    echo -e "\n------------------------------------------------------------------" | tee -a "${FULL_LOG_PATH:-/dev/null}"
    echo -e "${BLUE}${ICON_START} [STEP START]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
    echo -e "------------------------------------------------------------------\n" | tee -a "${FULL_LOG_PATH:-/dev/null}"
}

step_end() {
    echo -e "\n------------------------------------------------------------------" | tee -a "${FULL_LOG_PATH:-/dev/null}"
    echo -e "${GREEN}${ICON_END} [STEP END]${NC} $1" | tee -a "${FULL_LOG_PATH:-/dev/null}"
    echo -e "------------------------------------------------------------------\n" | tee -a "${FULL_LOG_PATH:-/dev/null}"
}
