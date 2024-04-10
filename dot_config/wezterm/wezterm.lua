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

-- Theme
function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Flexoki Dark'
  else
    return 'Flexoki Light'
	end
end

config.color_scheme = scheme_for_appearance(get_appearance())

-- config.color_scheme = 'flexoki-dark'
config.window_background_opacity = 0.9
config.enable_wayland = false
config.window_padding = {
    left = '0',
    right = '0',
    top = '0',
    bottom = '0',
}

--- Default config settings
config.font = wezterm.font('Sarasa Fixed SC Nerd Font',{weight = "Regular"})
config.font_size = 12
config.launch_menu = launch_menu
config.default_cursor_style = 'SteadyUnderline'
config.enable_tab_bar = false

return config

