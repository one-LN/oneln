#!/bin/bash

# 设置错误处理
set -e

# 设置语言环境（避免编码问题）
export LANG=C.UTF-8

# 默认配置
CONFIG_FILE="$HOME/.compress_config"
MAX_PARALLEL_JOBS=4
DEFAULT_COMPRESS_FORMAT="zip"

# 定义所需的压缩工具数组
declare -A REQUIRED_TOOLS=(
  ["zip"]="用于创建和管理ZIP格式压缩文件"
  ["unzip"]="用于解压ZIP格式文件"
  ["rar"]="用于创建和管理RAR格式压缩文件"
  ["unrar"]="用于解压RAR格式文件"
  ["7z"]="用于创建和管理7Z格式压缩文件"
  ["tar"]="用于创建和管理TAR格式压缩文件"
)

# 日志函数
log_info() {
  echo -e "\033[36m[INFO]\033[0m $1"
}

log_error() {
  echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

log_success() {
  echo -e "\033[32m[SUCCESS]\033[0m $1"
}

log_warning() {
  echo -e "\033[33m[WARNING]\033[0m $1"
}

# 错误处理函数
trap_errors() {
  local exit_code=$?
  local line_number=$1
  if [ $exit_code -ne 0 ]; then
      log_error "脚本在第 $line_number 行发生错误，退出码: $exit_code"
  fi
}

# 设置错误捕获
trap 'trap_errors $LINENO' ERR

# 系统检查函数
check_system_compatibility() {
  # 检查是否为 Linux 系统
  if [ "$(uname)" != "Linux" ]; then
      log_error "此脚本只能在 Linux 系统上运行"
      exit 1
  fi

  # 检查基础命令
  local required_commands=("which" "grep" "sed" "awk" "cut" "find" "tar")
  for cmd in "${required_commands[@]}"; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
          log_error "未找到必需的命令 '$cmd'"
          exit 1
      fi
  done

  # 检查包管理器
  package_manager="none"
  
  if command -v apt-get >/dev/null 2>&1; then
      package_manager="apt-get"
  elif command -v yum >/dev/null 2>&1; then
      package_manager="yum"
  elif command -v dnf >/dev/null 2>&1; then
      package_manager="dnf"
  elif command -v pacman >/dev/null 2>&1; then
      package_manager="pacman"
  elif command -v zypper >/dev/null 2>&1; then
      package_manager="zypper"
  elif command -v apk >/dev/null 2>&1; then
      package_manager="apk"
  fi

  if [ "$package_manager" = "none" ]; then
      log_warning "未检测到支持的包管理器，部分功能可能无法使用"
  else
      log_info "检测到包管理器: $package_manager"
  fi
}

# 权限检查函数
check_permissions() {
  # 检查是否有 sudo 权限
  if ! command -v sudo >/dev/null 2>&1; then
      log_warning "未检测到 sudo 命令"
      # 检查是否为 root 用户
      if [ "$(id -u)" != "0" ]; then
          log_error "此脚本需要 root 权限或 sudo 权限才能安装软件包"
          exit 1
      fi
  fi

  # 检查当前目录的写入权限
  if [ ! -w "." ]; then
      log_error "当前目录没有写入权限"
      exit 1
  fi
}

# 配置文件函数
save_config() {
  local key="$1"
  local value="$2"
  if [ -f "$CONFIG_FILE" ]; then
      sed -i "/$key=/d" "$CONFIG_FILE"
  fi
  echo "$key=$value" >> "$CONFIG_FILE"
}

load_config() {
  local key="$1"
  local default="$2"
  if [ -f "$CONFIG_FILE" ]; then
      local value=$(grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2)
      echo "${value:-$default}"
  else
      echo "$default"
  fi
}

# 检查脚本安装状态函数
check_script_installation() {
  local system_command="/usr/local/bin/c"
  local is_installed=0
  local needs_update=0
  
  # 检查系统命令是否存在
  if [ -f "$system_command" ]; then
      is_installed=1
      
      # 检查版本是否需要更新
      if [ -f "$0" ]; then
          local current_md5=$(md5sum "$0" | cut -d' ' -f1)
          local installed_md5=$(md5sum "$system_command" | cut -d' ' -f1)
          
          if [ "$current_md5" != "$installed_md5" ]; then
              needs_update=1
          fi
      fi
  fi
  
  # 根据检查结果显示状态
  if [ $is_installed -eq 1 ]; then
      if [ $needs_update -eq 1 ]; then
          log_warning "检测到新版本！建议更新系统命令"
          read -p "是否更新系统命令？(y/n): " update_choice
          case $update_choice in
              y|Y)
                  if install_system_command "force"; then
                      log_success "系统命令已更新"
                  else
                      log_error "系统命令更新失败"
                  fi
                  ;;
              *)
                  log_info "跳过更新"
                  ;;
          esac
      else
          log_success "系统命令已安装且为最新版本"
      fi
  else
      log_warning "系统命令未安装"
      read -p "是否安装系统命令？(y/n): " install_choice
      case $install_choice in
          y|Y)
              if install_system_command; then
                  log_success "系统命令安装成功"
              else
                  log_error "系统命令安装失败"
              fi
              ;;
          *)
              log_info "跳过安装"
              ;;
      esac
  fi
}

