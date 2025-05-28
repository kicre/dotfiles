Invoke-Expression (&starship init powershell)

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Set yazi
$env:YAZI_FILE_ONE = "C:/Users/kicre/scoop/apps/git/current/usr/bin/file.exe"
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath $cwd
    }
    Remove-Item -Path $tmp
}

# uv (python package manager) completion
if (Get-Command uv -ErrorAction SilentlyContinue) {
(& uv    generate-shell-completion powershell) | Out-String | Invoke-Expression
(& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression
}

#Proxy
function proxy {
    $env:HTTP_PROXY = "http://127.0.0.1:7890"
    $env:HTTPS_PROXY = "http://127.0.0.1:7890"
    Write-Host "Http Proxy Set"
}
function noproxy {
    $env:HTTP_PROXY = ""
    $env:HTTPS_PROXY = ""
    Write-Host "Unset Proxy"
}

# Aliases
# ls
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --git @args }
    function l { eza --icons --git @args }
    function la { eza --icons --all --group-directories-first --git @args }
    function ll { eza -l --icons --all --all --group-directories-first --git @args }
    function lt { eza -T --icons --git-ignore --level=2 --group-directories-first @args }
    function llt { eza -lT--icons  --git-ignore --level=2 --group-directories-first @args }
    function lT { eza -T --icons --git-ignore --level=4 --group-directories-first @args }
}
elseif (Get-Command lsd -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { lsd @args }
    function l { lsd @args }
    function la { lsd --all --group-directories-first @args }
    function ll { lsd -l --all --group-directories-first @args }
    function lt { lsd --tree --depth=2 --group-directories-first @args }
    function llt { lsd -l --tree --depth=2 --group-directories-first @args }
    function lT { lsd --tree --depth=4 --group-directories-first @args }
}
else {
    function l { Get-ChildItem -Force | Format-Table -AutoSize }
    function ll { Get-ChildItem -Force -Detailed | Format-Table -AutoSize }
    function la { Get-ChildItem -Force -Hidden | Format-Table -AutoSize }
}
# ssh
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ssh { tssh @args }
