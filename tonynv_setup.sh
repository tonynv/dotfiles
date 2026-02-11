#!/usr/bin/env bash
# tonynv_setup.sh — bootstrap a new host to match tonynv's environment
# Supports: macOS (Homebrew), Debian/Ubuntu (apt), Fedora/RHEL (dnf/yum)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="/tmp/.tonynv_setup"

# ---------- colors -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${CYAN}[info]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[ok]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[warn]${NC}  %s\n" "$*"; }
err()   { printf "${RED}[error]${NC} %s\n" "$*" >&2; }

# ---------- OS detection -----------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            ;;
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian|pop|linuxmint|raspbian)
                        OS="debian"
                        ;;
                    fedora|rhel|centos|rocky|alma|amzn)
                        OS="fedora"
                        ;;
                    *)
                        # Fall back to ID_LIKE
                        case "${ID_LIKE:-}" in
                            *debian*|*ubuntu*) OS="debian" ;;
                            *fedora*|*rhel*)   OS="fedora" ;;
                            *)
                                err "Unsupported Linux distro: $ID"
                                exit 1
                                ;;
                        esac
                        ;;
                esac
            else
                err "Cannot detect Linux distribution (no /etc/os-release)"
                exit 1
            fi
            ;;
        *)
            err "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
    ok "Detected OS: $OS"
}

# ---------- package helpers --------------------------------------------------
pkg_install() {
    case "$OS" in
        macos)
            if ! command -v brew &>/dev/null; then
                info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install "$@"
            ;;
        debian)
            sudo apt-get update -qq
            sudo apt-get install -y "$@"
            ;;
        fedora)
            if command -v dnf &>/dev/null; then
                sudo dnf install -y "$@"
            else
                sudo yum install -y "$@"
            fi
            ;;
    esac
}

# ---------- install vim if missing -------------------------------------------
install_vim() {
    if command -v vim &>/dev/null; then
        ok "vim already installed: $(vim --version | head -1)"
        return
    fi
    info "Installing vim..."
    pkg_install vim
    ok "vim installed"
}

# ---------- install core packages --------------------------------------------
install_packages() {
    info "Installing core packages..."

    case "$OS" in
        macos)
            pkg_install zsh vim tmux git curl tree
            ;;
        debian)
            pkg_install zsh vim tmux git curl tree
            ;;
        fedora)
            pkg_install zsh vim tmux git curl tree
            ;;
    esac

    ok "Core packages installed"
}

# ---------- Oh My Zsh --------------------------------------------------------
install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        ok "Oh My Zsh already installed"
        return
    fi
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
}

# ---------- Oh My Tmux (gpakosz/.tmux) ---------------------------------------
install_oh_my_tmux() {
    if [ -f "$HOME/.tmux/.tmux.conf" ]; then
        ok "Oh My Tmux already installed"
    else
        info "Installing Oh My Tmux (gpakosz/.tmux)..."
        git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
        ok "Oh My Tmux installed"
    fi
}

# ---------- symlink dotfiles -------------------------------------------------
link_dotfiles() {
    info "Linking dotfiles..."

    local files=(
        "zshrc:.zshrc"
        "vimrc:.vimrc"
        "tmux.conf:.tmux.conf"
        "tmux.conf.local:.tmux.conf.local"
    )

    for entry in "${files[@]}"; do
        local src="${entry%%:*}"
        local dst="${entry##*:}"
        local src_path="$DOTFILES_DIR/$src"
        local dst_path="$HOME/$dst"

        if [ ! -f "$src_path" ]; then
            warn "Source file missing: $src_path — skipping"
            continue
        fi

        # Skip if symlink already points to the correct target
        if [ -L "$dst_path" ] && [ "$(readlink "$dst_path")" = "$src_path" ]; then
            ok "Already linked $dst_path -> $src_path"
            continue
        fi

        # Back up existing file (regular file or wrong symlink) to BACKUP_DIR
        if [ -e "$dst_path" ] || [ -L "$dst_path" ]; then
            mkdir -p "$BACKUP_DIR"
            local backup="$BACKUP_DIR/${dst}.backup.$(date +%Y%m%d%H%M%S)"
            warn "Backing up existing $dst_path -> $backup"
            mv "$dst_path" "$backup"
        fi

        ln -s "$src_path" "$dst_path"
        ok "Linked $dst_path -> $src_path"
    done
}

# ---------- Vim-Plug ---------------------------------------------------------
install_vim_plug() {
    local plug_path="$HOME/.vim/autoload/plug.vim"
    if [ -f "$plug_path" ]; then
        ok "Vim-Plug already installed"
        return
    fi
    info "Installing Vim-Plug..."
    curl -fLo "$plug_path" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    ok "Vim-Plug installed"
}

install_vim_plugins() {
    info "Installing Vim plugins (this may take a moment)..."
    vim -E -s +PlugInstall +qall 2>/dev/null || true
    ok "Vim plugins installed"
}

