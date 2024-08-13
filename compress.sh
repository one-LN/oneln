#!/bin/bash

# 配置日志文件路径
LOG_FILE="compress_decompress.log"
MAX_LOG_LINES=10

# 检查工具是否已安装
check_tool() {
  if command -v $1 &> /dev/null; then
    return 0  # 工具已安装
  else
    return 1  # 工具未安装
  fi
}

# 提示并安装工具
install_tool() {
  tool_name=$1
  install_cmd=$2
  tool_description=$3
  
  echo "$tool_name 工具未安装。作用：$tool_description"
  echo "是否现在安装 $tool_name？(y/n)"
  read -r answer
  if [ "$answer" == "y" ]; then
    echo "正在安装 $tool_name..."
    eval "$install_cmd"
    if [ $? -eq 0 ]; then
      echo "$tool_name 安装成功。"
      return 0
    else
      echo "$tool_name 安装失败，请手动安装或跳过。"
      return 1
    fi
  else
    echo "未安装 $tool_name。您仍可以继续，但相关功能将受限。"
    return 1
  fi
}

# 记录日志并限制日志行数不超过 MAX_LOG_LINES
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> "$LOG_FILE"
  
  # 检查日志文件行数，如果超过 MAX_LOG_LINES 则删除最早的行
  if [ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_LINES ]; then
    tail -n $MAX_LOG_LINES "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
  fi
}

# 显示进度条
show_progress() {
  local current=$1
  local total=$2
  local bar_length=40
  local percent=$((current * 100 / total))
  local filled=$((current * bar_length / total))
  local unfilled=$((bar_length - filled))
  
  printf -v bar "%-${bar_length}s" " "
  printf -v bar "[%s>%${unfilled}s] %d%% (%d/%d)\r" "${bar:0:filled}" "" "$percent" "$current" "$total"
  
  if [ "$current" -eq "$total" ]; then
    echo -e "\n任务完成！"
  fi
}

# 压缩/解压缩脚本
compress_decompress() {
  # 检查并安装必要的工具
  pv_installed=false
  zip_installed=false
  unzip_installed=false

  if ! check_tool "pv"; then
    install_tool "pv" "apt-get install pv -y || yum install pv -y" "显示压缩和解压时的进度条。"
    [ $? -eq 0 ] && pv_installed=true
  else
    pv_installed=true
  fi

  if ! check_tool "zip"; then
    install_tool "zip" "apt-get install zip -y || yum install zip -y" "压缩文件为 ZIP 格式。"
    [ $? -eq 0 ] && zip_installed=true
  else
    zip_installed=false
  fi

  if ! check_tool "unzip"; then
    install_tool "unzip" "apt-get install unzip -y || yum install unzip -y" "解压 ZIP 格式的文件。"
    [ $? -eq 0 ] && unzip_installed=true
  else
    unzip_installed=true
  fi

  # 获取用户输入
  read -p "请选择操作（1: 压缩， 2: 解压）：" option
  case $option in
    1)
      # 压缩
      read -p "请输入要压缩的目录或文件: " source_dir
      read -p "请输入压缩文件的保存路径: " dest_dir
      read -p "请输入压缩级别(1-9, 默认9): " compression_level
      compression_level=${compression_level:-9}

      # 获取当前时间戳
      timestamp=$(date +%Y%m%d_%H%M%S)

      # 生成压缩格式选项列表
      compression_options=("tar.gz" "bzip2")
      if $zip_installed; then
        compression_options+=("zip")
      fi

      # 显示可选压缩格式
      echo "请选择压缩格式："
      select format in "${compression_options[@]}"; do
        case $REPLY in
          [1-${#compression_options[@]}])
            break
            ;;
          *)
            echo "无效选项，请重新选择。"
        esac
      done

      # 获取文件名或目录名作为前缀
      file_or_dir_name=$(basename "$source_dir")

      # ZIP 压缩进度条处理
      if [[ $format == "zip" ]]; then
        echo "开始压缩..."
        total_files=$(find "$source_dir" -type f | wc -l)
        current_file=0

        # 手动处理进度条
        find "$source_dir" -type f | while read -r file; do
          ((current_file++))
          zip -r -${compression_level} "${dest_dir}/${file_or_dir_name}_${timestamp}.zip" "$file" > /dev/null
          show_progress "$current_file" "$total_files"
        done
        echo -e "\n压缩完成！"
        log "压缩成功：${dest_dir}/${file_or_dir_name}_${timestamp}.zip"
      else
        # 处理 tar.gz 和 bzip2
        case $format in
          "tar.gz")
            if $pv_installed; then
              tar_cmd="tar -czf - $source_dir | pv | dd of=${dest_dir}/${file_or_dir_name}_${timestamp}.tar.gz"
            else
              tar_cmd="tar -czvf ${dest_dir}/${file_or_dir_name}_${timestamp}.tar.gz $source_dir"
            fi
            ;;
          "bzip2")
            if $pv_installed; then
              tar_cmd="tar -cjf - $source_dir | pv -s $(du -sb $source_dir | awk '{print $1}') | dd of=${dest_dir}/${file_or_dir_name}_${timestamp}.bz2"
            else
              tar_cmd="tar -cjvf ${dest_dir}/${file_or_dir_name}_${timestamp}.bz2 $source_dir"
            fi
            ;;
        esac

        # 执行压缩命令并显示进度条
        echo "开始压缩..."
        eval $tar_cmd | while IFS= read -r line; do
          echo -n "."
        done
        echo

        if [ $? -eq 0 ]; then
          log "压缩成功：${dest_dir}/${file_or_dir_name}_${timestamp}.${format}"
          echo "压缩完成！"
        else
          log "压缩失败：${dest_dir}/${file_or_dir_name}_${timestamp}.${format}"
          echo "压缩失败，请检查日志获取详细信息。"
        fi
      fi
      ;;
    2)
      # 解压
      read -p "请输入要解压的文件: " archive_file
      read -p "请输入解压的目录: " dest_dir

      # 自动识别压缩格式并解压
      case "$archive_file" in
        *.tar.gz)
          if $pv_installed; then
            tar_cmd="pv $archive_file | tar -xz -C $dest_dir"
          else
            tar_cmd="tar -xzvf $archive_file -C $dest_dir"
          fi
          ;;
        *.zip)
          if $unzip_installed; then
            unzip_cmd="unzip $archive_file -d $dest_dir"
          else
            echo "未安装 unzip 工具，无法解压 ZIP 文件。"
            return
          fi
          ;;
        *.bz2)
          if $pv_installed; then
            tar_cmd="pv $archive_file | tar -xj -C $dest_dir"
          else
            tar_cmd="tar -xjvf $archive_file -C $dest_dir"
          fi
          ;;
        *)
          log "不支持的压缩格式：$archive_file"
          echo "不支持的压缩格式！"
          return
          ;;
      esac

      # 执行解压命令并显示进度条
      echo "开始解压..."
      if [[ $archive_file == *.zip ]]; then
        eval $unzip_cmd
      else
        eval $tar_cmd | while IFS= read -r line; do
          echo -n "."
        done
        echo
      fi

      if [ $? -eq 0 ]; then
        log "解压成功：$archive_file 到 $dest_dir"
        echo "解压完成！"
