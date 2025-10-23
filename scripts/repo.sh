#!/bin/bash
# 第三方软件源管理脚本
# 功能：添加kenzok8/small-package软件源

REPO_URL="https://github.com/kenzok8/small-package"
REPO_NAME="kenzok8"
REPO_BRANCH="main"

echo "📦 开始添加第三方软件源..."

# 检查是否已存在
if [ -d "feeds/$REPO_NAME" ]; then
  echo "⚠️  软件源已存在，更新中..."
  cd feeds/$REPO_NAME
  git pull origin $REPO_BRANCH
else
  echo "🔽 克隆软件源..."
  git clone -b $REPO_BRANCH $REPO_URL feeds/$REPO_NAME
fi

# 更新软件包索引
echo "🔄 更新软件包索引..."
./scripts/feeds update -a
./scripts/feeds install -a

echo "✅ 第三方软件源添加完成！"
echo "📌 软件源信息："
echo "   - 仓库: $REPO_URL"
echo "   - 分支: $REPO_BRANCH"
echo "   - 本地路径: feeds/$REPO_NAME"
