#!/bin/bash
# ==============================================================================
# LUCI 软件包检查脚本
# 功能: 调用对比函数，并根据结果决定是否继续编译。
# ==============================================================================

# 设置严格模式
set -euo pipefail

# 引入日志和工具模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/utils.sh"

# 参数检查
if [[ $# -ne 3 ]]; then
    log_error "用法: $0 <Profile名称> <生成的.config路径> <期望的Profile配置路径>"
    exit 1
fi

PROFILE_NAME="$1"
GENERATED_CONFIG="$2"
USER_CONFIG="$3"

log_info "正在对 Profile: ${PROFILE_NAME} 进行 LUCI 软件包检查..."

# 调用对比函数
if ! compare_luci_packages "$USER_CONFIG" "$GENERATED_CONFIG"; then
    log_error "LUCI 软件包检查失败！发现缺失的软件包。"
    log_error "请检查 feeds 源或修正 configs/${PROFILE_NAME}.config 中的包名后，重新运行工作流。"
    # 退出并返回错误码，终止 Job
    exit 1
fi

log_success "LUCI 软件包检查通过！"
