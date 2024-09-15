#!/bin/bash

set -eo pipefail

# 输出错误信息并退出
error_exit() {
    echo "$1" 1>&2
    exit 1
}

# 获取操作系统和发行版信息
OS=$(uname -s)
DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"' | tr -d ' ' | tr '[:upper:]' '[:lower:]')

echo "检测到的操作系统: $OS"
echo "检测到的发行版: $DISTRO"

install_docker() {
    echo "在 Debian 或 Ubuntu 上安装或更新 Docker..."
    case "$DISTRO" in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | apt-key add -
            add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable"
            apt-get update -qq
            apt-get install -y -qq docker-ce docker-ce-cli containerd.io
            systemctl start docker
            systemctl enable docker
            unset DEBIAN_FRONTEND
            ;;
        centos|fedora)
            echo "在 CentOS 或 Fedora 上安装或更新 Docker..."
            yum install -y -q yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y -q docker-ce docker-ce-cli containerd.io
            systemctl start docker
            systemctl enable docker
            ;;
        *)
            error_exit "不支持的发行版: $DISTRO"
            ;;
    esac
}

install_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose 已安装，检查是否有更新..."
        CURRENT_VERSION=$(docker-compose --version | awk '{print $3}' | cut -d, -f1)
        LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
            echo "更新 Docker Compose 到最新版本..."
            curl -sL "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        else
            echo "Docker Compose 已是最新版本。"
        fi
    else
        echo "Docker Compose 未安装，开始安装 Docker Compose..."
        LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        curl -sL "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

uninstall_docker() {
    echo "在 Debian 或 Ubuntu 上卸载 Docker..."
    case "$DISTRO" in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get purge -y -qq docker-ce docker-ce-cli containerd.io
            apt-get autoremove -y -qq
            rm -rf /var/lib/docker
            unset DEBIAN_FRONTEND
            ;;
        centos|fedora)
            yum remove -y -q docker-ce docker-ce-cli containerd.io
            rm -rf /var/lib/docker
            ;;
        *)
            error_exit "不支持的发行版: $DISTRO"
            ;;
    esac
    echo "Docker 已卸载。"
}

uninstall_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        rm -f /usr/local/bin/docker-compose
        echo "Docker Compose 已卸载。"
    else
        echo "Docker Compose 未安装，无法卸载。"
    fi
}

run_docker_compose_projects() {
    read -p "请输入要搜索 Docker Compose 文件的起始目录（默认为当前目录）: " start_dir
    start_dir="${start_dir:-.}"  # 如果输入为空，使用当前目录

    if [ ! -d "$start_dir" ]; then
        error_exit "指定的目录不存在，请重新运行脚本并输入有效的目录。"
    fi

    echo "从目录 $start_dir 开始查找 Docker Compose 文件..."
    find "$start_dir" -type f -name 'docker-compose.yml' 2>/dev/null | while read -r file; do
        dir=$(dirname "$file")
        echo "在目录 $dir 中找到 docker-compose.yml，运行 Docker Compose 项目..."
        (cd "$dir" && docker-compose up -d)
    done
}

setup_shortcut() {
    local script_path="$(readlink -f "$0")"  # 获取当前脚本的实际路径
    local link_path="/usr/local/bin/dockers"

    if [ -L "$link_path" ]; then
        local existing_target=$(readlink -f "$link_path")
        if [ "$script_path" = "$existing_target" ]; then
            if [[ "$(basename "$0")" == "$(basename "$script_path")" ]]; then
                echo "快捷命令已正确设置并且是最新的。"
            fi
        else
            echo "更新快捷命令..."
            ln -sf "$script_path" "$link_path"
            chmod +x "$link_path"
            echo "快捷命令 dockers 已更新。"
        fi
    elif [ -e "$link_path" ]; then
        echo "已存在名为 dockers 的文件，但不是快捷方式。请检查并手动处理。"
    else
        ln -s "$script_path" "$link_path"
        chmod +x "$link_path"
        echo "快捷命令 dockers 已设置。"
    fi
}

echo "请选择操作："
echo "1. 安装 Docker 和 Docker Compose"
echo "2. 卸载 Docker 和 Docker Compose"
echo "3. 扫描并运行 Docker Compose 项目"
echo "4. 退出"

read -p "输入选项编号: " option

case $option in
    1)
        install_docker
        install_docker_compose
        ;;
    2)
        uninstall_docker
        uninstall_docker_compose
        ;;
    3)
        run_docker_compose_projects
        ;;
    4)
        echo "退出脚本。"
        exit 0
        ;;
    *)
        echo "无效选项，退出脚本。"
        exit 1
        ;;
esac

setup_shortcut
