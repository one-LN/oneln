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
		echo "0.  返回上一级"
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
				read -e -p "请输入要压缩的文件/目录名: " name
				install tar
				tar -czvf "$name.tar.gz" "$name" && echo "已压缩为 $name.tar.gz" || echo "压缩失败"
				send_stats "压缩文件/目录"
				;;
			22) # 解压文件/目录
				read -e -p "请输入要解压的文件名 (.tar.gz): " filename
				install tar
				tar -xzvf "$filename" && echo "已解压 $filename" || echo "解压失败"
				send_stats "解压文件/目录"
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



			0)  # 返回上一级
				send_stats "返回上一级菜单"
				break
				;;
			*)  # 处理无效输入
				echo "无效的选择，请重新输入"
				send_stats "无效选择"
				;;
		esac
	done
}
