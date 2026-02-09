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
            pkg_install zsh vim tmux git curl eza
            ;;
        debian)
            pkg_install zsh vim tmux git curl
            # eza: install from cargo or binary if not available in apt
            if ! command -v eza &>/dev/null; then
                if apt-cache show eza &>/dev/null 2>&1; then
                    pkg_install eza
                else
                    info "Installing eza from GitHub releases..."
                    install_eza_binary
                fi
            fi
            ;;
        fedora)
            pkg_install zsh vim tmux git curl
            if ! command -v eza &>/dev/null; then
                if dnf list eza &>/dev/null 2>&1; then
                    pkg_install eza
                else
                    info "Installing eza from GitHub releases..."
                    install_eza_binary
                fi
            fi
            ;;
    esac

    ok "Core packages installed"
}

install_eza_binary() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        arm64)   arch="aarch64" ;;
        *)       warn "Unsupported arch for eza binary: $arch — skipping"; return ;;
    esac

    local tmp
    tmp="$(mktemp -d)"
    local url="https://github.com/eza-community/eza/releases/latest/download/eza_${arch}-unknown-linux-gnu.tar.gz"
    curl -fsSL "$url" -o "$tmp/eza.tar.gz"
    tar -xzf "$tmp/eza.tar.gz" -C "$tmp"
    sudo install -m 755 "$tmp/eza" /usr/local/bin/eza
    rm -rf "$tmp"
    ok "eza installed to /usr/local/bin/eza"
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

# ---------- configure git ----------------------------------------------------
configure_git() {
    local desired_name="Tony Vattathil"
    local desired_email="avattathil@gmail.com"

    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || true)"
    current_email="$(git config --global user.email 2>/dev/null || true)"

    if [ "$current_name" = "$desired_name" ] && [ "$current_email" = "$desired_email" ]; then
        ok "Git already configured (${desired_name} <${desired_email}>)"
        return
    fi

    info "Configuring git user..."
    git config --global user.name "$desired_name"
    git config --global user.email "$desired_email"
    ok "Git configured: ${desired_name} <${desired_email}>"
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
