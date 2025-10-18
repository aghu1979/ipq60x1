#!/bin/bash
# 产出物处理脚本 - 处理编译产出物并签名
# 作者: Mary
# 最后更新: 2024-01-XX

# 加载依赖模块
source ./scripts/logger.sh
source ./scripts/utils.sh

# =============================================================================
# 固件签名函数
# =============================================================================

# 签名固件
# 参数: $1=固件文件路径, $2=密钥目录（默认./key-build）
# 返回: 0=成功, 1=失败
sign_firmware() {
    local firmware="$1"
    local key_dir="${2:-./key-build}"
    
    # 检查固件文件是否存在
    if [ ! -f "$firmware" ]; then
        log_error "固件文件不存在: $firmware"
        return 1
    fi
    
    # 创建密钥目录
    mkdir -p "$key_dir"
    
    # 生成签名密钥（如果不存在）
    if [ ! -f "$key_dir/key-build.pem" ]; then
        log_info "生成签名密钥..."
        openssl genpkey -algorithm RSA -out "$key_dir/key-build.pem" -pkeyopt rsa_keygen_bits:2048
        openssl rsa -pubout -in "$key_dir/key-build.pem" -out "$key_dir/key-build.pub"
        log_success "签名密钥生成完成"
    fi
    
    # 签名固件
    log_info "签名固件: $(basename "$firmware")"
    if openssl dgst -sha256 -sign "$key_dir/key-build.pem" -out "${firmware}.sig" "$firmware"; then
        # 验证签名
        if openssl dgst -sha256 -verify "$key_dir/key-build.pub" -signature "${firmware}.sig" "$firmware"; then
            log_success "固件签名成功: $(basename "$firmware")"
            return 0
        else
            log_error "固件签名验证失败: $(basename "$firmware")"
            return 1
        fi
    else
        log_error "固件签名失败: $(basename "$firmware")"
        return 1
    fi
}

# =============================================================================
# 固件重命名函数
# =============================================================================

# 重命名固件
# 参数: $1=原始文件, $2=分支, $3=SoC, $4=设备, $5=类型, $6=配置
rename_firmware() {
    local original="$1"
    local branch="$2"
    local soc="$3"
    local device="$4"
    local type="$5"  # factory or sysupgrade
    local config="$6"
    
    # 提取原始文件信息
    local basename=$(basename "$original")
    local extension="${basename##*.}"
    
    # 新文件名格式: branch-soc-device-type-config.extension
    local new_name="${branch}-${soc}-${device}-${type}-${config}.${extension}"
    
    # 创建产出物目录
    mkdir -p artifacts
    
    # 复制并重命名
    cp "$original" "artifacts/${new_name}"
    
    # 签名固件
    if sign_firmware "artifacts/${new_name}"; then
        log_success "重命名并签名: $basename -> ${new_name}"
    else
        log_warning "重命名但签名失败: $basename -> ${new_name}"
    fi
    
    # 显示文件信息
    echo "  📦 原始文件: $basename ($(get_file_size "$original"))"
    echo "  📦 新文件: ${new_name} ($(get_file_size "artifacts/${new_name}"))"
}

# =============================================================================
# 设备产出物处理函数
# =============================================================================

