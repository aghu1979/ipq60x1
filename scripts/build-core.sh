#!/bin/bash
# 核心系统编译脚本

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
CHIP=""
BRANCH=""
BUILD_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --chip)
            CHIP="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --path)
            BUILD_PATH="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 检查参数
if [ -z "$CHIP" ] || [ -z "$BRANCH" ] || [ -z "$BUILD_PATH" ]; then
    echo "用法: $0 --chip <芯片> --branch <分支> --path <构建路径>"
    exit 1
fi

log_info "开始编译核心系统..."
log_info "芯片: $CHIP"
log_info "分支: $BRANCH"
log_info "构建路径: $BUILD_PATH"

# 设置源码仓库
case "$BRANCH" in
    "openwrt")
        REPO_URL="https://github.com/laipeng668/openwrt.git"
        REPO_BRANCH="master"
        ;;
    "immwrt")
        REPO_URL="https://github.com/laipeng668/immortalwrt.git"
        REPO_BRANCH="master"
        ;;
    "libwrt")
        REPO_URL="https://github.com/laipeng668/openwrt-6.x.git"
        REPO_BRANCH="k6.12-nss"
        ;;
    *)
        log_warning "不支持的分支: $BRANCH"
        exit 1
        ;;
esac

# 创建构建目录
mkdir -p "$BUILD_PATH"
cd "$BUILD_PATH"

# 克隆源码
log_info "克隆源码: $REPO_URL"
git clone --depth=1 -b "$REPO_BRANCH" "$REPO_URL" openwrt
cd openwrt

# 合并配置文件
log_config "合并配置文件..."

# 应用芯片配置
if [ -f "../../configs/base_${CHIP}.config" ]; then
    cp "../../configs/base_${CHIP}.config" .config.chip
    cp "../../configs/base_${CHIP}.config" .config
    log_success "已应用芯片配置: base_${CHIP}.config"
else
    log_warning "芯片配置文件不存在: configs/base_${CHIP}.config"
    exit 1
fi

# 应用分支配置
if [ -f "../../configs/base_${BRANCH}.config" ]; then
    cp "../../configs/base_${BRANCH}.config" .config.branch
    cat "../../configs/base_${BRANCH}.config" >> .config
    log_success "已应用分支配置: base_${BRANCH}.config"
else
    log_warning "分支配置文件不存在: configs/base_${BRANCH}.config"
    exit 1
fi

# 第一次defconfig - 补全基础配置依赖
log_config "第一次 make defconfig..."
make defconfig
BEFORE_COUNT=$(grep -c '^CONFIG_PACKAGE_luci-' .config || echo 0)
log_info "补全前LUCI软件包数: $BEFORE_COUNT"

# 复制脚本
cp ../../scripts/check-luci.sh ./
cp ../../scripts/compare-config.sh ./
cp ../../scripts/diy.sh ./
cp ../../scripts/repo.sh ./
chmod +x check-luci.sh compare-config.sh diy.sh repo.sh

# 检查LUCI软件包
log_config "检查LUCI软件包..."
./check-luci.sh .config "核心系统-初始检查" false

# 对比配置差异
log_config "对比配置差异..."
./compare-config.sh .config.chip .config "芯片配置→核心系统"

# 执行初始化
log_config "执行系统初始化..."
./diy.sh

# 添加第三方软件源
log_config "添加第三方软件源..."
./repo.sh --add-common

# 更新feeds
log_config "更新软件源..."
./scripts/feeds update -a
./scripts/feeds install -a

# 第二次defconfig - 补全feeds后的配置
log_config "第二次 make defconfig..."
make defconfig
AFTER_COUNT=$(grep -c '^CONFIG_PACKAGE_luci-' .config || echo 0)
log_info "补全后LUCI软件包数: $AFTER_COUNT"

# 对比feeds更新前后的差异
log_config "对比feeds更新前后差异..."
./compare-config.sh .config.chip .config "芯片配置→最终核心系统"

# 最终LUCI检查
log_config "最终LUCI软件包检查..."
./check-luci.sh .config "核心系统-最终检查" true

# 编译工具链
log_config "编译工具链..."
make -j$(nproc) IGNORE_ERRORS=1 tools/compile
make -j$(nproc) IGNORE_ERRORS=1 toolchain/compile

# 保存报告
mkdir -p ../reports
cp *.md ../reports/ 2>/dev/null || true

log_success "核心系统编译完成！"