# 安装系统命令
install_system_command() {
  if [ ! -f "/usr/local/bin/c" ] || [ "$1" = "force" ]; then
      log_info "正在安装系统快捷命令..."
      if sudo cp "$0" /usr/local/bin/c && sudo chmod +x /usr/local/bin/c; then
          log_success "系统快捷命令 'c' 安装成功！您现在可以在任何位置使用 'c' 命令来运行此脚本"
          return 0
      else
          log_error "系统快捷命令安装失败，请检查权限"
          return 1
      fi
  else
      log_warning "系统快捷命令已存在"
      return 1
  fi
}

# 检查压缩工具函数
check_compression_tools() {
  local missing_tools=()
  local installed_tools=()
  
  log_info "正在检查压缩工具..."
  echo "----------------------------------------"
  
  # 检查每个工具
  for tool in "${!REQUIRED_TOOLS[@]}"; do
      printf "%-10s" "检查 $tool..."
      if command -v "$tool" &>/dev/null; then
          echo -e "\033[32m已安装\033[0m"
          installed_tools+=("$tool")
      else
          echo -e "\033[31m未安装\033[0m"
          missing_tools+=("$tool")
      fi
  done
  
  echo "----------------------------------------"
  
  # 显示工具状态摘要
  if [ ${#installed_tools[@]} -gt 0 ]; then
      log_success "已安装的工具 (${#installed_tools[@]}):"
      for tool in "${installed_tools[@]}"; do
          echo "  - $tool: ${REQUIRED_TOOLS[$tool]}"
      done
  fi
  
  # 如果有缺失的工具，提示安装
  if [ ${#missing_tools[@]} -gt 0 ]; then
      log_warning "缺失的工具 (${#missing_tools[@]}):"
      for tool in "${missing_tools[@]}"; do
          echo "  - $tool: ${REQUIRED_TOOLS[$tool]}"
      done
      
      echo "----------------------------------------"
      read -p "是否安装缺失的工具？(y/n): " install_choice
      case $install_choice in
          y|Y)
              for tool in "${missing_tools[@]}"; do
                  log_info "正在安装 $tool..."
                  if install_tool "$tool"; then
                      log_success "$tool 安装成功"
                  else
                      log_error "$tool 安装失败"
                  fi
              done
              ;;
          *)
              log_warning "跳过工具安装。注意：某些压缩功能可能无法使用"
              ;;
      esac
  else
      log_success "所有必需的压缩工具都已安装"
  fi
}

# 安装构建工具
install_build_tools() {
  if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
          ubuntu|debian)
              sudo apt-get update
              sudo apt-get install -y build-essential
              ;;
          centos|fedora|rhel)
              sudo $package_manager groupinstall -y "Development Tools"
              ;;
          arch)
              sudo pacman -S --noconfirm base-devel
              ;;
          *)
              log_error "未知的发行版，请手动安装 'make' 和相关的编译工具"
              exit 1
              ;;
      esac
  else
      log_error "无法确定系统类型，请手动安装 'make' 和相关的编译工具"
      exit 1
  fi
}

