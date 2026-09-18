-- Autostart processes for Uthman rice on Omarchy

hl.on("hyprland.start", function()
  -- Stop Omarchy default shell supervisor and instance
  hl.exec_cmd("pkill -TERM -f omarchy-launch-shell 2>/dev/null || true")
  hl.exec_cmd("pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell' 2>/dev/null || true")

  -- Start Uthman Quickshell desktop shell
  hl.exec_cmd("quickshell -p ~/.config/quickshell")

  -- Wallpaper with swaybg
  hl.exec_cmd("swaybg -i ~/.config/theme/current/background -m fill")

  -- Clipboard manager
  hl.exec_cmd("wl-paste --watch cliphist store")
end)
