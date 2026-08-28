# Language
export TZ=Asia/Shanghai
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:en_SG

export PATH="/home/kicre/.local/bin:$PATH"

# vim 
if hash vim 2>/dev/null; then
        alias vi=vim
fi
if hash nvim 2>/dev/null; then
        alias nv=nvim
fi

# Helix 输入法控制：启动/进入时先切到英文，避免普通模式按键被中文输入法拦截
helix() {
	{{ .chezmoi.homeDir }}/.config/scripts/rime-ctl.sh start >/dev/null 2>&1 || true
	command helix "$@"
}
hx() {
	{{ .chezmoi.homeDir }}/.config/scripts/rime-ctl.sh start >/dev/null 2>&1 || true
	command helix "$@"
}

# yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# Proxy
proxy(){
	export http_proxy="http://127.0.0.1:7890"
	export https_proxy="http://127.0.0.1:7890"
	export socks5_proxy="socks5://127.0.0.1:7890"
	echo "HTTP Proxy on"
}

noproxy(){
	unset http_proxy
	unset https_proxy
	unset socks5_proxy
	echo "HTTP Proxy off"
}

# Aliases
# ls
if hash eza 2>/dev/null; then
        alias ls='eza --group-directories-first --icons --git'
        alias l='eza --group-directories-first --icons --git'
        alias la='eza --all --group-directories-first --icons --git'
        alias ll='eza -l --all --group-directories-first --icons --git'
        alias lt='eza -T --git-ignore --level=2 --group-directories-first'
        alias llt='eza -lT --git-ignore --level=2 --group-directories-first'
        alias lT='eza -T --git-ignore --level=4 --group-directories-first'
elif hash lsd 2>/dev/null; then
        alias ls='lsd'
        alias l='lsd --group-directories-first'
        alias la='lsd --all --group-directories-first'
        alias ll='lsd -l --all --group-directories-first'
        alias lt='lsd --tree --depth=2 --group-directories-first'
        alias llt='lsd -l --tree --depth=2 --group-directories-first'
        alias lT='lsd --tree --depth=4 --group-directories-first'
else
        alias l='ls -lah'
        alias ll='ls -alF'
        alias la='ls -A'
fi
