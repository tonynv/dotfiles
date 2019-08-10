#!/bin/bash -x

# Create User bin dir
export BIN_DIR=~/.usr/bin/
mkdir -p $BIN_DIR
cp bin/* ~/.usr/bin/
chmod 755  ~/.usr/bin/*

#Add /bin/false
export PATH=/usr/local/bin:$PATH
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
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# Clone dotfiles
git clone --recurse-submodules git@github.com:avattathil/dotfiles.git  && mv dotfiles .dotfiles  
# Install tmux configs
cp submodules/tmux_configs/.tmux.conf ~/.tmux.conf 
cp configs/tmux/tmux.tonyv  ~/.tmux.conf.local
cp configs/vim/vimrc  ~/.vimrc

# Install brew packages
brew install vim
brew install cmake
brew install ispell
brew install tmux
brew install reattach-to-user-namespace
brew install ctags
brew tap sambadevi/powerlevel9k
brew install powerlevel9k
brew install zsh-syntax-highlighting

pip3 install awscli

source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
echo "export PATH=/usr/local/bin:$PATH" >~/.zshrc
echo 'source /usr/local/Cellar/powerlevel9k/0.6.7/powerlevel9k.zsh-theme ' >> ~/.zshrc


