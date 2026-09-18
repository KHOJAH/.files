#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  .files install.sh — Complete Desktop Environment Installer
#  Arch Linux & Omarchy · Hyprland · Quickshell · Matugen Dynamic Rice
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_CURRENT="$HOME/.config/theme/current"
THEME_SNOW_BLACK="$HOME/.config/theme/themes/snow_black"
NON_INTERACTIVE=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -y|--yes|--non-interactive)
            NON_INTERACTIVE=true
            ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes, --non-interactive  Run without interactive prompts (uses defaults)"
            echo "  -h, --help                    Show this help message"
            exit 0
            ;;
    esac
done

# ── Colors & Logging ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}──>${RESET} $*"; }
success() { echo -e "${GREEN} ✓ ${RESET} $*"; }
warn()    { echo -e "${YELLOW} ! ${RESET} $*"; }
error()   { echo -e "${RED} ✗ ${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${MAGENTA}==>${RESET} ${BOLD}$*${RESET}"; }

ask_confirm() {
    local prompt="$1"
    local default="${2:-y}"
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi
    if [ "$default" = "y" ]; then
        read -rp "  $prompt [Y/n]: " ans
        ans="${ans:-y}"
        [[ "$ans" =~ ^[Yy]$ ]]
    else
        read -rp "  $prompt [y/N]: " ans
        ans="${ans:-n}"
        [[ "$ans" =~ ^[Yy]$ ]]
    fi
}

# ── Environment Detection ─────────────────────────────────────────────────────
header "Detecting environment & distribution..."

IS_OMARCHY=false
if [ -d "/usr/share/omarchy" ] || (grep -qi "omarchy" /etc/os-release 2>/dev/null); then
    IS_OMARCHY=true
    success "Detected Omarchy Linux environment (Dual-support: Lua Hyprland active)"
else
    success "Detected standard Arch Linux environment (Dual-support: .conf Hyprland active)"
fi

# Detect AUR helper
AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
fi

if [ -n "$AUR_HELPER" ]; then
    success "Found AUR helper: $AUR_HELPER"
else
    warn "No AUR helper (yay or paru) found. Pacman will be used for official packages."
fi

# ── Step 1: Dependencies ──────────────────────────────────────────────────────
header "Checking dependencies..."

CORE_PACKAGES=(
    hyprland
    quickshell
    ghostty
    matugen
    starship
    zsh
    lsd
    zoxide
    fzf
    cava
    btop
    stow
    hyprlock
    hypridle
    hyprsunset
    wl-clipboard
    cliphist
    swaync
    mako
    walker
    rofi
    swayosd
    swaybg
    sddm
    xdg-desktop-portal-hyprland
    uwsm
    jq
    socat
    github-cli
    inter-font
)
PACKAGES=("${CORE_PACKAGES[@]}")

MISSING_PACKAGES=()

for pkg in "${CORE_PACKAGES[@]}"; do
    cmd_check="$pkg"
    case "$pkg" in
        "wl-clipboard") cmd_check="wl-copy" ;;
        "github-cli") cmd_check="gh" ;;
        "inter-font")
            if fc-list | grep -qi " inter"; then
                success "Found font: inter-font"
                continue
            fi
            cmd_check=""
            ;;
        "xdg-desktop-portal-hyprland")
            if [ -f "/usr/lib/xdg-desktop-portal-hyprland" ]; then
                success "Found: xdg-desktop-portal-hyprland"
                continue
            fi
            cmd_check=""
            ;;
    esac

    if [ -n "$cmd_check" ] && command -v "$cmd_check" &>/dev/null; then
        success "Found: $pkg"
    else
        MISSING_PACKAGES+=("$pkg")
        warn "Missing: $pkg"
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo ""
    warn "Missing ${#MISSING_PACKAGES[@]} package(s): ${MISSING_PACKAGES[*]}"
    if [ -n "$AUR_HELPER" ]; then
        if ask_confirm "Automatically install missing packages using $AUR_HELPER?" "y"; then
            info "Running: $AUR_HELPER -S --needed ${MISSING_PACKAGES[*]}"
            $AUR_HELPER -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || warn "Some packages could not be installed automatically. You may install them manually."
        fi
    elif command -v pacman &>/dev/null; then
        if ask_confirm "Attempt to install available packages using sudo pacman?" "y"; then
            sudo pacman -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || warn "Pacman completed with warnings (some packages may be in AUR)."
        fi
    fi
else
    success "All core dependencies are satisfied!"
fi

# ── Step 2: Theme directories & fallback colors ───────────────────────────────
header "Setting up theme directories and fallback colors..."

mkdir -p "$THEME_CURRENT"
mkdir -p "$THEME_SNOW_BLACK"
mkdir -p "$HOME/.config/theme/themes"
success "Theme directories created in $HOME/.config/theme"

