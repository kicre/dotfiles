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
if (!(Test-Path -Path $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force
}
Add-Content -Path $PROFILE -Value '(& uv generate-shell-completion powershell) | Out-String | Invoke-Expression'

#Proxy
function proxy {
    $env:HTTP_PROXY = "http://127.0.0.1:2080"
    $env:HTTPS_PROXY = "http://127.0.0.1:2080"
    Write-Host "Http Proxy Set"
}
function noproxy {
    $env:HTTP_PROXY = ""
    $env:HTTPS_PROXY = ""
    Write-Host "Unset Proxy"
}
