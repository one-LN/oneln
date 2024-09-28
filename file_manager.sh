
#!/bin/bash

# 默认国家设置
country="default"

# 判断国家设置
set_country_proxy() {
    if [ "$country" = "CN" ]; then
        zhushi=0
        gh_proxy="https://gh.kejilion.pro/"
    else
        zhushi=1  # 0 表示执行，1 表示不执行
        gh_proxy=""
    fi
}

set_country_proxy

# 定义一个函数来执行命令
run_command() {
    if [ "$zhushi" -eq 0 ]; then
        "$@"
    fi
}

# 权限许可检查函数
update_permission_status() {
    local status_file="$1"
    local current_status="$2"
    local new_status="$3"
    
    if grep -q "^permission_granted=\"$current_status\"" "$status_file" > /dev/null 2>&1; then
        sed -i "s/^permission_granted=\"$current_status\"/permission_granted=\"$new_status\"/" "$status_file"
    fi
}

# 检查首次运行
check_first_run_true() {
    update_permission_status /usr/local/bin/w "false" "true"
    update_permission_status ./file_manager.sh "false" "true"
}

check_first_run_true

# 复制文件
cp -f ./compress.sh /usr/local/bin/w > /dev/null 2>&1

# 检查是否需要用户同意条款
check_first_run_false() {
    if grep -q '^permission_granted="false"' /usr/local/bin/w > /dev/null 2>&1; then
        user_license_agreement
    fi
}

# 提示用户同意条款
user_license_agreement() {
    clear
    echo -e "欢迎使用文件管理器"
    echo -e "快捷指令：w"
    echo -e "----------------------"
    read -r -p "是否同意以上条款？(y/n): " user_input
    if [[ "$user_input" =~ ^[Yy]$ ]]; then
        update_permission_status ./file_manager.sh "false" "true"
        update_permission_status /usr/local/bin/w "false" "true"
    else
        clear
        exit
    fi
}

check_first_run_false
# 安装构建工具
install_build_tools() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                apt-get update
                apt-get install -y build-essential
                ;;
            centos|fedora|rhel)
                yum groupinstall -y "Development Tools" || dnf groupinstall -y "Development Tools"
                ;;
            arch)
                pacman -S --noconfirm base-devel
                ;;
            *)
                echo "未知的发行版，请手动安装 'make' 和相关的编译工具."
                exit 1
                ;;
        esac
    else
        echo "无法确定系统类型，请手动安装 'make' 和相关的编译工具."
        exit 1
    fi
}

# 从源代码安装 RAR
install_rar_from_source() {
    if ! command -v make &> /dev/null; then
        echo "'make' 未安装，正在安装必要的编译工具..."
        install_build_tools
    fi

    echo "正在从官方网站下载 RAR..."
    wget -O rarlinux.tar.gz https://www.rarlab.com/rar/rarlinux-x64-623.tar.gz
    if [ $? -ne 0 ]; then
        echo "下载失败，请检查网络连接。"
        exit 1
    fi

    echo "解压 RAR..."
    tar -xzf rarlinux.tar.gz
    cd rar || exit
    make install
    if [ $? -eq 0 ]; then
        echo "RAR 安装成功！"
    else
        echo "安装失败，请手动检查。"
        exit 1
    fi
    cd ..
    rm -rf rar rarlinux.tar.gz
}

# 安装工具
install_tool() {
    local tool=$1
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                apt-get update
                if [ "$tool" = "rar" ] || [ "$tool" = "unrar" ]; then
                    if ! apt-get install -y unrar rar; then
                        echo "Debian/Ubuntu 官方源中未找到 $tool 包。尝试从官方网站下载安装。"
                        install_rar_from_source
                    fi
                elif [ "$tool" = "7z" ]; then
                    apt-get install -y p7zip-full
                else
                    apt-get install -y "$tool"
                fi
                ;;
            centos|fedora|rhel)
                if [ "$tool" = "rar" ]; then
                    yum install -y epel-release && yum install -y rar unrar || dnf install -y rar unrar
                elif [ "$tool" = "7z" ]; then
                    yum install -y p7zip || dnf install -y p7zip
                else
                    yum install -y "$tool" || dnf install -y "$tool"
                fi
                ;;
            arch)
                if [ "$tool" = "rar" ]; then
                    pacman -S --noconfirm rar
                elif [ "$tool" = "7z" ]; then
                    pacman -S --noconfirm p7zip
                else
                    pacman -S --noconfirm "$tool"
                fi
                ;;
            *)
                echo "未知的发行版，请手动安装 '$tool'."
                ;;
        esac
    else
        echo "无法确定系统类型，请手动安装 '$tool'."
    fi
}

