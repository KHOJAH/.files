#!/bin/bash
# quick-controls-probe.sh — fast live state probe for Quick Controls in ControlCenter
# Outputs: <wifi_on>|<wifi_sub>|<bt_on>|<bt_sub>|<nl_on>|<nl_sub>|<dnd_on>|<dnd_sub>|<mic_live>|<mic_sub>

# 1. Wi-Fi
wifi_on="0"
wifi_sub="Off"
if nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    wifi_on="1"
    # check active connection name first (fastest and cleanest)
    ssid=$(nmcli -t -f TYPE,NAME c show --active 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2- | head -n1 | tr '|' '-' | tr -d '\r\n')
    if [ -z "$ssid" ]; then
        ssid=$(nmcli -t -f active,ssid dev wifi list --rescan no 2>/dev/null | sed -n 's/^yes://p' | head -n1 | tr '|' '-' | tr -d '\r\n')
    fi
    if [ -n "$ssid" ]; then
        wifi_sub="$ssid"
    else
        wifi_sub="On"
    fi
fi

# 2. Bluetooth
bt_on="0"
bt_sub="Off"
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    bt_on="1"
    dev=$(bluetoothctl devices Connected 2>/dev/null | cut -d " " -f 3- | head -n1 | tr '|' '-' | tr -d '\r\n')
    if [ -n "$dev" ]; then
        bt_sub="$dev"
    else
        bt_sub="On"
    fi
fi

# 3. Night Light
nl_on="0"
nl_sub="Off"
if pgrep -x hyprsunset >/dev/null 2>&1; then
    nl_on="1"
    temp="4500K"
    if [ -f /tmp/hyprsunset-temp ]; then
        t=$(cat /tmp/hyprsunset-temp 2>/dev/null | tr -d ' \n\rKk')
        [ -n "$t" ] && temp="${t}K"
    fi
    nl_sub="$temp"
fi

# 4. DND
dnd_on="0"
dnd_sub="Normal"
if [ -f /tmp/qs-dnd ]; then
    if [ "$(cat /tmp/qs-dnd 2>/dev/null | tr -d ' \n\r')" = "1" ]; then
        dnd_on="1"
        dnd_sub="Silent"
    fi
else
    # fallback to IPC query
    dnd_val=$(quickshell -p ~/.config/quickshell ipc call notifications isDnd 2>/dev/null | tr -d ' \n\r')
    if [ "$dnd_val" = "true" ]; then
        dnd_on="1"
        dnd_sub="Silent"
    fi
fi

# 5. Mic
mic_live="1"
mic_sub="Live"
if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q "MUTED"; then
    mic_live="0"
    mic_sub="Muted"
fi

# 6. Disk Space (root /)
disk_pct="0"
disk_used="0G"
disk_total="0G"
disk_free="0G"
read -r disk_pct disk_used disk_total disk_free < <(df -B1 / 2>/dev/null | awk 'NR==2 {printf "%d %dG %dG %dG", int(($3/$2)*100 + 0.5), int($3/1073741824 + 0.5), int($2/1073741824 + 0.5), int($4/1073741824 + 0.5)}')

echo "$wifi_on|$wifi_sub|$bt_on|$bt_sub|$nl_on|$nl_sub|$dnd_on|$dnd_sub|$mic_live|$mic_sub|$disk_pct|$disk_used|$disk_total|$disk_free"