# 从源码安装
install_from_source() {
  local url="$1"
  local tool_name="$2"
  local temp_dir=$(mktemp -d)
  
  log_info "正在从源码安装 $tool_name..."
  
  install_build_tools
  
  cd "$temp_dir"
  
  if ! wget "$url"; then
      log_error "下载源码失败"
      cd - >/dev/null
      rm -rf "$temp_dir"
      return 1
  fi
  
  case "$url" in
      *.tar.gz|*.tgz)
          tar xzf "${url##*/}"
          ;;
      *.tar.bz2)
          tar xjf "${url##*/}"
          ;;
      *.zip)
          unzip "${url##*/}"
          ;;
      *)
          log_error "不支持的压缩格式"
          cd - >/dev/null
          rm -rf "$temp_dir"
          return 1
          ;;
  esac
  
  cd "${url##*/}" 2>/dev/null || cd "${tool_name}"* || cd src
  make
  sudo make install
  
  cd - >/dev/null
  rm -rf "$temp_dir"
}

# 从源码安装 RAR
install_rar_from_source() {
  if ! command -v make &> /dev/null; then
      log_info "'make' 未安装，正在安装必要的编译工具..."
      install_build_tools
  fi

  log_info "正在从官方网站下载 RAR..."
  wget -O rarlinux.tar.gz https://www.rarlab.com/rar/rarlinux-x64-623.tar.gz
  if [ $? -ne 0 ]; then
      log_error "下载失败，请检查网络连接"
      exit 1
  fi

  log_info "解压 RAR..."
  tar -xzf rarlinux.tar.gz
  cd rar || exit
  make install
  if [ $? -eq 0 ]; then
      log_success "RAR 安装成功！"
  else
      log_error "安装失败，请手动检查"
      exit 1
  fi
  cd ..
  rm -rf rar rarlinux.tar.gz
}

# 安装工具
install_tool() {
  local tool=$1
  
  if [ "$package_manager" = "none" ]; then
      case "$tool" in
          zip|unzip)
              install_from_source "https://downloads.sourceforge.net/infozip/zip30.tar.gz" "zip"
              ;;
          rar|unrar)
              install_rar_from_source
              ;;
          7z)
              install_from_source "https://downloads.sourceforge.net/p7zip/p7zip_16.02_src_all.tar.bz2" "7zip"
              ;;
          *)
              log_error "无法安装 $tool，请手动安装"
              return 1
              ;;
      esac
      return
  fi

  case "$package_manager" in
      apt-get)
          sudo apt-get update
          case "$tool" in
              rar|unrar)
                  sudo apt-get install -y unrar rar || install_rar_from_source
                  ;;
              7z)
                  sudo apt-get install -y p7zip-full
                  ;;
              *)
                  sudo apt-get install -y "$tool"
                  ;;
          esac
          ;;
      yum|dnf)
          case "$tool" in
              rar|unrar)
                  sudo $package_manager install -y epel-release
                  sudo $package_manager install -y rar unrar || install_rar_from_source
                  ;;
              7z)
                  sudo $package_manager install -y p7zip
                  ;;
              *)
                  sudo $package_manager install -y "$tool"
                  ;;
          esac
          ;;
      pacman)
          case "$tool" in
              rar)
                  sudo pacman -S --noconfirm rar
                  ;;
              7z)
                  sudo pacman -S --noconfirm p7zip
                  ;;
              *)
                  sudo pacman -S --noconfirm "$tool"
                  ;;
          esac
          ;;
      zypper)
          case "$tool" in
              rar|unrar)
                  sudo zypper install -y unrar rar || install_rar_from_source
                  ;;
              7z)
                  sudo zypper install -y p7zip
                  ;;
              *)
                  sudo zypper install -y "$tool"
                  ;;
          esac
          ;;
      apk)
          case "$tool" in
              rar|unrar)
                  sudo apk add unrar || install_rar_from_source
                  ;;
              7z)
                  sudo apk add p7zip
                  ;;
              *)
                  sudo apk add "$tool"
                  ;;
          esac
          ;;
  esac
}

