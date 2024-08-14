#!/bin/bash

# 配置日志文件路径
LOG_FILE="compress_decompress.log"
MAX_LOG_LINES=10

# 工具定义
declare -A tools
tools=(
  ["pv"]="apt-get install pv -y || yum install pv -y|显示压缩和解压时的进度条。"
  ["zip"]="apt-get install zip -y || yum install zip -y|压缩文件为 ZIP 格式。"
  ["unzip"]="apt-get install unzip -y || yum install unzip -y|解压 ZIP 格式的文件。"
)

# 检查工具是否已安装
check_tool() {
  if command -v "$1" &> /dev/null; then
    return 0  # 工具已安装
  else
    return 1  # 工具未安装
  fi
}

# 提示并安装工具
install_tool() {
  tool_name=$1
  install_cmd=$(echo "${tools[$1]}" | cut -d '|' -f 1)
  tool_description=$(echo "${tools[$1]}" | cut -d '|' -f 2)

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

# 显示 Spinner
show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while ps a | awk '{print $1}' | grep -q "$pid"; do
    local temp="${spinstr#?}"
    printf " [%c]  " "$spinstr"
    local spinstr="$temp${spinstr%"$temp"}"
    sleep "$delay"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# 压缩/解压缩脚本
compress_decompress() {
  # 检查并安装必要的工具
  pv_installed=false
  for tool in "${!tools[@]}"; do
    check_tool "$tool" || install_tool "$tool"
    if [ "$tool" == "pv" ] && check_tool "pv"; then
      pv_installed=true
    fi
  done

  # 获取用户输入
  read -p "请选择操作（1: 压缩， 2: 解压）：" option
  case $option in
    1)
      # 压缩
      read -p "请输入要压缩的目录或文件: " source
      read -p "请输入压缩文件的保存路径: " dest_dir
      read -p "请输入压缩级别(1-9, 默认9): " compression_level
      compression_level=${compression_level:-9}

      # 获取当前时间戳
      timestamp=$(date +%Y%m%d_%H%M%S)

      # 检查目标目录是否存在，不存在则创建
      if [ ! -d "$dest_dir" ]; then
          mkdir -p "$dest_dir"
      fi

      # 生成压缩格式选项列表
      compression_options=("tar.gz" "bzip2")
      check_tool "zip" && compression_options+=("zip")

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
      base_name=$(basename "$source")

      if [[ $pv_installed == true ]]; then
        # 使用 pv 显示进度条
        case $format in
          "tar.gz")
            tar_cmd="tar -czf - -C $(dirname \"$source\") $(basename \"$source\") | pv > ${dest_dir}/${base_name}_${timestamp}.tar.gz"
            ;;
          "bzip2")
            tar_cmd="tar -cjf - -C $(dirname \"$source\") $(basename \"$source\") | pv > ${dest_dir}/${base_name}_${timestamp}.bz2"
            ;;
          "zip")
            total_size=$(du -sb "$source" | cut -f1)
            zip_cmd="zip -r -${compression_level} - -q \"$source\" | pv -s $total_size > ${dest_dir}/${base_name}_${timestamp}.zip"
            ;;
        esac

        # 执行压缩命令并显示进度条
        echo "开始压缩..."
        if [[ $format == "zip" ]]; then
          eval "$zip_cmd"
        else
          eval "$tar_cmd"
        fi

        if [ $? -eq 0 ]; then
          echo -e "\n压缩成功！"
          log "压缩成功：${dest_dir}/${base_name}_${timestamp}.${format}"
        else
          echo "压缩失败！请查看日志获取详细信息。"
          log "压缩失败：${dest_dir}/${base_name}_${timestamp}.${format}"
        fi
      else
        # 使用 Spinner 显示进度条
        if [[ $format == "zip" ]]; then
          echo "开始压缩..."
          total_files=$(find "$source" -type f | wc -l)
          current_file=0

          ( # 手动处理进度条
            find "$source" -type f | while read -r file; do
              ((current_file++))
              zip -r -${compression_level} "${dest_dir}/${base_name}_${timestamp}.zip" "$file" > /dev/null
            done
          ) &
          show_spinner $!
          echo -e "\n压缩完成！"
          log "压缩成功：${dest_dir}/${base_name}_${timestamp}.zip"
        else
          echo "开始压缩..."
          case $format in
            "tar.gz")
              tar_cmd="tar -czf ${dest_dir}/${base_name}_${timestamp}.tar.gz -C $(dirname \"$source\") $(basename \"$source\")"
              ;;
            "bzip2")
              tar_cmd="tar -cjf ${dest_dir}/${base_name}_${timestamp}.bz2 -C $(dirname \"$source\") $(basename \"$source\")"
              ;;
          esac

          (eval "$tar_cmd") &
          show_spinner $!
          if [ $? -eq 0 ]; then
            echo -e "\n压缩成功！"
            log "压缩成功：${dest_dir}/${base_name}_${timestamp}.${format}"
          else
            echo -e "\n压缩失败！请查看日志获取详细信息。"
            log "压缩失败：${dest_dir}/${base_name}_${timestamp}.${format}"
          fi
        fi
      fi
      ;;
    2)
      # 解压
      read -p "请输入要解压的文件: " archive_file
      read -p "请输入解压的目录: " dest_dir

      # 检查目标目录是否存在，不存在则创建
      if [ ! -d "$dest_dir" ]; then
          mkdir -p "$dest_dir"
      fi

      if [[ $pv_installed == true ]]; then
        case "$archive_file" in
          *.tar.gz)
            tar_cmd="pv \"$archive_file\" | tar -xz -C \"$dest_dir\""
            ;;
          *.zip)
            unzip_cmd="pv \"$archive_file\" > $dest_dir/archive.zip && unzip $dest_dir/archive.zip -d \"$dest_dir\""
            ;;
          *.bz2)
            tar_cmd="pv \"$archive_file\" | tar -xj -C \"$dest_dir\""
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
          eval "$unzip_cmd"
        else
          eval "$tar_cmd"
        fi

        if [ $? -eq 0 ]; then
          echo -e "\n解压成功！"
          log "解压成功：$archive_file 到 $dest_dir"
        else
          echo -e "\n解压失败！请查看日志获取详细信息。"
          log "解压失败：$archive_file"
        fi
      else
        # 使用 Spinner 显示进度条
        echo "开始解压..."
        case "$archive_file" in
          *.tar.gz)
            tar_cmd="tar -xzvf \"$archive_file\" -C \"$dest_dir\""
            ;;
          *.zip)
            unzip_cmd="unzip \"$archive_file\" -d \"$dest_dir\""
            ;;
          *.bz2)
            tar_cmd="tar -xjvf \"$archive_file\" -C \"$dest_dir\""
            ;;
          *)
            log "不支持的压缩格式：$archive_file"
            echo "不支持的压缩格式！"
            return
            ;;
        esac

        if [[ $archive_file == *.zip ]]; then
          (eval "$unzip_cmd") &
        else
          (eval "$tar_cmd") &
        fi
        show_spinner $!

        if [ $? -eq 0 ]; then
          echo -e "\n解压成功！"
          log "解压成功：$archive_file 到 $dest_dir"
        else
          echo -e "\n解压失败！请查看日志获取详细信息。"
          log "解压失败：$archive_file"
        fi
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
