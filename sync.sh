#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  sync.sh — Sync active changes from ~/dotfiles & ~/.config into ~/.files
#  and push them to remote repository
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_SRC="$HOME/dotfiles"
CONFIG_SRC="$HOME/.config"
COMMIT_MSG="${1:-"chore: reflect latest system configuration updates"}"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}-->${RESET} $*"; }
success() { echo -e "${GREEN} ✓ ${RESET} $*"; }
warn()    { echo -e "${YELLOW} ! ${RESET} $*"; }

header()  { echo -e "\n${BOLD}$*${RESET}"; }

header "Syncing changes into $REPO_DIR..."

# 1. Sync from ~/dotfiles if it exists
if [ -d "$DOTFILES_SRC" ]; then
    info "Syncing from $DOTFILES_SRC..."
    rsync -av --delete \
        --exclude='.git' \
        --exclude='README.md' \
        --exclude='install.sh' \
        --exclude='sync.sh' \
        --exclude='hypr/shaders/*' \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='*.bak*' \
        "$DOTFILES_SRC/.config/" "$REPO_DIR/.config/"
    
    rsync -av --delete \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='screentime' \
        --exclude='agy' \
        "$DOTFILES_SRC/.local/bin/" "$REPO_DIR/.local/bin/"

    rsync -av \
        "$DOTFILES_SRC/.local/share/" "$REPO_DIR/.local/share/"

    [ -f "$DOTFILES_SRC/.zshrc" ] && cp "$DOTFILES_SRC/.zshrc" "$REPO_DIR/.zshrc"
    [ -f "$DOTFILES_SRC/.gtkrc-2.0" ] && cp "$DOTFILES_SRC/.gtkrc-2.0" "$REPO_DIR/.gtkrc-2.0"
fi

# 2. Sync active Omarchy Lua configs from ~/.config/hypr/
if [ -d "$CONFIG_SRC/hypr" ]; then
    info "Syncing live Hyprland Lua configs from $CONFIG_SRC/hypr..."
    cp -u "$CONFIG_SRC/hypr/"*.lua "$REPO_DIR/.config/hypr/" 2>/dev/null || true
    [ -f "$CONFIG_SRC/hypr/.luarc.json" ] && cp -u "$CONFIG_SRC/hypr/.luarc.json" "$REPO_DIR/.config/hypr/"
fi

# 3. Ensure wallpapers are real files (dereference any symlinks)
if [ -d "$REPO_DIR/wallpapers" ]; then
    for f in "$REPO_DIR/wallpapers/"*; do
        if [ -L "$f" ]; then
            target="$(readlink -f "$f")"
            if [ -f "$target" ]; then
                rm "$f"
                cp "$target" "$f"
            fi
        fi
    done
fi

# 4. Clean up any accidental broken symlinks
find "$REPO_DIR" -not -path "*/.git/*" -type l -exec test ! -e {} \; -delete 2>/dev/null || true

# 5. Git status check
cd "$REPO_DIR"
if [ -z "$(git status --porcelain)" ]; then
    success "Everything is already up to date. No changes to commit."
    exit 0
fi

header "Changes detected:"
git status --short

# 6. Commit & Push
info "Staging and committing: '$COMMIT_MSG'..."
git add -A
git commit -m "$COMMIT_MSG"

info "Pushing to origin main..."
git push origin main
success "Successfully pushed updates to GitHub!"
