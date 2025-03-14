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
(& uv    generate-shell-completion powershell) | Out-String | Invoke-Expression
(& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression

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
