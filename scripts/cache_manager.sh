#!/bin/bash
# 缓存管理脚本 - 管理编译缓存和清理
# 作者: Mary
# 最后更新: 2024-01-XX

# 加载依赖模块
source ./scripts/logger.sh
source ./scripts/utils.sh

# =============================================================================
# 缓存大小检查函数
# =============================================================================

# 检查缓存大小
# 参数: $1=缓存路径, $2=最大大小GB（默认10）
# 返回: 缓存大小GB
check_cache_size() {
    local cache_path="$1"
    local max_size_gb="${2:-10}"
    
    # 检查路径是否存在
    if [ ! -d "$cache_path" ]; then
        echo "0"
        return
    fi
    
    # 获取缓存大小（字节）
    local size_bytes=$(du -sb "$cache_path" 2>/dev/null | cut -f1)
    
    # 转换为GB
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    
    # 输出大小
    echo "$size_gb"
    
    # 检查是否超过限制
    if [ $size_gb -gt $max_size_gb ]; then
        log_warning "缓存大小 ${size_gb}GB 超过限制 ${max_size_gb}GB"
    else
        log_info "缓存大小 ${size_gb}GB 在限制范围内"
    fi
}

# =============================================================================
# 缓存清理函数
# =============================================================================

# 清理过期缓存
# 参数: $1=最大天数（默认30）
cleanup_expired_cache() {
    local max_days="${1:-30}"
    
    log_info "清理超过 $max_days 天的缓存..."
    
    local cleaned_files=0
    local cleaned_size=0
    
    # 清理ccache
    if command -v ccache >/dev/null; then
        log_info "清理ccache..."
        local ccache_size_before=$(ccache -s | grep "cache size" | awk '{print $3}' | sed 's/M//')
        
        # 清理过期缓存
        ccache --evict-older-than "${max_days}d" 2>/dev/null || true
        
        local ccache_size_after=$(ccache -s | grep "cache size" | awk '{print $3}' | sed 's/M//')
        local cleaned=$((ccache_size_before - ccache_size_after))
        
        if [ $cleaned -gt 0 ]; then
            log_success "ccache清理: ${cleaned}MB"
            ((cleaned_size += cleaned))
        fi
    fi
    
    # 清理下载缓存
    if [ -d "dl" ]; then
        log_info "清理下载缓存..."
        local dl_size_before=$(get_dir_size "dl" | sed 's/[^0-9]//g')
        
        # 删除过期文件
        find dl -type f -mtime +$max_days -delete 2>/dev/null || true
        
        local dl_size_after=$(get_dir_size "dl" | sed 's/[^0-9]//g')
        local cleaned=$((dl_size_before - dl_size_after))
        
        if [ $cleaned -gt 0 ]; then
            log_success "下载缓存清理: ${cleaned}MB"
            ((cleaned_size += cleaned))
        fi
    fi
    
    # 清理临时文件
    log_info "清理临时文件..."
    find /tmp -name "openwrt_*" -mtime +$max_days -delete 2>/dev/null || true
    
    # 清理编译临时文件
    if [ -d "tmp" ]; then
        find tmp -type f -mtime +$max_days -delete 2>/dev/null || true
    fi
    
    # 输出清理结果
    if [ $cleaned_size -gt 0 ]; then
        log_success "缓存清理完成，释放空间: ${cleaned_size}MB"
    else
        log_info "没有需要清理的缓存"
    fi
}

# =============================================================================
# 缓存状态显示函数
# =============================================================================

# 显示缓存状态
show_cache_status() {
    echo ""
    echo "📊 缓存状态报告"
    echo "========================================"
    
    # 检查各个缓存目录
    local cache_dirs=(
        "dl:下载缓存"
        "build_dir:编译目录"
        "staging_dir:暂存目录"
        ".ccache:ccache"
        "feeds:feeds"
    )
    
    for item in "${cache_dirs[@]}"; do
        local dir=$(echo "$item" | cut -d':' -f1)
        local desc=$(echo "$item" | cut -d':' -f2)
        local size="0"
        
        if [ -d "$dir" ]; then
            size=$(get_dir_size "$dir")
        fi
        
        printf "  %-20s: %s\n" "$desc" "$size"
    done
    
    echo "========================================"
    
    # 显示ccache统计
    if command -v ccache >/dev/null; then
        echo ""
        echo "📈 ccache统计:"
        ccache -s | grep -E "(cache size|cache hit rate|files in cache)" | while read line; do
            echo "  $line"
        done
    fi
}

# =============================================================================
# 缓存优化函数
# =============================================================================

