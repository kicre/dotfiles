#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Waybar sing-box 模块
#    · 路由模式切换 → sing-box Clash API：PATCH /configs {"mode":"…"}
#    · 服务控制     → systemd：start / stop / restart
#
#  用法：
#    singbox.sh                   输出 waybar JSON（exec 调用）
#    singbox.sh set <mode>        切换到指定路由模式
#    singbox.sh cycle [next|prev] 顺序切换路由模式（滚轮）
#    singbox.sh menu              弹出菜单：路由模式 + 服务操作
#    singbox.sh toggle            运行中→停止；已停止→启动
#    singbox.sh start|stop|restart
#    singbox.sh modes             列出可用路由模式
#    singbox.sh api               打印 /configs 原始返回（排错）
#
#  可选配置文件 ~/.config/waybar/singbox.conf（直接赋值即可覆盖）：
#    API_BASE="http://127.0.0.1:9090"   # 留空则自动探测
#    API_SECRET=""                      # clash_api 的 secret
#    UNIT="sing-box.service"            # systemd 单元名
#    SIGNAL=12                          # 刷新 waybar 用的 SIGRTMIN+N
#    NOTIFY=1                           # 是否发桌面通知
#    MENU_CMD=""                        # 留空自动探测 fuzzel/rofi/wofi
#    SINGBOX_MODES="rule direct global" # 固定模式顺序（留空则从 API 读）
#    SYSTEMCTL_TIMEOUT=20               # systemctl 客户端最长等待秒数
#    ACTION_TIMEOUT=45                  # 单次点击最多等待多久（秒）
#    SYSTEMD_METHODS="systemctl busctl" # 调用方式优先级
#    SYSTEMD_PREFIXES="sudo -n|"        # 提权前缀优先级（| 分隔；空项=当前用户身份）
#    SYSTEMCTL_BIN="/usr/bin/systemctl" # systemctl 路径（留空自动探测，优先 /usr/bin）
#    MODE_ICON[direct]="…"              # 覆盖图标
#    MODE_LABEL[direct]="直连"          # 覆盖标签
# ════════════════════════════════════════════════════════════════════
set -uo pipefail

# ── 可覆盖的默认值（环境变量 > 配置文件 > 默认）───────────────────────
: "${API_BASE:=}"
: "${API_SECRET:=}"
: "${UNIT:=sing-box.service}"
: "${SIGNAL:=12}"
: "${NOTIFY:=1}"
: "${MENU_CMD:=}"
: "${SINGBOX_MODES:=}"
: "${SYSTEMCTL_TIMEOUT:=20}"   # 单次 systemd 客户端最长等待秒数
: "${ACTION_TIMEOUT:=45}"      # 一次点击最多等待多久（秒）
: "${SYSTEMD_METHODS:=systemctl busctl}"  # 调用方式优先级
: "${SYSTEMD_PREFIXES:=sudo -n|}"         # 提权前缀优先级，| 分隔；空项 = 用当前用户身份调用

