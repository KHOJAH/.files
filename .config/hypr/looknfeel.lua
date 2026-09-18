-- Uthman Rice Look and Feel for Omarchy Hyprland
-- Dynamically themed by Matugen

local function read_colors()
  local colors = {}
  local f = io.open(os.getenv("HOME") .. "/.config/theme/current/colors.conf", "r")
  if f then
    for line in f:lines() do
      local k, v = line:match("%$([%w_]+)%s*=%s*(%S+)")
      if k and v then colors[k] = v end
    end
    f:close()
  end
  return colors
end

local colors = read_colors()
local active_border = colors.primary and { colors = { colors.primary, colors.secondary or colors.primary }, angle = 45 } or "rgba(33ccffee)"
local inactive_border = colors.outline or "rgba(595959aa)"

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 10,
    border_size = 1,
    col = {
      active_border = active_border,
      inactive_border = inactive_border,
    },
    layout = "dwindle",
    resize_on_border = true,
  },

  decoration = {
    rounding = 12,
    rounding_power = 2.4,

    blur = {
      enabled = true,
      size = 7,
      passes = 3,
      new_optimizations = true,
      xray = false,
      ignore_opacity = true,
      popups = true,
    },

    shadow = {
      enabled = true,
      range = 20,
      render_power = 3,
      color = "rgba(00000055)",
      color_inactive = "rgba(00000025)",
    },

    active_opacity = 0.95,
    inactive_opacity = 0.86,
    fullscreen_opacity = 1.0,

    dim_inactive = true,
    dim_strength = 0.08,
  },

  animations = {
    enabled = true,
  },
})

-- Bezier curves
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("smooth", { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.curve("bounce", { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1.0 } } })

-- Animations
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "bounce", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smooth", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "snappy" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "smooth" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 12, bezier = "smooth", style = "once" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "smooth", style = "slidevert" })

-- Window rules for Ghostty transparent blurred glass
o.window("com.mitchellh.ghostty", { tag = "-default-opacity", opacity = "1.0 1.0" })

-- Frosted glass layer rules for Quickshell surfaces
hl.layer_rule({ match = { namespace = "qs-bar" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "qs-launcher" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "qs-passprompt" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "qs-nowplaying" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "qs-pet" }, blur = false, ignore_alpha = 0.01, no_anim = true, xray = 1 })

-- Floating popup tools
o.window({ title = "^Bluetooth Manager$" }, { float = true, center = true, size = { 820, 520 } })
o.window({ class = "^(blueman-manager|org\\.pulseaudio\\.pavucontrol|pavucontrol)$" }, { float = true, center = true, size = { 860, 560 } })
o.window({ class = "^(org\\.quickshell|quickshell)$", title = "^Cava$" }, { float = true, center = true, size = { 420, 160 } })
o.window({ class = "^(org\\.quickshell|quickshell)$", title = "^Control Center$" }, { float = true, center = true, size = { 780, 620 } })
o.window({ class = "^(org\\.quickshell|quickshell)$", title = "^Activity Dashboard$" }, { float = true, center = true, size = { 840, 310 } })


