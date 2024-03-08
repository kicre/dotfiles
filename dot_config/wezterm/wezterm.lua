-- The only required line is this one.
local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action
-- Some empty tables for later use
local config = {}
local keys = {}
local mouse_bindings = {}
local launch_menu = {}

local haswork,work = pcall(require,"work")

-- Shell
if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    table.insert( launch_menu, {
        label = 'Git Bash',
        args = { 'bash', '-l'}
     } )
    table.insert( launch_menu, {
        label = 'NuShell',
        args = { 'nu', '-l'}
     } )
    table.insert( launch_menu, {
        label = 'WSL',
        args = { 'wsl', '--cd', "/home/" }
     } )
    table.insert( launch_menu, {
        label = 'PWSH',
        args = { 'pwsh', '-l'}
     } )
    config.default_prog = { 'pwsh', '-l' }
elseif wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
    table.insert( launch_menu, {
        label = 'Bash',
        args = { 'bash', '-l' }
     } )
    table.insert( launch_menu, {
        label = 'Zsh',
        args = { 'zsh', '-l' }
     } )
      config.default_prog = { 'zsh', '-l' }
else
    table.insert( launch_menu, {
        label = 'Zsh',
        args = { 'zsh', '-l' }
     } )
    config.default_prog = { 'zsh', '-l' }
end

-- Theme
--function get_appearance()
--  if wezterm.gui then
--    return wezterm.gui.get_appearance()
--  end
--  return 'Dark'
--end
--
--function scheme_for_appearance(appearance)
--  if appearance:find 'Dark' then
--    return 'DanQing (base16)'
--  else
--    return 'DanQing Light (base16)'
--	end
--end
--
--return {
--  color_scheme = scheme_for_appearance(get_appearance()),
--}
-- config.color_scheme = 'Bamboo'
config.window_background_opacity = 0.9

-- 取消 Windows 原生标题栏
-- config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

--- Default config settings
config.font = wezterm.font('等距更纱黑体 SC Nerd Font')
config.font_size = 12
config.launch_menu = launch_menu
config.default_cursor_style = 'SteadyUnderline'
config.disable_default_key_bindings = true
config.keys = keys
config.mouse_bindings = mouse_bindings
config.enable_tab_bar = false

config.colors = {

  -- 默认文本颜色
  foreground = '#AEAEAE',

  -- 默认背景颜色
  background = '#181B1F',

  -- 当前单元格被光标占据且光标样式设置为块时，覆盖单元格背景颜色
  cursor_bg = '#3E4044',

  -- 当前单元格被光标占据时覆盖文本颜色
  cursor_fg = '#F2E6D4',

  -- 当光标样式设置为块时，指定光标边框颜色，或当光标样式设置为竖线或下划线时，指定竖线或横线的颜色
  cursor_border = '#FFFDFB',

  -- 选定文本的前景色
  selection_fg = '#FFF7ED',

  -- 选定文本的背景色
  selection_bg = '#0D0F13',

  -- 滚动条“滑块”的颜色；表示当前视口的部分
  scrollbar_thumb = '#3E4044',

  -- 分隔窗格之间的分割线的颜色
  split = '#636363',

  ansi = {
    '#0D0F13',   -- black
    '#CB7459',   -- red
    '#46A473',   -- green
    '#A38F2D',   -- yellow
    '#7E87D6',   -- navy
    '#BD72A8',   -- purple
    '#00A0BE',   -- teal
    '#DEDEDE',   -- silver
  },

  brights = {
    '#636363',   -- grey
    '#F48E74',   -- orange
    '#1AC2E1',   -- cyan
    '#C7AD40',   -- yellow
    '#97A6FF',   -- blue
    '#E18DCE',   -- magenta
    '#61C68A',   -- aqua
    '#FFFDFB',   -- white
  },

  -- 调色板中从16到255范围内的任意颜色
  indexed = { [136] = '#af8700' },

  -- 自20220319-142410-0fcdea07起
  -- 当正在处理输入法、死键或前导键并且实际上正在等待输入组合结果时，将光标更改为此颜色以提供有关组合状态的视觉提示
  compose_cursor = 'orange',

  -- copy_mode和quick_select的颜色
  -- 自20220807-113146-c2fee766起可用
  -- 在copy_mode中，活动文本的颜色是：
  -- 1. 如果使用鼠标选择了其他文本，则为copy_mode_active_highlight_*
  -- 2. 否则为selection_*
  copy_mode_active_highlight_bg = { Color = '#000000' },
  -- 使用`AnsiColor`指定ansi颜色调色板值（索引0-15）之一，使用以下名称之一："Black"、"Maroon"、"Green"、"Olive"、"Navy"、"Purple"、"Teal"、"Silver"、"Grey"、"Red"、"Lime"、"Yellow"、"Blue"、"Fuchsia"、"Aqua"或"White"
  copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
  copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
  copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

  quick_select_label_bg = { Color = 'peru' },
  quick_select_label_fg = { Color = '#ffffff' },
  quick_select_match_bg = { AnsiColor = 'Navy' },
  quick_select_match_fg = { Color = '#ffffff' },
}

return config

