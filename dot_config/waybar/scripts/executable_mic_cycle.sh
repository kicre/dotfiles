#!/bin/bash
# Cycle audio source (microphone) on click

all_sources=($(pactl list sources short | awk '{print $2}'))
current_source=$(pactl get-default-source)
current_index=-1

for i in "${!all_sources[@]}"; do
    if [[ "${all_sources[$i]}" == "$current_source" ]]; then
        current_index=$i
        break
    fi
done

if [[ $current_index -ne -1 ]]; then
    next_index=$(( (current_index + 1) % ${#all_sources[@]} ))
    pactl set-default-source "${all_sources[$next_index]}"
fi