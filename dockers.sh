#!/bin/bash

# 全局变量和配置
country="default"
zhushi=1
gh_proxy=""

# =====================
# 代理设置与权限相关
# =====================
set_country_proxy() {
    if [ "$country" = "CN" ]; then
        zhushi=0
        gh_proxy="https://gh.kejilion.pro/"
    else
        zhushi=1
        gh_proxy=""
    fi
}

run_command() {
    if [ "$zhushi" -eq 0 ]; then
        "$@"
    fi
}

update_permission_status() {
    local file="$1"
    local old_status="$2"
    local new_status="$3"
    if grep -q "^permission_granted=\"$old_status\"" "$file" 2>/dev/null; then
        sed -i "s/^permission_granted=\"$old_status\"/permission_granted=\"$new_status\"/" "$file"
    fi
}

check_license_agreement() {
    # 检查 /usr/local/bin/d 文件中 permission_granted 状态
    if grep -q '^permission_granted="false"' /usr/local/bin/d 2>/dev/null; then
        prompt_user_license
    elif ! grep -q '^permission_granted="true"' /usr/local/bin/d 2>/dev/null; then
        # 如果没有任何授权状态，默认首次也弹条款
        prompt_user_license
    fi
}


prompt_user_license() {
    clear
    echo "=============================================="
    echo "            欢迎使用压缩脚本工具箱              "
    echo "=============================================="
    echo "请注意：安装后，您可以通过输入快捷指令 'd' 来快速访问本脚本。"
    echo
    read -r -p "请阅读并同意条款，是否同意？(y/n): " input
    if [[ "$input" =~ ^[Yy]$ ]]; then
        update_permission_status ./dockers.sh "false" "true"
        update_permission_status /usr/local/bin/d "false" "true"
    else
        echo "未同意条款，脚本退出。"
        exit 1
    fi
}


check_license_agreement() {
    if grep -q '^permission_granted="false"' /usr/local/bin/d 2>/dev/null; then
        prompt_user_license
    fi
}

# =====================
# 系统检测相关
# =====================
detect_os() {
    OS=$(uname -s)
    DISTRO=$(grep ^ID= /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "检测到操作系统: $OS"
    echo "检测到发行版: $DISTRO"
}

# =====================
# Docker 相关功能函数
# =====================
install_docker() {
    echo "开始安装或更新 Docker..."
    case "$DISTRO" in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq apt-transport-https ca-certificates curl software-properties-common gnupg2
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | apt-key add -
            add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable"
            apt-get update -qq
            apt-get install -y -qq docker-ce docker-ce-cli containerd.io
            systemctl start docker
            systemctl enable docker
            unset DEBIAN_FRONTEND
            ;;
        centos|fedora)
            yum install -y -q yum-utils gnupg2
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y -q docker-ce docker-ce-cli containerd.io
            systemctl start docker
            systemctl enable docker
            ;;
        *)
            echo "不支持的发行版: $DISTRO"
            exit 1
            ;;
    esac
    echo "Docker 安装/更新完成。"
}

install_docker_compose() {
    echo "安装或更新 Docker Compose..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d\" -f4)
    LATEST_VERSION_NO_PREFIX=${LATEST_VERSION#v}  # 去掉前缀v

    if command -v docker-compose >/dev/null 2>&1; then
        CURRENT_VERSION=$(docker-compose --version | awk '{print $3}' | cut -d, -f1)
        if [ "$CURRENT_VERSION" = "$LATEST_VERSION_NO_PREFIX" ]; then
            echo "Docker Compose 已是最新版本: $CURRENT_VERSION"
            return 0  # 不更新，直接返回
        else
            echo "发现新版本 Docker Compose: $LATEST_VERSION，正在更新..."
        fi
    else
        echo "Docker Compose 未安装，开始安装 $LATEST_VERSION ..."
    fi

    curl -sL "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose 安装/更新完成。"
}

uninstall_docker() {
    echo "卸载 Docker..."
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
            echo "不支持的发行版: $DISTRO"
            exit 1
            ;;
    esac
    echo "Docker 卸载完成。"
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
    local start_dir
    read -r -p "请输入起始目录（默认当前目录）: " start_dir
    start_dir="${start_dir:-.}"
    if [ ! -d "$start_dir" ]; then
        echo "错误: 目录不存在。"
        exit 1
    fi
    echo "开始扫描并运行 Docker Compose 项目..."
	find "$start_dir" -type f \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \) 2>/dev/null | while read -r file; do
		dir=$(dirname "$file")
		echo "在目录 $dir 中找到 Docker Compose 文件 $(basename "$file")，运行 Docker Compose 项目..."
		(cd "$dir" && docker-compose up -d)
	done
}

