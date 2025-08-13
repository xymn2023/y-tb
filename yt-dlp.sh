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
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/xymn2023/yt-dlp/main/yt-dlp.sh"

# 检测pip版本并兼容--break-system-packages参数
check_pip_version() {
    local pip_version
    pip_version=$(pip3 --version 2>/dev/null | grep -oP '\\d+\\.\\d+' | head -1)
    if [ -n "$pip_version" ]; then
        # 检查版本是否大于等于23.0（支持--break-system-packages的版本）
        if python3 -c "import sys; sys.exit(0 if float('$pip_version') >= 23.0 else 1)" 2>/dev/null; then
            echo "--break-system-packages"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# 安装依赖
install_yt_dlp_dependency() {
    local packages=("python3" "python3-pip" "wget" "unzip" "tar" "jq" "grep" "ffmpeg")
    local success=0 # 使用 0 表示成功
    local break_packages_flag
    break_packages_flag=$(check_pip_version)
    
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
    
    # 额外安装 yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        echo -e "${gl_huang}正在安装 yt-dlp...${gl_bai}"
        # 根据pip版本选择是否使用--break-system-packages参数
        if [ -n "$break_packages_flag" ]; then
            pip3 install --user yt-dlp $break_packages_flag || sudo pip3 install yt-dlp $break_packages_flag || success=1
        else
            pip3 install --user yt-dlp || sudo pip3 install yt-dlp || success=1
        fi
    fi
    # 返回数字 0 或 1
    return "$success"
}


# 结束操作并等待用户输入
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    read -n 1 -s -r
    echo ""
}

# 检查或安装 yt-dlp 和 ffmpeg
check_or_install_yt_dlp() {
    local yt_dlp_installed=false
    local ffmpeg_installed=false

    # 统一调用安装函数，一次性处理所有依赖
    install_yt_dlp_dependency || return 1

    # 修复：检查 yt-dlp 是否安装成功
    # 首先检查PATH中是否可以直接找到yt-dlp
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

    if [ "$yt_dlp_installed" = true ]; then
        echo -e "${gl_lv}yt-dlp 已成功安装和配置。${gl_bai}"
    else
        echo -e "${gl_hong}yt-dlp 安装失败，请检查您的环境或手动安装。${gl_bai}"
        break_end
        return 1
    fi

    # 检查 ffmpeg 是否安装成功
    if command -v ffmpeg &>/dev/null; then
        ffmpeg_installed=true
    else
        echo -e "${gl_huang}ffmpeg 未检测到，yt-dlp 的某些功能可能受限。${gl_bai}"
    fi
    
    # 只要 yt-dlp 安装成功，就认为依赖检查通过
    if "$yt_dlp_installed"; then
        return 0
    else
        return 1
    fi
}

