#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "SCRIPT_DIR=${SCRIPT_DIR}"

if which zsh >/dev/null; then
    echo "ZSH exists"
else
  echo "ZSH does not exists, installing it ..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)"
fi

if which fzf >/dev/null; then
    echo "fzf exists"
else
  echo "Installing fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
fi

if which fasd >/dev/null; then
    echo "fasd exists"
else
  echo "Installing fasd"
  wget https://github.com/clvv/fasd/zipball/1.0.1 -O fasd.zip
  unzip -p fasd.zip clvv-fasd-4822024/fasd > ~/.local/bin/fasd
  chmod +x ~/.local/bin/fasd
  #clean
  rm fasd.zip
fi

if which lazygit >/dev/null; then
    echo "lazygit exists"
else
  echo "Installing lazygit"
  wget https://github.com/jesseduffield/lazygit/releases/download/v0.37.0/lazygit_0.37.0_Linux_x86_64.tar.gz
  tar -xf lazygit_0.37.0_Linux_x86_64.tar.gz
  mkdir -p ~/.local/bin
  mv lazygit ~/.local/bin/
  rm lazygit_0.37.0_Linux_x86_64.tar.gz LICENSE README.md
fi

echo -ne "\nCreate Vim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<< "$answer") 
if [[ "$answer" == "y" || -z "$answer" ]]; then
    if [ -f ~/.vimrc ]; then
      mv ~/.vimrc ~/.vimrc_orig
    fi
    if [ -f ~/.vimcommon ]; then
      mv ~/.vimcommon ~/.vimcommon_orig
    fi
    ln -s ${SCRIPT_DIR}/vim/.vimrc ~/.vimrc
    ln -s ${SCRIPT_DIR}/vim/.vimcommon ~/.vimcommon
    echo -e "\tSymlinks created!"
else
  echo "You can create Vim symlinks as:"
  echo "ln -s ${SCRIPT_DIR}/vim/.vimrc ~/.vimrc && ln -s ${SCRIPT_DIR}/vim/.vimcommon ~/.vimcommo"
fi

# install oh my ZSH
RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# install oh my ZSH plugins, must be after installing oh-my-zsh
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo -ne "\nCreate zshrc and p10k symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<< "$answer") 
if [[ "$answer" == "y" || -z "$answer" ]]; then
    if [ -f ~/.zshrc ]; then
      mv ~/.zshrc ~/.zshrc_orig
    fi
    if [ -f ~/..p10k.zsh ]; then
      mv ~/.p10k.zsh ~/.p10k.zsh_orig
    fi
    ln -s ${SCRIPT_DIR}/zsh/.zshrc ~/.zshrc
    ln -s ${SCRIPT_DIR}/zsh/.p10k.zsh ~/.p10k.zsh
    echo -e "\tSymlinks created!"
else
  echo "You can create ZSH symlinks as:"
  echo "ln -s ${SCRIPT_DIR}/zsh/.zshrc ~/.zshrc &&  ln -s ${SCRIPT_DIR}/zsh/.p10k.zsh ~/.p10k.zsh"
fi

echo "Installation completed!"
zsh # run ZSH