# 提权前缀列表：sudo -n 放第一位 —— 配了 NOPASSWD 就是最快路径，且不弹 polkit 授权框；
# 没配也只会立刻失败（-n 不交互），随后自然退回当前用户身份那条路
# （末尾补一个分隔符：read 会丢掉结尾的空字段，而空字段正是「不提权」那一项）
IFS='|' read -r -a SYSTEMD_PREFIX_ARR <<< "${SYSTEMD_PREFIXES}|"
[[ ${#SYSTEMD_PREFIX_ARR[@]} -gt 0 ]] || SYSTEMD_PREFIX_ARR=("sudo -n" "")

# systemctl 用哪条路径：优先 /usr/bin/systemctl —— sudoers 的 NOPASSWD 一般写的就是这条绝对路径，
# 而 PATH 里可能先命中 /usr/sbin/systemctl（usrmerge 下是同一个文件，但 sudo 是按路径字符串匹配授权项的）
if [[ -z ${SYSTEMCTL_BIN:-} ]]; then
  if [[ -x /usr/bin/systemctl ]]; then SYSTEMCTL_BIN=/usr/bin/systemctl
  else SYSTEMCTL_BIN=$(command -v systemctl || printf 'systemctl'); fi
fi

# 模式图标 / 中文标签（Clash API 的 mode 名 → 显示）
declare -A MODE_ICON=(
  [rule]="󰑪"          # md-routes
  [global]="󰖟"        # md-web
  [direct]="󱘖"        # md-connection
  [allowAds]="󱤪"      # md-advertisements
)
declare -A MODE_LABEL=(
  [rule]="规则"
  [global]="全局"
  [direct]="直连"
  [allowAds]="广告"
)
ICON_MODE_UNKNOWN="󰒓"  # md-cog
ICON_OFF="󰐥"           # md-power
ICON_FAIL="󰀦"          # md-alert
ICON_WAIT="󰝲"          # md-loading
ICON_RESTART="󰜉"       # md-restart
ICON_STOP="󰓛"          # md-stop
ICON_START="󰐊"         # md-play
NL=$'\n'               # 真换行：json_escape 会把它转成 JSON 的 \n（写 "\n" 只会得到字面量）

CONF="${SINGBOX_WAYBAR_CONF:-$HOME/.config/waybar/singbox.conf}"
# shellcheck source=/dev/null
[[ -r $CONF ]] && . "$CONF"

have() { command -v "$1" >/dev/null 2>&1; }

# 从 sing-box 配置里探测 clash_api 地址（配置没变时无需手写 API_BASE）
detect_api() {
  local f addr
  for f in /etc/sing-box/config.json \
           "${XDG_CONFIG_HOME:-$HOME/.config}/sing-box/config.json"; do
    [[ -r $f ]] || continue
    addr=$(grep -oP '"external_controller"\s*:\s*"\K[^"]+' "$f" 2>/dev/null | head -1)
    [[ -z $addr ]] && continue
    [[ $addr == /* ]] && continue                    # unix socket，暂不支持
    addr=${addr/0.0.0.0/127.0.0.1}
    addr=${addr/\[::\]/127.0.0.1}
    printf 'http://%s' "$addr"
    return 0
  done
  printf 'http://127.0.0.1:9090'
}
API_BASE="${API_BASE:-$(detect_api)}"

# ── Clash API ────────────────────────────────────────────────────────
api() { # api <METHOD> <PATH> [JSON] → 响应体
  local method=$1 path=$2 body=${3-}
  local -a args=(-sS -m 4 -X "$method")
  [[ -n $API_SECRET ]] && args+=(-H "Authorization: Bearer $API_SECRET")
  [[ -n $body ]] && args+=(-H 'Content-Type: application/json' --data-binary "$body")
  curl "${args[@]}" "$API_BASE$path" 2>/dev/null
}

api_status() { # api_status <METHOD> <PATH> [JSON] → HTTP 状态码
  local method=$1 path=$2 body=${3-}
  local -a args=(-sS -m 4 -o /dev/null -w '%{http_code}' -X "$method")
  [[ -n $API_SECRET ]] && args+=(-H "Authorization: Bearer $API_SECRET")
  [[ -n $body ]] && args+=(-H 'Content-Type: application/json' --data-binary "$body")
  curl "${args[@]}" "$API_BASE$path" 2>/dev/null
}

configs_raw() { api GET /configs; }

parse_mode() { # parse_mode <json>
  local raw=$1
  if have jq; then printf '%s' "$raw" | jq -r '.mode // empty' 2>/dev/null
  else printf '%s' "$raw" | grep -oP '"mode"\s*:\s*"\K[^"]+'; fi
}

parse_mode_list() { # parse_mode_list <json>
  local raw=$1
  if have jq; then printf '%s' "$raw" | jq -r '.["mode-list"][]?' 2>/dev/null
  else printf '%s' "$raw" | grep -oP '"mode-list"\s*:\s*\[\K[^]]*' | grep -oP '"[^"]+"' | tr -d '"'; fi
}

current_mode()   { local raw=${1-}; [[ -z $raw ]] && raw=$(configs_raw); parse_mode "$raw"; }
available_modes(){ local raw=${1-}; [[ -z $raw ]] && raw=$(configs_raw); parse_mode_list "$raw"; }

mode_icon()  { printf '%s' "${MODE_ICON[$1]:-$ICON_MODE_UNKNOWN}"; }
mode_label() { printf '%s' "${MODE_LABEL[$1]:-$1}"; }

# 模式顺序：rule 固定第一，其余按名字排序 → 滚轮顺序稳定
ordered_modes() { # ordered_modes [json]
  local raw=${1-} m
  local -a first=() rest=()
  if [[ -n $SINGBOX_MODES ]]; then
    for m in $SINGBOX_MODES; do printf '%s\n' "$m"; done
    return 0
  fi
  while IFS= read -r m; do
    [[ -z $m ]] && continue
    if [[ $m == rule ]]; then first+=("$m"); else rest+=("$m"); fi
  done < <(available_modes "$raw")
  ((${#first[@]})) && printf '%s\n' "${first[@]}"
  ((${#rest[@]}))  && printf '%s\n' "${rest[@]}" | LC_ALL=C sort
  return 0
}

set_mode() {
  local mode=$1 code
  code=$(api_status PATCH /configs "{\"mode\":\"$mode\"}")
  if [[ $code =~ ^2 ]]; then
    refresh_bar
    notify "$(mode_icon "$mode")  路由模式：$(mode_label "$mode")" "sing-box 已切换到 $mode"
    return 0
  fi
  notify "切换路由模式失败" "PATCH /configs → HTTP ${code:-无响应}（$mode）"
  return 1
}

cycle() { # cycle [next|prev]
  local dir=${1:-next} cur i idx=-1 n next
  local -a list=()
  while IFS= read -r m; do [[ -n $m ]] && list+=("$m"); done < <(ordered_modes)
  ((${#list[@]})) || { notify "没有可用的路由模式" "Clash API 无响应：$API_BASE"; return 1; }
  cur=$(current_mode)
  for i in "${!list[@]}"; do [[ ${list[$i]} == "$cur" ]] && { idx=$i; break; }; done
  n=${#list[@]}
  if   (( idx < 0 ));      then next=0
  elif [[ $dir == prev ]]; then next=$(( (idx - 1 + n) % n ))
  else                          next=$(( (idx + 1) % n )); fi
  set_mode "${list[$next]}"
}

# ── systemd ──────────────────────────────────────────────────────────
unit_state()  { systemctl is-active "$UNIT" 2>/dev/null || true; }
unit_active() { [[ $(unit_state) == active ]]; }

unit_pid()    { systemctl show -p MainPID --value "$UNIT" 2>/dev/null || true; }

# 检查动作是否已经生效。不看退出码：需要 polkit 授权时，systemctl 会一直等认证框回话
# （被取消、超时都可能发生），而单元其实可能已经切换成功，所以一律以「单元实际状态」为准。
_check_effect() {
  local action=$1 old_pid=$2 pid st
  st=$(unit_state)
  case $action in
    stop)  [[ $st == inactive || $st == failed ]] && return 0 ;;
    start) [[ $st == active ]] && return 0 ;;
    restart)
      pid=$(unit_pid)
      [[ -n $pid && $pid != 0 && $pid != "$old_pid" && $st == active ]] && return 0 ;;
  esac
  return 1
}

# 生成一条 systemd 调用命令。systemctl 优先：sudoers 的 NOPASSWD 一般只授权 /usr/bin/systemctl；
# busctl 是纯 D-Bus 调用（同样要过 polkit），仅作 systemctl 不可用时的兜底
_systemd_cmd() { # _systemd_cmd <action> [提权前缀]
  local action=$1 pre=${2-} m
  if [[ $SYSTEMD_METHOD == busctl ]]; then
    case $action in
      start)   m=StartUnit ;;
      stop)    m=StopUnit ;;
      restart) m=RestartUnit ;;
    esac
    printf '%s' "${pre:+$pre }busctl --system --timeout=$SYSTEMCTL_TIMEOUT call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager $m ss $UNIT replace"
  else
    printf '%s' "${pre:+$pre }$SYSTEMCTL_BIN $action $UNIT"
  fi
}

# 发起一次调用，并在客户端存活期间一直盯着实际状态
# 返回 0=已生效　1=快速失败（权限被拒等）　2=超时（授权可能仍在处理中）
_fire() {
  local action=$1 pre=$2 old_pid=$3 job rc
  local -a cmd
  read -r -a cmd <<< "$(_systemd_cmd "$action" "$pre")"
  timeout "$SYSTEMCTL_TIMEOUT" "${cmd[@]}" >/dev/null 2>&1 &
  job=$!
  while kill -0 "$job" 2>/dev/null; do
    _check_effect "$action" "$old_pid" && { kill "$job" 2>/dev/null; return 0; }
    sleep 0.25
  done
  wait "$job" 2>/dev/null; rc=$?
  _check_effect "$action" "$old_pid" && return 0
  (( rc == 124 )) && return 2
  return 1
}

systemd_act() { # systemd_act <start|stop|restart> → 0 表示已确认生效
  local action=$1 old_pid deadline method pre rc interactive=0
  old_pid=$(unit_pid)
  deadline=$(( SECONDS + ACTION_TIMEOUT ))

  # 前缀按 SYSTEMD_PREFIXES 的顺序试（默认 sudo -n 优先，理由见文件头注释）
  for method in $SYSTEMD_METHODS; do
    have "$method" || continue
    SYSTEMD_METHOD=$method
    for pre in "${SYSTEMD_PREFIX_ARR[@]}"; do
      if [[ -n $pre ]] && ! have "${pre%% *}"; then continue; fi
      _fire "$action" "$pre" "$old_pid"; rc=$?
      (( rc == 0 )) && return 0
      # 以当前用户身份调用会走 polkit，可能弹一次授权框：弹过就不再叠加新请求
      [[ -z $pre ]] && interactive=1
      (( interactive )) && break
    done
    (( interactive )) && break
  done

  # 请求都发出去了：剩余时间只盯实际状态（授权可能还在处理中），不再重复发起
  while (( SECONDS < deadline )); do
    _check_effect "$action" "$old_pid" && return 0
    sleep 0.25
  done
  return 1
}

wait_api() { # 等服务起来后 API 就绪，最多 ~6s
  local _i
  for _i in {1..12}; do
    [[ -n $(api GET /configs) ]] && return 0
    sleep 0.5
  done
  return 1
}

service_action() {
  local action=$1 cur
  case $action in
    stop)
      systemd_act stop || { notify "sing-box 停止未确认" "当前状态：$(unit_state)（可能需要 polkit 授权）"; return 1; }
      notify "sing-box 已停止" "代理已关闭" ;;
    start)
      systemd_act start || { notify "sing-box 启动未确认" "当前状态：$(unit_state)（可能需要 polkit 授权）"; return 1; }
      if wait_api; then cur=$(current_mode)
        notify "sing-box 已启动" "路由模式：$(mode_label "$cur")（$cur）"
      else notify "sing-box 已启动" "Clash API 尚未就绪"; fi ;;
    restart)
      systemd_act restart || { notify "sing-box 重启未确认" "当前状态：$(unit_state)（可能需要 polkit 授权）"; return 1; }
      if wait_api; then cur=$(current_mode)
        notify "sing-box 已重启" "路由模式：$(mode_label "$cur")（$cur）"
      else notify "sing-box 已重启" "Clash API 尚未就绪"; fi ;;
    *) return 1 ;;
  esac
  refresh_bar
  return 0
}

# ── 通知 / 刷新 / 输出 ───────────────────────────────────────────────
notify() {
  [[ $NOTIFY == 1 ]] || return 0
  have notify-send || return 0
  if [[ -n ${2-} ]]; then
    notify-send -a sing-box -i network-vpn "$1" "$2" >/dev/null 2>&1
  else
    notify-send -a sing-box -i network-vpn "$1" >/dev/null 2>&1
  fi
  return 0
}

refresh_bar() {
  [[ $SIGNAL =~ ^[0-9]+$ ]] && pkill -RTMIN+"$SIGNAL" waybar >/dev/null 2>&1
  return 0
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

emit() {
  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(json_escape "$1")" "$(json_escape "$2")" "${3-}"
}

# ── 状态输出（waybar 默认调用）────────────────────────────────────────
status() {
  local state raw mode text tip cls m line
  state=$(unit_state)

  if [[ $state != active ]]; then
    case $state in
      failed)     text="$ICON_FAIL 失败";    cls="off" ;;
      activating) text="$ICON_WAIT 启动中";  cls="off" ;;
      *)          text="$ICON_OFF 已停止";   cls="off" ;;
    esac
    tip="sing-box（$UNIT）：${state:-未知}${NL}${NL}左键：菜单　右键：重启服务　中键：启动/停止${NL}滚轮：切换路由模式"
    emit "$text" "$tip" "$cls"
    return 0
  fi

  raw=$(configs_raw)
  mode=$(current_mode "$raw")
  if [[ -z $mode ]]; then
    emit "$ICON_FAIL sing-box" \
      "sing-box 正在运行，但 Clash API 无响应${NL}$API_BASE/configs${NL}${NL}左键：菜单　右键：重启服务" "err"
    return 0
  fi

  tip="sing-box 运行中　$UNIT${NL}路由模式：$(mode_label "$mode")（$mode）${NL}────────────────${NL}"
  while IFS= read -r m; do
    [[ -z $m ]] && continue
    if [[ $m == "$mode" ]]; then line="● $(mode_icon "$m") $(mode_label "$m")"
    else                        line="　$(mode_icon "$m") $(mode_label "$m")"; fi
    tip+="$line${NL}"
  done < <(ordered_modes "$raw")
  tip+="────────────────${NL}左键：菜单　右键：重启服务　中键：停止服务${NL}滚轮：切换路由模式"

  emit "$(mode_icon "$mode") $(mode_label "$mode")" "$tip" "mode-$mode"
}

# ── 菜单 ─────────────────────────────────────────────────────────────
detect_menu() {
  if [[ -n $MENU_CMD ]]; then printf '%s' "$MENU_CMD"; return 0; fi
  if have fuzzel; then printf '%s' 'fuzzel --dmenu --prompt=sing-box: --width=34 --lines=14'; return 0; fi
  if have rofi;   then printf '%s' 'rofi -dmenu -i -p sing-box:'; return 0; fi
  if have wofi;   then printf '%s' 'wofi -dmenu -i -p sing-box:'; return 0; fi
  return 1
}

run_menu() {
  local cmd_str; cmd_str=$(detect_menu) || return 1
  local -a cmd; read -r -a cmd <<< "$cmd_str"
  "${cmd[@]}"
}

show_logs() {
  local term
  for term in foot kitty alacritty ghostty wezterm; do
    have "$term" || continue
    case $term in
      kitty) "$term" journalctl -u "$UNIT" -f -n 200 >/dev/null 2>&1 & ;;
      *)     "$term" -e journalctl -u "$UNIT" -f -n 200 >/dev/null 2>&1 & ;;
    esac
    return 0
  done
  notify "未找到终端模拟器" "请手动运行：journalctl -u $UNIT -f"
  return 0
}

menu() {
  local cur m sel
  local -a items=()
  local sep="─────────────────────────"
  local it_restart="$ICON_RESTART 重启 sing-box"
  local it_stop="$ICON_STOP 停止 sing-box"
  local it_start="$ICON_START 启动 sing-box"
  local it_logs="查看日志（journalctl）"

  cur=$(current_mode)
  while IFS= read -r m; do
    [[ -z $m ]] && continue
    if [[ $m == "$cur" ]]; then items+=("● $(mode_icon "$m") $(mode_label "$m")　($m)")
    else                        items+=("　$(mode_icon "$m") $(mode_label "$m")　($m)"); fi
  done < <(ordered_modes)
  items+=("$sep" "$it_restart" "$it_stop" "$it_start" "$it_logs")

  sel=$(printf '%s\n' "${items[@]}" | run_menu) || return 0
  [[ -z $sel ]] && return 0

  case $sel in
    "$it_restart") service_action restart ;;
    "$it_stop")    service_action stop ;;
    "$it_start")   service_action start ;;
    "$it_logs")    show_logs ;;
    "$sep")        return 0 ;;
    *) # 形如 "… (mode)" 的行，取括号里的模式名
       if [[ $sel =~ \(([A-Za-z0-9_.-]+)\)[[:space:]]*$ ]]; then
         set_mode "${BASH_REMATCH[1]}"
       fi ;;
  esac
}

# ── 入口 ─────────────────────────────────────────────────────────────
case "${1:-status}" in
  status|"") status ;;
  set)     [[ -n ${2-} ]] || { echo "用法: $0 set <mode>" >&2; exit 1; }; set_mode "$2" ;;
  cycle)   cycle "${2:-next}" ;;
  menu)    menu ;;
  toggle)  if unit_active; then service_action stop; else service_action start; fi ;;
  start|stop|restart) service_action "$1" ;;
  modes)   ordered_modes ;;
  api)     api GET /configs; echo ;;
  -h|--help|help) sed -n '2,30p' "$0" ;;
  *)       echo "未知参数: $1（-h 查看用法）" >&2; exit 1 ;;
esac
