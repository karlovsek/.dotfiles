#!/bin/bash

if which zsh >/dev/null; then
    echo "ZSH exists"
else
  echo "ZSH does not exists, installing it ..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)"
fi

# install oh my zsh
echo "Insalling oh my zsh and plugins ..."
echo "After installation press Ctrl-C, to exit ZSH and to continue the installation. Now press ENTER to continue!"
read foo
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

if which fzf >/dev/null; then
    echo "fzf exists"
else
  echo "Installing fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
fi

if which lazygit >/dev/null; then
    echo "lazygit exists"
else
  echo "Installing lazygit"
  wget https://github.com/jesseduffield/lazygit/releases/download/v0.37.0/lazygit_0.37.0_Linux_x86_64.tar.gz
  tar -xf lazygit_0.37.0_Linux_x86_64.tar.gz
  mkdir -p ~/.local/bin
  mv lazygit ~/.local/bin/
fi

echo "Installation completed!"
echo "add symlinks:"
echo "ln -s ~/.dotfiles/zsh/.zshrc ~/.zshrc"
echo "ln -s ~/.dotfiles/zsh/.p10k.zsh ~/.p10k.zsh"
echo  ""
echo "Now you can run ZSH!"