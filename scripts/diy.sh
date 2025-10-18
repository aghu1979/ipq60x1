#!/bin/bash
# DIY脚本 - 配置第三方源及设备初始设置
# 作者: Mary
# 最后更新: 2025-10-18

# 启用严格模式
set -euo pipefail

# 导入日志模块
source ./scripts/logger.sh

# =============================================================================
# 主逻辑
# =============================================================================

# 主函数
# 参数: $1=分支名称, $2=SoC名称
main() {
    # 接收参数
    local branch_name="${1:-openwrt}"
    local soc_name="${2:-ipq60xx}"
    
    # 开始步骤
    step_start "DIY配置: $branch_name-$soc_name"
    
    # 显示配置信息
    echo "=========================================="
    echo " DIY Script for OpenWrt"
    echo " Branch: ${branch_name}"
    echo " SoC:     ${soc_name}"
    echo "=========================================="
    
    # 步骤 1: 修改默认设置
    log_info "修改默认IP、主机名和编译署名..."
    
    # 修改默认IP
    if grep -q "192.168.1.1" package/base-files/files/bin/config_generate; then
        sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
        log_success "默认IP已修改为: 192.168.111.1"
    fi
    
    # 修改主机名
    if grep -q "hostname=" package/base-files/files/bin/config_generate; then
        sed -i "s/hostname='.*'/hostname='WRT'/g" package/base-files/files/bin/config_generate
        log_success "主机名已修改为: WRT"
    fi
    
    # 添加编译署名
    local status_file="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
    if [ -f "$status_file" ]; then
        sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Built by Mary')/g" "$status_file"
        log_success "编译署名已添加"
    else
        log_warning "状态文件不存在，跳过署名添加"
    fi
    
    # 步骤 2: 预删除官方软件源缓存
    log_info "预删除官方软件源缓存..."
    
    # 定义需要删除的官方缓存包
    local official_cache_packages=(
        "package/feeds/packages/golang"
        "package/feeds/packages/ariang"
        "package/feeds/packages/frp"
        "package/feeds/packages/adguardhome"
        "package/feeds/packages/wolplus"
        "package/feeds/packages/lucky"
        "package/feeds/packages/wechatpush"
        "package/feeds/packages/open-app-filter"
        "package/feeds/packages/gecoosac"
        "package/feeds/luci/luci-app-frpc"
        "package/feeds/luci/luci-app-frps"
        "package/feeds/luci/luci-app-adguardhome"
        "package/feeds/luci/luci-app-wolplus"
        "package/feeds/luci/luci-app-lucky"
        "package/feeds/luci/luci-app-wechatpush"
        "package/feeds/luci/luci-app-athena-led"
        "package/feeds/packages/netspeedtest"
        "package/feeds/packages/partexp"
        "package/feeds/packages/taskplan"
        "package/feeds/packages/tailscale"
        "package/feeds/packages/momo"
        "package/feeds/packages/nikki"
        "package/feeds/luci/luci-app-netspeedtest"
        "package/feeds/luci/luci-app-partexp"
        "package/feeds/luci/luci-app-taskplan"
        "package/feeds/luci/luci-app-tailscale"
        "package/feeds/luci/luci-app-momo"
        "package/feeds/luci/luci-app-nikki"
        "package/feeds/luci/luci-app-openclash"
    )
    
    # 删除缓存包
    local deleted_count=0
    for package in "${official_cache_packages[@]}"; do
        if [ -d "$package" ]; then
            rm -rf "$package"
            ((deleted_count++))
            echo "  🗑️ 已删除: $package"
        fi
    done
    log_success "删除了 $deleted_count 个缓存包"
    
    # 步骤 3: 预删除feeds工作目录
    log_info "预删除feeds工作目录..."
    
    # 定义需要删除的feeds工作包
    local feeds_work_packages=(
        "feeds/packages/lang/golang"
        "feeds/packages/net/ariang"
        "feeds/packages/net/frp"
        "feeds/packages/net/adguardhome"
        "feeds/packages/net/wolplus"
        "feeds/packages/net/lucky"
        "feeds/packages/net/wechatpush"
        "feeds/packages/net/open-app-filter"
        "feeds/packages/net/gecoosac"
        "feeds/luci/applications/luci-app-frpc"
        "feeds/luci/applications/luci-app-frps"
        "feeds/luci/applications/luci-app-adguardhome"
        "feeds/luci/applications/luci-app-wolplus"
        "feeds/luci/applications/luci-app-lucky"
        "feeds/luci/applications/luci-app-wechatpush"
        "feeds/luci/applications/luci-app-athena-led"
        "feeds/packages/net/netspeedtest"
        "feeds/packages/utils/partexp"
        "feeds/packages/utils/taskplan"
        "feeds/packages/net/tailscale"
        "feeds/packages/net/momo"
        "feeds/packages/net/nikki"
        "feeds/luci/applications/luci-app-netspeedtest"
        "feeds/luci/applications/luci-app-partexp"
        "feeds/luci/applications/luci-app-taskplan"
        "feeds/luci/applications/luci-app-tailscale"
        "feeds/luci/applications/luci-app-momo"
        "feeds/luci/applications/luci-app-nikki"
        "feeds/luci/applications/luci-app-openclash"
    )
    
    # 删除工作目录包
    deleted_count=0
    for package in "${feeds_work_packages[@]}"; do
        if [ -d "$package" ]; then
            rm -rf "$package"
            ((deleted_count++))
            echo "  🗑️ 已删除: $package"
        fi
    done
    log_success "删除了 $deleted_count 个工作目录包"
    
    # 步骤 4: 克隆定制化软件包
    log_info "克隆定制化软件包..."
    
    # 创建必要的目录
    mkdir -p feeds/packages/lang
    mkdir -p feeds/packages/net
    mkdir -p feeds/luci/applications
    mkdir -p package
    
    # 定义克隆命令
    local clone_commands=(
        "git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang"
        "git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist"
        "git clone --depth=1 https://github.com/laipeng668/packages.git feeds/packages/net/ariang"
        "git clone --depth=1 https://github.com/laipeng668/packages.git feeds/packages/net/frp"
        "git clone --depth=1 https://github.com/laipeng668/luci.git feeds/luci/applications/luci-app-frpc"
        "git clone --depth=1 https://github.com/laipeng668/luci.git feeds/luci/applications/luci-app-frps"
        "git clone --depth=1 https://github.com/kenzok8/openwrt-packages.git package/adguardhome"
        "git clone --depth=1 https://github.com/kenzok8/openwrt-packages.git package/luci-app-adguardhome"
        "git clone --depth=1 https://github.com/VIKINGYFY/packages.git feeds/luci/applications/luci-app-wolplus"
        "git clone --depth=1 https://github.com/tty228/luci-app-wechatpush.git package/luci-app-wechatpush"
        "git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter"
        "git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac.git package/openwrt-gecoosac"
        "git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led.git package/luci-app-athena-led"
        "git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest.git package/netspeedtest"
        "git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp.git package/partexp"
        "git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/taskplan"
        "git clone --depth=1 https://github.com/tailscale/tailscale.git package/tailscale"
        "git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo.git package/momo"
        "git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki.git package/nikki"
        "git clone --depth=1 https://github.com/vernesong/OpenClash.git package/openclash"
        "git clone --depth=1 https://github.com/kenzok8/small-package smpackage"
    )
    
    # 执行克隆命令
    local cloned_count=0
    local failed_count=0
    
    for cmd in "${clone_commands[@]}"; do
        echo "  📥 执行: $cmd"
        if eval "$cmd" 2>/dev/null; then
            ((cloned_count++))
            echo "    ✅ 成功"
        else
            ((failed_count++))
            echo "    ❌ 失败"
            log_warning "克隆失败: $cmd"
        fi
    done
    
    log_success "克隆结果: 成功 $cloned_count 个，失败 $failed_count 个"
    
    # 步骤 5: 设置权限
    log_info "设置文件权限..."
    
    # 设置athena-led权限
    if [ -f "package/luci-app-athena-led/root/etc/init.d/athena_led" ]; then
        chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led
        echo "  ✅ athena_led init脚本权限已设置"
    fi
    
    if [ -f "package/luci-app-athena-led/root/usr/sbin/athena-led" ]; then
        chmod +x package/luci-app-athena-led/root/usr/sbin/athena-led
        echo "  ✅ athena-led二进制权限已设置"
    fi
    
    # 步骤 6: 验证克隆结果
    log_info "验证克隆结果..."
    
    local verification_failed=0
    
    # 检查关键软件包
    local critical_packages=(
        "feeds/packages/lang/golang"
        "package/openclash"
        "package/luci-app-athena-led"
        "package/netspeedtest"
    )
    
    for pkg in "${critical_packages[@]}"; do
        if [ ! -d "$pkg" ]; then
            log_error "关键软件包缺失: $pkg"
            ((verification_failed++))
        fi
    done
    
    if [ $verification_failed -gt 0 ]; then
        log_error "验证失败，有 $verification_failed 个关键软件包缺失"
    else
        log_success "所有关键软件包验证通过"
    fi
    
    # 结束步骤
    step_end "DIY配置完成"
    
    # 显示摘要
    echo ""
    echo "📊 DIY配置摘要:"
    echo "  - 删除缓存包: $deleted_count"
    echo "  - 克隆软件包: $cloned_count"
    echo "  - 失败数量: $failed_count"
    echo "  - 验证失败: $verification_failed"
    
    # 返回结果
    if [ $verification_failed -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# =============================================================================
# 脚本入口点
# =============================================================================

# 执行主函数
main "$@"
