# Terminal Setup Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a parallel, Ghostty-scoped modern terminal setup (zinit/starship zsh, CLI tool belt, LazyVim, lazygit/diffview, justfile task running) versioned in `~/Code/dotfiles`, without touching the existing iTerm2 + oh-my-zsh + p10k setup.

**Architecture:** All new shell config lives in `~/.config/zsh/` and is only activated by Ghostty launching zsh with `ZDOTDIR` pointed there; iTerm2 keeps reading the legacy `~/.zshrc`. All config files live in the dotfiles repo and are symlinked into place by an idempotent `install.sh`. Neovim uses the LazyVim distro with a small set of additional plugin spec files.

**Tech Stack:** Ghostty, zsh + zinit + starship, fzf/zoxide/eza/bat/ripgrep/fd, Neovim + LazyVim (flutter-tools, diffview, overseer), just, lazygit, git-delta. Theme everywhere: Catppuccin Mocha.

**Spec:** `docs/superpowers/specs/2026-08-11-terminal-setup-design.md`

## Global Constraints

- **Never modify:** `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh`, `~/.oh-my-zsh/`, iTerm2 settings, or the legacy `macos/` scripts in this repo. The only globally visible change allowed is the git-delta pager config (spec §Error handling).
- **Machine paths:** Home is `/Users/marcel`; repo is `/Users/marcel/Code/dotfiles`; Homebrew prefix is `/opt/homebrew`.
- **Idempotency:** `install.sh` must be safe to re-run; symlinking must back up an existing non-symlink target to `<target>.bak` before linking.
- **Theme:** Catppuccin Mocha in Ghostty, starship, Neovim, bat, lazygit.
- **Pre-existing dirty files:** `README.md` and `macos/apps.sh` have uncommitted user changes and `.DS_Store` is untracked. Never `git add -A`; always stage explicit paths.
- **Verification instead of unit tests:** this is config, not application code — every task ends with concrete verification commands whose expected output is stated.
- **Do not push** to origin; the user pushes when they're ready.

---

### Task 1: `install.sh` — packages and symlink helper

**Files:**
- Create: `install.sh`

**Interfaces:**
- Produces: `link <absolute-src> <absolute-dst>` bash function; `$DOTFILES` variable (repo root). Later tasks append `link` lines to the `# --- symlinks ---` section.

- [ ] **Step 1: Write `install.sh`**

```bash
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

FORMULAE=(fzf zoxide eza bat ripgrep fd just lazygit git-delta starship)
CASKS=(ghostty font-jetbrains-mono-nerd-font)

for f in "${FORMULAE[@]}"; do
  brew list --formula "$f" &>/dev/null || brew install "$f"
done
for c in "${CASKS[@]}"; do
  brew list --cask "$c" &>/dev/null || brew install --cask "$c"
done

# --- symlinks ---
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x /Users/marcel/Code/dotfiles/install.sh && /Users/marcel/Code/dotfiles/install.sh`
Expected: brew installs the formulae/casks (several minutes on first run); exit code 0.

- [ ] **Step 3: Verify idempotency and installs**

Run: `/Users/marcel/Code/dotfiles/install.sh && which fzf zoxide eza bat fd just lazygit delta starship && ls /Applications/Ghostty.app >/dev/null && echo APP-OK`
Expected: second run produces no `brew install` output; all `which` lines print `/opt/homebrew/bin/...`; final line `APP-OK`.

Note: `rg` may resolve to a Claude Code shell shim in this session — verify the real binary with `ls /opt/homebrew/bin/rg` instead of `which rg`.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add install.sh
git commit -m "feat: install script with brew packages and symlink helper"
```

---

### Task 2: Ghostty config

**Files:**
- Create: `ghostty/config`
- Modify: `install.sh` (append to `# --- symlinks ---` section)

**Interfaces:**
- Consumes: `link` from Task 1.
- Produces: Ghostty launches zsh with `ZDOTDIR=/Users/marcel/.config/zsh` — Task 3 places the `.zshrc` there.

- [ ] **Step 1: Confirm the exact theme name**

Run: `ghostty +list-themes 2>/dev/null | grep -i "catppuccin" || /Applications/Ghostty.app/Contents/MacOS/ghostty +list-themes | grep -i catppuccin`
Expected: a line containing a Mocha variant, e.g. `catppuccin-mocha`. If the listed name differs (e.g. `Catppuccin Mocha`), use the listed spelling in Step 2.

- [ ] **Step 2: Write `ghostty/config`**