FALLBACK_DIR="$DOTFILES_DIR/theme-fallback"
if [ -d "$FALLBACK_DIR" ]; then
    cp -r "$FALLBACK_DIR"/. "$THEME_CURRENT/"
    cp -r "$FALLBACK_DIR"/. "$THEME_SNOW_BLACK/"
    success "Seeded fallback colors from theme-fallback to $THEME_CURRENT"
fi

# Clear old absolute theme symlinks so stow doesn't abort
rm -f "$HOME/.config/btop/themes/current.theme" "$HOME/.config/cava/themes/matugen"

# ── Step 3: Backup & Stow Dotfiles ────────────────────────────────────────────
header "Stowing configurations into \$HOME..."

BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
CONFLICTS=()

# Detect non-symlink conflicting files
while IFS= read -r -d '' f; do
    rel="${f#$DOTFILES_DIR/}"
    target="$HOME/$rel"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        CONFLICTS+=("$target")
    fi
done < <(find "$DOTFILES_DIR" \
    -not -path "$DOTFILES_DIR/.git/*" \
    -not -name '.git' \
    -not -name 'README.md' \
    -not -name 'install.sh' \
    -not -path "$DOTFILES_DIR/assets/*" \
    -not -path "$DOTFILES_DIR/sddm/*" \
    -not -path "$DOTFILES_DIR/firefox/*" \
    -not -path "$DOTFILES_DIR/theme-fallback/*" \
    -not -path "$DOTFILES_DIR/wallpapers/*" \
    -not -path "$DOTFILES_DIR/panel/*" \
    -type f -print0)

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    mkdir -p "$BACKUP_DIR"
    warn "Backing up ${#CONFLICTS[@]} existing configuration file(s) to $BACKUP_DIR"
    for f in "${CONFLICTS[@]}"; do
        rel="${f#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$f" "$BACKUP_DIR/$rel"
        info "  Backed up: $f"
    done
    success "Backup saved to $BACKUP_DIR"
fi

# Run Stow or manual symlink fallback
if command -v stow &>/dev/null; then
    stow --dir="$DOTFILES_DIR" --target="$HOME" --restow .
    success "GNU Stow linked all dotfiles to $HOME"
else
    warn "GNU Stow not found; using fallback symlink installer..."
    find "$DOTFILES_DIR/.config" -mindepth 1 -maxdepth 1 | while read -r item; do
        ln -sfn "$item" "$HOME/.config/$(basename "$item")"
    done
    mkdir -p "$HOME/.local/bin"
    find "$DOTFILES_DIR/.local/bin" -mindepth 1 -maxdepth 1 | while read -r item; do
        ln -sfn "$item" "$HOME/.local/bin/$(basename "$item")"
    done
    ln -sfn "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    ln -sfn "$DOTFILES_DIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"
    success "Fallback symlinks created successfully"
fi

# ── Step 4: Environment-Specific Hyprland Setup ───────────────────────────────
header "Configuring Hyprland (Omarchy / Arch dual support)..."

if [ "$IS_OMARCHY" = true ]; then
    info "Omarchy mode: Ensuring Lua Hyprland configs are active..."
    # Ensure Lua bootstrap files exist in ~/.config/hypr
    for luafile in hyprland.lua bindings.lua monitors.lua looknfeel.lua autostart.lua input.lua; do
        if [ -f "$DOTFILES_DIR/.config/hypr/$luafile" ]; then
            ln -sfn "$DOTFILES_DIR/.config/hypr/$luafile" "$HOME/.config/hypr/$luafile"
        fi
    done
    success "Omarchy Lua configurations wired in ~/.config/hypr"
else
    info "Standard Arch mode: Ensuring Hyprland .conf setup is primary..."
    # On non-Omarchy, hyprland.conf is standard
    if [ -f "$DOTFILES_DIR/.config/hypr/hyprland.conf" ]; then
        ln -sfn "$DOTFILES_DIR/.config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
    fi
    success "Standard Hyprland configuration wired in ~/.config/hypr"
fi

# ── Step 5: Post-Stow Integration Symlinks ────────────────────────────────────
header "Creating theme integration links..."

# btop
mkdir -p "$HOME/.config/btop/themes"
ln -sf "$HOME/.config/theme/current/btop.theme" "$HOME/.config/btop/themes/current.theme"
success "btop theme -> ~/.config/theme/current/btop.theme"

# cava
mkdir -p "$HOME/.config/cava/themes"
ln -sf "$HOME/.config/theme/current/cava_theme" "$HOME/.config/cava/themes/matugen"
success "cava theme -> ~/.config/theme/current/cava_theme"

# ── Step 6: System Extras (Fonts & SDDM theme) ────────────────────────────────
header "Installing system components (requires sudo)..."

