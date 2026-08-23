#!/usr/bin/env bash

swayidle -w \
        timeout 600   'hyprlock &' \
        timeout 1800   'niri msg action power-off-monitors' \
        resume         'niri msg action power-on-monitors' \
        timeout 3000   'systemctl suspend'