```
# Ghostty is the only entry point to the new setup: it launches zsh with
# ZDOTDIR pointing at the parallel config. iTerm2 keeps using ~/.zshrc.
command = /usr/bin/env ZDOTDIR=/Users/marcel/.config/zsh /bin/zsh --login

theme = catppuccin-mocha
font-family = JetBrainsMono Nerd Font
font-size = 13
```

- [ ] **Step 3: Add the symlink to `install.sh`**

Append after the `# --- symlinks ---` line:

```bash
link "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
```

- [ ] **Step 4: Run and verify**

Run: `/Users/marcel/Code/dotfiles/install.sh && readlink ~/.config/ghostty/config`
Expected: prints `/Users/marcel/Code/dotfiles/ghostty/config`.

Manual check: open Ghostty (Cmd-Space → Ghostty). It should show the Catppuccin Mocha colors with JetBrains Mono. The shell will be a bare zsh prompt (`ZDOTDIR` dir doesn't exist yet — that's expected until Task 3; zsh falls back to defaults, which is harmless).

- [ ] **Step 5: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add ghostty/config install.sh
git commit -m "feat: ghostty config with catppuccin theme and ZDOTDIR launch command"
```

---

### Task 3: Parallel zsh config (zinit, plugins, tools) + starship prompt

**Files:**
- Create: `zsh/.zshrc`
- Create: `starship/starship.toml`
- Modify: `install.sh` (append symlinks)

**Interfaces:**
- Consumes: `link` from Task 1; CLI tools installed in Task 1.
- Produces: working interactive shell for Ghostty; aliases `ls/ll/la/cat/lg/jc`.

- [ ] **Step 1: Write `zsh/.zshrc`**

```zsh
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
```

- [ ] **Step 2: Write `starship/starship.toml`**

```toml
palette = "catppuccin_mocha"

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"

[directory]
style = "bold lavender"
truncation_length = 4

[git_branch]
style = "mauve"

[git_status]
style = "peach"

[cmd_duration]
min_time = 2000
style = "yellow"

[palettes.catppuccin_mocha]
rosewater = "#f5e0dc"
flamingo = "#f2cdcd"
pink = "#f5c2e7"
mauve = "#cba6f7"
red = "#f38ba8"
maroon = "#eba0ac"
peach = "#fab387"
yellow = "#f9e2af"
green = "#a6e3a1"
teal = "#94e2d5"
sky = "#89dceb"
sapphire = "#74c7ec"
blue = "#89b4fa"
lavender = "#b4befe"
text = "#cdd6f4"
subtext1 = "#bac2de"
subtext0 = "#a6adc8"
overlay2 = "#9399b2"
overlay1 = "#7f849c"
overlay0 = "#6c7086"
surface2 = "#585b70"
surface1 = "#45475a"
surface0 = "#313244"
base = "#1e1e2e"
mantle = "#181825"
crust = "#11111b"
```

- [ ] **Step 3: Add symlinks to `install.sh`**

Append after the ghostty `link` line:

```bash
link "$DOTFILES/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"
link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
```

- [ ] **Step 4: Run install and verify the shell non-interactively**

Run: `/Users/marcel/Code/dotfiles/install.sh && ZDOTDIR="$HOME/.config/zsh" /bin/zsh -ic 'echo SHELL-OK; whence -p fzf zoxide starship eza bat; alias ls cat' 2>&1 | tail -10`
Expected: first invocation clones zinit and installs the three plugins (git output), then prints `SHELL-OK`, `/opt/homebrew/bin/...` paths for all five tools, and the `ls`/`cat` aliases. Exit code 0. Warnings from starship about non-tty output are acceptable.

- [ ] **Step 5: Verify legacy shell is untouched**

Run: `/bin/zsh -ic 'echo $ZSH_THEME; typeset -f _zsh_autosuggest_start >/dev/null && echo NEW-LEAKED || echo LEGACY-CLEAN' 2>/dev/null | tail -2`
Expected: `robbyrussell` is NOT printed (p10k overrides it late, so ignore that line if empty) and the last line is `LEGACY-CLEAN` — the new plugins must not load without `ZDOTDIR`.

Manual check: open a new Ghostty window → starship prompt with Catppuccin colors; type a previously-run command prefix → grey autosuggestion appears; `Ctrl-R` → fzf history search; `z dotfiles` after one `cd ~/Code/dotfiles` → jumps there. Open iTerm2 → unchanged p10k prompt.

- [ ] **Step 6: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add zsh/.zshrc starship/starship.toml install.sh
git commit -m "feat: parallel zsh config with zinit plugins and starship prompt"
```

