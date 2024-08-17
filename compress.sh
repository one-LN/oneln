#!/bin/bash

# 检查是否安装了必需的工具
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "未检测到 '$1'，需要安装。"
        while true; do
            read -p "是否安装 '$1'? (y/n): " yn
            case $yn in
                [Yy]*)
                    install_tool "$1"
                    break
                    ;;
                [Nn]*)
                    echo "跳过安装 '$1'。继续下一项。"
                    break
                    ;;
                *)
                    echo "请输入 y 或 n。"
                    ;;
            esac
        done
    fi
}

# 处理工具安装
install_tool() {
    local tool=$1
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y "$tool"
                ;;
            centos|fedora|rhel)
                sudo yum install -y "$tool" || sudo dnf install -y "$tool"
                ;;
            arch)
                sudo pacman -S --noconfirm "$tool"
                ;;
            *)
                echo "未知的发行版，请手动安装 '$tool'."
                ;;
        esac
    else
        echo "无法确定系统类型，请手动安装 '$tool'."
    fi
}

# 检查所需工具
check_tool "zip"
check_tool "unzip"
check_tool "rar"
check_tool "unrar"
check_tool "7z"
check_tool "tar"

# 显示菜单
echo "请选择操作类型:"
echo "1. 压缩"
echo "2. 解压"

read -p "请输入选项号: " op_type

case $op_type in
    1)
        echo "请选择要压缩的文件或文件夹（支持多个，以空格分隔）："
        read -r -a files_to_compress

        # 检查是否至少有一个有效的文件或文件夹
        for file in "${files_to_compress[@]}"; do
            if [ ! -e "$file" ]; then
                echo "提示：没有找到文件或文件夹 '$file'，请重新输入!"
                exit 1
            fi
        done

        # 检查用户是压缩单个还是多个文件/文件夹
        if [ ${#files_to_compress[@]} -eq 1 ]; then
            # 单个文件/文件夹，自动生成带时间戳的压缩文件名
            timestamp=$(date +"%Y%m%d_%H%M%S")
            base_name=$(basename "${files_to_compress[0]}")
            output_file="${base_name}_${timestamp}"
        else
            # 多个文件/文件夹，提示用户输入压缩文件名
            read -p "请输入压缩文件名（不含扩展名）：" output_file
            if [ -z "$output_file" ]; then
                echo "提示：压缩文件名不能为空，程序退出."
                exit 1
            fi
        fi

        # 显示压缩级别
        echo "请选择压缩级别:"
        echo "1. 低"
        echo "2. 普通"
        echo "3. 高"

        read -p "请输入选项号: " level

        case $level in
            1) compress_level="1" ;;  # 对应 zip 和 rar 的低压缩
            2) compress_level="5" ;;  # 对应 zip 和 rar 的普通压缩
            3) compress_level="9" ;;  # 对应 zip 和 rar 的高压缩
            *) echo "无效选项，默认使用普通级别"; compress_level="5" ;;
        esac

        # 显示压缩算法
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
            *) echo "无效选项，默认使用zip"; compress_algorithm="zip" ;;
        esac

        # 压缩文件或文件夹
        echo "提示：正在压缩..."
        case $compress_algorithm in
            zip)
                zip -rq -${compress_level} "${output_file}.zip" "${files_to_compress[@]}"
                ;;
            rar)
                rar a -m${compress_level} "${output_file}.rar" "${files_to_compress[@]}"
                ;;
            7z)
                case $compress_level in
                    1) level_flag="-mx1" ;;  # 低压缩
                    5) level_flag="-mx5" ;;  # 普通压缩
                    9) level_flag="-mx9" ;;  # 高压缩
                esac
                7z a $level_flag "${output_file}.7z" "${files_to_compress[@]}"
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
        echo "压缩完成!"

    ;;
    2)
        echo "请选择要解压的文件（支持多个，以空格分隔）："
        read -r -a files_to_decompress

        # 检查是否至少有一个有效的文件
        for file in "${files_to_decompress[@]}"; do
            if [ ! -f "$file" ]; then
                echo "提示：没有找到文件 '$file'，请重新输入!"
                exit 1
            fi
        done

        # 显示解压选项
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
                ;;
            2)
                echo "请输入解压目录："
                read -r decomp_dir

                # 检查是否存在该目录
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
                ;;
            *) echo "无效选项，解压失败!"; exit 1 ;;
        esac
        echo "解压完成!"
    ;;
    *) echo "无效选项，程序退出."; exit 1 ;;
esac