if ask_confirm "Install system-level fonts and SDDM theme?" "y"; then
    # Fonts: Inter + vendored Iceland font
    sudo mkdir -p /usr/share/fonts/TTF
    if [ -f "$DOTFILES_DIR/assets/fonts/Iceland-Regular.ttf" ]; then
        sudo cp "$DOTFILES_DIR/assets/fonts/Iceland-Regular.ttf" /usr/share/fonts/TTF/
        sudo fc-cache -f >/dev/null 2>&1 || true
        success "Vendored Iceland font installed to /usr/share/fonts/TTF"
    fi

    # SDDM Theme: elarun-custom
    if [ -d "$DOTFILES_DIR/sddm/elarun-custom" ]; then
        sudo mkdir -p /usr/share/sddm/themes
        sudo cp -r "$DOTFILES_DIR/sddm/elarun-custom" /usr/share/sddm/themes/
        sudo chown -R root:root /usr/share/sddm/themes/elarun-custom 2>/dev/null || true
        success "Installed SDDM theme: elarun-custom"
        
        sudo mkdir -p /etc/sddm.conf.d
        printf '[Theme]\nCurrent=elarun-custom\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
        success "Configured SDDM to use elarun-custom (/etc/sddm.conf.d/10-theme.conf)"
    fi
else
    info "Skipped system font & SDDM installation."
fi

# Fastfetch hollow knight artwork
mkdir -p "$HOME/fastfetchImages"
if [ -f "$DOTFILES_DIR/assets/fastfetch/The_Knight__Hollow_Knight_-removebg-preview.png" ]; then
    cp "$DOTFILES_DIR/assets/fastfetch/The_Knight__Hollow_Knight_-removebg-preview.png" "$HOME/fastfetchImages/"
    success "Installed fastfetch artwork to ~/fastfetchImages/"
fi

# Firefox userChrome / userContent theming
header "Checking Firefox profiles for dynamic theming..."
for ffdir in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    if [ -d "$ffdir" ]; then
        for prof in "$ffdir"/*.default-release "$ffdir"/*.default*; do
            if [ -d "$prof" ]; then
                mkdir -p "$prof/chrome"
                ln -sf "$HOME/.config/theme/current/firefox.css" "$prof/chrome/userChrome.css"
                ln -sf "$HOME/.config/theme/current/firefox-usercontent.css" "$prof/chrome/userContent.css"
                if [ -f "$DOTFILES_DIR/firefox/user.js" ]; then
                    ln -sf "$DOTFILES_DIR/firefox/user.js" "$prof/user.js"
                fi
                success "Wired Firefox profile: $(basename "$prof")"
            fi
        done
    fi
done

# ── Step 7: Matugen Dynamic Wallpaper Theming ─────────────────────────────────
header "Dynamic Wallpaper Theming (Matugen)..."

WALLPAPER_TO_APPLY=""
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    FIRST_WALL="$(find "$DOTFILES_DIR/wallpapers" -type f \( -name '*.png' -o -name '*.jpg' \) | head -n 1)"
    WALLPAPER_TO_APPLY="$FIRST_WALL"
fi

if ask_confirm "Generate and apply initial theme from wallpaper now?" "y"; then
    if [ -n "$WALLPAPER_TO_APPLY" ] && [ -f "$WALLPAPER_TO_APPLY" ]; then
        info "Applying wallpaper: $(basename "$WALLPAPER_TO_APPLY")"
        mkdir -p "$THEME_CURRENT"
        ln -sfn "$WALLPAPER_TO_APPLY" "$THEME_CURRENT/background" 2>/dev/null || true
        
        if command -v matugen &>/dev/null; then
            if [ -x "$DOTFILES_DIR/.local/bin/getTheme" ]; then
                bash "$DOTFILES_DIR/.local/bin/getTheme" "$WALLPAPER_TO_APPLY" || matugen image "$WALLPAPER_TO_APPLY" --mode dark --type scheme-fidelity --contrast 0.2
            else
                matugen image "$WALLPAPER_TO_APPLY" --mode dark --type scheme-fidelity --contrast 0.2 || matugen image "$WALLPAPER_TO_APPLY"
            fi
            success "Matugen generated live palette across all applications!"
        else
            warn "Matugen binary not found in PATH; fallback colors are active."
            info "Install matugen and run: matugen image <path-to-wallpaper>"
        fi
    fi
else
    info "Skipped wallpaper generation. You can run 'matugen image <wallpaper>' anytime."
fi

# ── Completion ────────────────────────────────────────────────────────────────
header "Installation complete!"
echo -e "${GREEN}${BOLD}  Your Desktop Environment is ready!${RESET}"
echo ""
echo -e "  Quick tips:"
echo -e "    ${CYAN}• Reload Hyprland:${RESET}      hyprctl reload  (or log out / log back in)"
echo -e "    ${CYAN}• Change Wallpaper:${RESET}     ~/.local/bin/set-wallpaper <image>  or  matugen image <image>"
echo -e "    ${CYAN}• Quickshell Keybinds:${RESET}  SUPER + SPACE (Launcher), SUPER + G (Activity Dashboard), SUPER + ALT + P (Control Center)"
echo -e "    ${CYAN}• App Keybinds:${RESET}         SUPER + RETURN (Ghostty), SUPER + Z (Close Window)"
echo -e "    ${CYAN}• Theming Palette:${RESET}      ~/.config/theme/current/"
echo ""