# 检查工具
check_tool() {
    local tool=$1
    if ! command -v $tool &> /dev/null; then
        echo "未检测到 '$tool'，需要安装。"
        read -p "是否安装 '$tool'? (y/n): " choice
        case "$choice" in
            y|Y) install_tool "$tool" ;;
            n|N) echo "跳过安装 '$tool'." ;;
            *) echo "无效选择，跳过安装 '$tool'." ;;
        esac
    fi
}

# 定义卸载函数
uninstall() {
    if [ -f "/usr/local/bin/w" ]; then
        rm -f "/usr/local/bin/w"
        echo "快捷指令已删除: /usr/local/bin/w"
    else
        echo "快捷指令不存在: /usr/local/bin/w"
    fi

    if [ -f "./file_manager.sh" ]; then
        rm -f "./file_manager.sh"
        echo "原始脚本已删除: ./file_manager.sh"
    else
        echo "原始脚本不存在: ./file_manager.sh"
    fi
}

# 检查所需工具
check_tool "zip"
check_tool "unzip"
check_tool "rar"
check_tool "unrar"
check_tool "7z"
check_tool "tar"

# 扫描文件夹并选择要压缩的文件
scan_and_select_files() {
    echo "当前目录下的文件和文件夹："
    local files=(*)

    if [ ${#files[@]} -eq 0 ]; then
        echo "提示：当前目录没有文件或文件夹！"
        return
    fi

    # 列出文件和文件夹及其大小和类型，并添加“返回上级目录”选项
    echo "0. 返回上级目录"
    for i in "${!files[@]}"; do
        size=$(du -sh "${files[$i]}" | cut -f1)  # 获取大小
        if [ -d "${files[$i]}" ]; then
            file_type="文件夹"
        elif [[ "${files[$i]}" == *.zip || "${files[$i]}" == *.rar || "${files[$i]}" == *.7z || "${files[$i]}" == *.tar || "${files[$i]}" == *.tar.gz || "${files[$i]}" == *.tar.bz2 || "${files[$i]}" == *.tar.xz ]]; then
            file_type="压缩文件"
        else
            file_type="文件"
        fi
        echo "$((i + 1)). ${files[$i]} - $size [$file_type]"
    done

    # 选择文件或文件夹
    read -p "请选择序号（单个文件夹会提示是否进入文件夹，支持多个，以空格分隔）: " -a choices
    if [[ " ${choices[@]} " =~ " 0 " ]]; then
        cd ..
        scan_and_select_files
        return
    fi

    for choice in "${choices[@]}"; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#files[@]}" ]; then
            selected_file="${files[$((choice - 1))]}"
            if [[ -d "$selected_file" && ${#choices[@]} -eq 1 ]]; then
                read -p "您选择了一个文件夹 [$selected_file]，要进入该文件夹吗？(y/n) " enter_folder
                if [[ "$enter_folder" =~ ^[yY]$ ]]; then
                    cd "$selected_file"
                    scan_and_select_files
                    return
                else
                    echo "您选择了: $selected_file"
                    files_to_compress+=("$selected_file")
                fi
            else
                echo "您选择了: $selected_file"
                files_to_compress+=("$selected_file")
            fi
        else
            echo "无效选择: $choice，请重新选择！"
        fi
    done

    # 根据选择的文件数量决定命名方式
    timestamp=$(date +"%Y%m%d_%H%M%S")  # 获取时间戳
    if [ ${#files_to_compress[@]} -eq 1 ]; then
        output_file="$(basename "${files_to_compress[0]}")_${timestamp}"
    else
        read -p "您选择了多个文件，是否给压缩文件命名？(y/n): " rename_choice
        if [[ "$rename_choice" =~ ^[yY]$ ]]; then
            read -p "请输入压缩文件名（不含扩展名）：" user_output_file
            if [ -z "$user_output_file" ]; then
                echo "提示：压缩文件名不能为空，使用默认命名."
                output_file="压缩文件_${timestamp}"
            else
                output_file="${user_output_file}_${timestamp}"
            fi
        else
            output_file="压缩文件_${timestamp}"
        fi
    fi

    echo "请选择压缩算法:"
    echo "1. zip"
    echo "2. rar"
    echo "3. 7z"
    echo "4. tar (gzip)"
    echo "5. tar (bz2)"
    echo "6. tar (xz)"
    read -p "请输入选项号: " algorithm

    case $algorithm in
        1) compress_algorithm="zip" ;;
        2) compress_algorithm="rar" ;;
        3) compress_algorithm="7z" ;;
        4) compress_algorithm="tar_gzip" ;;
        5) compress_algorithm="tar_bz2" ;;
        6) compress_algorithm="tar_xz" ;;
        *) echo "无效选项，默认使用7z"; compress_algorithm="7z" ;;
    esac

    echo "提示：正在压缩..."
    case $compress_algorithm in
        zip)
            echo "提示：zip 不支持保留权限，建议使用 7z。"
            zip -rq "${output_file}.zip" "${files_to_compress[@]}"
            ;;
        rar)
            echo "提示：rar 不支持保留权限，建议使用 7z。"
            rar a "${output_file}.rar" "${files_to_compress[@]}"
            ;;
        7z)
            7z a "${output_file}.7z" "${files_to_compress[@]}"
            ;;
        tar_gzip)
            tar -czf "${output_file}.tar.gz" "${files_to_compress[@]}"
            ;;
        tar_bz2)
            tar -cjf "${output_file}.tar.bz2" "${files_to_compress[@]}"
            ;;
        tar_xz)
            tar -cJf "${output_file}.tar.xz" "${files_to_compress[@]}"
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "压缩完成!"
    else
        echo "压缩失败!"
    fi
}