# 改进的文件列表显示
improved_file_list() {
  local -a files=("$@")
  local columns=$(tput cols)
  local divider=$(printf '%*s' "$columns" '' | tr ' ' '-')
  
  echo "$divider"
  printf "%-4s %-40s %-10s %-20s\n" "序号" "文件名" "大小" "类型"
  echo "$divider"
  
  for i in "${!files[@]}"; do
      local file="${files[$i]}"
      local size=$(du -sh "$file" 2>/dev/null | cut -f1)
      local type
      
      # 使用更基础的方法检测文件类型
      if [ -d "$file" ]; then
          type="目录"
      elif [ -L "$file" ]; then
          type="链接"
      elif [ -x "$file" ]; then
          type="可执行文件"
      else
          # 通过文件扩展名判断类型
          case "${file##*.}" in
              txt|md|conf|log) type="文本文件" ;;
              jpg|jpeg|png|gif|bmp) type="图像文件" ;;
              mp3|wav|ogg) type="音频文件" ;;
              mp4|avi|mkv) type="视频文件" ;;
              zip|rar|7z|tar|gz) type="压缩文件" ;;
              sh|bash) type="Shell脚本" ;;
              py) type="Python脚本" ;;
              *) type="普通文件" ;;
          esac
      fi
      
      printf "%-4s %-40s %-10s %-20s\n" "$((i+1))" "${file:0:40}" "$size" "$type"
  done
  echo "$divider"
}

