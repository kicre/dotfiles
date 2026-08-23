#!/usr/bin/env bash
# Waybar 音频模块
# 用法:
#   audio_status.sh          输出状态 JSON（默认）
#   audio_status.sh --toggle 切换静音
#   audio_status.sh --cycle  循环切换默认输出设备
set -euo pipefail

case "${1:-}" in
  --toggle)
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    exit 0
    ;;
  --cycle)
    all_sinks=($(pactl list sinks short | awk '{print $2}'))
    current=$(pactl get-default-sink)
    idx=-1
    for i in "${!all_sinks[@]}"; do
      [[ "${all_sinks[$i]}" == "$current" ]] && { idx=$i; break; }
    done
    if (( idx >= 0 && ${#all_sinks[@]} > 0 )); then
      pactl set-default-sink "${all_sinks[$(( (idx + 1) % ${#all_sinks[@]} ))]}"
    fi
    exit 0
    ;;
esac

# ── 状态输出 ──
sink=$(pactl get-default-sink)
vol=$(pactl get-sink-volume "$sink" 2>/dev/null | grep -oP '[0-9]+(?=%)' | head -1 || true)
vol=${vol:-0}
muted=$(pactl get-sink-mute "$sink" 2>/dev/null | grep -oP '(?<=: ).*')

if [[ "$muted" == "yes" ]]; then
  text="󰝟"
  css_class="muted"
else
  if ((vol == 0)); then icon="󰝟"
  elif ((vol < 33)); then icon="󰕿"
  elif ((vol < 66)); then icon="󰖀"
  else icon="󰕾"
  fi
  text="$icon  $vol%"
  css_class=""
fi

# 设备列表 tooltip
sink_data=$(pactl list sinks | awk '
  /Name:/ { name=$2 }
  /Description:/ { gsub(/.*Description: /, ""); if (name != "") printf "%s\t%s\n", name, $0; name="" }')

tooltip=""
while IFS=$'\t' read -r name desc; do
  [[ -z "$name" ]] && continue
  if [[ "$name" == "$sink" ]]; then
    tooltip+="→ $desc\n"
  else
    tooltip+="  $desc\n"
  fi
done <<< "$sink_data"

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$css_class"