# 列出压缩文件供用户选择解压
list_and_select_compressed_files() {
    echo "当前目录及其子目录下的压缩文件："
    local compressed_files=()
    while IFS= read -r -d '' file; do
        compressed_files+=("$file")
    done < <(find . -type f \( -iname "*.zip" -o -iname "*.rar" -o -iname "*.7z" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tar.bz2" -o -iname "*.tar.xz" \) -print0)

    if [ ${#compressed_files[@]} -eq 0 ]; then
        echo "提示：当前目录及其子目录没有压缩文件！"
        return
    fi

    # 列出压缩文件及其大小和完整路径
    for i in "${!compressed_files[@]}"; do
        size=$(du -sh "${compressed_files[$i]}" | cut -f1)  # 获取大小
        full_path="$(cd "$(dirname "${compressed_files[$i]}")" && pwd)/$(basename "${compressed_files[$i]}")"
        echo "$((i + 1)). $full_path - $size [压缩文件]"
    done

    read -p "请选择要解压的文件的序号（支持多个，以空格分隔）: " -a decompress_choices
    # 检查用户选择的每个文件序号是否有效
    for choice in "${decompress_choices[@]}"; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#compressed_files[@]}" ]; then
            selected_file="${compressed_files[$((choice - 1))]}"
            echo "您选择了解压文件: $selected_file"
            files_to_decompress+=("$selected_file")
        else
            echo "无效选择: $choice，请重新选择！"
            return
        fi
    done

    echo "请选择解压选项:"
    echo "1. 解压到当前目录"
    echo "2. 指定解压目录"
    read -p "请输入选项号: " decomp_option

    case $decomp_option in
        1)
            echo "提示：正在解压..."
            for file in "${files_to_decompress[@]}"; do
                case ${file##*.} in
                    zip) unzip -q "$file" ;;
                    rar) unrar e -q "$file" ;;
                    7z) 7z x -y "$file" ;;
                    tar) tar -xf "$file" ;;
                    gz) tar -xzf "$file" ;;
                    bz2) tar -xjf "$file" ;;
                    xz) tar -xJf "$file" ;;
                    *) echo "未知文件格式: $file" ;;
                esac
            done
            echo "解压完成!"
            ;;
        2)
            echo "请输入解压目录："
            read -r decomp_dir
            if [ ! -d "$decomp_dir" ]; then
                read -p "提示：没有找到该目录，是否创建新目录？(y/n) " choice
                case $choice in
                    y|Y) mkdir -p "$decomp_dir" ;;
                    n|N) echo "提示：解压失败!"; exit 1 ;;
                    *) echo "提示：无效选择，解压失败!"; exit 1 ;;
                esac
            fi
            echo "提示：正在解压..."
            for file in "${files_to_decompress[@]}"; do
                case ${file##*.} in
                    zip) unzip -q "$file" -d "$decomp_dir" ;;
                    rar) unrar e -q "$file" "$decomp_dir" ;;
                    7z) 7z x -y "$file" -o"$decomp_dir" ;;
                    tar) tar -xf "$file" -C "$decomp_dir" ;;
                    gz) tar -xzf "$file" -C "$decomp_dir" ;;
                    bz2) tar -xjf "$file" -C "$decomp_dir" ;;
                    xz) tar -xJf "$file" -C "$decomp_dir" ;;
                    *) echo "未知文件格式: $file" ;;
                esac
            done
            echo "解压完成!"
            ;;
        *) echo "无效选项，解压失败!"; exit 1 ;;
    esac
}

