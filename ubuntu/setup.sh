#Ubuntu
ln -s ~/.dotfiles/.vimrc ~/
ln -s ~/.dotfiles/.zshrc ~/
ln -s ~/.dotfiles/.ohmyzsh ~/


# Ubuntu
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.6 10
sudo apt-get install -y python3-pip virtualenvwrapper
sudo apt-get install -y ctags neovim awscli git
sudo apt-get install build-essential curl file git
sudo apt-get install -y zsh linuxbrew-wrapper

sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Brew taps
brew install jesseduffield/lazygit/lazygit
# Brew Installs
brew install scli pyenv pyenv-virtualenvwrapper pre-commit  git-secrets python@3.8

# pip installs
pip3 install virtualenvwrapper

