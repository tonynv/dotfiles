#!/bin/bash -x

# Create User bin dir
export BIN_DIR=~/.usr/bin/
mkdir -p $BIN_DIR
cp bin/* ~/.usr/bin/
chmod 755  ~/.usr/bin/*

#Add /bin/false
echo "export SHELL=$(which bash)" > ~/.bash_profile

# Setup alias
cat bash/bash.alias >> ~/.bash_profile

# Setup editor
export EDITOR=vim

# Setup path
export PATH=$BIN_DIR:/usr/local/bin:$PATH

# Install xcode (requires prompts) 
xcode-select --install

# Install Homebrew
#|#/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# Clone dotfiles
git clone --recursive git@github.com:avattathil/dotfiles.git  && mv dotfiles .dotfiles  
# Install tmux configs
cp submodules/tmux_configs/.tmux.conf ~/.tmux.conf 
cp configs/tmux/tmux.tonyv  ~/.tmux.conf.local

#mkdir -p ~/.vim/colors
#cp vim/wombat.vim ~/.vim/colors 

# Install brew packages
brew install cmake
brew install macvim --env-std --override-system-vim
brew install ispell
brew install tmux
brew install reattach-to-user-namespace

# Install  python vim configs
sh -c "$(curl -fsSL https://raw.githubusercontent.com/avattathil/python-vimrc/18574648b741e571cdfc29340b7e3e2ee03e2400/setup.sh)"
~/.vim/bundle/YouCompleteMe/install.py --clang-completer

# BASH 
if [ -f `which powerline-daemon` ]; then
  powerline-daemon -q
  POWERLINE_BASH_CONTINUATION=1
  POWERLINE_BASH_SELECT=1
  . ~/.usr/bin/powerline.sh
fi


# ZSH
brew install zsh-syntax-highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
git clone https://github.com/bhilburn/powerlevel9k.git ~/powerlevel9k
echo 'source  ~/powerlevel9k/powerlevel9k.zsh-theme' >> ~/.zshrc
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k

