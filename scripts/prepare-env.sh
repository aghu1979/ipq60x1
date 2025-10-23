#!/bin/bash
# 环境准备脚本
# 用法: prepare-env.sh <芯片> <分支>

CHIP=$1
BRANCH=$2

echo "🌱 准备编译环境..."
echo "📌 芯片: $CHIP"
echo "📌 分支: $BRANCH"

# 更新软件包列表
sudo apt-get update

# 安装基础依赖
sudo apt-get install -y \
  build-essential \
  clang \
  flex \
  bison \
  g++ \
  gawk \
  gcc-multilib \
  g++-multilib \
  gettext \
  git \
  libncurses5-dev \
  libssl-dev \
  python3-distutils \
  rsync \
  unzip \
  zlib1g-dev \
  file \
  wget

# 克隆源码
if [ "$BRANCH" = "openwrt" ]; then
  REPO_URL="https://github.com/openwrt/openwrt"
elif [ "$BRANCH" = "immwrt" ]; then
  REPO_URL="https://github.com/immortalwrt/immortalwrt"
elif [ "$BRANCH" = "libwrt" ]; then
  REPO_URL="https://github.com/LibreWrt/LibreWrt"
fi

git clone $REPO_URL openwrt
cd openwrt

# 应用基础配置
cp "../.github/configs/base_${CHIP}.config" .config
cp "../.github/configs/base_${BRANCH}.config" .config

# 执行自定义脚本
../scripts/diy.sh
../scripts/repo.sh

echo "✅ 环境准备完成！"
