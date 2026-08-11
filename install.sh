#!/usr/bin/env bash
# Sets up the Ghostty-scoped terminal environment. Idempotent; safe to re-run.
# Legacy setup (iTerm2, ~/.zshrc, oh-my-zsh, p10k) is intentionally untouched.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "backed up: $dst -> $dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "linked: $dst -> $src"
}

brew bundle --file "$DOTFILES/Brewfile"

# --- symlinks ---
link "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
link "$DOTFILES/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"
link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
link "$DOTFILES/nvim" "$HOME/.config/nvim"
link "$DOTFILES/bat/config" "$HOME/.config/bat/config"
link "$DOTFILES/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# bat catppuccin theme (download once, then build cache)
BAT_THEME_DIR="$(bat --config-dir)/themes"
if [ ! -f "$BAT_THEME_DIR/Catppuccin Mocha.tmTheme" ]; then
  mkdir -p "$BAT_THEME_DIR"
  curl -fsSL -o "$BAT_THEME_DIR/Catppuccin Mocha.tmTheme.tmp" \
    "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"
  mv "$BAT_THEME_DIR/Catppuccin Mocha.tmTheme.tmp" "$BAT_THEME_DIR/Catppuccin Mocha.tmTheme"
  bat cache --build
fi

# delta as git pager — the one intentionally global change (revert: git config --global --unset include.path)
if ! git config --global --get-all include.path | grep -q "delta.gitconfig"; then
  git config --global --add include.path "$DOTFILES/git/delta.gitconfig"
fi
