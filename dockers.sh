#!/bin/bash

set -e

# 函数：安装或更新 Docker 和 Docker Compose
install_or_update_docker() {
    echo "检测 Docker 和 Docker Compose 的安装情况..."

    # 检查 Docker 是否已安装
    if command -v docker &> /dev/null; then
        echo "Docker 已安装，检查是否有更新..."
         apt update ||  yum check-update
         apt upgrade -y docker-ce ||  yum update -y docker-ce
    else
        echo "Docker 未安装，开始安装 Docker..."
        if [ "$DISTRO" == "Ubuntu" ]; then
             apt update
             apt install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  apt-key add -
             add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
             apt update
             apt install -y docker-ce
             systemctl start docker
             systemctl enable docker
        elif [ "$DISTRO" == "CentOS" ]; then
             yum update -y
             yum install -y yum-utils
             yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
             yum install -y docker-ce
             systemctl start docker
             systemctl enable docker
        else
            echo "不支持的发行版: $DISTRO"
            exit 1
        fi
    fi

    # 检查 Docker Compose 是否已安装
    if command -v docker-compose &> /dev/null; then
        echo "Docker Compose 已安装，检查是否有更新..."
        CURRENT_VERSION=$(docker-compose --version | awk '{print $3}' | cut -d, -f1)
        LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
            echo "更新 Docker Compose 到最新版本..."
             curl -L "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
             chmod +x /usr/local/bin/docker-compose
        else
            echo "Docker Compose 已是最新版本。"
        fi
    else
        echo "Docker Compose 未安装，开始安装 Docker Compose..."
         curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
         chmod +x /usr/local/bin/docker-compose
    fi

    echo "Docker 和 Docker Compose 安装或更新完成。"
    docker --version
    docker-compose --version
}

# 函数：运行 Docker Compose 项目
run_docker_compose_projects() {
    echo "查找并运行 Docker Compose 项目..."

    for dir in */; do
        if [ -f "$dir/docker-compose.yml" ]; then
            echo "在目录 $dir 中找到 docker-compose.yml，运行 Docker Compose 项目..."
            cd "$dir"
            docker-compose up -d
            cd ..
        fi
    done
}

# 函数：设置快捷命令
setup_shortcut() {
    echo "设置快捷命令 dockers..."

    # 确保脚本路径正确
    if [ ! -f ./docker.sh ]; then
        echo "docker.sh 脚本不存在，无法设置快捷命令。"
        exit 1
    fi

    # 复制脚本到 /usr/local/bin 并重命名为 dockers
     cp -f ./dockers.sh /usr/local/bin/dockers > /dev/null 2>&1
     chmod +x /usr/local/bin/dockers

    echo "快捷命令 dockers 设置完成。"
}

# 检测操作系统类型
OS=$(uname -s)
DISTRO=$(lsb_release -is 2>/dev/null || echo "Unknown")

echo "检测到的操作系统: $OS"
echo "检测到的发行版: $DISTRO"

# 执行安装或更新函数
install_or_update_docker

# 执行 Docker Compose 项目
run_docker_compose_projects

# 设置快捷命令
setup_shortcut
