#!/bin/bash
# scripts/repo.sh
# 功能: 添加第三方软件源
# 作者: Mary

#!/bin/bash

# 定义颜色和图标
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'
ICON_START='🚀'
ICON_SUCCESS='✅'
ICON_ERROR='❌'
ICON_WARNING='⚠️'
ICON_INFO='ℹ️'
ICON_PACKAGE='📦'
ICON_CONFIG='⚙️'

# 输出开始信息
echo -e "${COLOR_CYAN}${ICON_START} 开始添加第三方软件源${COLOR_RESET}"

# 添加kenzok8/small-package第三方软件源
echo -e "${COLOR_BLUE}${ICON_PACKAGE} 添加kenzok8/small-package软件源${COLOR_RESET}"

# 检查feeds.conf.default文件是否存在
if [ -f "feeds.conf.default" ]; then
    # 备份原始文件
    cp feeds.conf.default feeds.conf.default.bak
    
    # 添加第三方软件源
    echo "src-git small_package https://github.com/kenzok8/small-package" >> feeds.conf.default
    
    # 输出成功信息
    echo -e "${COLOR_GREEN}${ICON_SUCCESS} 第三方软件源添加成功${COLOR_RESET}"
else
    # 输出错误信息
    echo -e "${COLOR_RED}${ICON_ERROR} feeds.conf.default文件不存在${COLOR_RESET}"
    exit 1
fi

# 输出结束信息
echo -e "${COLOR_GREEN}${ICON_SUCCESS} 第三方软件源添加完成${COLOR_RESET}"
