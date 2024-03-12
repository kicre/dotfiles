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
command4 = "powershell -Command ""& {aria2c --conf-path=" & scoopPersist & "\aria2\aria2.conf --async-dns=false}"""
command5 = "powershell -Command ""& {rclone mount alist: S: --volname alist --cache-dir ""F:\alist-vfs-cache"" --multi-thread-streams 1024 --multi-thread-cutoff 128M --network-mode --vfs-cache-mode full --vfs-cache-max-size 100G --vfs-cache-max-age 240000h --vfs-read-chunk-size-limit off --buffer-size 64K --vfs-read-chunk-size 64K --vfs-read-wait 0ms -v --vfs-read-chunk-size-limit 64K --vfs-read-wait 0ms -v -vv}"""
command6 = "powershell -Command ""& {rclone mount cos:cloud-1319789079 T: --volname cos --cache-dir ""F:\cos-vfs-cache"" --multi-thread-streams 1024 --multi-thread-cutoff 128M --network-mode --vfs-cache-mode full --vfs-cache-max-size 100G --vfs-cache-max-age 240000h --vfs-read-chunk-size-limit off --buffer-size 64K --vfs-read-chunk-size 64K --vfs-read-wait 0ms -v --vfs-read-chunk-size-limit 64K --vfs-read-wait 0ms -v -vv}"""

objShell.CurrentDirectory = singBoxDir
objShell.Run command1, 0, False
objShell.CurrentDirectory = "C:\users\kicre"
WScript.Sleep 5000
objShell.Run command2, 1, False
objShell.Run command4, 0, False
objShell.Run command5, 0, False
objShell.Run command6, 0, False
