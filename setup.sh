# Clone dotfiles
git clone --recursive git@github.com:avattathil/dotfiles.git && mv dotfiles .dotfiles  
# Install tmux configs
ln -s .dotfiles/submodule/.tmux.conf && cp .dotfiles/tmux.tonyv  ~/.tmux.conf.local

