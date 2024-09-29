Set objShell = WScript.CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

scoop = objShell.ExpandEnvironmentStrings("%scoop%")
scoopPersist = scoop & "\persist"
singBoxDir = scoop & "\apps\sing-box\current\"
runVbs = singBoxDir & "\run.vbs"
configJson = singBoxDir & "\config.json"

If Not objFSO.FileExists(runVbs) Then
    objFSO.CopyFile scoopPersist & "\sing-box\run.vbs", runVbs
End If

If Not objFSO.FileExists(configJson) Then
    objFSO.CopyFile scoopPersist & "\sing-box\config.json", configJson
End If

command1 = "cscript """ & runVbs & """"
command2 = "powershell -Command ""& {sudo scoop update * -g}"""
command3 = "powershell -Command ""& {aria2c --conf-path=" & scoopPersist & "\aria2\aria2.conf --async-dns=false}"""
command4 = "powershell -Command ""& {rclone mount alist: S: --volname alist --multi-thread-streams 64 --network-mode --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 10m --buffer-size 128M -v -vv}"""
command5 = "powershell -Command ""& {rclone mount pikpak: P: --volname pikpak --multi-thread-streams 64 --network-mode --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 10m --buffer-size 128M -v -vv}"""

objShell.CurrentDirectory = singBoxDir
objShell.Run command1, 0, False
objShell.CurrentDirectory = "C:\users\kicre\scoop\persist\aria2"
WScript.Sleep 3000
objShell.Run command2, 1, False
objShell.Run command3, 0, False
objShell.Run command4, 0, False
objShell.Run command5, 0, False
