#!/bin/bash

# 定义颜色变量
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

# GitHub 仓库中的脚本URL
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/xymn2023/y-tb/main/yt-dlp.sh"

# 全局命令名称
GLOBAL_COMMAND_NAME="y-tb"

# 虚拟环境路径
VENV_DIR="$HOME/.y-tb-venv"

# 检测系统中可用的Python和pip命令
detect_python_commands() {
    local python_cmd=""
    local pip_cmd=""
    
    # 检测Python命令
    if command -v python3 &>/dev/null; then
        python_cmd="python3"
    elif command -v python &>/dev/null; then
        # 检查python命令是否是Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            python_cmd="python"
        fi
    fi
    
    # 检测pip命令
    if command -v pip3 &>/dev/null; then
        pip_cmd="pip3"
    elif command -v pip &>/dev/null; then
        # 检查pip命令是否对应Python 3
        if pip --version 2>&1 | grep -q "python 3"; then
            pip_cmd="pip"
        fi
    fi
    
    # 返回检测结果
    echo "$python_cmd|$pip_cmd"
}

# 检测pip版本并兼容--break-system-packages参数
check_pip_version() {
    local commands
    commands=$(detect_python_commands)
    local pip_cmd=$(echo "$commands" | cut -d'|' -f2)
    
    if [ -z "$pip_cmd" ]; then
        echo ""
        return
    fi
    
    local pip_version
    pip_version=$($pip_cmd --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    if [ -n "$pip_version" ]; then
        local python_cmd=$(echo "$commands" | cut -d'|' -f1)
        # 检查版本是否大于等于23.0（支持--break-system-packages的版本）
        if [ -n "$python_cmd" ] && $python_cmd -c "import sys; sys.exit(0 if float('$pip_version') >= 23.0 else 1)" 2>/dev/null; then
            echo "--break-system-packages"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# 创建虚拟环境
create_virtual_environment() {
    local commands
    commands=$(detect_python_commands)
    local python_cmd=$(echo "$commands" | cut -d'|' -f1)
    
    if [ -z "$python_cmd" ]; then
        echo -e "${gl_hong}错误：未找到可用的 Python 3 命令。${gl_bai}"
        return 1
    fi
    
    echo -e "${gl_huang}正在创建虚拟环境...${gl_bai}"
    echo -e "${gl_kjlan}虚拟环境位置: $VENV_DIR${gl_bai}"
    
    # 删除旧的虚拟环境（如果存在）
    if [ -d "$VENV_DIR" ]; then
        echo -e "${gl_huang}发现旧的虚拟环境，正在清理...${gl_bai}"
        rm -rf "$VENV_DIR"
    fi
    
    # 创建虚拟环境
    if $python_cmd -m venv "$VENV_DIR" 2>/dev/null; then
        echo -e "${gl_lv}虚拟环境创建成功。${gl_bai}"
        return 0
    else
        echo -e "${gl_hong}虚拟环境创建失败。${gl_bai}"
        return 1
    fi
}

# 激活虚拟环境并设置环境变量
activate_virtual_environment() {
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${gl_hong}虚拟环境不存在，请先创建。${gl_bai}"
        return 1
    fi
    
    local venv_activate="$VENV_DIR/bin/activate"
    if [ ! -f "$venv_activate" ]; then
        echo -e "${gl_hong}虚拟环境激活脚本不存在。${gl_bai}"
        return 1
    fi
    
    # 激活虚拟环境
    source "$venv_activate"
    
    # 更新PATH以确保使用虚拟环境中的命令
    export PATH="$VENV_DIR/bin:$PATH"
    
    echo -e "${gl_lv}虚拟环境已激活。${gl_bai}"
    return 0
}

# 在虚拟环境中安装依赖
install_in_virtual_environment() {
    echo -e "${gl_huang}=== 虚拟环境安装模式 ===${gl_bai}"
    echo -e "${gl_kjlan}由于系统环境安装失败，切换到虚拟环境模式...${gl_bai}"
    
    # 创建虚拟环境
    if ! create_virtual_environment; then
        return 1
    fi
    
    # 激活虚拟环境
    if ! activate_virtual_environment; then
        return 1
    fi
    
    # 升级pip
    echo -e "${gl_huang}正在升级虚拟环境中的pip...${gl_bai}"
    python -m pip install --upgrade pip
    
    # 安装yt-dlp
    echo -e "${gl_huang}正在在虚拟环境中安装 yt-dlp...${gl_bai}"
    if python -m pip install yt-dlp; then
        echo -e "${gl_lv}yt-dlp 在虚拟环境中安装成功。${gl_bai}"
        
        # 创建全局可访问的yt-dlp包装脚本
        create_venv_wrapper
        return 0
    else
        echo -e "${gl_hong}yt-dlp 在虚拟环境中安装失败。${gl_bai}"
        return 1
    fi
}

# 创建虚拟环境包装脚本
create_venv_wrapper() {
    local wrapper_dir="$HOME/.local/bin"
    local wrapper_script="$wrapper_dir/yt-dlp"
    
    # 确保目录存在
    mkdir -p "$wrapper_dir"
    
    # 创建包装脚本
    cat > "$wrapper_script" << EOF
#!/bin/bash
# yt-dlp 虚拟环境包装脚本
# 自动激活虚拟环境并运行yt-dlp

VENV_DIR="$VENV_DIR"

if [ -f "\$VENV_DIR/bin/activate" ]; then
    source "\$VENV_DIR/bin/activate"
    exec "\$VENV_DIR/bin/yt-dlp" "\$@"
else
    echo "错误：虚拟环境不存在或已损坏"
    exit 1
fi
EOF
    
    chmod +x "$wrapper_script"
    
    # 将wrapper目录添加到PATH
    export PATH="$wrapper_dir:$PATH"
    
    echo -e "${gl_lv}已创建 yt-dlp 包装脚本: $wrapper_script${gl_bai}"
    echo -e "${gl_kjlan}提示：请将 $wrapper_dir 添加到你的 PATH 环境变量中以永久使用。${gl_bai}"
}

# 检查虚拟环境状态
check_virtual_environment_status() {
    if [ -d "$VENV_DIR" ]; then
        echo -e "${gl_lv}虚拟环境存在: $VENV_DIR${gl_bai}"
        
        # 检查yt-dlp是否在虚拟环境中安装
        if [ -f "$VENV_DIR/bin/yt-dlp" ]; then
            echo -e "${gl_lv}yt-dlp 已在虚拟环境中安装${gl_bai}"
            
            # 检查包装脚本
            local wrapper_script="$HOME/.local/bin/yt-dlp"
            if [ -f "$wrapper_script" ]; then
                echo -e "${gl_lv}包装脚本已创建: $wrapper_script${gl_bai}"
            else
                echo -e "${gl_huang}包装脚本不存在，可能需要重新创建${gl_bai}"
            fi
            return 0
        else
            echo -e "${gl_huang}yt-dlp 未在虚拟环境中安装${gl_bai}"
            return 1
        fi
    else
        echo -e "${gl_huang}虚拟环境不存在${gl_bai}"
        return 1
    fi
}

# 删除虚拟环境
remove_virtual_environment() {
    if [ -d "$VENV_DIR" ]; then
        echo -e "${gl_huang}正在删除虚拟环境...${gl_bai}"
        rm -rf "$VENV_DIR"
        
        # 删除包装脚本
        local wrapper_script="$HOME/.local/bin/yt-dlp"
        if [ -f "$wrapper_script" ]; then
            rm -f "$wrapper_script"
            echo -e "${gl_lv}已删除包装脚本${gl_bai}"
        fi
        
        echo -e "${gl_lv}虚拟环境已删除${gl_bai}"
    else
        echo -e "${gl_huang}虚拟环境不存在，无需删除${gl_bai}"
    fi
}

# 安装依赖（增强版，支持虚拟环境备用方案）
install_yt_dlp_dependency() {
    local packages=("python3" "python3-pip" "wget" "unzip" "tar" "jq" "grep" "ffmpeg")
    local success=0 # 使用 0 表示成功
    local commands
    commands=$(detect_python_commands)
    local python_cmd=$(echo "$commands" | cut -d'|' -f1)
    local pip_cmd=$(echo "$commands" | cut -d'|' -f2)
    
    echo -e "${gl_kjlan}检测到的Python命令: ${python_cmd:-未找到}${gl_bai}"
    echo -e "${gl_kjlan}检测到的pip命令: ${pip_cmd:-未找到}${gl_bai}"
    
    local break_packages_flag
    break_packages_flag=$(check_pip_version)
    
    # 安装系统包
    for package in "${packages[@]}"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${gl_huang}正在尝试安装 $package...${gl_bai}"
            # 尝试使用 sudo 进行安装
            if command -v dnf &>/dev/null; then
                sudo dnf -y update && sudo dnf install -y epel-release "$package" || success=1
            elif command -v yum &>/dev/null; then
                sudo yum -y update && sudo yum install -y epel-release "$package" || success=1
            elif command -v apt &>/dev/null; then
                sudo apt update -y && sudo apt install -y "$package" || success=1
            elif command -v apk &>/dev/null; then
                sudo apk update && sudo apk add "$package" || success=1
            elif command -v pacman &>/dev/null; then
                sudo pacman -Syu --noconfirm && sudo pacman -S --noconfirm "$package" || success=1
            elif command -v zypper &>/dev/null; then
                sudo zypper refresh && sudo zypper install -y "$package" || success=1
            elif command -v opkg &>/dev/null; then
                sudo opkg update && sudo opkg install "$package" || success=1
            elif command -v pkg &>/dev/null; then
                sudo pkg update && sudo pkg install -y "$package" || success=1
            else
                echo -e "${gl_hong}未知的包管理器，请手动安装 $package。${gl_bai}"
                success=1
            fi
        fi
    done
    
    # 重新检测Python和pip命令（系统包可能已更新）
    commands=$(detect_python_commands)
    python_cmd=$(echo "$commands" | cut -d'|' -f1)
    pip_cmd=$(echo "$commands" | cut -d'|' -f2)
    
    # 安装 yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        echo -e "${gl_huang}正在安装 yt-dlp...${gl_bai}"
        
        local install_success=false
        
        # 尝试正常安装
        if [ -n "$pip_cmd" ]; then
            echo -e "${gl_kjlan}尝试系统环境安装...${gl_bai}"
            if [ -n "$break_packages_flag" ]; then
                if $pip_cmd install --user yt-dlp $break_packages_flag 2>/dev/null || sudo $pip_cmd install yt-dlp $break_packages_flag 2>/dev/null; then
                    install_success=true
                fi
            else
                if $pip_cmd install --user yt-dlp 2>/dev/null || sudo $pip_cmd install yt-dlp 2>/dev/null; then
                    install_success=true
                fi
            fi
        fi
        
        # 如果系统安装失败，尝试虚拟环境安装
        if [ "$install_success" = false ]; then
            echo -e "${gl_hong}系统环境安装失败，尝试虚拟环境安装...${gl_bai}"
            if install_in_virtual_environment; then
                install_success=true
            else
                success=1
            fi
        fi
        
        if [ "$install_success" = false ]; then
            success=1
        fi
    fi
    
    # 返回数字 0 或 1
    return "$success"
}

# 结束操作并等待用户输入
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    # 修复：从 /dev/tty 读取以解决管道输入问题
    read -n 1 -s -r < /dev/tty
    echo ""
}

# 检查或安装 yt-dlp 和 ffmpeg - 主要修复点！
check_or_install_yt_dlp() {
    local yt_dlp_installed=false
    local ffmpeg_installed=false

    # 首先检查 yt-dlp 是否已安装
    if command -v yt-dlp &>/dev/null; then
        yt_dlp_installed=true
    else
        # 如果找不到，检查用户主目录下的.local/bin
        local user_local_bin="$HOME/.local/bin"
        if [ -x "$user_local_bin/yt-dlp" ]; then
            # 如果存在，则临时将此路径添加到PATH
            export PATH="$user_local_bin:$PATH"
            yt_dlp_installed=true
        fi
    fi

    # 检查 ffmpeg 是否已安装
    if command -v ffmpeg &>/dev/null; then
        ffmpeg_installed=true
    fi

    # 只有在缺少依赖时才进行安装
    if [ "$yt_dlp_installed" = false ] || [ "$ffmpeg_installed" = false ]; then
        echo -e "${gl_huang}检测到缺少必要依赖，正在安装...${gl_bai}"
        if [ "$yt_dlp_installed" = false ]; then
            echo "  - 需要安装 yt-dlp"
        fi
        if [ "$ffmpeg_installed" = false ]; then
            echo "  - 需要安装 ffmpeg"
        fi
        
        # 调用安装函数
        install_yt_dlp_dependency || return 1
        
        # 重新检查安装结果
        # 重新检查 yt-dlp
        if command -v yt-dlp &>/dev/null; then
            yt_dlp_installed=true
        else
            local user_local_bin="$HOME/.local/bin"
            if [ -x "$user_local_bin/yt-dlp" ]; then
                export PATH="$user_local_bin:$PATH"
                yt_dlp_installed=true
            fi
        fi
        
        # 重新检查 ffmpeg
        if command -v ffmpeg &>/dev/null; then
            ffmpeg_installed=true
        fi
    else
        echo -e "${gl_lv}所有依赖已安装，跳过安装步骤。${gl_bai}"
    fi

    # 验证最终状态
    if [ "$yt_dlp_installed" = true ] && [ "$ffmpeg_installed" = true ]; then
        return 0
    else
        echo -e "${gl_hong}依赖安装失败，请检查错误信息并重试。${gl_bai}"
        if [ "$yt_dlp_installed" = false ]; then
            echo "  - yt-dlp 未安装或不可用"
        fi
        if [ "$ffmpeg_installed" = false ]; then
            echo "  - ffmpeg 未安装或不可用"
        fi
        return 1
    fi
}

# 安装全局命令
install_global_command() {
    local script_path
    script_path=$(realpath "$0")
    local bin_dir="/usr/local/bin"
    local global_script_path="$bin_dir/$GLOBAL_COMMAND_NAME"
    
    echo -e "${gl_huang}正在安装全局命令 '$GLOBAL_COMMAND_NAME'...${gl_bai}"
    
    # 检查是否有写入权限
    if [ ! -w "$bin_dir" ]; then
        echo -e "${gl_huang}需要 sudo 权限来安装全局命令到 $bin_dir${gl_bai}"
    fi
    
    # 创建全局命令脚本
    cat <<EOF | sudo tee "$global_script_path" > /dev/null
#!/bin/bash
# y-tb 全局命令 - YouTube视频下载器
# 自动生成的全局命令，指向原始脚本

# 获取原始脚本路径
ORIGINAL_SCRIPT="$script_path"

# 如果原始脚本存在，直接执行
if [ -f "\$ORIGINAL_SCRIPT" ]; then
    exec bash "\$ORIGINAL_SCRIPT" "\$@"
else
    echo "错误：找不到原始脚本文件 \$ORIGINAL_SCRIPT"
    echo "正在尝试从 GitHub 下载最新版本..."
    
    # 如果本地脚本不存在，从 GitHub 下载并执行
    TEMP_SCRIPT="/tmp/y-tb-temp.sh"
    if command -v curl &>/dev/null; then
        curl -sL "$GITHUB_SCRIPT_URL" -o "\$TEMP_SCRIPT"
    elif command -v wget &>/dev/null; then
        wget -qO "\$TEMP_SCRIPT" "$GITHUB_SCRIPT_URL"
    else
        echo "错误：未找到 curl 或 wget，无法下载脚本。"
        exit 1
    fi
    
    if [ -f "\$TEMP_SCRIPT" ]; then
        exec bash "\$TEMP_SCRIPT" "\$@"
    else
        echo "错误：下载脚本失败。"
        exit 1
    fi
fi
EOF

    # 设置执行权限
    sudo chmod +x "$global_script_path"
    
    if [ -f "$global_script_path" ] && [ -x "$global_script_path" ]; then
        echo -e "${gl_lv}全局命令 '$GLOBAL_COMMAND_NAME' 安装成功！${gl_bai}"
        echo -e "${gl_lv}现在你可以在任何地方使用 '$GLOBAL_COMMAND_NAME' 命令来启动脚本。${gl_bai}"
        echo -e "${gl_kjlan}使用方法：${gl_bai}"
        echo -e "  $GLOBAL_COMMAND_NAME          # 启动主菜单"
        echo -e "  $GLOBAL_COMMAND_NAME --help   # 显示帮助信息"
        return 0
    else
        echo -e "${gl_hong}全局命令安装失败。${gl_bai}"
        return 1
    fi
}

# 卸载全局命令
uninstall_global_command() {
    local bin_dir="/usr/local/bin"
    local global_script_path="$bin_dir/$GLOBAL_COMMAND_NAME"
    
    if [ -f "$global_script_path" ]; then
        echo -e "${gl_huang}正在卸载全局命令 '$GLOBAL_COMMAND_NAME'...${gl_bai}"
        echo -n "确定要卸载全局命令吗？(y/N): "
        read confirm_uninstall_global < /dev/tty
        confirm_uninstall_global=${confirm_uninstall_global:-N}
        
        if [[ "$confirm_uninstall_global" =~ ^[Yy]$ ]]; then
            sudo rm -f "$global_script_path"
            if [ ! -f "$global_script_path" ]; then
                echo -e "${gl_lv}全局命令 '$GLOBAL_COMMAND_NAME' 已成功卸载。${gl_bai}"
            else
                echo -e "${gl_hong}卸载全局命令失败。${gl_bai}"
            fi
        else
            echo -e "${gl_lv}取消卸载全局命令。${gl_bai}"
        fi
    else
        echo -e "${gl_huang}全局命令 '$GLOBAL_COMMAND_NAME' 未安装。${gl_bai}"
    fi
}

# 检查全局命令状态
check_global_command_status() {
    local bin_dir="/usr/local/bin"
    local global_script_path="$bin_dir/$GLOBAL_COMMAND_NAME"
    
    if [ -f "$global_script_path" ] && [ -x "$global_script_path" ]; then
        echo -e "${gl_lv}全局命令 '$GLOBAL_COMMAND_NAME' 已安装${gl_bai}"
        echo -e "位置: $global_script_path"
        return 0
    else
        echo -e "${gl_huang}全局命令 '$GLOBAL_COMMAND_NAME' 未安装${gl_bai}"
        return 1
    fi
}

# 卸载 yt-dlp 及相关文件
uninstall_yt_dlp_function() {
    # 获取脚本所在目录
    local SCRIPT_DIR
    SCRIPT_DIR=$(dirname "$(realpath "$0")")

    echo -e "${gl_hong}=== 警告：卸载操作 ===${gl_bai}"
    echo -e "${gl_huang}此操作将执行以下删除：${gl_bai}"
    echo "- ${gl_lv}yt-dlp 程序（通过 pip3 安装的部分）${gl_bai}"
    echo "- ${gl_lv}ffmpeg （如果是由包管理器安装）${gl_bai}"
    echo "- ${gl_lv}本脚本文件 (yt-dlp.sh)${gl_bai}"
    echo "- ${gl_lv}本脚本所在的目录及其所有内容： ${SCRIPT_DIR}/${gl_bai}"
    echo -e "  (这包括所有由 yt-dlp 下载到此目录的视频、音频或其他文件)"
    echo "- ${gl_lv}全局命令 '$GLOBAL_COMMAND_NAME' (如果已安装)${gl_bai}"
    echo "- ${gl_lv}虚拟环境 '$VENV_DIR' (如果存在)${gl_bai}"
    echo -e "${gl_hong}重要提示：${gl_bai}"
    echo -e "${gl_hong}像 python3, pip3, wget, unzip, tar, jq, grep 等核心系统工具非常重要，不建议自动卸载。${gl_bai}"
    echo -e "${gl_hong}本脚本不会自动卸载它们。如需卸载，请您自行判断并手动使用'sudo apt remove/dnf remove/yum remove'等命令。${gl_bai}"
    echo ""
    echo -n "您确定要继续卸载吗？(y/N): "
    # 修复：从 /dev/tty 读取以解决管道输入问题
    read confirm_uninstall < /dev/tty
    confirm_uninstall=${confirm_uninstall:-N}

    if [[ "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}正在尝试卸载 yt-dlp...${gl_bai}"
        
        # 检测命令
        local commands
        commands=$(detect_python_commands)
        local pip_cmd=$(echo "$commands" | cut -d'|' -f2)
        
        # 尝试卸载系统安装的yt-dlp
        if [ -n "$pip_cmd" ]; then
            $pip_cmd uninstall -y yt-dlp &>/dev/null || sudo $pip_cmd uninstall -y yt-dlp &>/dev/null || true 
        fi
        
        # 删除虚拟环境
        remove_virtual_environment
        
        echo -e "${gl_huang}正在尝试卸载 ffmpeg...${gl_bai}"
        # 尝试使用 sudo 卸载 ffmpeg
        if command -v dnf &>/dev/null; then
            sudo dnf -y remove ffmpeg || true
        elif command -v yum &>/dev/null; then
            sudo yum -y remove ffmpeg || true
        elif command -v apt &>/dev/null; then
            sudo apt -y remove ffmpeg || true
        elif command -v apk &>/dev/null; then
            sudo apk del ffmpeg || true
        elif command -v pacman &>/dev/null; then
            sudo pacman -Rs --noconfirm ffmpeg || true
        elif command -v zypper &>/dev/null; then
            sudo zypper -y remove ffmpeg || true
        elif command -v opkg &>/dev/null; then
            sudo opkg remove ffmpeg || true
        elif command -v pkg &>/dev/null; then
            sudo pkg remove ffmpeg || true
        else
            echo -e "${gl_hong}未知的包管理器，无法自动卸载 ffmpeg。请手动卸载。${gl_bai}"
        fi

        # 卸载全局命令
        uninstall_global_command

        echo -e "${gl_huang}正在删除脚本文件和目录...${gl_bai}"
        # 清理脚本文件和目录，使用 trap 确保脚本在删除前退出
        cd /
        rm -rf "$SCRIPT_DIR"
        echo -e "${gl_lv}卸载完成。${gl_bai}"
        exit 0
    else
        echo -e "${gl_lv}卸载已取消。${gl_bai}"
    fi
    break_end
}

# 更新脚本自身
update_self_script() {
    local SCRIPT_PATH
    SCRIPT_PATH=$(realpath "$0")
    local TEMP_SCRIPT="/tmp/yt-dlp-update-temp.sh"
    local WRAPPER_SCRIPT="/tmp/yt-dlp-wrapper.sh"

    echo -e "${gl_huang}正在从 GitHub 检查脚本更新...${gl_bai}"
    if command -v curl &>/dev/null; then
        curl -sL "$GITHUB_SCRIPT_URL" -o "$TEMP_SCRIPT"
    elif command -v wget &>/dev/null; then
        wget -qO "$TEMP_SCRIPT" "$GITHUB_SCRIPT_URL"
    else
        echo -e "${gl_hong}未找到 curl 或 wget，无法下载更新。请手动更新脚本。${gl_bai}"
        break_end
        return 1
    fi

    if [ ! -f "$TEMP_SCRIPT" ]; then
        echo -e "${gl_hong}下载最新脚本失败。请检查网络连接或 GitHub URL。${gl_bai}"
        break_end
        return 1
    fi

    # 比较文件内容，判断是否有更新
    if diff -q "$SCRIPT_PATH" "$TEMP_SCRIPT" &>/dev/null; then
        echo -e "${gl_lv}当前脚本已是最新版本，无需更新。${gl_bai}"
        rm -f "$TEMP_SCRIPT"
    else
        echo -e "${gl_huang}检测到新版本脚本！${gl_bai}"
        echo -n "是否立即更新？(y/N): "
        # 修复：从 /dev/tty 读取以解决管道输入问题
        read confirm_update < /dev/tty
        confirm_update=${confirm_update:-N}

        if [[ "$confirm_update" =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}正在备份旧脚本并替换为新脚本...${gl_bai}"

            # 创建一个临时包装脚本来处理更新后的重新启动
            # 这个脚本会把必要的路径作为参数传入，避免环境变量问题
            cat <<EOF > "$WRAPPER_SCRIPT"
#!/bin/bash
# 这个临时脚本用于在主脚本更新后重新运行它
# 它会在替换旧文件后，自动启动新脚本
# 然后自行删除

# 从参数中获取主脚本的路径
SCRIPT_PATH="\$1"
# 从参数中获取新脚本的临时路径
TEMP_SCRIPT="\$2"

# 等待主脚本完全退出
sleep 1

# 使用 mv 替换主脚本文件
mv "\$TEMP_SCRIPT" "\$SCRIPT_PATH"
chmod +x "\$SCRIPT_PATH"

echo "脚本更新完成，正在重新启动..."

# 清理自身，然后使用exec命令重新运行新脚本，并传递所有原始参数
rm "\$0"
exec "\$SCRIPT_PATH" "\${@:3}"

EOF
            chmod +x "$WRAPPER_SCRIPT"
            
            echo -e "${gl_lv}即将重启以完成更新，请稍候...${gl_bai}"
            # 使用exec启动临时脚本，替换当前进程，并传入所需参数
            exec "$WRAPPER_SCRIPT" "$SCRIPT_PATH" "$TEMP_SCRIPT" "$@"
        else
            echo -e "${gl_lv}脚本更新已取消。${gl_bai}"
            rm -f "$TEMP_SCRIPT"
        fi
    fi
    break_end
}

# 显示帮助信息
show_help() {
    echo -e "${gl_kjlan}YouTube视频下载器 (yt-dlp) - 帮助信息${gl_bai}"
    echo "================================================"
    echo -e "${gl_lv}使用方法：${gl_bai}"
    echo "  $0                    # 启动交互式菜单"
    echo "  $0 --help           # 显示此帮助信息"
    echo "  $0 --install-global # 安装全局命令 '$GLOBAL_COMMAND_NAME'"
    echo "  $0 --check-global   # 检查全局命令状态"
    echo "  $0 --check-venv     # 检查虚拟环境状态"
    echo ""
    echo -e "${gl_lv}全局命令：${gl_bai}"
    echo "  安装全局命令后，你可以在任何地方使用："
    echo "  $GLOBAL_COMMAND_NAME            # 启动主菜单"
    echo "  $GLOBAL_COMMAND_NAME --help     # 显示帮助信息"
    echo ""
    echo -e "${gl_lv}功能特性：${gl_bai}"
    echo "  - 一键安装和配置所有依赖"
    echo "  - 支持视频和音频下载"
    echo "  - 多种视频质量选择"
    echo "  - 自动更新脚本和 yt-dlp"
    echo "  - 全局命令注册"
    echo "  - 虚拟环境备用安装方案"
    echo "  - 完整的卸载功能"
    echo ""
    echo -e "${gl_huang}虚拟环境功能：${gl_bai}"
    echo "  当系统环境安装失败时，脚本会自动切换到虚拟环境模式"
    echo "  虚拟环境位置: $VENV_DIR"
    echo ""
    echo -e "${gl_huang}项目地址：${gl_bai}https://github.com/xymn2023/y-tb"
}

# yt-dlp主菜单
yt_menu_pro() {
    check_or_install_yt_dlp || return 1

    while true; do
        clear
        echo -e "${gl_kjlan}YouTube视频下载器 (yt-dlp) 功能菜单${gl_bai}"
        echo "------------------------------------------------"
        echo "1. 下载视频或音频"
        echo "2. 更新 yt-dlp"
        echo "3. 查看 yt-dlp 版本"
        echo "4. 检查 yt-dlp 更新"
        echo "5. 更新脚本自身"
        echo "6. 卸载 yt-dlp 及相关文件"
        echo "7. 安装全局命令 '$GLOBAL_COMMAND_NAME'"
        echo "8. 卸载全局命令 '$GLOBAL_COMMAND_NAME'"
        echo "9. 检查全局命令状态"
        echo "10. 虚拟环境管理"
        echo "------------------------------------------------"
        echo "0. 退出"
        echo "------------------------------------------------"
        
        # 修复：从 /dev/tty 读取用户输入以解决管道输入问题
        printf "请输入你的选择: "
        read choice < /dev/tty
        
        # 清理输入
        choice=$(echo "$choice" | tr -d '\r\n\t ' | head -c 2)
        
        # 如果输入为空，设置为无效值
        [ -z "$choice" ] && choice="x"

        case "$choice" in
            1)
                echo -e "${gl_huang}下载视频或音频${gl_bai}"
                printf "请输入视频/播放列表URL: "
                read url < /dev/tty
                printf "选择下载类型 (video/audio, 默认为video): "
                read type < /dev/tty
                type=${type:-video}

                if [ "$type" == "audio" ]; then
                    printf "请输入音频格式 (mp3/m4a/best, 默认为best): "
                    read audio_format < /dev/tty
                    audio_format=${audio_format:-best}
                    yt-dlp -x --audio-format "$audio_format" "$url"
                else
                    echo -e "${gl_kjlan}请选择视频下载质量优先级:${gl_bai}"
                    echo "1. 优先4K -> 2K -> 1080P (否则最佳可用)"
                    echo "2. 指定视频格式 (例如: best, bestvideo+bestaudio, 22, 137等)"
                    printf "请输入你的选择 (默认为1): "
                    read video_quality_choice < /dev/tty
                    video_quality_choice=${video_quality_choice:-1}

                    case $video_quality_choice in
                        1)
                            video_format_string="bestvideo[height=2160]+bestaudio/bestvideo[height=1440]+bestaudio/bestvideo[height=1080]+bestaudio/best"
                            echo -e "${gl_lv}将尝试按 4K -> 2K -> 1080P 优先级下载视频...${gl_bai}"
                            yt-dlp -f "$video_format_string" "$url"
                            ;;
                        2)
                            printf "请输入视频格式 (best/bestvideo+bestaudio/22/137等, 默认为best): "
                            read video_format < /dev/tty
                            video_format=${video_format:-best}
                            yt-dlp -f "$video_format" "$url"
                            ;;
                        *)
                            echo -e "${gl_hong}无效的选择，将使用默认最佳视频格式下载。${gl_bai}"
                            yt-dlp -f "best" "$url"
                            ;;
                    esac
                fi
                break_end
                ;;
            2)
                echo -e "${gl_huang}正在更新 yt-dlp...${gl_bai}"
                
                # 检测当前使用的yt-dlp类型（系统还是虚拟环境）
                if check_virtual_environment_status &>/dev/null; then
                    echo -e "${gl_kjlan}检测到虚拟环境安装，在虚拟环境中更新...${gl_bai}"
                    activate_virtual_environment
                    python -m pip install --upgrade yt-dlp
                else
                    # 使用系统环境更新
                    local commands
                    commands=$(detect_python_commands)
                    local pip_cmd=$(echo "$commands" | cut -d'|' -f2)
                    local break_packages_flag
                    break_packages_flag=$(check_pip_version)
                    
                    if [ -n "$pip_cmd" ]; then
                        if [ -n "$break_packages_flag" ]; then
                            $pip_cmd install --user --upgrade yt-dlp $break_packages_flag || sudo $pip_cmd install --upgrade yt-dlp $break_packages_flag
                        else
                            $pip_cmd install --user --upgrade yt-dlp || sudo $pip_cmd install --upgrade yt-dlp
                        fi
                    fi
                fi
                break_end
                ;;
            3)
                echo -e "${gl_huang}yt-dlp 版本信息:${gl_bai}"
                yt-dlp --version
                break_end
                ;;
            4)
                echo -e "${gl_huang}正在检查 yt-dlp 更新...${gl_bai}"
                
                if check_virtual_environment_status &>/dev/null; then
                    echo -e "${gl_kjlan}检测到虚拟环境安装，检查虚拟环境中的更新...${gl_bai}"
                    activate_virtual_environment
                    python -m pip install --upgrade --no-deps yt-dlp 2>&1 | grep -q 'Requirement already satisfied'
                else
                    # 检查系统环境中的yt-dlp包是否有更新（不更新，只检查）
                    local commands
                    commands=$(detect_python_commands)
                    local pip_cmd=$(echo "$commands" | cut -d'|' -f2)
                    local break_packages_flag
                    break_packages_flag=$(check_pip_version)
                    
                    if [ -n "$pip_cmd" ]; then
                        if [ -n "$break_packages_flag" ]; then
                            $pip_cmd install --upgrade --no-deps yt-dlp $break_packages_flag 2>&1 | grep -q 'Requirement already satisfied'
                        else
                            $pip_cmd install --upgrade --no-deps yt-dlp 2>&1 | grep -q 'Requirement already satisfied'
                        fi
                    fi
                fi
                
                if [ $? -eq 0 ]; then
                    echo -e "${gl_lv}yt-dlp 已是最新版本。${gl_bai}"
                else
                    echo -e "${gl_huang}yt-dlp 有可用更新，请选择选项2进行更新。${gl_bai}"
                fi
                break_end
                ;;
            5) # 新增的脚本自身更新功能
                update_self_script
                ;;
            6) # 卸载选项顺序调整
                uninstall_yt_dlp_function
                ;;
            7) # 安装全局命令
                install_global_command
                break_end
                ;;
            8) # 卸载全局命令
                uninstall_global_command
                break_end
                ;;
            9) # 检查全局命令状态
                check_global_command_status
                break_end
                ;;
            10) # 虚拟环境管理
                venv_management_menu
                ;;
            0)
                # 修复：退出时清屏
                clear
                echo -e "${gl_lv}感谢使用！${gl_bai}"
                exit 0
                ;;
            *)
                echo -e "${gl_hong}无效的选择 [$choice]，请输入 0-10 之间的数字。${gl_bai}"
                sleep 2
                ;;
        esac
    done
}