# 扫描并选择文件进行压缩
scan_and_select_files() {
  local files=()
  local selected_files=()
  local available_formats=()
  
  # 检查可用的压缩工具
  if command -v zip >/dev/null 2>&1; then
      available_formats+=("ZIP")
  fi
  if command -v rar >/dev/null 2>&1; then
      available_formats+=("RAR")
  fi
  if command -v 7z >/dev/null 2>&1; then
      available_formats+=("7Z")
  fi
  if command -v tar >/dev/null 2>&1; then
      available_formats+=("TAR.GZ")
  fi
  
  if [ ${#available_formats[@]} -eq 0 ]; then
      log_error "没有可用的压缩工具，请先安装压缩工具"
      return 1
  fi
  
  mapfile -t files < <(ls -A)
  
  if [ ${#files[@]} -eq 0 ]; then
      log_error "当前目录为空"
      return 1
  fi
  
  improved_file_list "${files[@]}"
  
  read -p "请输入要压缩的文件/目录序号（多个用空格分隔）：" -a choices
  
  for choice in "${choices[@]}"; do
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#files[@]}" ]; then
          selected_files+=("${files[$((choice-1))]}")
      else
          log_error "无效选择: $choice"
          return 1
      fi
  done
  
  echo "请选择压缩格式："
  local format_index=1
  local format_map=()
  for format in "${available_formats[@]}"; do
      echo "$format_index. $format"
      format_map[$format_index]=$format
      ((format_index++))
  done
  
  read -p "请输入格式序号: " format_choice
  
  if [[ ! "$format_choice" =~ ^[0-9]+$ ]] || [ "$format_choice" -lt 1 ] || [ "$format_choice" -gt ${#available_formats[@]} ]; then
      log_error "无效的格式选择"
      return 1
  fi
  
  read -p "请输入压缩文件名（不带扩展名）: " output_name
  
  case ${format_map[$format_choice]} in
      "ZIP")
          zip -r "${output_name}.zip" "${selected_files[@]}"
          ;;
      "RAR")
          rar a "${output_name}.rar" "${selected_files[@]}"
          ;;
      "7Z")
          7z a "${output_name}.7z" "${selected_files[@]}"
          ;;
      "TAR.GZ")
          tar -czf "${output_name}.tar.gz" "${selected_files[@]}"
          ;;
  esac
  
  if [ $? -eq 0 ]; then
      log_success "压缩完成：${output_name}.*"
  else
      log_error "压缩失败"
      return 1
  fi
}

# 列出压缩文件并解压
list_and_select_compressed_files() {
    log_info "扫描压缩文件..."
    local compressed_files=()
    local files_to_decompress=()
    
    # 修复 find 命令语法，添加排序和去重
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            compressed_files+=("$file")
        fi
    done < <(find . \( \
        -name "*.zip" -o \
        -name "*.rar" -o \
        -name "*.7z" -o \
        -name "*.tar" -o \
        -name "*.tar.gz" -o \
        -name "*.tar.bz2" -o \
        -name "*.tar.xz" \
        \) -type f | sort -u)

    if [ ${#compressed_files[@]} -eq 0 ]; then
        log_warning "当前目录及其子目录没有压缩文件！"
        return
    fi

    # 使用关联数组来确保文件路径的唯一性
    declare -A unique_files
    for file in "${compressed_files[@]}"; do
        unique_files["$file"]=1
    done

    # 重建压缩文件数组，确保唯一性
    compressed_files=()
    for file in "${!unique_files[@]}"; do
        compressed_files+=("$file")
    done

    # 显示文件列表
    improved_file_list "${compressed_files[@]}"

    # 选择文件
    while true; do
        read -p "请选择要解压的文件序号（多个用空格分隔，输入 'q' 退出）: " input
        
        # 检查是否要退出
        if [[ "$input" == "q" ]]; then
            log_info "操作已取消"
            return
        fi
        
        # 清空之前的选择
        files_to_decompress=()
        
        # 解析输入的序号
        read -ra choices <<< "$input"
        valid_selection=true
        
        for choice in "${choices[@]}"; do
            # 验证输入是否为数字
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                log_error "无效的输入：'$choice' 不是数字"
                valid_selection=false
                break
            fi
            
            # 验证序号范围
            if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#compressed_files[@]}" ]; then
                log_error "无效的序号：$choice（有效范围：1-${#compressed_files[@]}）"
                valid_selection=false
                break
            fi
            
            # 添加到待解压列表
            files_to_decompress+=("${compressed_files[$((choice-1))]}")
        done
        
        # 如果选择有效，显示选中的文件并确认
        if [ "$valid_selection" = true ]; then
            echo "已选择以下文件："
            for file in "${files_to_decompress[@]}"; do
                echo "  - $file"
            done
            
            read -p "确认解压这些文件？(y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done

    # 如果没有选择文件，退出
    if [ ${#files_to_decompress[@]} -eq 0 ]; then
        log_warning "未选择任何文件"
        return
    fi

    echo "请选择解压选项:"
    echo "1. 解压到当前目录"
    echo "2. 指定解压目录"
    read -p "请输入选项号: " decomp_option

    case $decomp_option in
        1)
            log_info "正在解压..."
            for file in "${files_to_decompress[@]}"; do
                case ${file##*.} in
                    zip)
                        if ! command -v unzip >/dev/null 2>&1; then
                            log_error "未安装 unzip 工具"
                            continue
                        fi
                        unzip -q "$file"
                        ;;
                    rar)
                        if ! command -v unrar >/dev/null 2>&1; then
                            log_error "未安装 unrar 工具"
                            continue
                        fi
                        unrar e -q "$file"
                        ;;
                    7z)
                        if ! command -v 7z >/dev/null 2>&1; then
                            log_error "未安装 7z 工具"
                            continue
                        fi
                        7z x -y "$file"
                        ;;
                    tar|gz|bz2|xz)
                        if ! command -v tar >/dev/null 2>&1; then
                            log_error "未安装 tar 工具"
                            continue
                        fi
                        tar -xf "$file"
                        ;;
                    *)
                        log_error "未知文件格式: $file"
                        ;;
                esac
            done
            log_success "解压完成!"
            ;;
        2)
            echo "请输入解压目录："
            read -r decomp_dir
            if [ ! -d "$decomp_dir" ]; then
                read -p "目录不存在，是否创建？(y/n) " choice
                case $choice in
                    y|Y) mkdir -p "$decomp_dir" ;;
                    n|N) log_error "解压失败!"; return 1 ;;
                    *) log_error "无效选择，解压失败!"; return 1 ;;
                esac
            fi
            log_info "正在解压..."
            for file in "${files_to_decompress[@]}"; do
                case ${file##*.} in
                    zip)
                        if ! command -v unzip >/dev/null 2>&1; then
                            log_error "未安装 unzip 工具"
                            continue
                        fi
                        unzip -q "$file" -d "$decomp_dir"
                        ;;
                    rar)
                        if ! command -v unrar >/dev/null 2>&1; then
                            log_error "未安装 unrar 工具"
                            continue
                        fi
                        unrar e -q "$file" "$decomp_dir"
                        ;;
                    7z)
                        if ! command -v 7z >/dev/null 2>&1; then
                            log_error "未安装 7z 工具"
                            continue
                        fi
                        7z x -y "$file" -o"$decomp_dir"
                        ;;
                    tar|gz|bz2|xz)
                        if ! command -v tar >/dev/null 2>&1; then
                            log_error "未安装 tar 工具"
                            continue
                        fi
                        tar -xf "$file" -C "$decomp_dir"
                        ;;
                    *)
                        log_error "未知文件格式: $file"
                        ;;
                esac
            done
            log_success "解压完成!"
            ;;
        *)
            log_error "无效选项，解压失败!"
            return 1
            ;;
    esac
}

