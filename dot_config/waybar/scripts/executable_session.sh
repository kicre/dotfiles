#!/usr/bin/env bash
# Waybar 会话操作：关机 / 重启 / 注销 / 锁屏
# 用法: session_action.sh {poweroff|reboot|logout|lock}
set -euo pipefail

confirm() { # 确认弹窗 — 右上角，选项居中
  local choice
  choice=$(echo -e '         󰅖 否\n         󰄬 是' | fuzzel --dmenu --prompt "$1" \
    --lines 2 --width 22 \
    --anchor=top-right --x-margin 12 --y-margin 12)
  [[ "$choice" == *是* ]]
}

case "${1:-}" in
  poweroff)
    confirm '确定要关机吗？ ' && notify-send '关机中...' && systemctl poweroff
    ;;
  reboot)
    confirm '确定要重启吗？ ' && notify-send '重启中...' && systemctl reboot
    ;;
  logout)
    # 按当前 compositor 注销
    if pgrep -x niri >/dev/null; then
      niri msg action quit
    elif pgrep -x hyprland >/dev/null; then
      hyprctl dispatch exit
    else
      loginctl terminate-session "${XDG_SESSION_ID:-self}"
    fi
    ;;
  lock)
    # 按可用锁屏工具顺序尝试
    for cmd in hyprlock swaylock waylock; do
      command -v "$cmd" >/dev/null && { "$cmd"; exit 0; }
    done
    notify-send '未找到锁屏工具' '请安装 hyprlock 或 swaylock'
    ;;
  *)
    echo "用法: $0 {poweroff|reboot|logout|lock}" >&2
    exit 1
    ;;
esac