# 卸载 yt-dlp 及相关文件
uninstall_yt_dlp_function() {
    local SCRIPT_DIR
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

    clear
    echo -e "${gl_hong}=== 警告：卸载操作 ===${gl_bai}"
    echo -e "${gl_huang}此操作将执行以下删除：${gl_bai}"
    echo "- ${gl_lv}yt-dlp 程序（通过 pip3 安装的部分）${gl_bai}"
    echo "- ${gl_lv}ffmpeg （如果是由包管理器安装）${gl_bai}"
    echo "- ${gl_lv}本脚本文件 (yt-dlp.sh)${gl_bai}"
    echo "- ${gl_lv}本脚本所在的目录及其所有内容： ${SCRIPT_DIR}/${gl_bai}"
    echo -e "  (这包括所有由 yt-dlp 下载到此目录的视频、音频或其他文件)"
    echo -e "${gl_hong}重要提示：${gl_bai}"
    echo -e "${gl_hong}像 python3, pip3, wget, unzip, tar, jq, grep 等核心系统工具非常重要，不建议自动卸载。${gl_bai}"
    echo -e "${gl_hong}本脚本不会自动卸载它们。如需卸载，请您自行判断并手动使用'sudo apt remove/dnf remove/yum remove'等命令。${gl_bai}"
    echo ""
    echo -n "您确定要继续卸载吗？(y/N): "
    read confirm_uninstall
    confirm_uninstall=${confirm_uninstall:-N}

    if [[ "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}正在尝试卸载 yt-dlp...${gl_bai}"
        # 尝试卸载 yt-dlp，优先卸载用户安装的，如果失败则尝试全局（可能需要 sudo）
        pip3 uninstall -y yt-dlp &>/dev/null || sudo pip3 uninstall -y yt-dlp &>/dev/null || true 
        
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

        echo -e "${gl_huang}正在删除脚本文件和目录：${SCRIPT_DIR}...${gl_bai}"
        rm -rf "$SCRIPT_DIR" &>/dev/null & disown
        echo -e "${gl_lv}yt-dlp 及相关文件已成功删除。${gl_bai}"
        echo -e "${gl_lv}请注意：其他核心系统依赖可能仍然存在，如需卸载请手动操作。${gl_bai}"
        exit 0 
    else
        echo -e "${gl_lv}卸载操作已取消。${gl_bai}"
        break_end
    fi
}

# 更新脚本自身
update_self_script() {
    local SCRIPT_PATH
    SCRIPT_PATH=$(readlink -f "$0")
    local TEMP_SCRIPT="/tmp/yt-dlp_temp_update_script.sh"
    local WRAPPER_SCRIPT="/tmp/yt-dlp_wrapper_script.sh"

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
        read confirm_update
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

# 备份旧脚本并替换为新脚本
mv "\$SCRIPT_PATH" "\${SCRIPT_PATH}.bak"
mv "\$TEMP_SCRIPT" "\$SCRIPT_PATH"
chmod +x "\$SCRIPT_PATH"

echo -e "${gl_lv}脚本更新成功！正在启动新版本...${gl_bai}"

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
        echo "------------------------------------------------"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        
        # 使用更稳定的输入方式
        printf "请输入你的选择: "
        read choice
        
        # 清理输入
        choice=$(echo "$choice" | tr -d '\r\n\t ' | head -c 1)
        
        # 如果输入为空，设置为无效值
        [ -z "$choice" ] && choice="x"

        case "$choice" in
            1)
                echo -e "${gl_huang}下载视频或音频${gl_bai}"
                printf "请输入视频/播放列表URL: "
                read url
                printf "选择下载类型 (video/audio, 默认为video): "
                read type
                type=${type:-video}

                if [ "$type" == "audio" ]; then
                    printf "请输入音频格式 (mp3/m4a/best, 默认为best): "
                    read audio_format
                    audio_format=${audio_format:-best}
                    yt-dlp -x --audio-format "$audio_format" "$url"
                else
                    echo -e "${gl_kjlan}请选择视频下载质量优先级:${gl_bai}"
                    echo "1. 优先4K -> 2K -> 1080P (否则最佳可用)"
                    echo "2. 指定视频格式 (例如: best, bestvideo+bestaudio, 22, 137等)"
                    printf "请输入你的选择 (默认为1): "
                    read video_quality_choice
                    video_quality_choice=${video_quality_choice:-1}

                    case $video_quality_choice in
                        1)
                            video_format_string="bestvideo[height=2160]+bestaudio/bestvideo[height=1440]+bestaudio/bestvideo[height=1080]+bestaudio/best"
                            echo -e "${gl_lv}将尝试按 4K -> 2K -> 1080P 优先级下载视频...${gl_bai}"
                            yt-dlp -f "$video_format_string" "$url"
                            ;;
                        2)
                            printf "请输入视频格式 (best/bestvideo+bestaudio/22/137等, 默认为best): "
                            read video_format
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
                # pip 安装 yt-dlp 优先尝试用户目录安装，如果失败则尝试全局安装（可能需要 sudo）
                local break_packages_flag
                break_packages_flag=$(check_pip_version)
                if [ -n "$break_packages_flag" ]; then
                    pip3 install --user --upgrade yt-dlp $break_packages_flag || sudo pip3 install --upgrade yt-dlp $break_packages_flag
                else
                    pip3 install --user --upgrade yt-dlp || sudo pip3 install --upgrade yt-dlp
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
                # 检查 yt-dlp 包是否有更新（不更新，只检查）
                local break_packages_flag
                break_packages_flag=$(check_pip_version)
                if [ -n "$break_packages_flag" ]; then
                    pip3 install --upgrade --no-deps yt-dlp $break_packages_flag 2>&1 | grep -q 'Requirement already satisfied'
                else
                    pip3 install --upgrade --no-deps yt-dlp 2>&1 | grep -q 'Requirement already satisfied'
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
            0)
                # 修复：退出时清屏
                clear
                echo -e "${gl_lv}感谢使用！${gl_bai}"
                exit 0
                ;;
            *)
                echo -e "${gl_hong}无效的选择 [$choice]，请输入 0-6 之间的数字。${gl_bai}"
                sleep 2
                ;;
        esac
    done
}

# 启动菜单
yt_menu_pro