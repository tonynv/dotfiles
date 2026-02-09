# tonynv dotfiles

Personal dotfiles and bootstrap script to configure a consistent shell, editor, and terminal multiplexer environment across macOS, Debian/Ubuntu, and Fedora/RHEL systems.

## Quick Start

```bash
git clone https://github.com/tonynv/dotfiles ~/dotfiles
cd ~/dotfiles
./tonynv_setup.sh
```

## Supported Platforms

| Platform | Package Manager |
|---|---|
| macOS | Homebrew (installed automatically if missing) |
| Debian / Ubuntu 
| Fedora / RHEL / CentOS / Amazon Linux | dnf / yum |

The script auto-detects the OS at runtime — no flags needed.

## What Gets Installed

### Packages

| Package | Description |
|---|---|
| zsh | Default shell |
| vim | Text editor |
| tmux | Terminal multiplexer |
| git | Version control |
| curl | HTTP client (used by installers) |
| eza | Modern `ls` replacement with icons and git awareness |

On Linux, if `eza` is not available in the distro's package repos, the script fetches the binary from GitHub releases.

### Frameworks & Plugin Managers

| Tool | Purpose |
|---|---|
| [Oh My Zsh](https://ohmyz.sh/) | Zsh framework — themes, plugins, helpers |
| [Oh My Tmux](https://github.com/gpakosz/.tmux) | Tmux configuration framework (gpakosz/.tmux) |
| [Vim-Plug](https://github.com/junegunn/vim-plug) | Vim plugin manager |

## What Gets Configured

### Shell (zsh)

- **Theme:** agnoster (powerline-style prompt with git status)
- **Plugin:** git (aliases and completions)
- **Aliases:**
  - `ls` — `eza --long --all --classify --group-directories-first`
  - `ll` — `eza --long --classify --group-directories-first`
  - `lt` — `eza --tree --classify --group-directories-first`
- `~/.local/bin` added to `$PATH`
- Sets zsh as the default login shell

### Editor (vim)

- **Color scheme:** molokai (dark)
- **Status bar:** vim-airline with powerline symbols
- **File browser:** NERDTree (`F2` find, `F3` toggle)
- **Syntax checking:** Syntastic (supports cfn-lint, flake8, golint, and more)
- **Language support:** Go (vim-go), Python (jedi-vim), JavaScript, YAML, CloudFormation, Kubernetes
- **Key features:**
  - Line numbers, cursor line highlight
  - Smart search (incremental, case-insensitive until uppercase)
  - Code folding (syntax-based)
  - Tmux-aware paste mode
  - Fugitive git integration (`<leader>gs` for status, `<leader>gc` for commit, etc.)

### Terminal Multiplexer (tmux)

- **Framework:** Oh My Tmux with local overrides
- **Prefix:** `C-b` (default) and `C-a` (GNU Screen compatible)
- **Navigation:** vim-style pane movement (`h/j/k/l`)
- **Splits:** `-` horizontal, `_` or `|` vertical
- **Theme:** Dark with yellow/pink/green status bar sections
- **Status bar:** Session name, uptime, battery, date/time, username, hostname
- **Features:**
  - 256-color support
  - Mouse toggle (`<prefix> + m`)
  - Copy mode with vi bindings
  - OS-aware clipboard integration (pbcopy, xsel, xclip, wl-copy)
  - Window numbering starts at 1

## Dotfiles Included

| Repo File | Symlinked To | Description |
|---|---|---|
| `zshrc` | `~/.zshrc` | Zsh configuration |
| `vimrc` | `~/.vimrc` | Vim configuration |
| `tmux.conf` | `~/.tmux.conf` | Oh My Tmux base config |
| `tmux.conf.local` | `~/.tmux.conf.local` | Tmux local overrides (theme, bindings) |

## How Linking Works

The setup script creates symlinks from `$HOME` back to this repo. If an existing dotfile is found that is **not** already a symlink, it is backed up with a timestamp:

```
~/.zshrc.backup.20260208143000
```

This means you can safely re-run the script without losing anything.

## Re-running the Setup

The script is idempotent. Running it again will:

- Skip packages already installed
- Skip Oh My Zsh / Oh My Tmux if already present
- Re-link dotfiles (backing up any manual changes)
- Skip shell change if zsh is already the default

```bash
./tonynv_setup.sh
```

## Post-Setup

After the script finishes, restart your terminal or run:

```bash
exec zsh
```

Vim plugins install automatically on first launch via Vim-Plug. If you need to manually trigger it:

```bash
vim +PlugInstall +qall
```
