#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Waybar 电源 / 启动器按钮（四个功能合并成一个按钮）
#    左键 → 应用启动器（默认 fuzzel）
#    右键 → 电源菜单：关机 / 重启 / 登出 / 锁屏（fuzzel 菜单选择）
#
#  本脚本自包含，不再依赖外部 session.sh。
#  菜单即确认：选中后立即执行，默认不再弹二次确认。
#
#  用法：
#    power.sh                    弹出电源菜单（右键用）
#    power.sh launcher           打开应用启动器（左键用）
#    power.sh poweroff|reboot|logout|lock   直接执行
#
#  可用环境变量覆盖：
#    POWER_LAUNCHER=fuzzel        启动器命令
#    POWER_FUZZEL=fuzzel          菜单程序
#    POWER_ANCHOR=top-right       菜单锚点（center/top-right/…）
#    POWER_X_MARGIN / POWER_Y_MARGIN   锚点边距
#    POWER_CONFIRM=1              可选：执行前再弹一次确认（默认关闭）
# ════════════════════════════════════════════════════════════════════
set -uo pipefail

LAUNCHER="${POWER_LAUNCHER:-fuzzel}"
FUZZEL="${POWER_FUZZEL:-fuzzel}"
ANCHOR="${POWER_ANCHOR:-top-right}"
X_MARGIN="${POWER_X_MARGIN:-12}"
Y_MARGIN="${POWER_Y_MARGIN:-12}"
# 默认为空串：不确认，选中即执行
CONFIRM="${POWER_CONFIRM:-}"

# 图标沿用原来四个按钮的字形，观感保持一致
# （用 $'\uXXXX' 转义书写，避免脚本里出现不可见字符）
ICON_POWEROFF=$'\U000f0425'   # 原 custom/wlogout
ICON_REBOOT=$'\ueb37'         # 原 custom/reboot
ICON_LOGOUT=$'\U000f0206'     # 原 custom/logout
ICON_LOCK=$'\ue672'           # 原 custom/lockscreen

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
  have notify-send || return 0
  if [[ -n ${2-} ]]; then
    notify-send -a power "$1" "$2" 2>/dev/null
  else
    notify-send -a power "$1" 2>/dev/null
  fi
  return 0
}

# 仅当 POWER_CONFIRM 被显式设为 1/true/yes 时才二次确认
want_confirm() {
  case "${CONFIRM,,}" in
    1|true|yes|on) return 0 ;;
    *)             return 1 ;;
  esac
}

confirm() { # $1=提示语；未启用确认时直接通过
  want_confirm || return 0

  local -a fz
  read -r -a fz <<< "$FUZZEL"
  have "${fz[0]}" || return 0

  local choice
  choice=$(printf '%s\n' \
      '         󰅖 否' \
      '         󰄬 是' \
    | "${fz[@]}" --dmenu --prompt "$1" \
        --lines 2 --width 22 \
        --anchor "$ANCHOR" --x-margin "$X_MARGIN" --y-margin "$Y_MARGIN") || return 1
  [[ $choice == *是* ]]
}

do_poweroff() {
  confirm '确定要关机吗？ ' || return 0
  notify '关机中...'
  systemctl poweroff
}

do_reboot() {
  confirm '确定要重启吗？ ' || return 0
  notify '重启中...'
  systemctl reboot
}

do_logout() {
  confirm '确定要登出吗？ ' || return 0
  # 按当前 compositor 注销
  if pgrep -x niri >/dev/null; then
    niri msg action quit
  elif pgrep -x hyprland >/dev/null; then
    hyprctl dispatch exit
  else
    loginctl terminate-session "${XDG_SESSION_ID:-self}"
  fi
}

do_lock() {
  # 按可用锁屏工具顺序尝试
  local cmd
  for cmd in hyprlock swaylock waylock; do
    if have "$cmd"; then
      exec "$cmd"
    fi
  done
  notify '未找到锁屏工具' '请安装 hyprlock 或 swaylock'
  return 1
}

open_launcher() {
  local -a cmd
  read -r -a cmd <<< "$LAUNCHER"
  have "${cmd[0]}" || { notify "找不到启动器" "$LAUNCHER"; return 1; }
  exec "${cmd[@]}"
}

power_menu() {
  local -a fz
  read -r -a fz <<< "$FUZZEL"
  have "${fz[0]}" || { notify "找不到菜单程序" "$FUZZEL"; return 1; }

  local -a items=(
    "         $ICON_POWEROFF 关机"
    "         $ICON_REBOOT 重启"
    "         $ICON_LOGOUT 登出"
    "         $ICON_LOCK 锁屏"
  )

  local choice
  choice=$(printf '%s\n' "${items[@]}" \
    | "${fz[@]}" --dmenu --prompt '电源 ' \
        --lines 4 --width 22 \
        --anchor "$ANCHOR" --x-margin "$X_MARGIN" --y-margin "$Y_MARGIN") || return 0
  [[ -z $choice ]] && return 0

  case $choice in
    *关机*) do_poweroff ;;
    *重启*) do_reboot ;;
    *登出*) do_logout ;;
    *锁屏*) do_lock ;;
  esac
}

case "${1:-menu}" in
  menu)                        power_menu ;;
  launcher)                    open_launcher ;;
  poweroff)                    do_poweroff ;;
  reboot)                      do_reboot ;;
  logout)                      do_logout ;;
  lock)                        do_lock ;;
  *) echo "用法: $0 [menu|launcher|poweroff|reboot|logout|lock]" >&2; exit 1 ;;
esac