scan_and_compress_parent_of_compose() {
    read -r -p "请输入要扫描的起始目录（默认为当前目录）: " start_dir
    start_dir="${start_dir:-.}"

    read -r -p "请输入压缩包保存目录（默认为当前目录的backup子目录）: " backup_dir
    backup_dir="${backup_dir:-${PWD}/backup}"
    mkdir -p "$backup_dir"

    backup_dir_abs=$(realpath "$backup_dir")

    echo "开始扫描 docker-compose 文件并压缩上级目录，保存到：$backup_dir"

    # 这次查找 docker-compose.yml 和 docker-compose.yaml 文件
    mapfile -t compose_files < <(find "$start_dir" -type f \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \))

    # 使用关联数组记录已压缩的目录，避免重复压缩
    declare -A compressed_dirs

    for compose_file in "${compose_files[@]}"; do
        compose_dir=$(dirname "$compose_file")
        parent_dir=$(dirname "$compose_dir") # 上级目录

        # 绝对路径，便于比较
        parent_dir_abs=$(realpath "$parent_dir")

        # 排除备份目录自身，避免压缩备份包
        if [[ "$parent_dir_abs" == "$backup_dir_abs" ]]; then
            echo "跳过备份目录: $parent_dir_abs"
            continue
        fi

        # 避免重复压缩同一个上级目录
        if [[ -n "${compressed_dirs[$parent_dir_abs]}" ]]; then
            continue
        fi

        base_name=$(basename "$parent_dir_abs")
        timestamp=$(date +%Y%m%d%H%M%S)
        archive_name="${base_name}_${timestamp}.tar.gz"

        echo "压缩目录 $parent_dir_abs 到 $backup_dir/$archive_name ..."
        tar -czf "${backup_dir}/${archive_name}" -C "$(dirname "$parent_dir_abs")" "$base_name"

        if [ $? -eq 0 ]; then
            echo "压缩成功: $archive_name"
            compressed_dirs["$parent_dir_abs"]=1
        else
            echo "压缩失败: $archive_name"
        fi

        sleep 1  # 防止时间戳重复
    done

    echo "docker-compose 上级目录压缩完成。"
}






# =====================
# 脚本卸载功能
# =====================
uninstall_script() {
    echo "卸载脚本及快捷指令..."
    local removed=0
    if [ -f "/usr/local/bin/d" ]; then
        rm -f "/usr/local/bin/d"
        echo "已删除快捷指令 /usr/local/bin/d"
        removed=1
    fi
    if [ -f "./dockers.sh" ]; then
        rm -f "./dockers.sh"
        echo "已删除原始脚本 ./dockers.sh"
        removed=1
    fi
    if [[ $removed -eq 0 ]]; then
        echo "未检测到脚本或快捷指令文件。"
    fi
}

# =====================
# 主菜单显示与交互
# =====================
show_menu() {
    while true; do
        clear
        echo "=============================================="
        echo "                 Docker 管理脚本               "
        echo "=============================================="
        echo "1. 安装 Docker 和 Docker Compose"
        echo "2. 卸载 Docker 和 Docker Compose"
        echo "3. 扫描并运行 Docker Compose 项目"
        echo "4. 扫描目录并压缩备份"
        echo "5. 卸载脚本和快捷指令"
		echo "0. 退出脚本" 
        echo "=============================================="
        read -r -p "请选择操作（0-5）: " option
        echo
        case $option in
            1)
                install_docker
                install_docker_compose
                read -r -p "按任意键返回主菜单..." _
                ;;
            2)
                uninstall_docker
                uninstall_docker_compose
                read -r -p "按任意键返回主菜单..." _
                ;;
            3)
                run_docker_compose_projects
                read -r -p "按任意键返回主菜单..." _
                ;;

			4)
				scan_and_compress_parent_of_compose
				read -r -p "按任意键返回主菜单..." _
				;;
            5)
                read -r -p "确定卸载脚本和快捷指令？(y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    uninstall_script
                    echo "卸载完成。"
                else
                    echo "已取消卸载。"
                fi
                read -r -p "按任意键返回主菜单..." _
                ;;				
            0)
                echo "退出脚本。"
                exit 0
                ;;	
            *)
                echo "无效选项，请重新选择。"
                sleep 2
                ;;
        esac
    done
}

# =====================
# 主程序执行入口
# =====================
main() {
    set_country_proxy
    check_and_update_permission
    check_license_agreement
    detect_os
    show_menu
}

main
