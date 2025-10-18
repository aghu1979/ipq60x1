#!/bin/bash
# 工具函数库 - 提供通用的工具函数
# 作者: Mary
# 最后更新: 2025-10-18

# =============================================================================
# 命令检查函数
# =============================================================================

# 检查命令是否存在
# 参数: $1=命令名称
# 返回: 0=存在, 1=不存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# 文件处理函数
# =============================================================================

# 检查文件是否存在（忽略大小写）
# 参数: $1=文件路径
# 返回: 0=存在, 1=不存在
file_exists_case_insensitive() {
    local file="$1"
    local dir=$(dirname "$file")
    local basename=$(basename "$file")
    
    # 如果目录存在
    if [ -d "$dir" ]; then
        # 查找文件（忽略大小写）
        local found=$(find "$dir" -iname "$basename" -type f | head -n1)
        [ -n "$found" ]
    else
        return 1
    fi
}

# 获取文件真实路径（处理大小写）
# 参数: $1=文件路径
# 返回: 文件真实路径
get_real_path() {
    local file="$1"
    local dir=$(dirname "$file")
    local basename=$(basename "$file")
    
    # 如果目录存在
    if [ -d "$dir" ]; then
        # 查找文件（忽略大小写）
        find "$dir" -iname "$basename" -type f | head -n1
    fi
}

# =============================================================================
# 设备处理函数
# =============================================================================

# 提取设备名称
# 参数: $1=配置文件路径
# 返回: 设备名称列表
extract_devices() {
    local config_file="$1"
    
    # 从配置文件中提取设备名称
    local devices=$(grep "CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$config_file" 2>/dev/null | \
                   sed 's/.*_DEVICE_\(.*\)=y/\1/' | \
                   sort -u)
    
    # 如果没有找到设备
    if [ -z "$devices" ]; then
        echo "⚠️ 未找到设备配置"
        return 1
    fi
    
    # 统计设备数量
    local device_count=$(echo "$devices" | wc -l)
    echo "🔍 检测到 $device_count 个设备:"
    echo "$devices" | while read device; do
        echo "  - $device"
    done
    
    # 返回设备列表
    echo "$devices"
}

# =============================================================================
# 随机数生成函数
# =============================================================================

# 生成随机字符串
# 参数: $1=长度（默认16）
# 返回: 随机字符串
generate_random() {
    local length=${1:-16}
    openssl rand -hex $((length/2))
}

# =============================================================================
# 网络相关函数
# =============================================================================