linux_file() {
	root_use
	send_stats "文件管理器"
	while true; do
		clear
		echo "文件管理器"
		echo "------------------------"
		echo "当前路径"
		pwd
		echo "------------------------"
		ls --color=auto -x
		echo "------------------------"
		echo "1.  进入目录           2.  创建目录             3.  修改目录权限         4.  重命名目录"
		echo "5.  删除目录           6.  返回上一级目录"
		echo "------------------------"
		echo "11. 创建文件           12. 编辑文件             13. 修改文件权限         14. 重命名文件"
		echo "15. 删除文件"
		echo "------------------------"
		echo "21. 压缩文件目录       22. 解压文件目录         23. 移动文件目录         24. 复制文件目录"
		echo "25. 传文件至其他服务器"
		echo "------------------------"
		echo "0.  退出        00.卸载"
		echo "------------------------"
		read -e -p "请输入你的选择: " Limiting

		case "$Limiting" in
			1)  # 进入目录
				read -e -p "请输入目录名: " dirname
				cd "$dirname" 2>/dev/null || echo "无法进入目录"
				send_stats "进入目录"
				;;
			2)  # 创建目录
				read -e -p "请输入要创建的目录名: " dirname
				mkdir -p "$dirname" && echo "目录已创建" || echo "创建失败"
				send_stats "创建目录"
				;;
			3)  # 修改目录权限
				read -e -p "请输入目录名: " dirname
				read -e -p "请输入权限 (如 755): " perm
				chmod "$perm" "$dirname" && echo "权限已修改" || echo "修改失败"
				send_stats "修改目录权限"
				;;
			4)  # 重命名目录
				read -e -p "请输入当前目录名: " current_name
				read -e -p "请输入新目录名: " new_name
				mv "$current_name" "$new_name" && echo "目录已重命名" || echo "重命名失败"
				send_stats "重命名目录"
				;;
			5)  # 删除目录
				read -e -p "请输入要删除的目录名: " dirname
				rm -rf "$dirname" && echo "目录已删除" || echo "删除失败"
				send_stats "删除目录"
				;;
			6)  # 返回上一级目录
				cd ..
				send_stats "返回上一级目录"
				;;
			11) # 创建文件
				read -e -p "请输入要创建的文件名: " filename
				touch "$filename" && echo "文件已创建" || echo "创建失败"
				send_stats "创建文件"
				;;
			12) # 编辑文件
				read -e -p "请输入要编辑的文件名: " filename
				install nano
				nano "$filename"
				send_stats "编辑文件"
				;;
			13) # 修改文件权限
				read -e -p "请输入文件名: " filename
				read -e -p "请输入权限 (如 755): " perm
				chmod "$perm" "$filename" && echo "权限已修改" || echo "修改失败"
				send_stats "修改文件权限"
				;;
			14) # 重命名文件
				read -e -p "请输入当前文件名: " current_name
				read -e -p "请输入新文件名: " new_name
				mv "$current_name" "$new_name" && echo "文件已重命名" || echo "重命名失败"
				send_stats "重命名文件"
				;;
			15) # 删除文件
				read -e -p "请输入要删除的文件名: " filename
				rm -f "$filename" && echo "文件已删除" || echo "删除失败"
				send_stats "删除文件"
				;;
			21) # 压缩文件/目录
				scan_and_select_files
        			;;
			22) # 解压文件/目录
        			list_and_select_compressed_files
        			;;

			23) # 移动文件或目录
				read -e -p "请输入要移动的文件或目录路径: " src_path
				if [ ! -e "$src_path" ]; then
					echo "错误: 文件或目录不存在。"
					send_stats "移动文件或目录失败: 文件或目录不存在"
					continue
				fi

				read -e -p "请输入目标路径 (包括新文件名或目录名): " dest_path
				if [ -z "$dest_path" ]; then
					echo "错误: 请输入目标路径。"
					send_stats "移动文件或目录失败: 目标路径未指定"
					continue
				fi

				mv "$src_path" "$dest_path" && echo "文件或目录已移动到 $dest_path" || echo "移动文件或目录失败"
				send_stats "移动文件或目录"
				;;


		   24) # 复制文件目录
				read -e -p "请输入要复制的文件或目录路径: " src_path
				if [ ! -e "$src_path" ]; then
					echo "错误: 文件或目录不存在。"
					send_stats "复制文件或目录失败: 文件或目录不存在"
					continue
				fi

				read -e -p "请输入目标路径 (包括新文件名或目录名): " dest_path
				if [ -z "$dest_path" ]; then
					echo "错误: 请输入目标路径。"
					send_stats "复制文件或目录失败: 目标路径未指定"
					continue
				fi

				# 使用 -r 选项以递归方式复制目录
				cp -r "$src_path" "$dest_path" && echo "文件或目录已复制到 $dest_path" || echo "复制文件或目录失败"
				send_stats "复制文件或目录"
				;;


			 25) # 传送文件至远端服务器
				read -e -p "请输入要传送的文件路径: " file_to_transfer
				if [ ! -f "$file_to_transfer" ]; then
					echo "错误: 文件不存在。"
					send_stats "传送文件失败: 文件不存在"
					continue
				fi

				read -e -p "请输入远端服务器IP: " remote_ip
				if [ -z "$remote_ip" ]; then
					echo "错误: 请输入远端服务器IP。"
					send_stats "传送文件失败: 未输入远端服务器IP"
					continue
				fi

				read -e -p "请输入远端服务器用户名 (默认root): " remote_user
				remote_user=${remote_user:-root}

				read -e -p "请输入远端服务器密码: " -s remote_password
				echo
				if [ -z "$remote_password" ]; then
					echo "错误: 请输入远端服务器密码。"
					send_stats "传送文件失败: 未输入远端服务器密码"
					continue
				fi

				read -e -p "请输入登录端口 (默认22): " remote_port
				remote_port=${remote_port:-22}

				# 清除已知主机的旧条目
				ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
				sleep 2  # 等待时间

				# 使用scp传输文件
				scp -P "$remote_port" -o StrictHostKeyChecking=no "$file_to_transfer" "$remote_user@$remote_ip:/home/" <<EOF
$remote_password
EOF

				if [ $? -eq 0 ]; then
					echo "文件已传送至远程服务器home目录。"
					send_stats "文件传送成功"
				else
					echo "文件传送失败。"
					send_stats "文件传送失败"
				fi

				break_end
				;;



			0)  # 退出
				send_stats "退出"
				exit 0
				;;
    
			00)  # 卸载
			        read -r -p "您确定要卸载脚本和快捷指令吗？(y/n): " user_input
			        if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
			            uninstall
			            echo "卸载完成。"
			        else
			            echo "卸载已取消。"
			        fi
			        ;;
    
			*)  # 处理无效输入
				echo "无效的选择，请重新输入"
				send_stats "无效选择"
				;;
		esac
	done
}

linux_file

