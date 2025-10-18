#!/bin/bash
# ==============================================================================
# 用户自定义脚本
# 功能: 在编译前对 OpenWrt 源码进行自定义修改。
#       此脚本将在 OpenWrt 源码根目录下执行。
#
# 优化点:
# 1. 集成了统一的日志系统，所有输出格式化并记录。
# 2. 采用严格模式 (`set -euo pipefail`)，任何命令失败都会立即终止。
# 3. 功能模块化，每个操作封装为独立函数，结构清晰。
# 4. 增加了健壮性检查，操作前会验证文件/目录是否存在。
# 5. 提供了详细的中文注释，易于理解和维护。
# ==============================================================================

# 设置严格模式：遇到错误或未定义变量时立即退出
set -euo pipefail

# 引入日志模块 (假设 logger.sh 在同一目录或可访问路径)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 检查 logger.sh 是否存在
if [[ ! -f "$SCRIPT_DIR/logger.sh" ]]; then
    echo -e "\033[0;31m❌ [ERROR]${NC} logger.sh 未找到，请确保其在 scripts 目录下。"
    exit 1
fi
source "$SCRIPT_DIR/logger.sh"

# ==============================================================================
# 配置区域 - 在此修改您的自定义设置
# ==============================================================================

# --- 网络设置 ---
DEFAULT_LAN_IP="192.168.111.1"

# --- WiFi 设置 ---
DEFAULT_WIFI_SSID="OpenWrt"
DEFAULT_WIFI_KEY="12345678"
DEFAULT_WIFI_ENCRYPTION="psk2"

# --- 第三方软件源 ---
# 格式: "源名称 源地址"
# 示例: "small https://github.com/kenzok8/small"
CUSTOM_FEEDS=(
    # "small https://github.com/kenzok8/small"
)

# --- 主题设置 ---
# 如果您想使用不同的主题，可以在这里设置
# 例如: "luci-theme-argon"
CUSTOM_THEME=""

# ==============================================================================
# 函数定义区域
# ==============================================================================

# 函数: set_default_lan_ip
# 描述: 修改默认的 LAN IP 地址。
set_default_lan_ip() {
    local config_generate_file="package/base-files/files/bin/config_generate"
    step_start "设置默认 LAN IP 为 ${DEFAULT_LAN_IP}"

    if [[ ! -f "$config_generate_file" ]]; then
        log_error "文件 $config_generate_file 不存在，无法修改 LAN IP。"
        return 1
    fi

    # 使用 -i.bak 创建备份，以防修改失败
    sed -i.bak "s/192.168.1.1/${DEFAULT_LAN_IP}/g" "$config_generate_file"
    log_success "已将默认 LAN IP 修改为 ${DEFAULT_LAN_IP}"
    step_end "设置默认 LAN IP"
}

# 函数: set_default_wifi
# 描述: 通过 uci-defaults 脚本设置默认的 WiFi SSID 和密码。
set_default_wifi() {
    step_start "设置默认 WiFi (SSID: ${DEFAULT_WIFI_SSID})"
    local uci_defaults_dir="package/base-files/files/etc/uci-defaults"
    local wifi_script="$uci_defaults_dir/99-custom-wifi"

    # 确保目录存在
    mkdir -p "$uci_defaults_dir"

    # 创建或覆盖 uci-defaults 脚本
    cat > "$wifi_script" << EOF
#!/bin/sh
# This script is executed at the first boot

# Set WiFi SSID and Key for radio0 (usually 2.4GHz)
uci set wireless.default_radio0.ssid='${DEFAULT_WIFI_SSID}'
uci set wireless.default_radio0.key='${DEFAULT_WIFI_KEY}'
uci set wireless.default_radio0.encryption='${DEFAULT_WIFI_ENCRYPTION}'

# Set WiFi SSID and Key for radio1 (usually 5GHz), if it exists
if uci -q get wireless.default_radio1 > /dev/null; then
    uci set wireless.default_radio1.ssid='${DEFAULT_WIFI_SSID}_5G'
    uci set wireless.default_radio1.key='${DEFAULT_WIFI_KEY}'
    uci set wireless.default_radio1.encryption='${DEFAULT_WIFI_ENCRYPTION}'
fi

# Commit changes
uci commit wireless

# Restart wireless service to apply changes
wifi reload
EOF

    chmod +x "$wifi_script"
    log_success "已创建默认 WiFi 设置脚本。"
    step_end "设置默认 WiFi"
}

# 函数: add_custom_feeds
# 描述: 向 feeds.conf.default 添加自定义的第三方软件源。
add_custom_feeds() {
    if [[ ${#CUSTOM_FEEDS[@]} -eq 0 ]]; then
        log_info "未配置自定义软件源，跳过此步骤。"
        return 0
    fi

    step_start "添加自定义软件源"
    local feeds_file="feeds.conf.default"

    if [[ ! -f "$feeds_file" ]]; then
        log_error "文件 $feeds_file 不存在，无法添加软件源。"
        return 1
    fi

    for feed in "${CUSTOM_FEEDS[@]}"; do
        # 读取 "源名称 源地址"
        read -r name url <<< "$feed"
        local feed_entry="src-git $name $url"

        # 检查源是否已存在，避免重复添加
        if grep -qF "$feed_entry" "$feeds_file"; then
            log_warn "软件源已存在，跳过: $feed_entry"
        else
            echo "$feed_entry" >> "$feeds_file"
            log_success "已添加软件源: $feed_entry"
        fi
    done

    step_end "添加自定义软件源"
}

# 函数: apply_custom_theme
# 描述: 设置默认的 LUCI 主题。
apply_custom_theme() {
    if [[ -z "$CUSTOM_THEME" ]]; then
        log_info "未配置自定义主题，跳过此步骤。"
        return 0
    fi

    step_start "设置默认主题为 ${CUSTOM_THEME}"
    local uci_defaults_dir="package/base-files/files/etc/uci-defaults"
    local theme_script="$uci_defaults_dir/98-custom-theme"

    mkdir -p "$uci_defaults_dir"

    cat > "$theme_script" << EOF
#!/bin/sh
# This script is executed at the first boot

# Set the main theme
uci set luci.main.mediaurlbase='/luci-static/${CUSTOM_THEME}'
uci commit luci
EOF

    chmod +x "$theme_script"
    log_success "已创建主题设置脚本，默认主题将设置为 ${CUSTOM_THEME}。"
    step_end "设置默认主题"
}

# ==============================================================================
# 主执行逻辑
# ==============================================================================

log_info "开始执行自定义脚本..."

# 按顺序执行所有自定义操作
set_default_lan_ip
set_default_wifi
add_custom_feeds
apply_custom_theme

log_success "所有自定义操作已成功完成！"
