#!/bin/bash

# 工具函数脚本：提供通用的工具函数
# 作者：AI助手
# 用途：为其他脚本提供通用的工具函数

# 导入日志函数
source $(dirname "${BASH_SOURCE[0]}")/logger.sh

# 函数：检查命令是否存在
# 参数：$1 - 命令名称
# 返回：0 - 存在，1 - 不存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 函数：检查文件是否存在
# 参数：$1 - 文件路径
# 返回：0 - 存在，1 - 不存在
file_exists() {
    [ -f "$1" ]
}

# 函数：检查目录是否存在
# 参数：$1 - 目录路径
# 返回：0 - 存在，1 - 不存在
dir_exists() {
    [ -d "$1" ]
}

# 函数：创建目录（如果不存在）
# 参数：$1 - 目录路径
create_dir() {
    if ! dir_exists "$1"; then
        mkdir -p "$1"
        log_info "创建目录: $1"
    fi
}

# 函数：复制文件（如果源文件存在）
# 参数：$1 - 源文件路径，$2 - 目标文件路径
copy_file() {
    if file_exists "$1"; then
        cp "$1" "$2"
        log_info "复制文件: $1 -> $2"
    else
        log_error "源文件不存在: $1"
        return 1
    fi
}

# 函数：合并配置文件
# 参数：$1 - 输出文件路径，$2... - 输入文件路径
merge_configs() {
    local output_file="$1"
    shift
    local input_files=("$@")
    
    log_info "合并配置文件到: $output_file"
    
    # 清空输出文件
    > "$output_file"
    
    # 合并所有输入文件
    for input_file in "${input_files[@]}"; do
        if file_exists "$input_file"; then
            cat "$input_file" >> "$output_file"
            log_info "添加配置文件: $input_file"
        else
            log_error "配置文件不存在: $input_file"
            return 1
        fi
    done
    
    log_info "配置文件合并完成"
}

# 函数：比较软件包列表
# 参数：$1 - 第一个列表文件，$2 - 第二个列表文件，$3 - 输出差异文件
compare_package_lists() {
    local list1="$1"
    local list2="$2"
    local diff_file="$3"
    
    log_info "比较软件包列表: $list1 vs $list2"
    
    if file_exists "$list1" && file_exists "$list2"; then
        # 比较两个列表并保存差异
        diff -u "$list1" "$list2" > "$diff_file" || true
        
        if [ -s "$diff_file" ]; then
            log_info "软件包列表有差异，差异已保存到: $diff_file"
        else
            log_info "软件包列表无差异"
        fi
    else
        log_error "无法比较软件包列表，文件不存在"
        return 1
    fi
}

# 函数：获取系统信息
get_system_info() {
    log_info "获取系统信息"
    
    echo "-------- 系统信息 --------"
    echo "操作系统: $(uname -s)"
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
    echo "CPU核心数: $(nproc)"
    echo "内存信息: $(free -h | grep Mem)"
    echo "磁盘使用: $(df -h / | tail -1)"
    echo "------------------------"
}

# 函数：清理临时文件
# 参数：$1... - 要清理的文件或目录路径
cleanup_temp_files() {
    local paths=("$@")
    
    log_info "清理临时文件"
    
    for path in "${paths[@]}"; do
        if [ -e "$path" ]; then
            rm -rf "$path"
            log_info "已删除: $path"
        else
            log_warning "路径不存在: $path"
        fi
    done
    
    log_info "临时文件清理完成"
}

# 函数：计算文件哈希值
# 参数：$1 - 文件路径
# 返回：文件哈希值
calculate_hash() {
    local file="$1"
    
    if file_exists "$file"; then
        sha256sum "$file" | cut -d' ' -f1
    else
        log_error "文件不存在: $file"
        return 1
    fi
}

# 函数：验证文件完整性
# 参数：$1 - 文件路径，$2 - 预期哈希值
# 返回：0 - 验证通过，1 - 验证失败
verify_file() {
    local file="$1"
    local expected_hash="$2"
    
    log_info "验证文件完整性: $file"
    
    if ! file_exists "$file"; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    local actual_hash=$(calculate_hash "$file")
    
    if [ "$actual_hash" == "$expected_hash" ]; then
        log_info "文件完整性验证通过"
        return 0
    else
        log_error "文件完整性验证失败"
        log_error "预期哈希值: $expected_hash"
        log_error "实际哈希值: $actual_hash"
        return 1
    fi
}

# 记录日志
log_info "工具函数脚本加载完成"