# 处理单个设备的产出物
# 参数: $1=分支, $2=SoC, $3=设备, $4=配置
process_device_artifacts() {
    local branch="$1"
    local soc="$2"
    local device="$3"
    local config="$4"
    
    log_info "处理设备: $device"
    
    # 查找固件文件
    local factory_bin=$(find bin/targets -name "*${device}*squashfs-factory.bin" 2>/dev/null | head -n1)
    local sysupgrade_bin=$(find bin/targets -name "*${device}*squashfs-sysupgrade.bin" 2>/dev/null | head -n1)
    
    # 处理factory固件
    if [ -n "$factory_bin" ] && [ -f "$factory_bin" ]; then
        rename_firmware "$factory_bin" "$branch" "$soc" "$device" "factory" "$config"
    else
        log_warning "未找到factory固件: $device"
    fi
    
    # 处理sysupgrade固件
    if [ -n "$sysupgrade_bin" ] && [ -f "$sysupgrade_bin" ]; then
        rename_firmware "$sysupgrade_bin" "$branch" "$soc" "$device" "sysupgrade" "$config"
    else
        log_warning "未找到sysupgrade固件: $device"
    fi
    
    # 复制配置文件
    local config_name="${branch}-${soc}-${device}-${config}.config"
    cp .config "artifacts/${config_name}"
    log_info "复制配置文件: ${config_name}"
    
    # 复制manifest
    local manifest=$(find bin/targets -name "manifest" 2>/dev/null | head -n1)
    if [ -n "$manifest" ] && [ -f "$manifest" ]; then
        local manifest_name="${branch}-${soc}-${device}-${config}.manifest"
        cp "$manifest" "artifacts/${manifest_name}"
        log_info "复制manifest: ${manifest_name}"
    fi
    
    # 复制buildinfo
    if [ -f "config.buildinfo" ]; then
        local buildinfo_name="${branch}-${soc}-${device}-${config}.config.buildinfo"
        cp config.buildinfo "artifacts/${buildinfo_name}"
        log_info "复制buildinfo: ${buildinfo_name}"
    fi
}

# =============================================================================
# 软件包收集函数
# =============================================================================

# 收集软件包
# 参数: 无
collect_packages() {
    local package_dir="artifacts/packages"
    mkdir -p "$package_dir"
    
    log_info "收集软件包..."
    
    # 查找所有ipk文件
    local ipk_count=0
    local total_size=0
    
    while IFS= read -r -d '' ipk; do
        cp "$ipk" "$package_dir/"
        ((ipk_count++))
        
        # 计算文件大小
        local size=$(stat -c%s "$ipk")
        ((total_size += size))
    done < <(find bin/packages -name "*.ipk" -print0 2>/dev/null)
    
    # 格式化总大小
    local total_size_mb=$((total_size / 1024 / 1024))
    
    log_success "收集了 $ipk_count 个软件包 (总大小: ${total_size_mb}MB)"
}

# =============================================================================
# 清单生成函数
# =============================================================================

