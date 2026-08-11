# Parallel shell config, activated only via ZDOTDIR (see ghostty/config).
# The legacy ~/.zshrc (oh-my-zsh + p10k, used by iTerm2) stays untouched.

# ~/.zshenv is skipped when ZDOTDIR is set; source it if it exists.
[ -f "$HOME/.zshenv" ] && source "$HOME/.zshenv"

eval "$(/opt/homebrew/bin/brew shellenv)"

# --- zinit (plugin manager) ---
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

# completions must be initialized before fzf-tab
fpath=("$HOME/.zsh/completions" $fpath)
autoload -Uz compinit && compinit

# fzf-tab first, syntax highlighting last (both wrap ZLE widgets)
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

# --- history (kept outside the repo) ---
export HISTFILE="$HOME/.local/state/zsh/history"
mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

bindkey -e

# --- env parity with the legacy ~/.zshrc (kept in sync manually) ---
[ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/.pub-cache/bin"
export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
command -v rbenv >/dev/null && eval "$(rbenv init - zsh)"
export JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null)"

# --- tool integrations ---
eval "$(zoxide init zsh)"
source <(fzf --zsh)
eval "$(starship init zsh)"

# --- aliases ---
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias cat='bat'
alias lg='lazygit'
alias jc='just --choose'
