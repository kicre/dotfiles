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

sing-box = "cscript """ & runVbs & """"
scoop-up = "powershell -Command ""& {sudo scoop update * -g}"""
mount-1 = "powershell -Command ""& {rclone mount alist: S: --volname alist --multi-thread-streams 64 --network-mode --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 10m --buffer-size 128M -v -vv}"""
mount-2 = "powershell -Command ""& {rclone mount pikpak: P: --volname pikpak --multi-thread-streams 64 --network-mode --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 10m --buffer-size 128M -v -vv}"""

objShell.CurrentDirectory = singBoxDir
objShell.Run sing-box, 0, False
WScript.Sleep 3000
objShell.Run scoop-up, 1, False
objShell.Run mount-1, 0, False
objShell.Run mount-2, 0, False