# 生成产出物清单
# 参数: $1=分支, $2=SoC, $3=配置
generate_artifact_manifest() {
    local branch="$1"
    local soc="$2"
    local config="$3"
    local manifest_file="artifacts/MANIFEST.txt"
    
    log_info "生成产出物清单: $manifest_file"
    
    # 生成清单文件
    {
        echo "# 产出物清单"
        echo "生成时间: $(date)"
        echo "分支: $branch"
        echo "SoC: $soc"
        echo "配置: $config"
        echo ""
        
        echo "## 固件文件"
        find artifacts -name "*.bin" -exec basename {} \; | sort | while read fw; do
            echo "- $fw ($(get_file_size "artifacts/$fw"))"
        done
        echo ""
        
        echo "## 配置文件"
        find artifacts -name "*.config*" -exec basename {} \; | sort | while read cfg; do
            echo "- $cfg"
        done
        echo ""
        
        echo "## 软件包"
        if [ -d "artifacts/packages" ]; then
            local pkg_count=$(ls artifacts/packages/*.ipk 2>/dev/null | wc -l)
            local pkg_size=$(get_dir_size artifacts/packages)
            echo "总数: $pkg_count"
            echo "大小: $pkg_size"
        fi
        echo ""
        
        echo "## 签名文件"
        find artifacts -name "*.sig" -exec basename {} \; | sort | while read sig; do
            echo "- $sig"
        done
        echo ""
        
        echo "## 校验和"
        echo "SHA256校验和:"
        find artifacts -type f \( -name "*.bin" -o -name "*.tar.gz" \) -exec sha256sum {} \; | while read sum; do
            echo "  $sum"
        done
    } > "$manifest_file"
    
    log_success "产出物清单已生成: $manifest_file"
}

# =============================================================================
# 主处理函数
# =============================================================================

# 主处理函数
# 参数: $1=分支, $2=配置, $3=SoC（默认ipq60xx）
process_artifacts() {
    local branch="$1"
    local config="$2"
    local soc="${3:-ipq60xx}"
    
    # 开始步骤
    step_start "处理产出物: $branch-$config"
    
    # 创建产出物目录
    mkdir -p artifacts
    mkdir -p artifacts/packages
    
    # 提取设备列表
    local devices=$(extract_devices .config)
    
    # 检查是否找到设备
    if [ -z "$devices" ]; then
        log_error "未找到设备配置"
        exit 1
    fi
    
    # 处理每个设备
    local device_count=$(echo "$devices" | wc -l)
    local current=0
    
    while IFS= read -r device; do
        ((current++))
        show_progress $current $device_count "处理设备"
        process_device_artifacts "$branch" "$soc" "$device" "$config"
    done <<< "$devices"
    
    # 收集软件包
    collect_packages
    
    # 生成清单
    generate_artifact_manifest "$branch" "$soc" "$config"
    
    # 显示摘要
    echo ""
    echo "📊 产出物摘要:"
    echo "  - 固件文件: $(ls artifacts/*.bin 2>/dev/null | wc -l)"
    echo "  - 配置文件: $(ls artifacts/*.config* 2>/dev/null | wc -l)"
    echo "  - 软件包: $(ls artifacts/packages/*.ipk 2>/dev/null | wc -l)"
    echo "  - 总大小: $(get_dir_size artifacts)"
    
    # 结束步骤
    step_end "产出物处理完成"
}

# =============================================================================
# 打包函数
# =============================================================================

# 打包产出物
# 参数: $1=SoC（默认ipq60xx）
package_artifacts() {
    local soc="${1:-ipq60xx}"
    local output_dir="release"
    
    # 开始步骤
    step_start "打包产出物"
    
    # 创建发布目录
    mkdir -p "$output_dir"
    
    # 打包配置文件
    log_info "打包配置文件..."
    local config_files=$(ls artifacts/*.config* 2>/dev/null)
    if [ -n "$config_files" ]; then
        tar -czf "${output_dir}/${soc}-config.tar.gz" -C artifacts $config_files
        log_success "配置文件打包完成: ${soc}-config.tar.gz"
    fi
    
    # 打包软件包
    log_info "打包软件包..."
    if [ -d "artifacts/packages" ]; then
        tar -czf "${output_dir}/${soc}-app.tar.gz" -C artifacts/packages .
        log_success "软件包打包完成: ${soc}-app.tar.gz"
    fi
    
    # 打包日志
    log_info "打包日志..."
    local log_files=$(ls artifacts/*.log 2>/dev/null)
    if [ -n "$log_files" ]; then
        tar -czf "${output_dir}/${soc}-log.tar.gz" -C artifacts $log_files
        log_success "日志打包完成: ${soc}-log.tar.gz"
    fi
    
    # 生成校验和
    log_info "生成校验和..."
    cd "$output_dir"
    sha256sum *.tar.gz > checksums.txt
    cd ..
    
    # 显示打包结果
    echo ""
    echo "📦 打包结果:"
    ls -lh "$output_dir"/*.tar.gz 2>/dev/null | while read line; do
        echo "  $line"
    done
    
    # 结束步骤
    step_end "打包完成"
}

# =============================================================================
# 主函数
# =============================================================================

# 主函数
# 参数: $1=分支, $2=配置, $3=SoC（可选）
main() {
    # 检查参数
    if [ $# -lt 2 ]; then
        echo "❌ 用法错误"
        echo "用法: $0 <branch> <config> [soc]"
        echo "示例: $0 openwrt Pro ipq60xx"
        exit 1
    fi
    
    # 处理产出物
    process_artifacts "$1" "$2" "$3"
    
    # 打包产出物
    package_artifacts "${3:-ipq60xx}"
    
    log_success "产出物处理流程完成"
}

# =============================================================================
# 脚本入口点
# =============================================================================

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
