#Ubuntu
#useradd -s /usr/bin/zsh -G admin tonynv

[[ -f ~/.zshrc ]] && mv ~/.zshrc ~/zshrc_old

ln -s ~/.dotfiles/.vimrc ~/
ln -s ~/.dotfiles/.zshrc ~/
ln -s ~/.dotfiles/.ohmyzsh ~/
ln -s ~/.dotfiles/.gitconfig ~/

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo cp kubernetes.list /etc/apt/sources.list.d/

sudo apt-get -y update
sudo apt-get -y install python3-pip
sudo apt-get -y install neovim
sudo apt-get -y install awscli
sudo apt-get -y install linuxbrew-wrapper
sudo apt-get -y install apt-transport-https
sudo apt-get -y install kubectl

sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.6 10
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# pip installs
pip3 install virtualenvwrapper


# Brew Installs
brew install  pyenv pyenv-virtualenvwrapper pre-commit  git-secrets 
brew install --HEAD pyenv-virtualenv

