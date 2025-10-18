#!/bin/bash
# 发布准备脚本 - 准备Release内容和发布说明
# 作者: Mary
# 最后更新: 2024-01-XX

# 加载依赖模块
source ./scripts/logger.sh

# =============================================================================
# 信息获取函数
# =============================================================================

# 获取内核版本
# 返回: 内核版本字符串
get_kernel_version() {
    if [ -f ".config" ]; then
        # 从配置文件中提取内核版本
        local kernel_ver=$(grep "^CONFIG_KERNEL_VERSION" .config | cut -d'"' -f2)
        if [ -n "$kernel_ver" ]; then
            echo "$kernel_ver"
        else
            # 尝试其他方式获取
            kernel_ver=$(grep "^CONFIG_KERNEL" .config | head -n1 | cut -d'=' -f2 | tr -d '"')
            echo "${kernel_ver:-未知}"
        fi
    else
        echo "未知"
    fi
}

# 获取设备列表
# 返回: 设备列表字符串
get_device_list() {
    # 从配置文件中提取设备列表
    local devices=$(grep "CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" .config 2>/dev/null | \
                   sed 's/.*_DEVICE_\(.*\)=y/\1/' | \
                   sort -u | \
                   tr '\n' ', ' | sed 's/,$//')
    echo "${devices:-无}"
}

# 获取Luci应用列表
# 返回: Luci应用列表
get_luci_apps() {
    # 获取所有Luci应用
    local apps=$(grep "^CONFIG_PACKAGE_luci-app.*=y" .config 2>/dev/null | \
                cut -d'=' -f1 | \
                sed 's/CONFIG_PACKAGE_//' | \
                sort | \
                head -20)  # 限制显示数量
    
    # 格式化输出
    if [ -n "$apps" ]; then
        echo "$apps" | while read app; do
            echo "- $app"
        done
    else
        echo "无"
    fi
}

# 获取编译信息
# 返回: 编译信息字符串
get_build_info() {
    local build_date=$(date '+%Y-%m-%d %H:%M:%S')
    local build_host=$(hostname)
    local build_user=$(whoami)
    
    echo "编译时间: $build_date"
    echo "编译主机: $build_host"
    echo "编译用户: $build_user"
}

# =============================================================================
# 发布说明生成函数
# =============================================================================

