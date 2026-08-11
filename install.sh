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