---

### Task 4: Neovim — LazyVim base with Catppuccin and TypeScript

**Files:**
- Create: `nvim/` (LazyVim starter template)
- Create: `nvim/lua/plugins/colorscheme.lua`
- Modify: `nvim/lua/config/lazy.lua` (add TypeScript extra)
- Modify: `install.sh` (append symlink)

**Interfaces:**
- Consumes: `link` from Task 1; neovim, tree-sitter (already brew-installed).
- Produces: `~/.config/nvim` → repo `nvim/`; LazyVim running. Tasks 5–7 add files under `nvim/lua/plugins/`.

- [ ] **Step 1: Vendor the LazyVim starter into the repo**

```bash
git clone https://github.com/LazyVim/starter /Users/marcel/Code/dotfiles/nvim
rm -rf /Users/marcel/Code/dotfiles/nvim/.git
```

- [ ] **Step 2: Add the TypeScript language extra**

In `nvim/lua/config/lazy.lua`, find the `spec = {` block containing the line `{ "LazyVim/LazyVim", import = "lazyvim.plugins" },` and insert directly below it:

```lua
    { import = "lazyvim.plugins.extras.lang.typescript" },
```

- [ ] **Step 3: Create `nvim/lua/plugins/colorscheme.lua`**

```lua
return {
  { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "mocha" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
```

- [ ] **Step 4: Add the symlink to `install.sh`**

Append after the starship `link` line:

```bash
link "$DOTFILES/nvim" "$HOME/.config/nvim"
```

Note: this is a directory symlink — Neovim will write `lazy-lock.json` into the repo, which is desirable (versioned plugin lockfile).

- [ ] **Step 5: Run install and sync plugins headlessly**

Run: `/Users/marcel/Code/dotfiles/install.sh && nvim --headless "+Lazy! sync" +qa && echo NVIM-OK`
Expected: plugin clone/build output, then `NVIM-OK`, exit 0. First run takes a few minutes (plugins, tree-sitter parsers, Mason installs LSP servers on first real file open).

- [ ] **Step 6: Verify colorscheme and TypeScript LSP wiring**

Run: `nvim --headless "+lua vim.defer_fn(function() print('colors='..(vim.g.colors_name or 'none')) vim.cmd('qa') end, 3000)"`
Expected: `colors=catppuccin` (or `catppuccin-mocha`).

Manual check: `cd` into any TypeScript project, `nvim <some>.ts` — after Mason finishes installing (status line shows progress), `gd` (go to definition) and `K` (hover) work; `<leader><space>` opens the file picker; `<leader>/` live-greps the project.

- [ ] **Step 7: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add nvim install.sh
git commit -m "feat: LazyVim config with catppuccin and typescript extra"
```

---

### Task 5: Neovim — Flutter/Dart via flutter-tools.nvim

**Files:**
- Create: `nvim/lua/plugins/flutter.lua`

**Interfaces:**
- Consumes: LazyVim setup from Task 4; flutter SDK (already installed as brew cask, provides `dart` LSP).
- Produces: Dart LSP + `:FlutterRun`, `:FlutterReload` etc. in dart files.

- [ ] **Step 1: Create `nvim/lua/plugins/flutter.lua`**

```lua
return {
  "nvim-flutter/flutter-tools.nvim",
  ft = "dart",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {},
}
```

- [ ] **Step 2: Sync and verify plugin installs**

Run: `nvim --headless "+Lazy! sync" +qa && ls ~/.local/share/nvim/lazy/ | grep flutter-tools`
Expected: `flutter-tools.nvim` listed, exit 0.

- [ ] **Step 3: Verify against a real Dart file**

Run: `cd /Users/marcel/Code && ls */pubspec.yaml 2>/dev/null | head -3` to find a Flutter project (e.g. strik-duel).
Manual check: open a `.dart` file from that project in nvim; wait for the Dart LSP to attach (`:LspInfo` shows `dartls` attached); `gd`/`K`/`<leader>ca` work; `:FlutterDevices` lists devices.

If no Flutter project is available, minimum verification: `nvim --headless "+e /tmp/t.dart" "+lua vim.defer_fn(function() print('clients='..#vim.lsp.get_clients()) vim.cmd('qa') end, 8000)"` — expected `clients=` ≥ 1.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add nvim/lua/plugins/flutter.lua nvim/lazy-lock.json
git commit -m "feat: flutter-tools for dart lsp and flutter commands"
```

---

### Task 6: Neovim — diffs in workspace context (diffview.nvim)

