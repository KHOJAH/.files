-- Keybinding overrides for Uthman rice on Omarchy
-- Maps keys to Quickshell modules and Ghostty terminal

-- Unbind defaults that conflict
hl.unbind("SUPER + RETURN")
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + H")
hl.unbind("SUPER + U")
hl.unbind("SUPER + K")
hl.unbind("SUPER + E")
hl.unbind("SUPER + N")
hl.unbind("SUPER + COMMA")
hl.unbind("SUPER + SHIFT + COMMA")
hl.unbind("SUPER + ALT + COMMA")
hl.unbind("SUPER + CTRL + V")
hl.unbind("SUPER + V")
hl.unbind("SUPER + CTRL + SPACE")
hl.unbind("SUPER + ALT + B")
hl.unbind("SUPER + W")
hl.unbind("SUPER + SHIFT + SPACE")
hl.unbind("SUPER + CTRL + B")
hl.unbind("SUPER + CTRL + A")
hl.unbind("SUPER + ALT + SPACE")
hl.unbind("SUPER + ESCAPE")
hl.unbind("XF86PowerOff")
hl.unbind("SUPER + G")
hl.unbind("SUPER + ALT + T")

-- Window management: Close window with SUPER + Z instead of SUPER + W
o.bind("SUPER + Z", "Close window", hl.dsp.window.close())

-- Island Style Toggle (Capsule vs Trapezoid)
o.bind("SUPER + ALT + SPACE", "Toggle island style", "quickshell -p ~/.config/quickshell ipc call bar toggleIsland")

-- Bluetooth & Audio Device Managers
o.bind("SUPER + CTRL + B", "Bluetooth Manager", "uwsm-app -- blueman-manager")
o.bind("SUPER + CTRL + A", "Audio Devices & Volume", "uwsm-app -- pavucontrol")

-- Top bar toggle: hide top bar to give windows full screen
o.bind("SUPER + B", "Toggle top bar (full screen)", "quickshell -p ~/.config/quickshell ipc call bar toggle")
o.bind("SUPER + SHIFT + SPACE", "Toggle top bar (full screen)", "quickshell -p ~/.config/quickshell ipc call bar toggle")

-- Terminal
o.bind("SUPER + RETURN", "Ghostty terminal", "uwsm-app -- ghostty")


-- Quickshell Panels & IPC
o.bind("SUPER + SPACE", "App launcher", "quickshell -p ~/.config/quickshell ipc call launcher toggle")
o.bind("SUPER + H", "WiFi controls", "quickshell -p ~/.config/quickshell ipc call wifi toggle")
o.bind("SUPER + U", "System monitor", "quickshell -p ~/.config/quickshell ipc call sysmon toggle")
o.bind("SUPER + ALT + B", "Battery panel", "quickshell -p ~/.config/quickshell ipc call battery toggle")
o.bind("SUPER + V", "Clipboard manager", "quickshell -p ~/.config/quickshell ipc call clipboard toggle")
o.bind("SUPER + CTRL + V", "Clipboard manager", "quickshell -p ~/.config/quickshell ipc call clipboard toggle")
o.bind("SUPER + K", "Keybindings browser", "quickshell -p ~/.config/quickshell ipc call keybinds toggle")
o.bind("SUPER + E", "Theme switcher", "quickshell -p ~/.config/quickshell ipc call theme toggle")
o.bind("SUPER + N", "System info (fastfetch)", "quickshell -p ~/.config/quickshell ipc call fastfetch toggle")
o.bind("SUPER + COMMA", "Notification center", "quickshell -p ~/.config/quickshell ipc call notifications toggle")
o.bind("SUPER + ALT + COMMA", "Notification center", "quickshell -p ~/.config/quickshell ipc call notifications toggle")
o.bind("SUPER + SHIFT + COMMA", "Toggle Do Not Disturb", "quickshell -p ~/.config/quickshell ipc call notifications toggleDnd")
o.bind("SUPER + ALT + N", "PDF viewer library", "quickshell -p ~/.config/quickshell ipc call pdfviewer toggle")
o.bind("SUPER + CTRL + SPACE", "Wallshelf wallpaper browser", "quickshell -p ~/.config/quickshell ipc call wallshelf toggle")
o.bind("SUPER + ALT + O", "Workspace view", "quickshell -p ~/.config/quickshell ipc call wsview toggle")
o.bind("SUPER + ALT + P", "Control center", "quickshell -p ~/.config/quickshell ipc call controlcenter toggle")
o.bind("SUPER + G", "Activity Dashboard (GitHub & Screen Time)", "quickshell -p ~/.config/quickshell ipc call github toggle")
o.bind("SUPER + ALT + T", "Screen time activity calendar", "quickshell -p ~/.config/quickshell ipc call screentime toggle")
o.bind("SUPER + ALT + V", "Audio visualizer", "quickshell -p ~/.config/quickshell ipc call visualizer toggle")
o.bind("SUPER + ESCAPE", "Power menu", "quickshell -p ~/.config/quickshell ipc call power toggle")
o.bind("XF86PowerOff", "Power menu", "quickshell -p ~/.config/quickshell ipc call power toggle", { locked = true })
