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
        label = 'Git Bash',
        args = { 'bash', '-l'}
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

config.color_scheme_dirs = {'~/.config/wezterm/colors'}
config.color_scheme = 'Penumbra Light'
config.window_background_opacity = 0.9
config.window_padding = {
    left = '0',
    right = '0',
    top = '0',
    bottom = '0',
}

--- Default config settings
if wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
    config.font = wezterm.font ( 'monospace' )
else
    config.font = wezterm.font_with_fallback{
        'Iosevka Fixed',
        'Noto Sans CJK SC',
        'Symbols Nerd Font Mono',
        'Twitter color Emoji',
    }
end

config.font_size = 12
config.launch_menu = launch_menu
config.default_cursor_style = 'SteadyUnderline'
config.enable_tab_bar = false
--- window size
if wezterm.target_triple ~= 'x86_64-unknown-linux-gnu' then
config.initial_cols = 96
config.initial_rows = 32
end

return config