# 定义卸载函数
uninstall() {
  log_info "开始卸载..."
  
  # 卸载系统命令
  if [ -f "/usr/local/bin/c" ]; then
      if sudo rm -f "/usr/local/bin/c"; then
          log_success "系统命令已删除: /usr/local/bin/c"
      else
          log_error "删除系统命令失败: /usr/local/bin/c"
      fi
  else
      log_warning "系统命令不存在: /usr/local/bin/c"
  fi

  # 删除配置文件
  if [ -f "$CONFIG_FILE" ]; then
      if rm -f "$CONFIG_FILE"; then
          log_success "配置文件已删除: $CONFIG_FILE"
      else
          log_error "删除配置文件失败: $CONFIG_FILE"
      fi
  else
      log_warning "配置文件不存在: $CONFIG_FILE"
  fi

  # 删除当前脚本
  if [ -f "./compress.sh" ]; then
      if rm -f "./compress.sh"; then
          log_success "原始脚本已删除: ./compress.sh"
      else
          log_error "删除原始脚本失败: ./compress.sh"
      fi
  else
      log_warning "原始脚本不存在: ./compress.sh"
  fi

  log_success "卸载完成"
  exit 0
}

# 在配置文件函数部分添加检查首次运行函数
check_first_run() {
  if [ ! -f "$CONFIG_FILE" ] || ! grep -q "^first_run=done" "$CONFIG_FILE"; then
      clear
      echo "=== 欢迎使用压缩文件工具箱 ==="
      echo "这是您首次运行此脚本。"
      echo "您可以："
      echo "1. 直接使用当前脚本"
      echo "2. 安装为系统命令（推荐）"
      echo "安装为系统命令后，您可以在任何位置使用 'c' 来运行此脚本"
      echo "======================="
      read -p "是否安装为系统命令？(y/n): " install_choice
      case $install_choice in
          y|Y)
              if install_system_command; then
                  save_config "first_run" "done"
              fi
              ;;
          *)
              save_config "first_run" "done"
              log_info "跳过系统命令安装，您可以稍后在主菜单中选择安装"
              ;;
      esac
  fi
}

# 主程序开始
clear
check_system_compatibility
check_permissions

# 检查首次运行
check_first_run

# 主菜单循环
while true; do
  clear
  echo "=== 压缩文件工具箱 ==="
  echo "1. 扫描文件夹并压缩"
  echo "2. 列出压缩文件并解压"
  echo "3. 安装为系统命令"
  echo "4. 检查压缩工具状态"
  echo "5. 退出"
  echo "6. 卸载"
  echo "===================="
  
  read -p "请输入选项号: " op_type
  
  case $op_type in
      1)
          check_compression_tools
          scan_and_select_files
          echo -e "\n操作完成！按回车键继续..."
          read
          clear
          ;;
      2)
          check_compression_tools
          list_and_select_compressed_files
          echo -e "\n操作完成！按回车键继续..."
          read
          clear
          ;;
      3)
          install_system_command "force"
          echo -e "\n操作完成！按回车键继续..."
          read
          clear
          ;;
      4)
          check_compression_tools
          echo -e "\n操作完成！按回车键继续..."
          read
          clear
          ;;
      5)
          log_info "退出脚本"
          exit 0
          ;;
      6)
          read -r -p "您确定要卸载脚本和快捷指令吗？(y/n): " user_input
          if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
              uninstall
          else
              log_info "卸载已取消"
          fi
          echo -e "\n操作完成！按回车键继续..."
          read
          clear
          ;;
      *)
          log_error "无效选项!"
          echo -e "\n按回车键继续..."
          read
          clear
          ;;
  esac
done
