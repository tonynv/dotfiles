# Install xcode (requires prompts) 
xcode-select --install
# Install Homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# Clone dotfiles
git clone --recursive git@github.com:avattathil/dotfiles.git && mv dotfiles .dotfiles  
# Install tmux configs
ln -s .dotfiles/submodules/tmux_configs/.tmux.conf ~/.tmux.conf 
ln -s .dotfiles/configs/tmux/tmux.tonyv  ~/.tmux.conf.local
