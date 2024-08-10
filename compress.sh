#!/bin/bash

# 自定义提示信息
prompt_info="欢迎使用压缩/解压工具！您可以进行以下操作："

# 获取用户输入的操作类型
echo "$prompt_info"
echo "1. 压缩文件"
echo "2. 解压文件"
read option

# 根据用户选择执行不同操作
case $option in
    1)
        # 压缩文件
        read -p "请输入要压缩的目录或文件: " source_dir
        read -p "请输入压缩文件的保存路径: " dest_dir
        read -p "请输入压缩级别(1-9, 默认9): " compression_level
        compression_level=${compression_level:-9}

        # 获取当前时间戳
        timestamp=$(date +%Y%m%d_%H%M%S)

        # 选择压缩格式
        echo "请选择压缩格式："
        select format in "tar.gz" "zip" "bzip2"; do
            case $REPLY in
                1|2|3)
                    break
                    ;;
                *)
                    echo "无效选项，请重新选择。"
            esac
        done

        # 根据选择生成压缩命令
        case $format in
            "tar.gz")
                compression_cmd="tar -czvf"
                ;;
            "zip")
                compression_cmd="zip -r -${compression_level}"
                ;;
            "bzip2")
                compression_cmd="tar -cjvf"
                ;;
        esac

        # 执行压缩命令
        $compression_cmd "${dest_dir}/${timestamp}_archive.${format}" "$source_dir"
        if [ $? -eq 0 ]; then
            echo "压缩成功！"
        else
            echo "压缩失败！"
        fi
        ;;
    2)
        # ... （解压部分保持不变）
        ;;
    *)
        echo "输入无效，请重新输入！"
        ;;
esac