# ---------- setup SSH ---------------------------------------------------------
# Uses 1Password SSH agent when available, falls back to local Ed25519 keys.
setup_ssh() {
    local ssh_src="$DOTFILES_DIR/ssh"
    local ssh_dst="$HOME/.ssh"
    local op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

    info "Setting up SSH..."
    mkdir -p "$ssh_dst"
    chmod 700 "$ssh_dst"

    # Back up existing config if it differs
    local dst_config="$ssh_dst/config"
    if [ -f "$dst_config" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup="$BACKUP_DIR/ssh_config.backup.$(date +%Y%m%d%H%M%S)"
        warn "Backing up existing $dst_config -> $backup"
        cp "$dst_config" "$backup"
    fi

    if [ -S "$op_sock" ]; then
        # ---- 1Password path ----
        ok "1Password SSH agent detected"

        # Deploy 1Password ssh config
        local src_config="$ssh_src/config"
        if [ -f "$src_config" ]; then
            cp "$src_config" "$dst_config"
            chmod 600 "$dst_config"
            ok "Deployed ssh config (1Password agent)"
        fi

        # Clean out old local keys (1Password manages keys now)
        local removed=0
        for keyfile in "$ssh_dst"/id_*; do
            [ -f "$keyfile" ] || continue
            mkdir -p "$BACKUP_DIR"
            local fname
            fname="$(basename "$keyfile")"
            local bak="$BACKUP_DIR/${fname}.backup.$(date +%Y%m%d%H%M%S)"
            warn "Removing old key $keyfile -> backed up to $bak"
            mv "$keyfile" "$bak"
            removed=$((removed + 1))
        done
        [ "$removed" -gt 0 ] && ok "Removed $removed old key(s) — backed up to $BACKUP_DIR"

        ok "SSH setup complete (keys managed by 1Password)"
    else
        # ---- Fallback: local Ed25519 key ----
        warn "1Password SSH agent not found — using local keys"

        # Generate Ed25519 key if none exists
        if [ ! -f "$ssh_dst/id_ed25519" ]; then
            local email="${GIT_USER_EMAIL:-avattathil@gmail.com}"
            info "Generating new Ed25519 key ($email)..."
            ssh-keygen -t ed25519 -C "$email" -f "$ssh_dst/id_ed25519" -N ""
            ok "Generated $ssh_dst/id_ed25519"
            echo ""
            warn "Add this public key to GitHub:"
            echo ""
            cat "$ssh_dst/id_ed25519.pub"
            echo ""
        else
            ok "Ed25519 key already exists at $ssh_dst/id_ed25519"
        fi

        # Write a minimal config without 1Password agent
        cat > "$dst_config" <<'SSHEOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
SSHEOF
        chmod 600 "$dst_config"
        ok "Deployed ssh config (local key)"

        # Add key to agent
        if [ -z "${SSH_AUTH_SOCK:-}" ]; then
            eval "$(ssh-agent -s)" >/dev/null
            info "Started ssh-agent"
        fi
        ssh-add "$ssh_dst/id_ed25519" 2>/dev/null || true
        ok "SSH setup complete (local Ed25519 key)"
    fi
}

# ---------- configure git ----------------------------------------------------
configure_git() {
    # Priority: env vars > defaults (override with GIT_USER_NAME / GIT_USER_EMAIL)
    local name="${GIT_USER_NAME:-Tony Vattathil}"
    local email="${GIT_USER_EMAIL:-avattathil@gmail.com}"

    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || true)"
    current_email="$(git config --global user.email 2>/dev/null || true)"

    if [ "$current_name" = "$name" ] && [ "$current_email" = "$email" ]; then
        ok "Git already configured (${name} <${email}>)"
        return
    fi

    info "Configuring git user..."
    [ -n "$name" ]  && git config --global user.name "$name"
    [ -n "$email" ] && git config --global user.email "$email"
    ok "Git configured: ${name} <${email}>"
}

# ---------- set default shell ------------------------------------------------
set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"

    if [ "$SHELL" = "$zsh_path" ]; then
        ok "Default shell is already zsh"
        return
    fi

    # Ensure zsh is in /etc/shells
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
        info "Adding $zsh_path to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    info "Changing default shell to zsh..."
    chsh -s "$zsh_path"
    ok "Default shell set to $zsh_path (takes effect on next login)"
}

# ---------- main -------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  tonynv dotfiles setup"
    echo "=========================================="
    echo ""

    detect_os
    install_packages
    install_vim
    install_oh_my_zsh
    install_oh_my_tmux
    install_vim_plug
    link_dotfiles
    install_vim_plugins
    setup_ssh
    configure_git
    set_default_shell

    echo ""
    echo "=========================================="
    printf "  ${GREEN}Setup complete!${NC}\n"
    echo "=========================================="
    echo ""
    echo "  Restart your terminal or run:"
    echo "    exec zsh"
    echo ""
}

main "$@"
