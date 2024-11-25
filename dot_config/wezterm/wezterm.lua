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
    config.color_scheme_dirs = {'~/.config/wezterm/colors'}
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

config.color_scheme = 'Catppuccin Latte'
config.window_background_opacity = 0.9
-- config.enable_wayland = false
config.window_padding = {
    left = '0',
    right = '0',
    top = '0',
    bottom = '0',
}

--- Default config settings
if wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
    config.font = wezterm.font('monospace',{weight = "Regular"})
else
    config.font = wezterm.font('Sarasa Fixed SC Nerd Font',{weight = "Regular"})
end

config.font_size = 12
config.launch_menu = launch_menu
config.default_cursor_style = 'SteadyUnderline'
config.enable_tab_bar = false
--- window size
if not wezterm.target_triple == 'x86_64-unknown-linux-gnu' then
config.initial_cols = 96
config.initial_rows = 32
end

return config

