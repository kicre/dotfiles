#!/bin/bash
# Power menu for Waybar using fuzzel

power_menu() {
    options="󰐥 关机\n󰜉 重启\n󰍃 注销\n󰌾 锁屏"
    chosen=$(echo -e "$options" | fuzzel --dmenu --prompt="电源菜单: " --lines=4 --width=20)

    case "$chosen" in
        *关机*)
            systemctl poweroff
            ;;
        *重启*)
            systemctl reboot
            ;;
        *注销*)
            # Check for niri or other Wayland compositors
            if pgrep -x "niri" > /dev/null; then
                niri msg action quit
            elif pgrep -x "hyprland" > /dev/null; then
                hyprctl dispatch exit
            else
                pkill -KILL -u "$USER"
            fi
            ;;
        *锁屏*)
            # Try different lock screen tools
            if command -v swaylock &> /dev/null; then
                swaylock
            elif command -v waylock &> /dev/null; then
                waylock
            elif command -v lock &> /dev/null; then
                lock
            else
                notify-send "锁屏工具未找到" "请安装 swaylock 或 waylock"
            fi
            ;;
    esac
}

# Show menu on click
power_menu