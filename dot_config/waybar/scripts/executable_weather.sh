#!/usr/bin/env bash
# Waybar weather module - 使用 wttr.in JSON API
# 用法: get_weather.sh [location]  (空 = 自动定位)

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
CACHE_TTL=1800   # 30 分钟缓存
mkdir -p "$CACHE_DIR"

# ── --refresh: 清除所有地点缓存（供 waybar 右键刷新用） ──
if [[ "${1:-}" == "--refresh" ]]; then
    rm -f "$CACHE_DIR"/weather-*.cache "$CACHE_DIR"/weather-*.cache.tmp \
          "$CACHE_DIR"/weather.cache "$CACHE_DIR"/weather.cache.tmp
    exit 0
fi

# ── 读取 ~/.env 配置 ──
ENV_FILE="$HOME/.env"
WEATHER_LOCATION=""
if [[ -f "$ENV_FILE" ]]; then
    WEATHER_LOCATION=$(grep -E '^[[:space:]]*WEATHER_LOCATION[[:space:]]*=' "$ENV_FILE" | head -1 | \
        cut -d= -f2- | xargs)
fi

# 优先级: 命令行参数 > .env > 自动定位
# 用 "$*" 拼接所有参数，这样 `weather.sh xinfu xinzhou` 不加引号也能整句搜索
if [[ $# -gt 0 ]]; then
    LOCATION="$*"
else
    LOCATION="$WEATHER_LOCATION"
fi

# 每个地点用独立缓存，避免改了位置后仍读到上一个地点的旧数据
CACHE_ID=$(printf '%s' "$LOCATION" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/weather-${CACHE_ID}.cache"

# ── 读取缓存（用 tab 分隔，避免空格歧义） ──
if [[ -f "$CACHE_FILE" ]]; then
    IFS=$'\t' read -r cache_text cache_tooltip cache_time < "$CACHE_FILE" 2>/dev/null || true
    if [[ -n "${cache_time:-}" ]] && (( $(date +%s) - 10#${cache_time:-0} < CACHE_TTL )); then
        printf '{"text":"%s","tooltip":"%s"}\n' "$cache_text" "$cache_tooltip"
        exit 0
    fi
fi

# ── 获取 JSON 数据 ──
data=""
enc=""
for i in 1 2 3; do
    if [[ -n "$LOCATION" ]]; then
        # 路径方式 + URL 编码（wttr.in 只认路径，忽略 ?location= 参数）
        enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=','))" "$LOCATION" 2>/dev/null)
        data=$(curl -sfL --connect-timeout 5 --max-time 10 \
            "https://wttr.in/${enc}?format=j1" 2>/dev/null) && break
    else
        data=$(curl -sfL --connect-timeout 5 --max-time 10 \
            "https://wttr.in/?format=j1" 2>/dev/null) && break
    fi
    sleep $(( i * 2 ))
done

[[ -n "$data" ]] || {
    # 兜底：用过期缓存
    if [[ -f "$CACHE_FILE" ]]; then
        IFS=$'\t' read -r cache_text cache_tooltip _ < "$CACHE_FILE" 2>/dev/null || true
        [[ -n "${cache_text:-}" ]] && \
            printf '{"text":"%s","tooltip":"⚠️ 数据过期: %s"}\n' "$cache_text" "${cache_tooltip:-}" && exit 0
    fi
    printf '{"text":"⚠️","tooltip":"天气获取失败"}\n'
    exit 0
}

# ── 获取 wttr.in 实际解析出的显示名 ──
# JSON API 的 nearest_area 对小地点会返回错误的附近地名（如 xinfu 返回 Hesuo），
# 但普通文本输出的 "Location:" 行是 wttr.in 真正解析出的地点，优先使用它。
LOCATION_DISPLAY=""
if [[ -n "$LOCATION" && -n "$enc" ]]; then
    LOCATION_DISPLAY=$(curl -sfL --connect-timeout 5 --max-time 10 \
        "https://wttr.in/${enc}" 2>/dev/null | grep -m1 '^Location:' | \
        sed 's/^Location: //; s/ \[.*\]$//') || true
fi

# ── 解析 JSON 并输出 ──
python3 - "$data" "$LOCATION_DISPLAY" "$LOCATION" <<'PYEOF' > "$CACHE_FILE.tmp"
import json, sys

d = json.loads(sys.argv[1])
loc_display = sys.argv[2]
loc_input = sys.argv[3]
cur = d["current_condition"][0]
area = d["nearest_area"][0]

city   = area["areaName"][0]["value"]
region = area.get("region", [{}])[0].get("value", "")
country= area["country"][0]["value"]
temp   = int(float(cur["temp_C"]))
feels  = int(float(cur["FeelsLikeC"]))
hum    = cur["humidity"]
wind   = cur["windspeedKmph"]
winddir= cur["winddir16Point"]
code   = cur["weatherCode"]

# MDI 图标映射 (按 WMO 天气代码)
def icon(c):
    c = int(c)
    if c == 113:      return "󰖙"  # 晴
    if c == 116:      return "󰖕"  # 少云
    if c in (119,122):return "󰖐"  # 多云/阴
    if c in (143,248,260): return "󰖑"  # 雾/霾
    if c in (200,386,389,392,395): return "󰖓"  # 雷暴
    if c in (179,182,227,230,326,329,332,335,338,350,368,371,374,377): return "󰖘"  # 雪
    if c in (185,311,314): return "󰖔"  # 冻雨
    if c in (176,263,266,281,284,293,296,353): return "󰖖"  # 小雨
    if c in (299,302,305,308,356,359): return "󰼳"  # 中到大雨
    return "󰖐"  # 默认多云

# 中文天气描述 (按 WMO 天气代码)
def desc_zh(c):
    c = int(c)
    table = {
        113: "晴", 116: "少云", 119: "多云", 122: "阴",
        143: "雾", 248: "雾", 260: "冻雾",
        176: "零星小雨", 263: "零星小雨", 266: "小雨", 293: "零星小雨", 296: "小雨",
        299: "小到中雨", 302: "中雨", 305: "中到大雨", 308: "大雨",
        353: "阵雨", 356: "中到大阵雨", 359: "强阵雨",
        281: "冻雨", 284: "强冻雨", 311: "小冻雨", 314: "中到强冻雨",
        185: "零星冻雨", 321: "小冻雨",
        179: "零星小雪", 182: "零星雨夹雪", 227: "吹雪", 230: "暴风雪",
        326: "小阵雪", 329: "小雪", 332: "小到中雪", 335: "中雪", 338: "大雪",
        368: "小阵雪", 371: "中到大阵雪", 350: "冰粒", 374: "小阵冰粒", 377: "中到大阵冰粒",
        200: "雷阵雨", 386: "雷阵雨", 389: "强雷阵雨", 392: "雷阵雪", 395: "强雷阵雪",
    }
    return table.get(c, "未知")

# 风向 16 点转中文
def wind_zh(d):
    table = {
        "N": "北风", "NNE": "东北偏北", "NE": "东北", "ENE": "东北偏东",
        "E": "东风", "ESE": "东南偏东", "SE": "东南", "SSE": "东南偏南",
        "S": "南风", "SSW": "西南偏南", "SW": "西南", "WSW": "西南偏西",
        "W": "西风", "WNW": "西北偏西", "NW": "西北", "NNW": "西北偏北",
    }
    return table.get(d, d)

ic = icon(code)
zh = desc_zh(code)
wz = wind_zh(winddir)

if loc_display:
    loc = loc_display
elif loc_input:
    # 拿不到解析名时，至少显示用户输入的地点，避免显示 JSON 里错误的 nearest_area
    loc = f"{loc_input}, {country}"
else:
    loc = f"{city}, {region} {country}" if region else f"{city}, {country}"
text = f"{ic} {temp}°C"
tooltip = (f"{loc}\n"
           f"{ic} {zh} {temp}°C (体感 {feels}°C)\n"
           f"💧 湿度 {hum}%  🌬️ {wz} {wind}km/h")

# 换行转义为 \n 字面量，避免 bash read 拆行
print(f"{text}\t{tooltip.replace(chr(10), '\\n')}\t{__import__('time').time():.0f}")
PYEOF

if [[ -s "$CACHE_FILE.tmp" ]]; then
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    IFS=$'\t' read -r text tooltip _ < "$CACHE_FILE"
    printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$tooltip"
else
    rm -f "$CACHE_FILE.tmp"
    printf '{"text":"⚠️","tooltip":"天气解析失败"}\n'
fi
