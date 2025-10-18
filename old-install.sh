# install nix
echo "Do you want to install Nix TUIs? [y/N]"
read response
# Check the value of the response variable and proceed accordingly
if [ "$response" = "y" ]; then
  echo "Empowering your shell"
  git clone https://github.com/karlovsek/Linux-TUI-essential-install.git TUI
  cd TUI
  chmod +x install.sh && ./install.sh
  cd ..
fi

# add zsh as a login shell
command -v zsh | sudo tee -a /etc/shells

echo "Do you want to set ZSH as default shell? [y/N]"
read response
# Check the value of the response variable and proceed accordingly
if [ "$response" = "y" ]; then
  echo "use zsh as default shell"
  sudo chsh -s $(which zsh) $USER
fi

echo "Installing ZSH plugins..."
RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# stow dotfiles
#stow vim
#stow tmux
#stow zsh

# make symlinks and other stuff to apply settings
# vim
ln -s $(pwd)/vim/.vimcommon ~/.vimcommon
ln -s $(pwd)/vim/.vimrc ~/.vimrc

# zsh
mv ~/.zshrc ~/.zshrc-orig
mv ~/.pk10k.zsh ~/.pk10k.zsh-orig
ln -s $(pwd)/zsh/.zshrc ~/.zshrc
ln -s $(pwd)/zsh/.pk10k.zsh ~/.pk10k.zsh

# tmux
ln -s $(pwd)/tmux/.tmux.conf ~/.tmux.conf
ln -s $(pwd)/tmux/.tmux.conf.local ~/.tmux.conf.local
