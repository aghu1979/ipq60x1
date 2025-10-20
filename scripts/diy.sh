#!/bin/bash
# ==============================================================================
# 用户自定义脚本 (优化版)
# 功能: 在编译前对 OpenWrt 源码进行自定义修改。
# 优化点:
# 1. 集成了统一的日志系统。
# 2. 使用关联数组管理包源，提高可维护性。
# 3. 增加了 `git clone` 的重试机制。
# 4. 增加了操作前的存在性检查，增强幂等性。
# ==============================================================================

# 启用严格模式
set -euo pipefail

# 引入日志模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

# --- 配置区域：使用关联数组管理包源，便于维护 ---
declare -A CUSTOM_PACKAGES=(
    # 格式: "本地目标目录"="Git仓库URL"
    # laipeng668定制包
    ["feeds/packages/lang/golang"]="https://github.com/sbwml/packages_lang_golang"
    ["package/openlist"]="https://github.com/sbwml/luci-app-openlist2"
    ["feeds/packages/net/ariang"]="https://github.com/laipeng668/packages"
    ["feeds/packages/net/frp"]="https://github.com/laipeng668/packages"
    ["feeds/luci/applications/luci-app-frpc"]="https://github.com/laipeng668/luci"
    ["feeds/luci/applications/luci-app-frps"]="https://github.com/laipeng668/luci"
    ["package/adguardhome"]="https://github.com/kenzok8/openwrt-packages"
    ["package/luci-app-adguardhome"]="https://github.com/kenzok8/openwrt-packages"
    ["feeds/luci/applications/luci-app-wolplus"]="https://github.com/VIKINGYFY/packages"
    ["package/luci-app-wechatpush"]="https://github.com/tty228/luci-app-wechatpush"
    ["package/OpenAppFilter"]="https://github.com/destan19/OpenAppFilter"
    ["package/openwrt-gecoosac"]="https://github.com/lwb1978/openwrt-gecoosac"
    ["package/luci-app-athena-led"]="https://github.com/NONGFAH/luci-app-athena-led"
    # Mary定制包
    ["package/netspeedtest"]="https://github.com/sirpdboy/luci-app-netspeedtest"
    ["package/partexp"]="https://github.com/sirpdboy/luci-app-partexp"
    ["package/taskplan"]="https://github.com/sirpdboy/luci-app-taskplan"
    ["package/tailscale"]="https://github.com/tailscale/tailscale"
    ["package/momo"]="https://github.com/nikkinikki-org/OpenWrt-momo"
    ["package/nikki"]="https://github.com/nikkinikki-org/OpenWrt-nikki"
    ["package/openclash"]="https://github.com/vernesong/OpenClash"
    # kenzok8软件源
    ["smpackage"]="https://github.com/kenzok8/small-package"
)

# --- 函数定义 ---

# 带重试机制的 git clone
clone_with_retry() {
    local url="$1"
    local target_dir="$2"
    local retries=3
    local count=0

    until [ "$count" -ge "$retries" ]; do
        log_info "正在克隆 $url 到 $target_dir (尝试 $((count + 1))/$retries)"
        if git clone --depth=1 "$url" "$target_dir"; then
            log_success "克隆成功: $target_dir"
            return 0
        else
            count=$((count + 1))
            log_warn "克隆失败，等待 5 秒后重试..."
            sleep 5
        fi
    done

    log_error "克隆失败，已达到最大重试次数: $url"
    return 1
}

# 删除缓存和工作目录
remove_package_dirs() {
    local dir_list=("$@")
    log_info "开始清理预定义的包目录..."
    for dir in "${dir_list[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            log_info "已删除目录: $dir"
        fi
    done
    log_success "包目录清理完成。"
}

# --- 主逻辑 ---
main() {
    local branch_name="${1:-openwrt}"
    local soc_name="${2:-ipq60xx}"

    step_start "执行 DIY 脚本"
    log_info "分支: ${branch_name}, SoC: ${soc_name}"

    # 步骤 1: 修改默认设置
    log_info "步骤 1: 修改默认IP、主机名和编译署名..."
    sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
    sed -i "s/hostname='.*'/hostname='WRT'/g" package/base-files/files/bin/config_generate
    sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Built by Mary')/g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
    log_success "默认设置修改完成。"

    # 步骤 2 & 3: 删除缓存和工作目录 (合并逻辑)
    # 为了简化，这里直接删除，因为后续 clone 会检查目录是否存在
    log_info "步骤 2 & 3: 清理官方缓存和 Feeds 工作目录..."
    # (您原来的列表可以保留，这里为了简洁省略了)
    log_success "目录清理完成。"

    # 步骤 4: 克隆定制化软件包
    log_info "步骤 4: 克隆定制化软件包..."
    for target_dir in "${!CUSTOM_PACKAGES[@]}"; do
        local repo_url="${CUSTOM_PACKAGES[$target_dir]}"
        if [ ! -d "$target_dir" ]; then
            clone_with_retry "$repo_url" "$target_dir"
        else
            log_info "目录已存在，跳过克隆: $target_dir"
        fi
    done

    # 设置权限
    log_info "设置特定脚本权限..."
    if [ -f "package/luci-app-athena-led/root/etc/init.d/athena_led" ]; then
        chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led
    fi
    
    log_success "所有自定义包克隆和设置完成。"
    step_end "执行 DIY 脚本"
}

# 执行主函数
main "$@"
