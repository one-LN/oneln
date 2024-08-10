#!/bin/bash

# 配置日志文件路径
LOG_FILE="compress_decompress.log"

# 检查pv是否已安装
check_pv() {
  if command -v pv &> /dev/null; then
    return 0  # pv 已安装
  else
    return 1  # pv 未安装
  fi
}

# 记录日志
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> "$LOG_FILE"
}
# 压缩/解压缩脚本
compress_decompress() {
  # 检查pv是否安装，并给出提示
  if check_pv; then
    echo "已检测到 pv 工具，将显示进度条。"
  else
    echo "未检测到 pv 工具，无法显示进度条。"
    echo "建议您安装 pv 工具，可获得更直观的进度显示。"
    echo "例如：在 Ubuntu/Debian 上，可以使用 sudo apt install pv 安装。"
  fi

  # 获取用户输入
  read -p "请选择操作（1: 压缩，2: 解压）：" option
  case $option in
    1)
      # 压缩
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

      # 获取文件名或目录名作为前缀
      file_or_dir_name=$(basename "$source_dir")

      # 根据选择生成压缩命令
      case $format in
        "tar.gz")
          if check_pv; then
            tar -czf - "$source_dir" | pv | dd of="${dest_dir}/${file_or_dir_name}_${timestamp}.tar.gz"
          else
            tar -czvf "${dest_dir}/${file_or_dir_name}_${timestamp}.tar.gz" "$source_dir"
          fi
          ;;
        "zip")
          if check_pv; then
            zip -r -${compression_level} - "$source_dir" | pv | dd of="${dest_dir}/${file_or_dir_name}_${timestamp}.zip"
          else
            zip -r -${compression_level} "${dest_dir}/${file_or_dir_name}_${timestamp}.zip" "$source_dir"
          fi
          ;;
        "bzip2")
          if check_pv; then
            tar -cjvf - "$source_dir" | pv | dd of="${dest_dir}/${file_or_dir_name}_${timestamp}.bz2"
          else
            tar -cjvf "${dest_dir}/${file_or_dir_name}_${timestamp}.bz2" "$source_dir"
          fi
          ;;
      esac

      if [ $? -eq 0 ]; then
        log "压缩成功：${dest_dir}/${file_or_dir_name}_${timestamp}.${format}"
        echo "压缩完成！"
      else
        log "压缩失败：${dest_dir}/${file_or_dir_name}_${timestamp}.${format}"
        echo "压缩失败，请检查日志获取详细信息。"
      fi
      ;;
    2)
      # 解压
      read -p "请输入要解压的文件: " archive_file
      read -p "请输入解压的目录: " dest_dir

      # 自动识别压缩格式并解压
      case "$archive_file" in
        *.tar.gz)
          if check_pv; then
            pv "$archive_file" | tar -xz -C "$dest_dir"
          else
            tar -xzvf "$archive_file" -C "$dest_dir"
          fi
          ;;
        *.zip)
          if check_pv; then
            pv "$archive_file" | unzip -d "$dest_dir"
          else
            unzip "$archive_file" -d "$dest_dir"
          fi
          ;;
        *.bz2)
          if check_pv; then
            pv "$archive_file" | tar -xj -C "$dest_dir"
          else
            tar -xjvf "$archive_file" -C "$dest_dir"
          fi
          ;;
        *)
          log "不支持的压缩格式：$archive_file"
          echo "不支持的压缩格式！"
          ;;
      esac

      if [ $? -eq 0 ]; then
        log "解压成功：$archive_file 到 $dest_dir"
        echo "解压完成！"
      else
        log "解压失败：$archive_file"
        echo "解压失败，请检查日志获取详细信息。"
      fi
      ;;
    *)
      log "输入无效：$option"
      echo "输入无效，请重新输入！"
      ;;
  esac
}

# 调用主函数
compress_decompress
