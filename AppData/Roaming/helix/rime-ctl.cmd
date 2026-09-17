@echo off
setlocal EnableExtensions

set "WEASEL="
set "PF=%ProgramFiles%"
set "PF86=%ProgramFiles(x86)%"
set "LA=%LocalAppData%"
set "AA=%APPDATA%"
set "UP=%USERPROFILE%"

REM Allow overriding the WeaselServer.exe path with the WEASEL_SERVER env var
if defined WEASEL_SERVER if exist "%WEASEL_SERVER%" set "WEASEL=%WEASEL_SERVER%"
if defined PF if exist "%PF%\Rime\WeaselServer.exe" set "WEASEL=%PF%\Rime\WeaselServer.exe"
if not defined WEASEL if defined PF86 if exist "%PF86%\Rime\WeaselServer.exe" set "WEASEL=%PF86%\Rime\WeaselServer.exe"
if not defined WEASEL if defined LA if exist "%LA%\Rime\WeaselServer.exe" set "WEASEL=%LA%\Rime\WeaselServer.exe"
if not defined WEASEL if defined AA if exist "%AA%\Rime\WeaselServer.exe" set "WEASEL=%AA%\Rime\WeaselServer.exe"
if not defined WEASEL if defined UP if exist "%UP%\scoop\apps\rime\current\WeaselServer.exe" set "WEASEL=%UP%\scoop\apps\rime\current\WeaselServer.exe"
if not defined WEASEL if defined UP if exist "%UP%\scoop\apps\weasel\current\WeaselServer.exe" set "WEASEL=%UP%\scoop\apps\weasel\current\WeaselServer.exe"
if not defined WEASEL if defined UP if exist "%UP%\scoop\apps\rime-weasel\current\WeaselServer.exe" set "WEASEL=%UP%\scoop\apps\rime-weasel\current\WeaselServer.exe"

REM Weasel is often installed in a versioned subdirectory: weasel-*\
if not defined WEASEL if defined PF for /d %%D in ("%PF%\Rime\weasel-*") do if not defined WEASEL if exist "%%D\WeaselServer.exe" set "WEASEL=%%D\WeaselServer.exe"
if not defined WEASEL if defined PF86 for /d %%D in ("%PF86%\Rime\weasel-*") do if not defined WEASEL if exist "%%D\WeaselServer.exe" set "WEASEL=%%D\WeaselServer.exe"
if not defined WEASEL if defined LA for /d %%D in ("%LA%\Rime\weasel-*") do if not defined WEASEL if exist "%%D\WeaselServer.exe" set "WEASEL=%%D\WeaselServer.exe"
if not defined WEASEL if defined UP for /d %%D in ("%UP%\Rime\weasel-*") do if not defined WEASEL if exist "%%D\WeaselServer.exe" set "WEASEL=%%D\WeaselServer.exe"

if not defined WEASEL (
    for /f "delims=" %%I in ('where WeaselServer.exe 2^>nul') do if not defined WEASEL set "WEASEL=%%I"
)

REM 找不到 WeaselServer 时静默退出，不干扰编辑器
if not defined WEASEL exit /b 0

REM 只有切到 normal/英文 时才切换；进入 insert 时不处理输入法
if /i "%~1"=="exit"  "%WEASEL%" /ascii
if /i "%~1"=="normal" "%WEASEL%" /ascii
if /i "%~1"=="start" "%WEASEL%" /ascii
if /i "%~1"=="status" echo %WEASEL%

exit /b 0