# 优化缓存
# 参数: 无
optimize_cache() {
    log_info "优化缓存配置..."
    
    # 优化ccache配置
    if command -v ccache >/dev/null; then
        # 设置最大缓存大小
        ccache -M 5G
        
        # 设置压缩
        ccache -o compression=true
        
        # 统计信息
        ccache -s
        
        log_success "ccache优化完成"
    fi
    
    # 清理重复文件
    log_info "清理重复文件..."
    
    # 在dl目录中查找重复文件
    if [ -d "dl" ]; then
        find dl -type f -exec md5sum {} \; | sort | uniq -d -w32 | cut -d' ' -f3 | while read file; do
            if [ -f "$file" ]; then
                echo "  🗑️ 删除重复文件: $(basename "$file")"
                rm "$file"
            fi
        done
    fi
    
    log_success "缓存优化完成"
}

# =============================================================================
# 缓存备份函数
# =============================================================================

# 备份缓存
# 参数: $1=备份路径（默认./cache_backup）
backup_cache() {
    local backup_path="${1:-./cache_backup}"
    
    log_info "备份缓存到: $backup_path"
    
    # 创建备份目录
    mkdir -p "$backup_path"
    
    # 备份重要缓存
    local backup_items=(
        "dl"
        ".ccache"
        "feeds"
    )
    
    local backup_count=0
    
    for item in "${backup_items[@]}"; do
        if [ -d "$item" ]; then
            echo "  📦 备份: $item"
            tar -czf "$backup_path/${item}.tar.gz" "$item"
            ((backup_count++))
        fi
    done
    
    # 生成备份清单
    {
        echo "# 缓存备份清单"
        echo "备份时间: $(date)"
        echo "备份路径: $backup_path"
        echo ""
        echo "备份项目:"
        for item in "${backup_items[@]}"; do
            if [ -f "$backup_path/${item}.tar.gz" ]; then
                local size=$(get_file_size "$backup_path/${item}.tar.gz")
                echo "- ${item}.tar.gz ($size)"
            fi
        done
    } > "$backup_path/backup_manifest.txt"
    
    log_success "备份完成，共备份 $backup_count 个项目"
}

# =============================================================================
# 缓存恢复函数
# =============================================================================

# 恢复缓存
# 参数: $1=备份路径（默认./cache_backup）
restore_cache() {
    local backup_path="${1:-./cache_backup}"
    
    log_info "从备份恢复缓存: $backup_path"
    
    # 检查备份路径
    if [ ! -d "$backup_path" ]; then
        log_error "备份路径不存在: $backup_path"
        return 1
    fi
    
    # 检查备份清单
    if [ ! -f "$backup_path/backup_manifest.txt" ]; then
        log_error "备份清单不存在"
        return 1
    fi
    
    # 恢复备份项目
    local restore_count=0
    
    # 从清单中读取备份项目
    grep "\.tar.gz" "$backup_path/backup_manifest.txt" | while read line; do
        local backup_file=$(echo "$line" | awk '{print $1}')
        local item=$(echo "$backup_file" | sed 's/\.tar.gz$//')
        
        if [ -f "$backup_path/$backup_file" ]; then
            echo "  📦 恢复: $item"
            tar -xzf "$backup_path/$backup_file"
            ((restore_count++))
        fi
    done
    
    log_success "恢复完成，共恢复 $restore_count 个项目"
}

# =============================================================================
# 主函数
# =============================================================================

# 主函数
# 参数: $1=操作类型, $2+=参数
main() {
    local action="${1:-status}"
    
    case "$action" in
        "check")
            # 检查缓存大小
            local cache_path="${2:-.}"
            local max_size="${3:-10}"
            check_cache_size "$cache_path" "$max_size"
            ;;
        "cleanup")
            # 清理过期缓存
            local max_days="${2:-30}"
            cleanup_expired_cache "$max_days"
            ;;
        "status")
            # 显示缓存状态
            show_cache_status
            ;;
        "optimize")
            # 优化缓存
            optimize_cache
            ;;
        "backup")
            # 备份缓存
            local backup_path="${2:-./cache_backup}"
            backup_cache "$backup_path"
            ;;
        "restore")
            # 恢复缓存
            local backup_path="${2:-./cache_backup}"
            restore_cache "$backup_path"
            ;;
        "all")
            # 执行所有操作
            show_cache_status
            cleanup_expired_cache
            optimize_cache
            ;;
        *)
            # 显示帮助
            echo "用法: $0 <check|cleanup|status|optimize|backup|restore|all> [参数]"
            echo ""
            echo "操作说明:"
            echo "  check [路径] [最大GB]     - 检查缓存大小"
            echo "  cleanup [天数]           - 清理过期缓存"
            echo "  status                   - 显示缓存状态"
            echo "  optimize                 - 优化缓存"
            echo "  backup [路径]            - 备份缓存"
            echo "  restore [路径]           - 恢复缓存"
            echo "  all                      - 执行所有操作"
            exit 1
            ;;
    esac
}

# =============================================================================
# 脚本入口点
# =============================================================================

# 如果直接执行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
