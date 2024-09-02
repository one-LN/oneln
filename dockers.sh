#!/bin/bash

set -eo pipefail

# 函数：输出错误信息并退出
error_exit() {
    echo "$1" 1>&2
    exit 1
}

# 函数：安装或更新 Docker 和 Docker Compose
install_or_update_docker() {
    echo "检测 Docker 和 Docker Compose 的安装情况..."

    if command -v docker >/dev/null 2>&1; then
        echo "Docker 已安装，检查是否有更新..."
        update_docker
    else
        echo "Docker 未安装，开始安装 Docker..."
        install_docker
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose 已安装，检查是否有更新..."
        update_docker_compose
    else
        echo "Docker Compose 未安装，开始安装 Docker Compose..."
        install_docker_compose
    fi

    echo "Docker 和 Docker Compose 安装或更新完成。"
    docker --version
    docker-compose --version
}

# 更新 Docker
update_docker() {
    case "$DISTRO" in
        Ubuntu|Debian)
            sudo apt update && sudo apt upgrade -y docker-ce || error_exit "更新 Docker 失败"
            ;;
        CentOS|Fedora)
            sudo yum update -y docker-ce || error_exit "更新 Docker 失败"
            ;;
        *)
            error_exit "不支持的发行版: $DISTRO"
            ;;
    esac
}

# 安装 Docker
install_docker() {
    case "$DISTRO" in
        Ubuntu|Debian)
            install_docker_deb "https://download.docker.com/linux/$DISTRO"
            ;;
        CentOS|Fedora)
            install_docker_rpm
            ;;
        *)
            error_exit "不支持的发行版: $DISTRO"
            ;;
    esac
}

install_docker_deb() {
    local repo_url=$1
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL $repo_url/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] $repo_url $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker
}

install_docker_rpm() {
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker
}

update_docker_compose() {
    local CURRENT_VERSION=$(docker-compose --version | awk '{print $3}' | cut -d, -f1)
    local LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        echo "更新 Docker Compose 到最新版本..."
        sudo curl -L "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose 已是最新版本。"
    fi
}

install_docker_compose() {
    local LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

# 运行 Docker Compose 项目
run_docker_compose_projects() {
    echo "查找并运行 Docker Compose 项目..."
    find / -type f -name 'docker-compose.yml' 2>/dev/null | while read -r file; do
        dir=$(dirname "$file")
        echo "在目录 $dir 中找到 docker-compose.yml，运行 Docker Compose 项目..."
        (cd "$dir" && sudo docker-compose up -d)
    done
}

# 设置快捷命令
setup_shortcut() {
    echo "设置快捷命令 dockers..."

    local script_path="./docker.sh"
    if [ ! -f "$script_path" ]; then
        error_exit "$script_path 脚本不存在，无法设置快捷命令。"
    fi

    sudo cp -f "$script_path" /usr/local/bin/dockers
    sudo chmod +x /usr/local/bin/dockers

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
