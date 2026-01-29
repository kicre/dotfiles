#!/bin/bash
# Cycle audio device on click

all_sinks=($(pactl list sinks short | awk '{print $2}'))
current_sink=$(pactl get-default-sink)
current_index=-1

for i in "${!all_sinks[@]}"; do
    if [[ "${all_sinks[$i]}" == "$current_sink" ]]; then
        current_index=$i
        break
    fi
done

if [[ $current_index -ne -1 ]]; then
    next_index=$(( (current_index + 1) % ${#all_sinks[@]} ))
    pactl set-default-sink "${all_sinks[$next_index]}"
fi