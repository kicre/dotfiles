Set objShell = WScript.CreateObject("WScript.Shell")

scoop_up = "powershell -Command ""& {sudo scoop update * -g}"""
mount_1 = "powershell -Command ""& {rclone mount alist: S: --volname alist --multi-thread-streams 64 --network-mode --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 10m --buffer-size 128M -v -vv}"""
mount_2 = "powershell -Command ""& {rclone mount pikpak: P: --volname pikpak --multi-thread-streams 64 --network-mode --vfs-cache-mode full --vfs-cache-max-size 1G --vfs-cache-max-age 10m --buffer-size 128M -v -vv}"""

objShell.Run scoop_up, 1, False
objShell.Run mount_1, 0, False
objShell.Run mount_2, 0, False
