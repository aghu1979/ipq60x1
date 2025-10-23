#!/bin/bash
# 软件包编译脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
ICON_SUCCESS="✅"
ICON_INFO="ℹ️"
ICON_CONFIG="🔧"
ICON_WARNING="⚠️"

# 日志函数
log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

log_config() {
    echo -e "${YELLOW}${ICON_CONFIG} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING} $1${NC}"
}

# 参数解析
PACKAGE=""
CORE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --package)
            PACKAGE="$2"
            shift 2
            ;;
        --core-path)
            CORE_PATH="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 检查参数
if [ -z "$PACKAGE" ] || [ -z "$CORE_PATH" ]; then
    echo "用法: $0 --package <软件包> --core-path <核心路径>"
    exit 1
fi

log_info "开始编译软件包..."
log_info "软件包: $PACKAGE"
log_info "核心路径: $CORE_PATH"

# 进入核心系统目录
cd "$CORE_PATH/openwrt"

# 备份原始配置
cp .config .config.core
BEFORE_COUNT=$(grep -c '^CONFIG_PACKAGE_luci-' .config || echo 0)
log_info "合并前LUCI软件包数: $BEFORE_COUNT"

# 应用软件包配置
if [ -f "../../configs/${PACKAGE}.config" ]; then
    cp "../../configs/${PACKAGE}.config" .config.package
    
    # 合并配置
    while IFS= read -r line; do
        if [[ $line =~ ^CONFIG_ ]]; then
            key=$(echo "$line" | cut -d'=' -f1)
            if grep -q "^$key=" .config; then
                sed -i "s|^$key=.*|$line|" .config
            else
                echo "$line" >> .config
            fi
        fi
    done < "../../configs/${PACKAGE}.config"
    
    log_success "已应用软件包配置: ${PACKAGE}.config"
else
    log_warning "软件包配置文件不存在: configs/${PACKAGE}.config"
    exit 1
fi

# defconfig补全配置
log_config "执行 make defconfig..."
make defconfig
AFTER_COUNT=$(grep -c '^CONFIG_PACKAGE_luci-' .config || echo 0)
log_info "合并后LUCI软件包数: $AFTER_COUNT"

# 复制脚本
cp ../../scripts/check-luci.sh ./
cp ../../scripts/compare-config.sh ./
chmod +x check-luci.sh compare-config.sh

# 检查软件包配置
log_config "检查软件包配置..."
./check-luci.sh .config.package "软件包-${PACKAGE}-检查" false

# 对比核心系统和软件包配置的差异
log_config "对比核心系统和软件包配置差异..."
./compare-config.sh .config.core .config "核心系统→${PACKAGE}软件包"

# 最终检查
log_config "最终LUCI软件包检查..."
./check-luci.sh .config "最终-${PACKAGE}检查" true

# 编译固件
log_config "开始编译固件..."
make -j$(nproc) IGNORE_ERRORS=1

# 收集产物
log_info "收集编译产物..."
mkdir -p ../firmware ../reports

# 复制固件
find bin/targets -name "*.bin" -type f -exec cp {} ../firmware/ \;

# 复制配置和清单
cp .config "../firmware/config-${PACKAGE}.config"
find bin/targets -name "*.manifest" -type f -exec cp {} ../firmware/ \;

# 复制报告
cp *.md ../reports/ 2>/dev/null || true

# 生成文件列表
ls -la ../firmware/ > ../firmware/filelist.txt

log_success "软件包编译完成！"
log_info "固件文件数: $(find ../firmware -name '*.bin' | wc -l)"
