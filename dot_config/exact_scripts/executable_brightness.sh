#!/usr/bin/env bash
# 低延迟亮度控制
# 显示与操控走 cache（毫秒级），DDC/CI 写入异步后台执行（不阻塞 waybar）
#
# 子命令:
#   get     — 读亮度（cache 新鲜则秒回，否则读硬件校准）
#   up      — 增加亮度（步进 STEP%）
#   down    — 减少亮度（步进 STEP%）
#   save    — 读硬件写入 cache
#   restore — 从 cache 恢复亮度（唤醒恢复/手动调用）
#   sync    — 定时同步：硬件与 cache 不一致时，把 cache 写回硬件

set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/brightness"
METHOD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/brightness-method"
LOCK="${TMPDIR:-/tmp}/brightness.lock"
STEP=5
FRESH_CACHE=600     # 亮度 cache 新鲜窗口（秒）
FRESH_METHOD=3600   # 检测方式 cache 新鲜窗口（秒）
FRESH_METHOD_NONE=30 # 检测失败(none)只缓存 30 秒，避免显示器休眠/启动竞态导致长时间失效
SYNC_FRESH_GUARD=5  # cache 刚被手动更新时，sync 跳过写硬件（秒）

# ── 检测控制方式（结果缓存，避免每次慢查询 ddcutil detect） ──
detect_method() {
  local mt m cached ttl
  if [[ -f "$METHOD_CACHE" ]] && mt=$(stat -c %Y "$METHOD_CACHE" 2>/dev/null); then
    cached=$(cat "$METHOD_CACHE" 2>/dev/null)
    ttl=$FRESH_METHOD
    [[ "$cached" == "none" ]] && ttl=$FRESH_METHOD_NONE
    # backlight 缓存需设备仍存在，否则视为失效
    if [[ "$cached" == "backlight" ]] && ! ls -A /sys/class/backlight 2>/dev/null | grep -q .; then
      cached=""
    fi
    if [[ -n "$cached" ]] && (( $(date +%s) - mt < ttl )); then
      echo "$cached"
      return
    fi
  fi
  m=none
  if [[ -d /sys/class/backlight ]] && ls -A /sys/class/backlight 2>/dev/null | grep -q .; then
    m=backlight
  elif command -v ddcutil &>/dev/null && ddcutil detect --brief 2>/dev/null | grep -q "Display"; then
    m=ddc
  fi
  echo "$m" > "$METHOD_CACHE"
  echo "$m"
}

# ── 读硬件亮度（慢查询，仅在校准/初始化时调用） ──
get_hardware() {
  case "$(detect_method)" in
    backlight)
      local bl cur max
      bl=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
      [[ -n "$bl" ]] || return 1
      cur=$(cat "/sys/class/backlight/$bl/brightness" 2>/dev/null)
      max=$(cat "/sys/class/backlight/$bl/max_brightness" 2>/dev/null)
      [[ -n "$cur" && -n "$max" && "$max" -gt 0 ]] || return 1
      echo $((cur * 100 / max))
      ;;
    ddc)
      local val
      val=$(ddcutil getvcp 10 --brief 2>/dev/null | awk 'NR==1 {print $4}') || true
      if [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "$val"
      else
        rm -f "$METHOD_CACHE"
        return 1
      fi
      ;;
    none)
      return 1
      ;;
  esac
}

# ── 写硬件亮度 ──
set_hardware() {
  local val=$1 dev
  case "$(detect_method)" in
    backlight)
      dev=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
      [[ -n "$dev" ]] && brightnessctl --device="$dev" set "${val}%" 2>/dev/null
      ;;
    ddc)
      if ! ddcutil setvcp 10 "$val" 2>/dev/null; then
        rm -f "$METHOD_CACHE"
        return 1
      fi
      ;;
  esac
}

# ── cache 是否新鲜 ──
cache_fresh() {
  local mt
  [[ -f "$CACHE" ]] || return 1
  mt=$(stat -c %Y "$CACHE" 2>/dev/null) || return 1
  (( $(date +%s) - mt < FRESH_CACHE ))
}

# ── 读取 cache（必须是有效数字才返回） ──
read_cache() {
  local v
  v=$(cat "$CACHE" 2>/dev/null) || return 1
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  echo "$v"
}

main() {
  case "${1:-get}" in
    get)
      # 快路径：cache 新鲜直接返回（毫秒级，不碰硬件）
      if cache_fresh && v=$(read_cache); then
        echo "$v"
        exit 0
      fi
      # 慢路径：cache 缺失/过期，读硬件校准
      if v=$(get_hardware); then
        echo "$v" > "$CACHE"
        echo "$v"
      else
        echo ""
      fi
      ;;
    up|down)
      # 前台：纯 cache 运算（毫秒级），UI 立即响应
      local cur new v
      cur=$(read_cache) || cur=$(get_hardware) || cur=50
      if [[ "$1" = up ]]; then
        new=$((cur + STEP)); (( new > 100 )) && new=100
      else
        new=$((cur - STEP)); (( new < 0 )) && new=0
      fi
      echo "$new" > "$CACHE"
      echo "$new"
      # 后台异步写硬件：防抖 0.15s + flock 串行 + 写 cache 最新值
      (
        flock 9
        sleep 0.15
        if v=$(read_cache); then
          # 写硬件失败则丢弃 cache，让下次 get 重新从硬件校准，避免 UI 与实际长期不一致
          set_hardware "$v" || rm -f "$CACHE"
        fi
      ) 9>"$LOCK" </dev/null >/dev/null 2>&1 &
      disown
      ;;
    save)
      if v=$(get_hardware); then
        echo "$v" > "$CACHE"
        echo "$v"
      else
        echo "读取失败" >&2
        exit 1
      fi
      ;;
    restore)
      local v
      v=$(read_cache) || { echo "无缓存" >&2; exit 1; }
      set_hardware "$v"
      echo "restored: $v"
      ;;
    sync)
      local hw cache
      cache=$(read_cache) || { echo "无缓存" >&2; exit 1; }
      # 如果 cache 刚被 up/down 更新，后台写硬件可能还没完成，跳过本次
      if [[ -f "$CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) < SYNC_FRESH_GUARD )); then
        echo "in-sync: $cache"
        exit 0
      fi
      hw=$(get_hardware) || { echo "读取失败" >&2; exit 1; }
      if [[ "$hw" != "$cache" ]]; then
        set_hardware "$cache"
        echo "synced: $cache"
      else
        echo "in-sync: $cache"
      fi
      ;;
    hw)
      # 只读硬件亮度（不碰 cache），供外部脚本检测用
      get_hardware
      ;;
    *)
      echo "用法: $0 {get|up|down|save|restore|sync|hw}" >&2
      exit 1
      ;;
  esac
}

main "$@"
