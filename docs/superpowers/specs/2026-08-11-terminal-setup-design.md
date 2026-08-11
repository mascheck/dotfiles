# Terminal Setup Modernization — Design

**Date:** 2026-08-11
**Status:** Approved (pending spec review)

## Goal

A modern terminal environment that runs **in parallel** to the existing iTerm2 + oh-my-zsh + Powerlevel10k setup, scoped entirely to Ghostty. The existing setup stays untouched and functional; the new one can be evaluated risk-free and adopted (or discarded) later.

Primary use cases, in priority order:

1. **Read and navigate code in project context** (go-to-definition, references, fuzzy file/grep search) — not heavy refactoring; a full IDE replacement is explicitly *not* the goal.
2. **View diffs in workspace context** (branch/commit diffs with file tree, staged/unstaged work).
3. **Run named per-project tasks** — the IntelliJ run-configuration workflow, in the terminal.
4. General quality-of-life: faster navigation, better defaults, consistent look.

## Non-goals / deferred

- **tmux / sessionizer** — deferred pending the herdr evaluation for agent shells. Nothing in this design conflicts with adding tmux later.
- **Replacing the iTerm2 / oh-my-zsh / p10k setup** — only reconsidered if the Ghostty setup wins after real use.
- **atuin** (synced searchable shell history) — deferred; needs a sync/setup decision. fzf's Ctrl-R covers history search initially.
- IDE-grade refactoring support in Neovim.

## Architecture

### Isolation mechanism

Zsh reads its config from `$ZDOTDIR` when set. Ghostty's config launches zsh with `ZDOTDIR=~/.config/zsh`, where a brand-new `.zshrc` lives. iTerm2 launches zsh normally and keeps using `~/.zshrc` (oh-my-zsh + p10k). Result: two fully independent shell configurations selected by which terminal app you open.

Brew-installed CLI tools are on `$PATH` in both shells, but shell integrations (zoxide hook, fzf keybindings, aliases) are wired up **only** in the new config.

### Components

**1. Ghostty** (brew cask)
- Font: JetBrains Mono Nerd Font (brew cask `font-jetbrains-mono-nerd-font`) — required for icons in starship, eza, and Neovim.
- Theme: **Catppuccin Mocha** (chosen as default; Ghostty ships it built-in, switching later is a one-line change). The same theme is applied in starship, Neovim, bat, and lazygit for a consistent look.
- `command` set to launch zsh with the new `ZDOTDIR`.
- Config file: `~/.config/ghostty/config`, versioned in this repo.

**2. Shell — `~/.config/zsh/.zshrc`** (new, versioned)
- **zinit** as plugin manager with lazy loading.
- **starship** prompt (config `~/.config/starship.toml`, Catppuccin palette).
- Plugins: `zsh-autosuggestions`, `fast-syntax-highlighting`, `fzf-tab` (fuzzy completion menus).
- Sources the same PATH/env additions the old `.zshrc` has (deno, rbenv, JAVA_HOME, libpq, pub-cache, ~/.local/bin) so all dev tooling works identically. These are duplicated deliberately — the old `.zshrc` must remain standalone.

**3. CLI tool belt** (brew formulas; integrations only in the new shell config)
- `fzf` — fuzzy finder; Ctrl-R history, Ctrl-T file picker.
- `zoxide` — frecency-based directory jumping (`z <partial-name>`).
- `eza` — modern ls (icons, git status); aliased to `ls`/`ll`.
- `bat` — cat with syntax highlighting; aliased to `cat`.
- `ripgrep`, `fd` — fast content/file search; also power Neovim pickers. (Note: `rg` is currently shadowed by a Claude Code shell function in the old config — the real binary must be installed and take precedence for Neovim.)
- `just` — task runner (see §5).
- `lazygit`, `git-delta` — see §6.

**4. Neovim — LazyVim** (config at `~/.config/nvim`, versioned)
- Bootstrap from the LazyVim starter template.
- Enabled extras/plugins:
  - `flutter-tools.nvim` — Dart LSP, Flutter commands (hot reload/restart), device selection.
  - TypeScript LSP (typescript-language-server is already installed).
  - Tree-sitter highlighting (tree-sitter already installed).
  - `gitsigns.nvim` — inline change markers (ships with LazyVim).
  - `diffview.nvim` — see §6.
  - `overseer.nvim` — see §5.
- Theme: Catppuccin Mocha.
- Tuned for reading/navigation: file explorer, fuzzy file + live-grep pickers, LSP go-to-definition/references/hover, symbol outline.

**5. Run configurations → justfiles**
- A `justfile` per project defines named tasks (`just run-dev`, `just test`, `just build-ios`) — the analog of IntelliJ run configurations, versionable and shareable.
- Shell: `just --list` + an fzf-backed picker alias for discovery.
- Neovim: `overseer.nvim` auto-discovers justfile tasks and runs them in a task panel (closest analog to IntelliJ's run panel).
- This repo includes one example justfile template for a Flutter project as a starting pattern.

**6. Git / diff workflow**
- **lazygit** — standalone TUI for staging, branching, log, stash; also opened from inside Neovim via a keybinding (LazyVim ships this integration).
- **diffview.nvim** — side-by-side diffs of any branch/commit range with a file tree; the core answer to "look at diffs in workspace context".
- **git-delta** — configured as git's pager (scoped via `~/.gitconfig` include or global; readable `git diff` everywhere).

**7. Repo layout (this repo)**

```
dotfiles/
├── docs/superpowers/specs/   # this spec
├── ghostty/config            # → ~/.config/ghostty/config
├── zsh/.zshrc                # → ~/.config/zsh/.zshrc
├── starship/starship.toml    # → ~/.config/starship.toml
├── nvim/                     # → ~/.config/nvim
├── just/flutter.justfile     # example template (not symlinked)
├── install.sh                # brew installs + symlinks (idempotent)
└── macos/                    # pre-existing machine-setup scripts (untouched)
```

- `install.sh` installs brew packages, creates symlinks (backing up any existing target files first), and is safe to re-run.

## Error handling / safety

- The old `~/.zshrc`, iTerm2 profile, and p10k config are never modified.
- Symlink creation backs up existing files instead of overwriting.
- `~/.config/nvim` currently doesn't exist, so LazyVim installs clean; if a config appears later, install.sh backs it up.
- git-delta is the only change visible outside Ghostty (affects `git diff` in iTerm2 too). Accepted as low-risk; revert is one gitconfig line.

## Testing / success criteria

1. Opening Ghostty yields the new prompt with working autosuggestions, fzf Ctrl-R, and `z` jumping; opening iTerm2 yields the unchanged p10k setup.
2. In a Flutter project in Neovim: go-to-definition, find-references, and live-grep work; hot reload triggers via flutter-tools.
3. `:DiffviewOpen main` shows a side-by-side branch diff with file tree.
4. `just <task>` runs from shell and via overseer.nvim from Neovim in a project with a justfile.
5. `install.sh` re-run is a no-op on an already-installed machine.
6. Shell startup in Ghostty is subjectively instant (< ~150 ms).
