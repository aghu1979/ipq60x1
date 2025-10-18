#!/bin/bash
# ==============================================================================
# 生成哈希值脚本
# 功能: 计算 configs 目录下所有 .config 文件的哈希值，用于缓存键。
# ==============================================================================

# 设置严格模式
set -euo pipefail

# 引入日志模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

step_start "生成配置文件哈希值"

HASHES_FILE="hashes.txt"
# 清空旧的哈希文件
> "$HASHES_FILE"

# 遍历所有 .config 文件并计算哈希
for config_file in configs/*.config; do
    if [[ -f "$config_file" ]]; then
        sha256sum "$config_file" >> "$HASHES_FILE"
        log_info "已计算 $config_file 的哈希值"
    fi
done

log_success "所有配置文件哈希值已生成到 $HASHES_FILE"
cat "$HASHES_FILE"

step_end "生成配置文件哈希值"