# 虚拟环境管理菜单
venv_management_menu() {
    while true; do
        clear
        echo -e "${gl_kjlan}虚拟环境管理${gl_bai}"
        echo "------------------------------------------------"
        echo "1. 检查虚拟环境状态"
        echo "2. 创建虚拟环境"
        echo "3. 在虚拟环境中安装 yt-dlp"
        echo "4. 删除虚拟环境"
        echo "5. 重建虚拟环境"
        echo "------------------------------------------------"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        
        printf "请输入你的选择: "
        read venv_choice < /dev/tty
        
        # 清理输入
        venv_choice=$(echo "$venv_choice" | tr -d '\r\n\t ' | head -c 1)
        [ -z "$venv_choice" ] && venv_choice="x"

        case "$venv_choice" in
            1)
                echo -e "${gl_huang}检查虚拟环境状态...${gl_bai}"
                check_virtual_environment_status
                break_end
                ;;
            2)
                echo -e "${gl_huang}创建虚拟环境...${gl_bai}"
                create_virtual_environment
                break_end
                ;;
            3)
                echo -e "${gl_huang}在虚拟环境中安装 yt-dlp...${gl_bai}"
                install_in_virtual_environment
                break_end
                ;;
            4)
                echo -e "${gl_huang}删除虚拟环境...${gl_bai}"
                echo -n "确定要删除虚拟环境吗？(y/N): "
                read confirm_delete < /dev/tty
                confirm_delete=${confirm_delete:-N}
                
                if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
                    remove_virtual_environment
                else
                    echo -e "${gl_lv}取消删除虚拟环境。${gl_bai}"
                fi
                break_end
                ;;
            5)
                echo -e "${gl_huang}重建虚拟环境...${gl_bai}"
                echo -n "确定要重建虚拟环境吗？这会删除现有环境并创建新的。(y/N): "
                read confirm_rebuild < /dev/tty
                confirm_rebuild=${confirm_rebuild:-N}
                
                if [[ "$confirm_rebuild" =~ ^[Yy]$ ]]; then
                    remove_virtual_environment
                    sleep 1
                    install_in_virtual_environment
                else
                    echo -e "${gl_lv}取消重建虚拟环境。${gl_bai}"
                fi
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}无效的选择 [$venv_choice]，请输入 0-5 之间的数字。${gl_bai}"
                sleep 2
                ;;
        esac
    done
}

# 处理命令行参数
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --install-global)
        install_global_command
        exit $?
        ;;
    --check-global)
        check_global_command_status
        exit $?
        ;;
    --check-venv)
        check_virtual_environment_status
        exit $?
        ;;
    "")
        # 无参数，启动主菜单
        yt_menu_pro
        ;;
    *)
        echo -e "${gl_hong}未知参数: $1${gl_bai}"
        echo "使用 $0 --help 查看帮助信息"
        exit 1
        ;;
esac
