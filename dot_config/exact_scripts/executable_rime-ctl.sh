#!/usr/bin/env bash
# Helix + Fcitx5/Rime 输入法控制脚本
#
# 用法:
#   rime-ctl.sh enter   # 进入插入模式前调用：按需恢复中文输入
#   rime-ctl.sh exit    # 退出插入模式前调用：保存当前状态并强制切到英文
#   rime-ctl.sh start   # 启动 Helix 前调用：确保英文；首次启动时记录当前中/英状态
#   rime-ctl.sh status  # 查看当前 Rime 是否处于 ASCII 模式
set -euo pipefail

SERVICE="org.fcitx.Fcitx5"
OBJECT="/rime"
IFACE="org.fcitx.Fcitx.Rime1"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/helix-rime-state"

# 没有 busctl 或不在图形会话中时，直接忽略（SSH/服务器场景）
rime_available() {
    command -v busctl >/dev/null 2>&1 || return 1

    # 无 DISPLAY / WAYLAND_DISPLAY 通常说明是 SSH、服务器或纯文本环境
    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        return 1
    fi

    # 确认 Fcitx5 + Rime 的 D-Bus 接口真实可用
    if ! busctl --user call "$SERVICE" "$OBJECT" "$IFACE" IsAsciiMode >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

# 输入法环境不可用时自动忽略，不报错、不写状态文件
if ! rime_available; then
    exit 0
fi

is_ascii() {
    busctl --user call "$SERVICE" "$OBJECT" "$IFACE" IsAsciiMode
}

set_ascii() {
    busctl --user call "$SERVICE" "$OBJECT" "$IFACE" SetAsciiMode b "$1"
}

case "${1:-}" in
    enter)
        if [[ -f "$STATE_FILE" ]]; then
            saved="$(cat "$STATE_FILE")"
            if [[ "$saved" == "b false" ]]; then
                set_ascii false
            fi
        else
            # 没有历史状态时，进入插入模式默认切到中文输入
            set_ascii false
        fi
        ;;
    exit)
        is_ascii > "$STATE_FILE"
        set_ascii true
        ;;
    start)
        # 首次启动时记录当前中/英状态，之后只强制英文，不覆盖已保存的插入偏好
        if [[ ! -f "$STATE_FILE" ]]; then
            is_ascii > "$STATE_FILE"
        fi
        set_ascii true
        ;;
    status)
        is_ascii
        ;;
    *)
        echo "Usage: $0 {enter|exit|start|status}" >&2
        exit 1
        ;;
esac
