#!/usr/bin/env bash
# Waybar 麦克风模块
# 用法:
#   mic_status.sh          输出状态 JSON（默认）
#   mic_status.sh --toggle 切换静音
#   mic_status.sh --cycle  循环切换默认输入设备（排除 .monitor 回环）
set -euo pipefail

case "${1:-}" in
  --toggle)
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    exit 0
    ;;
  --cycle)
    all_sources=($(pactl list sources short | awk '{print $2}' | grep -v '\.monitor$'))
    current=$(pactl get-default-source)
    idx=-1
    if [[ "$current" != *.monitor ]]; then
      for i in "${!all_sources[@]}"; do
        [[ "${all_sources[$i]}" == "$current" ]] && { idx=$i; break; }
      done
    fi
    if (( ${#all_sources[@]} > 0 )); then
      pactl set-default-source "${all_sources[$(( (idx + 1) % ${#all_sources[@]} ))]}"
    fi
    exit 0
    ;;
esac

# ── 状态输出 ──
default_source=$(pactl get-default-source)
volume=$(pactl get-source-volume "$default_source" 2>/dev/null | grep -oP '[0-9]+(?=%)' | head -1 || true)
volume=${volume:-0}
muted=$(pactl get-source-mute "$default_source" 2>/dev/null | grep -oP '(?<=: ).*')

if [[ "$muted" == "yes" ]]; then
  text="󰍭"
  css_class="muted"
else
  text="󰍬  $volume%"
  css_class=""
fi

# 输入设备列表 tooltip（过滤 .monitor 回环源）
source_data=$(pactl list sources | awk '
  /Name:/ { name=$2 }
  /Description:/ {
    gsub(/.*Description: /, "")
    if (name != "" && name !~ /\.monitor$/) {
      printf "%s\t%s\n", name, $0
    }
    name=""
  }')

tooltip=""
while IFS=$'\t' read -r src_name desc; do
  [[ -z "$src_name" ]] && continue
  if [[ "$src_name" == "$default_source" ]]; then
    tooltip+="→ $desc\n"
  else
    tooltip+="  $desc\n"
  fi
done <<< "$source_data"

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$css_class"