**Files:**
- Create: `nvim/lua/plugins/diffview.lua`

**Interfaces:**
- Consumes: LazyVim setup from Task 4 (gitsigns already ships with LazyVim — no task needed for it).
- Produces: `:DiffviewOpen [rev]`, `:DiffviewFileHistory`; keymaps `<leader>gd`, `<leader>gH`.

- [ ] **Step 1: Create `nvim/lua/plugins/diffview.lua`**

```lua
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working tree)" },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current file)" },
  },
}
```

- [ ] **Step 2: Sync and verify**

Run: `nvim --headless "+Lazy! sync" +qa && ls ~/.local/share/nvim/lazy/ | grep diffview`
Expected: `diffview.nvim` listed, exit 0.

Manual check (this repo has uncommitted changes, perfect test bed): `cd ~/Code/dotfiles && nvim`, then `:DiffviewOpen` — side-by-side diff of `README.md`/`macos/apps.sh` with a file tree panel; `:DiffviewOpen origin/main` diffs against the remote branch; `:DiffviewClose` exits.

- [ ] **Step 3: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add nvim/lua/plugins/diffview.lua nvim/lazy-lock.json
git commit -m "feat: diffview for branch and history diffs"
```

---

### Task 7: Run configurations — just + overseer.nvim

**Files:**
- Create: `nvim/lua/plugins/overseer.lua`
- Create: `just/flutter.justfile`

**Interfaces:**
- Consumes: `just` binary (Task 1), LazyVim (Task 4); `jc` alias already defined in Task 3's zshrc.
- Produces: `:OverseerRun` task picker (auto-discovers a project's `justfile`), `:OverseerToggle` task panel; a reusable Flutter justfile template.

- [ ] **Step 1: Create `nvim/lua/plugins/overseer.lua`**

```lua
return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerToggle", "OverseerInfo" },
  keys = {
    { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
    { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Task panel" },
  },
  opts = {},
}
```

- [ ] **Step 2: Create `just/flutter.justfile`**

```just
# Template: copy to <flutter-project>/justfile and adapt.
# Discovery: `just --list`, `jc` (fzf chooser), or :OverseerRun in Neovim.

default:
    @just --list

run:
    flutter run

test:
    flutter test

analyze:
    flutter analyze

format:
    dart format lib test

build-ios:
    flutter build ios

clean:
    flutter clean
```

- [ ] **Step 3: Sync and verify the template parses**

Run: `nvim --headless "+Lazy! sync" +qa && just --justfile /Users/marcel/Code/dotfiles/just/flutter.justfile --list`
Expected: exit 0; the list shows `run`, `test`, `analyze`, `format`, `build-ios`, `clean`.

- [ ] **Step 4: Verify overseer discovers justfile tasks**

```bash
mkdir -p /private/tmp/claude-501/-Users-marcel-Code/9773339c-a114-48de-9d24-648e75bd7987/scratchpad/just-test
printf 'hello:\n    @echo overseer-works\n' > /private/tmp/claude-501/-Users-marcel-Code/9773339c-a114-48de-9d24-648e75bd7987/scratchpad/just-test/justfile
```

Manual check: `cd` into that dir, open `nvim`, run `:OverseerRun` — the picker lists `just hello`; select it, then `:OverseerToggle` shows the finished task with output `overseer-works`. (Headless fallback: `cd <dir> && nvim --headless "+lua require('overseer'); vim.defer_fn(function() require('overseer').run_template({name='just hello'}, function(t) print(t and 'TASK-OK' or 'TASK-MISSING') vim.defer_fn(function() vim.cmd('qa') end, 2000) end) end, 2000)"` — expected `TASK-OK`.)

- [ ] **Step 5: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add nvim/lua/plugins/overseer.lua nvim/lazy-lock.json just/flutter.justfile
git commit -m "feat: overseer task runner and flutter justfile template"
```

---

### Task 8: Git viewing polish — delta pager, lazygit + bat themes

**Files:**
- Create: `git/delta.gitconfig`
- Create: `lazygit/config.yml`
- Create: `bat/config`
- Modify: `install.sh` (append symlinks, bat theme download, git include)

**Interfaces:**
- Consumes: `link` from Task 1; delta/lazygit/bat binaries (Task 1).
- Produces: `git diff` rendered by delta everywhere (the one intentionally global change); themed lazygit and bat.

- [ ] **Step 1: Create `git/delta.gitconfig`**

```gitconfig
[core]
	pager = delta
[interactive]
	diffFilter = delta --color-only
[delta]
	navigate = true
	line-numbers = true
	dark = true
```

- [ ] **Step 2: Create `lazygit/config.yml`** (Catppuccin Mocha, from catppuccin/lazygit)

```yaml
gui:
  theme:
    activeBorderColor:
      - "#cba6f7"
      - bold
    inactiveBorderColor:
      - "#a6adc8"
    optionsTextColor:
      - "#89b4fa"
    selectedLineBgColor:
      - "#313244"
    cherryPickedCommitBgColor:
      - "#45475a"
    cherryPickedCommitFgColor:
      - "#cba6f7"
    unstagedChangesColor:
      - "#f38ba8"
    defaultFgColor:
      - "#cdd6f4"
    searchingActiveBorderColor:
      - "#f9e2af"
  authorColors:
    "*": "#b4befe"
```

- [ ] **Step 3: Create `bat/config`**

```
--theme="Catppuccin Mocha"
```

- [ ] **Step 4: Extend `install.sh`**

Append after the nvim `link` line:

```bash
link "$DOTFILES/bat/config" "$HOME/.config/bat/config"
link "$DOTFILES/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# bat catppuccin theme (download once, then build cache)
BAT_THEME_DIR="$(bat --config-dir)/themes"
if [ ! -f "$BAT_THEME_DIR/Catppuccin Mocha.tmTheme" ]; then
  mkdir -p "$BAT_THEME_DIR"
  curl -fsSL -o "$BAT_THEME_DIR/Catppuccin Mocha.tmTheme" \
    "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"
  bat cache --build
fi

# delta as git pager — the one intentionally global change (revert: git config --global --unset include.path)
if ! git config --global --get-all include.path | grep -q "delta.gitconfig"; then
  git config --global include.path "$DOTFILES/git/delta.gitconfig"
fi
```

- [ ] **Step 5: Run and verify**

Run: `/Users/marcel/Code/dotfiles/install.sh && bat --list-themes | grep "Catppuccin Mocha" && cd /Users/marcel/Code/dotfiles && git diff macos/apps.sh | head -5 && git config --global --get include.path`
Expected: theme listed; `git diff` output shows delta's styled rendering (file header box, line numbers); include path printed. Then re-run `install.sh` once more — expected: no new output from the bat/git sections (idempotent).

Manual check: `lg` in Ghostty inside this repo → lazygit opens with mauve/catppuccin borders, shows the two modified files.

- [ ] **Step 6: Commit**

```bash
cd /Users/marcel/Code/dotfiles
git add git/delta.gitconfig lazygit/config.yml bat/config install.sh
git commit -m "feat: delta pager, catppuccin lazygit and bat themes"
```

---

### Task 9: End-to-end verification against spec success criteria

**Files:** none (verification only; fix-forward and commit if anything fails).

- [ ] **Step 1: Parallel-setup criterion** — Open Ghostty: starship prompt, autosuggestions, `Ctrl-R` fzf history, `z <dir>` jumping. Open iTerm2: unchanged p10k prompt. Both true → PASS.

- [ ] **Step 2: Neovim navigation criterion** — In a Flutter project: `nvim .`, fuzzy-open a file (`<leader><space>`), `gd` on a symbol, `<leader>/` live-grep, hover with `K`. All work → PASS.

- [ ] **Step 3: Diff criterion** — In a repo with a branch: `:DiffviewOpen main` (or `origin/main`) shows side-by-side diffs with file tree → PASS.

- [ ] **Step 4: Task-runner criterion** — Copy `just/flutter.justfile` to a Flutter project as `justfile`; `just --list` and `jc` work in Ghostty; `:OverseerRun` lists and runs the tasks in Neovim → PASS.

- [ ] **Step 5: Idempotency criterion** — `/Users/marcel/Code/dotfiles/install.sh` full re-run: only "linked:" lines, no installs, exit 0 → PASS.

- [ ] **Step 6: Startup-speed criterion** — In Ghostty: `for i in 1 2 3; do /usr/bin/time /bin/zsh -ic exit; done` with `ZDOTDIR` set (i.e. run inside Ghostty). Expected: real time well under 0.5s after the first run (spec target: subjectively instant).

- [ ] **Step 7: Report** — Summarize pass/fail per criterion to the user; do not push (user pushes when ready).

---

## Self-review notes

- Spec §atuin/tmux: intentionally absent (deferred in spec).
- gitsigns: ships with LazyVim (Task 4), no separate task — matches spec note.
- The only global side effects are brew installs and the delta pager include (spec-sanctioned, revert documented in install.sh comment).