# 检查网络连接
# 参数: $1=URL（默认https://github.com）
# 返回: 0=连接正常, 1=连接失败
check_network() {
    local url=${1:-"https://github.com"}
    
    # 使用curl检查网络连接
    if curl -s --head "$url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 等待网络连接
# 参数: $1=最大尝试次数（默认30）
# 返回: 0=连接成功, 1=连接失败
wait_for_network() {
    local max_attempts=${1:-30}
    local attempt=1
    
    echo "⏳ 等待网络连接..."
    
    # 循环检查网络连接
    while [ $attempt -le $max_attempts ]; do
        if check_network; then
            echo "✅ 网络连接正常"
            return 0
        fi
        
        echo "  尝试 $attempt/$max_attempts..."
        sleep 2
        ((attempt++))
    done
    
    echo "❌ 网络连接失败"
    return 1
}

# =============================================================================
# 安全操作函数
# =============================================================================

# 安全删除目录
# 参数: $1=目录路径
# 返回: 0=成功, 1=失败
safe_remove() {
    local path="$1"
    
    # 安全检查
    if [ -n "$path" ] && [ "$path" != "/" ] && [[ "$path" == *"/"*" ]]; then
        rm -rf "$path"
        echo "🗑️ 已删除: $path"
        return 0
    else
        echo "⚠️ 拒绝删除不安全的路径: $path"
        return 1
    fi
}

# 创建符号链接（处理已存在的情况）
# 参数: $1=源路径, $2=目标路径
# 返回: 0=成功, 1=失败
safe_symlink() {
    local source $GITHUB_WORKSPACE/scripts/logger.sh
    local source $GITHUB_WORKSPACE/scripts/utils.sh
    
    local source="$1"
    local target="$2"
    
    # 如果目标已存在，先删除
    if [ -e "$target" ]; then
        echo "⚠️ 目标已存在，删除: $target"
        rm -rf "$target"
    fi
    
    # 创建符号链接
    ln -sf "$source" "$target"
    echo "🔗 创建链接: $source -> $target"
}

# =============================================================================
# 文件大小函数
# =============================================================================

# 获取文件大小（人类可读）
# 参数: $1=文件路径
# 返回: 文件大小
get_file_size() {
    local file="$1"
    
    if [ -f "$file" ]; then
        ls -lh "$file" | awk '{print $5}'
    else
        echo "0"
    fi
}

# 获取目录大小
# 参数: $1=目录路径
# 返回: 目录大小
get_dir_size() {
    local dir="$1"
    
    if [ -d "$dir" ]; then
        du -sh "$dir" | cut -f1
    else
        echo "0"
    fi
}

# =============================================================================
# 磀查磁盘空间
# =============================================================================

# 检查磁盘空间
# 参数: $1=路径（默认当前目录）, $2=最小空间GB（默认5）
# 返回: 0=充足, 1=不足
check_disk_space() {
    local path=${1:-"."}
    local min_space_gb=${2:-5}
    
    # 获取可用空间（KB）
    local available=$(df "$path" | awk 'NR==2 {print $4}')
    
    # 转换为GB
    local available_gb=$((available / 1024 / 1024))
    
    # 检查是否满足最小空间要求
    if [ $available_gb -lt $min_space_gb ]; then
        echo "⚠️ 磁盘空间不足: ${available_gb}GB 可用，需要至少 ${min_space_gb}GB"
        return 1
    else
        echo "✅ 磁盘空间充足: ${available_gb}GB 可用"
        return 0
    fi
}

# =============================================================================
# 并行执行函数
# =============================================================================

# 并行执行函数
# 参数: $1=最大并行数, $2+=任务列表
parallel_exec() {
    local max_jobs=${1:-$(nproc)}
    local tasks=("${@:2}")
    local job_count=0
    
    echo "🔄 开始并行执行，最大并行数: $max_jobs"
    
    # 遍历所有任务
    for task in "${tasks[@]}"; do
        # 等待有空闲槽位
        while [ $job_count -ge $max_jobs ]; do
            wait -n
            ((job_count--))
        done
        
        # 启动任务
        (
            echo "  执行任务: $task"
            eval "$task"
        ) &
        ((job_count++))
    done
    
    # 等待所有任务完成
    wait
    echo "✅ 所有任务执行完成"
}

# =============================================================================
# 配置验证函数
# =============================================================================

# 验证配置文件格式
# 参数: $1=配置文件路径
# 返回: 0=有效, 1=无效
validate_config() {
    local config_file="$1"
    
    # 检查文件是否存在
    if [ ! -f "$config_file" ]; then
        echo "❌ 配置文件不存在: $config_file"
        return 1
    fi
    
    # 检查配置文件格式
    local invalid_lines=$(grep -v '^#' "$config_file" | grep -v '^$' | grep -v '^CONFIG_')
    
    # 如果有无效行
    if [ -n "$invalid_lines" ]; then
        echo "⚠️ 配置文件格式警告:"
        echo "$invalid_lines"
    fi
    
    echo "✅ 配置文件验证通过: $config_file"
    return 0
}

# =============================================================================
# 配置差异函数
# =============================================================================

# 生成配置差异报告
# 参数: $1=旧配置文件, $2=新配置文件, $3=输出文件
generate_config_diff() {
    local old_config="$1"
    local new_config="$2"
    local output_file="$3"
    
    # 检查文件是否存在
    if [ ! -f "$old_config" ] || [ ! -f "$new_config" ]; then
        echo "❌ 配置文件不存在"
        return 1
    fi
    
    # 生成差异报告
    {
        echo "# 配置差异报告"
        echo "生成时间: $(date)"
        echo "旧配置: $old_config"
        echo "新配置: $new_config"
        echo ""
        
        echo "## 新增的配置项"
        diff -u "$old_config" "$new_config" | grep "^+" | grep "^+CONFIG_" | sed 's/^+//' || echo "无新增"
        echo ""
        
        echo "## 删除的配置项"
        diff -u "$old_config" "$new_config" | grep "^-" | grep "^-CONFIG_" | sed 's/^-//' || echo "无删除"
        echo ""
        
        echo "## 修改的配置项"
        diff -u "$old_config" "$new_config" | grep "^-" | grep "^-CONFIG_" | while read line; do
            local config=$(echo "$line" | sed 's/^-//')
            if grep -q "^$config" "$new_config"; then
                echo "$config"
            fi
        done
    } > "$output_file"
    
    echo "✅ 配置差异报告已生成: $output_file"
}

# =============================================================================
# 时间函数
# =============================================================================

# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 获取Unix时间戳
get_unix_timestamp() {
    date +%s
}

# 格式化持续时间
# 参数: $1=秒数
# 返回: 格式化的时间字符串
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}小时${minutes}分钟${secs}秒"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}分钟${secs}秒"
    else
        echo "${secs}秒"
    fi
}

# =============================================================================
# 进度显示函数
# =============================================================================

# 显示进度条
# 参数: $1=当前进度, $2=总进度, $3=描述
show_progress() {
    local current=$1
    local total=$2
    local description=${3:-"处理中"}
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))
    
    # 构建进度条
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    # 输出进度条
    printf "\r⏳ %s [%s] %d%% (%d/%d/%d/%d)" "$description" "$bar" "$percentage" "$current" "$total"
    
    # 如果完成，换行
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# =============================================================================
# 初始化
# =============================================================================

# 加载时显示初始化信息
echo "🔧 工具函数库已加载"