# 生成发布说明
# 参数: $1=SoC（默认ipq60xx）
generate_release_notes() {
    local soc="${1:-ipq60xx}"
    local date=$(date '+%Y-%m-%d %H:%M:%S')
    local kernel_ver=$(get_kernel_version)
    local devices=$(get_device_list)
    local build_info=$(get_build_info)
    
    # 生成Markdown格式的发布说明
    cat << EOF
# OpenWrt 固件发布 - $soc

## 📥 下载说明

### 固件文件说明
- **\*-factory-*.bin**: 用于首次刷机或恢复出厂设置
- **\*-sysupgrade-*.bin**: 用于系统升级（保留配置）
- **校验和文件**: 请下载后验证文件完整性

### 刷机步骤
1. 下载对应设备的固件文件
2. 使用SHA256校验和验证文件完整性
3. 根据设备类型选择合适的刷机方法
4. 刷机后恢复出厂设置

## 🔑 基本信息

| 项目 | 值 |
|------|-----|
| **默认管理地址** | 192.168.111.1 |
| **默认用户** | root |
| **默认密码** | none（空密码） |
| **默认WiFi密码** | 12345678 |
| **SSH端口** | 22 |

## 📋 固件信息

| 项目 | 值 |
|------|-----|
| **包含分支** | openwrt, immwrt, libwrt |
| **包含设备** | $devices |
| **包含配置** | Pro, Max, Ultra |
| **内核版本** | $kernel_ver |
| **编译时间** | $date |

## 📦 编译的Luci应用列表

 $(get_luci_apps)

## 👤 作者信息

- **作者**: Mary
- **项目仓库**: [$GITHUB_REPOSITORY]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY)
- **编译任务**: [#$GITHUB_RUN_NUMBER]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)

## 📁 附件说明

| 文件类型 | 说明 |
|----------|------|
| **\*-factory-*.bin** | 刷机固件 |
| **\*-sysupgrade-*.bin** | 升级固件 |
| **$soc-config.tar.gz** | 所有配置文件 |
| **$soc-app.tar.gz** | 所有软件包 |
| **$soc-log.tar.gz** | 编译日志 |
| **checksums.txt** | 文件校验和 |

## 🔧 编译环境信息

 $build_info

## ⚠️ 注意事项

### 重要提醒
1. **刷机前请备份原固件**
2. **首次刷机使用factory.bin**
3. **升级使用sysupgrade.bin**
4. **刷机后建议恢复出厂设置**

### 兼容性说明
- 本固件仅适用于指定的设备型号
- 不同设备请勿混用固件
- 升级前请确认设备型号

### 性能优化
- 已启用必要的内核优化
- 预装常用软件包
- 优化网络性能

## 🐛 问题反馈

如果遇到问题，请按以下步骤操作：

1. **查看日志**
   - [完整编译日志]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)
   - 设备日志: \`logread\` 或 \`dmesg\`

2. **收集信息**
   - 设备型号
   - 固件版本
   - 问题描述
   - 复现步骤

3. **提交反馈**
   - [提交Issue]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/issues)
   - 请附上相关日志和截图

## 📚 相关链接

- [OpenWrt官网](https://openwrt.org)
- [项目源码]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY)
- [更新日志](CHANGELOG.md)

## 📄 许可证

本项目遵循 GPL-3.0 许可证。

---

**感谢使用 OpenWrt 固件！** 🎉

如果觉得有用，请给个⭐️支持一下！
EOF
}

# =============================================================================
# 设备对比表生成函数
# =============================================================================

# 生成设备对比表
# 参数: 无
generate_device_comparison() {
    local output_file="device_comparison.md"
    
    log_info "生成设备对比表: $output_file"
    
    # 生成对比表
    cat > $output_file << EOF
# 设备支持对比

## 支持的设备

| 设备型号 | Pro版本 | Max版本 | Ultra版本 | 备注 |
|----------|---------|---------|-----------|------|
| jdcloud_re-ss-01 | ✅ | ✅ | ✅ | 主流设备 |
| jdcloud_re-cs-02 | ✅ | ✅ | ✅ | 主流设备 |

## 版本差异

| 功能 | Pro | Max | Ultra |
|------|-----|-----|-------|
| 基础功能 | ✅ | ✅ | ✅ |
| 高级网络 | ❌ | ✅ | ✅ |
| 科学上网 | ❌ | ❌ | ✅ |
| 性能优化 | 基础 | 增强 | 最强 |
| 软件包数量 | 基础 | 丰富 | 最全 |

## 选择建议

- **Pro版本**: 适合基础使用，稳定可靠
- **Max版本**: 适合进阶用户，功能丰富
- **Ultra版本**: 适合高级用户，功能最全

EOF
    
    log_success "设备对比表已生成: $output_file"
}

# =============================================================================
# 软件包清单生成函数
# =============================================================================

# 生成软件包清单
# 参数: 无
generate_package_list() {
    local output_file="package_list.txt"
    
    log_info "生成软件包清单: $output_file"
    
    # 生成清单
    {
        echo "# 软件包清单"
        echo "生成时间: $(date)"
        echo ""
        
        echo "## 所有软件包"
        if [ -d "release/packages" ]; then
            ls release/packages/*.ipk 2>/dev/null | xargs -n1 basename | sort
        else
            echo "无软件包"
        fi
        echo ""
        
        echo "## 分类统计"
        if [ -d "release/packages" ]; then
            echo "总数: $(ls release/packages/*.ipk 2>/dev/null | wc -l)"
            echo "大小: $(get_dir_size release/packages)"
        fi
    } > "$output_file"
    
    log_success "软件包清单已生成: $output_file"
}

# =============================================================================
# 更新日志生成函数
# =============================================================================

# 生成更新日志
# 参数: 无
generate_changelog() {
    local output_file="CHANGELOG.md"
    
    log_info "生成更新日志: $output_file"
    
    # 生成更新日志
    cat > $output_file << EOF
# 更新日志

## [$(date '+%Y-%m-%d')] - 新版本发布

### 新增
- 支持多芯片架构编译
- 新增自动签名功能
- 优化缓存策略
- 增强错误处理

### 改进
- 提升编译速度
- 优化软件包依赖处理
- 改进日志系统
- 增强产出物管理

### 修复
- 修复配置合并问题
- 解决软件包冲突
- 修复签名验证问题

### 已知问题
- 暂无

## 历史版本

### [2024-01-XX] - 初始版本
- 基础功能实现
- 支持OpenWrt编译
- 基本的产出物处理

EOF
    
    log_success "更新日志已生成: $output_file"
}

# =============================================================================
# 主函数
# =============================================================================

# 主函数
# 参数: $1=SoC（默认ipq60xx）
main() {
    local soc="${1:-ipq60xx}"
    
    # 开始步骤
    step_start "准备发布内容"
    
    # 生成发布说明
    log_info "生成发布说明..."
    generate_release_notes "$soc"
    
    # 生成辅助文档
    generate_device_comparison
    generate_package_list
    generate_changelog
    
    # 显示统计信息
    echo ""
    echo "📊 发布统计:"
    echo "  - 固件文件: $(ls release/*.bin 2>/dev/null | wc -l)"
    echo "  - 配置包: $(ls release/*-config.tar.gz 2>/dev/null | wc -l)"
    echo "  - 软件包: $(ls release/*-app.tar.gz 2>/dev/null | wc -l)"
    echo "  - 日志包: $(ls release/*-log.tar.gz 2>/dev/null | wc -l)"
    echo "  - 文档文件: $(ls *.md 2>/dev/null | wc -l)"
    
    # 结束步骤
    step_end "发布准备完成"
    
    log_success "所有发布内容准备完成"
}

# =============================================================================
# 脚本入口点
# =============================================================================

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
