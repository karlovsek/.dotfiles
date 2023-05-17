#!/bin/bash

if which zsh >/dev/null; then
    echo "ZSH exists"
else
  echo "ZSH does not exists, installing it ..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)"
fi

# install oh my zsh
echo "Insalling oh my zsh and plugins ..."
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


echo "Copying .dofiles"
ln -s $(pwd)/vim/.vimcommon ~/.vimcommon
ln -s $(pwd)/vim/.vimrc ~/.vimrc

mv ~/.zshrc ~/.zshrc-orig
mv ~/.pk10k.zsh ~/.pk10k.zsh-orig

ln -s $(pwd)/zsh/.zshrc ~/.zshrc
ln -s $(pwd)/zsh/.pk10k.zsh ~/.pk10k.zsh
