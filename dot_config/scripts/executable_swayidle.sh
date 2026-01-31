#!/usr/bin/env bash

swayidle -w \
        timeout 300   'hyprlock -f' \
        timeout 600   'niri msg action power-off-monitors' \
        resume        'niri msg action power-on-monitors' \
        timeout 1200  'systemctl suspend'
