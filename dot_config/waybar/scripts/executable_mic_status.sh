#!/bin/bash
# Waybar microphone control script
# Shows current microphone with volume and mute status

get_current_source() {
    pactl get-default-source
}

get_source_short_name() {
    local source_name="$1"
    local description=$(pactl list sources | grep -A 20 "Name: $source_name" | grep "Description:" | sed 's/.*Description: //')
    echo "$description"
}

get_source_type() {
    local source_name="$1"
    local description=$(pactl list sources | grep -A 20 "Name: $source_name" | grep "Description:" | sed 's/.*Description: //')
    
    case "$description" in
        *"Headset"*) echo "Headset" ;;
        *"Headphones"*) echo "Headphones" ;;
        *"Webcam"*|*"Camera"*) echo "Webcam" ;;
        *"USB"*|*"USB Audio"*) echo "USB Mic" ;;
        *"Built-in"*|*"内置"*) echo "Built-in" ;;
        *"Blue"*) echo "Bluetooth" ;;
        *"External"*) echo "External" ;;
        *".monitor"*) echo "Monitor" ;;
        *) echo "Other" ;;
    esac
}

get_source_info() {
    local source_name="$1"
    local volume=$(pactl get-source-volume "$source_name" | grep -o '[0-9]*%' | head -1)
    local is_muted=$(pactl get-source-mute "$source_name" | grep -o 'yes\|no')
    
    if [[ "$is_muted" == "yes" ]]; then
        echo "Muted"
    else
        echo "$volume"
    fi
}

# Toggle mute if requested
if [[ "$1" == "--toggle" ]]; then
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    exit 0
fi

# Output for waybar
current_source=$(get_current_source)
current_volume=$(get_source_info "$current_source")
source_name=$(get_source_short_name "$current_source")
source_type=$(get_source_type "$current_source")

if [[ "$current_volume" == "Muted" ]]; then
    echo "{\"text\": \"󰍭\", \"tooltip\": \"Microphone: $source_name\\nType: $source_type\\nStatus: Muted\\nClick: toggle mute\\nRight-click: cycle device\\nScroll: volume\"}"
else
    echo "{\"text\": \"󰍬$current_volume\", \"tooltip\": \"Microphone: $source_name\\nType: $source_type\\nVolume: $current_volume\\nClick: toggle mute\\nRight-click: cycle device\\nScroll: volume\"}"
fi
