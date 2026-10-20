# ble.sh 自定义配色方案：base16_nobg
# 继承官方 base16（全部使用 ANSI 颜色名，实际 RGB 由终端主题决定），
# 仅移除 base16 中带 bg= 的背景色块。这里没有硬编码 hex/256 色值。

ble-import contrib/scheme/base16

function ble/contrib/scheme:base16_nobg/initialize {
  ble/contrib/scheme:base16/initialize

  # 自动建议：不再使用背景块
  ble-face -s auto_complete             'fg=gray,underline'
  ble-face -s cmdinfo_cd_cdpath         'fg=yellow,bold'

  # 特殊文件名
  ble-face -s filename_directory_sticky 'fg=blue,bold,underline'
  ble-face -s filename_orphan           'fg=red,bold,underline'
  ble-face -s filename_setgid           'fg=magenta,bold,underline'
  ble-face -s filename_setuid           'fg=magenta,bold,underline'

  # 补全菜单 / 过滤器
  ble-face -s menu_filter_input         'fg=yellow,bold,underline'
  ble-face -s menu_complete_selected    'fg=cyan,bold,underline'

  # 编辑状态
  ble-face -s overwrite_mode            'fg=red,bold'
  ble-face -s prompt_status_line        none
  ble-face -s region                    'fg=blue,bold,underline'
  ble-face -s region_insert             'fg=blue,underline'
  ble-face -s region_match              'fg=yellow,bold,underline'
  ble-face -s region_target             'fg=cyan,bold,underline'

  # 语法高亮
  ble-face -s syntax_error              'fg=red,bold,underline'
  ble-face -s syntax_history_expansion  'fg=magenta,bold'

  # 其他
  ble-face -s vbell_erase               'fg=gray'

  return 0
}
