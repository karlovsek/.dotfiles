#!/bin/bash

INSTALL_DIR="$HOME/.local"

echo -e "\e[0;33m\nPress Enter to intall all programs into $INSTALL_DIR \033[0m"
read -p ""

INSTALL_BIN_DIR=$INSTALL_DIR/bin
mkdir -p $INSTALL_BIN_DIR

export PATH=$PATH:$INSTALL_BIN_DIR

if ! grep -q -e "\$PATH\" == .*${INSTALL_BIN_DIR}" "$HOME/.bashrc"; then
  echo "Adding $INSTALL_BIN_DIR to $HOME/.bashrc"

  cat <<EOF >>"$HOME/.bashrc"

if [[ ! "\$PATH" == *${INSTALL_BIN_DIR}* ]]; then
  PATH="${INSTALL_BIN_DIR}:\${PATH:+\${PATH}:}"
fi

EOF
fi

RED='\033[0;31m'
YELLOW='\e[0;33m'
GREEN='\e[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if which 7zz >/dev/null 2>&1; then
  echo -e "${GREEN}7zip exists ($(7zz | grep 7-Zip | awk '{print $3}') ${NC}"
else
  version=7z2409

  echo "7zip does not exist, installing ${version} ..."

  curl -OL https://www.7-zip.org/a/7z2409-linux-x64.tar.xz
  tar -xvf 7z2409-linux-x64.tar.xz 7zz
  chmod +x 7zz && mv 7zz $INSTALL_BIN_DIR

  # clean
  rm 7z2409-linux-x64.tar.xz
fi

# get current curl version
if command -v curl >/dev/null 2>&1; then
  curl_version=$(curl --version | head -n 1 | awk '{print $2}')
  echo "Curl version ${curl_version} installed"
else
  echo "curl is not installed"
  exit 1
fi

# latest_curl_version=$(curl --silent "https://api.github.com/repos/moparisthebest/static-curl/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

# # Test if latest version is greater than current version, and if it is download it

# if [ "$(printf '%s\n' "$latest_curl_version" "$curl_version" | sort -V | head -n 1)" != "$latest_curl_version" ]; then
#   echo "A newer version of curl is available. Downloading version $latest_curl_version ..."
#   curl_archive=curl-amd64

#   curl -OL https://github.com/moparisthebest/static-curl/releases/download/v${latest_curl_version}/${curl_archive}

#   mv $curl_archive ${INSTALL_BIN_DIR}/curl
#   chmod +x ${INSTALL_BIN_DIR}/curl
#   # clean
# else
#   echo "You already have the latest version of curl."
# fi

if which nvim >/dev/null 2>&1; then
  echo -e "${GREEN}NeoVim exists ($(nvim --version | grep NVIM)) ${NC}"
else
  version=$(curl --silent "https://api.github.com/repos/neovim/neovim/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  echo "NeoVim does not exist, installing ${version} ..."

  nvim_archive=nvim-linux-x86_64.tar.gz

  curl -OL https://github.com/neovim/neovim-releases/releases/download/${version}/${nvim_archive}
  tar -xf ${nvim_archive} --strip-components=1 -C $INSTALL_DIR

  # clean
  rm ${nvim_archive}
fi

if which zsh >/dev/null 2>&1; then
  echo -e "${GREEN}ZSH exists ($(zsh --version)) ${NC}"
else
  echo -e "${YELLOW}ZSH does not exist, installing it ... ${NC}"
  bash <(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install) -d $INSTALL_DIR -e yes
fi

if which fd >/dev/null 2>&1; then
  echo -e "${GREEN}fd exists ($(fd --version)) ${NC}"
else
  echo -e "${YELLOW}fd does not exist, installing it ... ${NC}"
  # get the latest version of fd from github
  version=$(curl --silent "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  curl -OL https://github.com/sharkdp/fd/releases/download/${version}/fd-${version}-x86_64-unknown-linux-musl.tar.gz
  tar zxf fd-${version}-x86_64-unknown-linux-musl.tar.gz
  mv fd-${version}-x86_64-unknown-linux-musl/fd $INSTALL_BIN_DIR

  #clean
  rm -fr fd-${version}-x86_64-unknown-linux-musl*
fi

if which sshs >/dev/null 2>&1; then
  echo -e "${GREEN}sshs exists ($(sshs --version)) ${NC}"
else
  echo -e "${YELLOW}sshs does not exist, installing it ... ${NC}"
  # get the latest version of sshs from github
  version=$(curl --silent "https://api.github.com/repos/quantumsheep/sshs/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  sshs_bin_name=sshs-linux-amd64-musl

  curl -OL https://github.com/quantumsheep/sshs/releases/download/${version}/${sshs_bin_name}
  mv ${sshs_bin_name} $INSTALL_BIN_DIR/sshs
  chmod a+x $INSTALL_BIN_DIR/sshs

  # clean
  # nothing to do
fi

if which rg >/dev/null 2>&1; then
  echo -e "${GREEN}RG exists ($(rg --version | grep rip)) ${NC}"
else
  echo -e "${YELLOW}RG does not exist, installing it ...${NC}"

  curl -OL https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
  tar -xf ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
  mv ripgrep-13.0.0-x86_64-unknown-linux-musl/rg $INSTALL_BIN_DIR

  #clean
  rm -fr ripgrep-13.0.0-x86_64-unknown-linux-musl ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
fi

if which fzf >/dev/null 2>&1; then
  echo -e "${GREEN}fzf exists ($(fzf --version | awk '{print $1}')) ${NC}"
else
  echo -e "${YELLOW}Installing fzf ${NC}"
  git clone -q --depth 1 https://github.com/junegunn/fzf.git $INSTALL_DIR/fzf
  $INSTALL_DIR/fzf/install --key-bindings --completion --update-rc
fi

if which htop >/dev/null 2>&1; then
  echo -e "${GREEN}htop exists ($(htop --version)) ${NC}"
else
  # get the latest version of htop from github
  version=$(curl --silent "https://api.github.com/repos/htop-dev/htop/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  echo -e "${YELLOW}Installing htop ${version} ${NC}"

  curl  --progress-bar -OL https://github.com/htop-dev/htop/releases/download/${version}/htop-${version}.tar.xz
  tar -xf htop-${version}.tar.xz
  cd htop-${version}
  ./autogen.sh >/dev/null && ./configure --prefix=$INSTALL_DIR >/dev/null && make >/dev/null && make install >/dev/null
  #clean
  cd ..
  rm -fr htop-${version} htop-${version}.tar.xz
fi

if which btop >/dev/null 2>&1; then
  echo -e "${GREEN}btop exists ($(btop --version)) ${NC}"
else
  # get the latest version of btop from github
  version=$(curl --silent "https://api.github.com/repos/aristocratos/btop/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  echo -e "${YELLOW}Installing btop ${version} ${NC}"

  curl --progress-bar -OL https://github.com/aristocratos/btop/releases/download/${version}/btop-x86_64-linux-musl.tbz
  tar -xf btop-x86_64-linux-musl.tbz
  cd btop
  PREFIX=~/.local make install
  cd ..

  # clean
  rm -fr btop btop-x86_64-linux-musl.tbz
fi

if which bfs >/dev/null 2>&1; then
  echo -e "${GREEN}bfs exists ($(bfs --version | grep "bfs ")) ${NC}"
else
  # get the latest version of htop from github
  version=$(curl --silent "https://api.github.com/repos/tavianator/bfs/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  echo -e "${YELLOW}Installing bfs ${version} ${NC}"

  curl --progress-bar -OL https://github.com/tavianator/bfs/archive/refs/tags/${version}.zip
  7zz x ${version}.zip
  cd bfs-${version}
  ./configure --enable-release --mandir=$HOME/.local/man --prefix=$HOME/.local
  make -j$(nproc) >/dev/null
  make install

  #clean
  cd ..
  rm -fr bfs-${version} ${version}.zip
fi

if which broot >/dev/null 2>&1; then
  echo -e "${GREEN}broot exists ($(broot --version | awk '{print $2}')) ${NC}"
else
  # get the latest version of htop from github
  # version=$(curl --silent "https://api.github.com/repos/Canop/broot/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
  echo -e "${YELLOW}Installing broot latest version ${NC}"

  curl --progress-bar -OL https://dystroy.org/broot/download/x86_64-unknown-linux-musl/broot
  chmod +x ./broot
  mv ./broot ${INSTALL_BIN_DIR}
  broot --version
fi

if which zoxide >/dev/null 2>&1; then
  echo -e "${GREEN}zoxide exists ($(zoxide --version)) ${NC}"
else
  echo "Installing zoxide"
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- --bin-dir $INSTALL_BIN_DIR
fi

if which bat >/dev/null 2>&1; then
  echo -e "${GREEN}bat exists ($(bat --version | grep -o " .* ")) ${NC}"
else
  echo -e "${YELLOW}bat does not exist, installing it ... ${NC}"
  # get the latest version of fd from github
  version=$(curl --silent "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  curl -OL https://github.com/sharkdp/bat/releases/download/${version}/bat-${version}-x86_64-unknown-linux-gnu.tar.gz
  tar -xf bat-${version}-x86_64-unknown-linux-gnu.tar.gz
  mv bat-${version}-x86_64-unknown-linux-gnu/bat $INSTALL_BIN_DIR/bat
  chmod +x $INSTALL_BIN_DIR/bat

  #clean
  rm -fr bat-${version}-x86_64-unknown-linux-gnu*
fi

if which eza >/dev/null 2>&1; then
  echo -e "${GREEN}eza exists ($(eza --version | grep -o "^v.* ")) ${NC}"
else
  echo -e "${YELLOW}eza does not exist, installing it ... ${NC}"
  # get the latest version of fd from github
  version=$(curl --silent "https://api.github.com/repos/eza-community/eza/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  curl -OL https://github.com/eza-community/eza/releases/download/${version}/eza_x86_64-unknown-linux-gnu.zip
  7zz x eza_x86_64-unknown-linux-gnu.zip
  mv eza $INSTALL_BIN_DIR/eza
  chmod +x $INSTALL_BIN_DIR/eza

  #clean
  rm -fr eza_x86_64-unknown-linux-gnu.zip
fi

if which lazygit >/dev/null 2>&1; then
  echo -e "${GREEN}lazygit exists ($(lazygit --version | awk '{print $6}' | grep -oP "([[:digit:]]*\.?)+")) ${NC}"
else
  # get the latest version of lazygit from github
  version=$(curl --silent "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

  echo -e "${YELLOW}Installing lazygit ${version} ${NC}"

  curl -OL https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz
  tar -xf lazygit_${version}_Linux_x86_64.tar.gz
  mv lazygit $INSTALL_BIN_DIR/
  rm -f lazygit_${version}_Linux_x86_64.tar.gz LICENSE README.md
fi

if which lazydocker >/dev/null 2>&1; then
  echo -e "${GREEN}lazydocker exists ($(lazydocker --version | head -n1 | awk '{print $2}')) ${NC}"
else
  # get the latest version of lazygit from github
  version=$(curl --silent "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

  echo -e "${YELLOW}Installing lazydocker ${version} ${NC}"

  curl -OL https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_x86_64.tar.gz
  tar -xf lazydocker_${version}_Linux_x86_64.tar.gz
  mv lazydocker $INSTALL_BIN_DIR/
  rm -f lazydocker_${version}_Linux_x86_64.tar.gz LICENSE README.md
fi

if which zellij >/dev/null 2>&1; then
  echo -e "${GREEN}zellij exists ($(zellij --version | awk '{print $2}')) ${NC}"
else
  # get the latest version of lazygit from github
  version=$(curl --silent "https://api.github.com/repos/zellij-org/zellij/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

  echo -e "${YELLOW}Installing zellij ${version} ${NC}"

  mkdir zellij_tmp && cd zellij_tmp
  curl -OL https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-x86_64-unknown-linux-musl.tar.gz
  tar -xf zellij-x86_64-unknown-linux-musl.tar.gz
  mv zellij $INSTALL_BIN_DIR/
  cd ..
  rm -fr zellij_tmp
fi

# TODO install node
if which node >/dev/null 2>&1; then
  echo -e "${GREEN}node exists ($(node -v)) ${NC}"
else
  echo -e "${YELLOW}Installing fnm ${NC}"

  # Download and install fnm:
  curl -o- https://fnm.vercel.app/install | bash

  FNM_PATH="$HOME/.local/share/fnm"
  if [ -d "$FNM_PATH" ]; then
    export PATH="$FNM_PATH:$PATH"
    eval "`fnm env`"

    # Download and install Node.js:
    fnm install 23

    # Verify the Node.js version:
    node -v # Should print "v23.11.0".

    # Verify npm version:
    npm -v # Should print "10.9.2".
  else
    echo -e "${RED} FNM not installed ${NC}"
  fi

  mkdir zellij_tmp && cd zellij_tmp
  curl -OL https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-x86_64-unknown-linux-musl.tar.gz
  tar -xf zellij-x86_64-unknown-linux-musl.tar.gz
  mv zellij $INSTALL_BIN_DIR/
  cd ..
  rm -fr zellij_tmp
fi






echo -ne "\nCreate Vim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
  if [ -f $HOME/.vimrc ]; then
    mv $HOME/.vimrc $HOME/.vimrc_orig
  fi
  if [ -f $HOME/.vimcommon ]; then
    mv $HOME/.vimcommon $HOME/.vimcommon_orig
  fi
  ln -sf ${SCRIPT_DIR}/vim/.vimrc $HOME/.vimrc
  ln -sf ${SCRIPT_DIR}/vim/.vimcommon $HOME/.vimcommon
  echo -e "\t${GREEN}Symlinks created! ${NC}"
else
  echo "You can create Vim symlinks as:"
  echo "ln -sf ${SCRIPT_DIR}/vim/.vimrc $HOME/.vimrc && ln -sf ${SCRIPT_DIR}/vim/.vimcommon $HOME/.vimcommon"
fi

echo -ne "\nCreate NeoVim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
  mkdir -p $HOME/.config
  ln -sf ${SCRIPT_DIR}/nvim $HOME/.config/nvim
  echo -e "\t${GREEN}Symlinks created! ${NC}"
else
  echo "You can create NeoVim symlinks as:"
  echo "ln -sf ${SCRIPT_DIR}/nvim $HOME/.config/nvim"
fi

echo -ne "\nCreate Git config symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
  if [ -f $HOME/.gitconfig ]; then
    mv $HOME/.gitconfig $HOME/.gitconfig_orig
  fi
  ln -sf ${SCRIPT_DIR}/git/.gitconfig $HOME/.gitconfig
  echo -e "\t${GREEN}Symlinks created! ${NC}"
fi

if which zellij 2>/dev/null 2>&1; then
  echo -e "${GREEN}zellij exists ${NC}"

  echo -ne "Create Zellij symlinks? (Y/n): "
  read answer
  answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
  if [[ "$answer" == "y" || -z "$answer" ]]; then
    mkdir -p $HOME/.config
    ln -sf ${SCRIPT_DIR}/zellij $HOME/.config/zellij
    echo -e "\t${GREEN}Symlinks created! ${NC}"
  else
    echo "You can create Zellij symlinks as:"
    echo "ln -sf ${SCRIPT_DIR}/zellij $HOME/.config/zellij"
  fi
fi

# install oh my ZSH
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo -e "${YELLOW}$HOME/.oh-my-zsh does exist. Skipping installing oh-my-zsh ${NC}"
else
  echo -e "Installing oh-my-zsh ${NC}"
  #   CHSH       - 'no' means the installer will not change the default shell (default: yes)
  #   RUNZSH     - 'no' means the installer will not run zsh after the install (default: yes)
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# install oh my ZSH plugins, must be after installing oh-my-zsh
install_zsh_plugin() {
  url=$1
  install_path=$2
  plugin_name=$(basename $2)

  if [ ! -d "$2" ]; then
    echo -e "${GREEN}Installing $plugin_name ${NC}"
    git clone -q --depth=1 $1 $2
  else
    echo -e "${YELLOW}${plugin_name} already installed${NC}"
  fi
}

install_zsh_plugin https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab
install_zsh_plugin https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
install_zsh_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
install_zsh_plugin https://github.com/jeffreytse/zsh-vi-mode ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-vi-mode
install_zsh_plugin https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo -e "\n${YELLOW}Creating symlinks for zsh and p10k ... ${NC}"
if [ -f $HOME/.zshrc ]; then
  mv $HOME/.zshrc $HOME/.zshrc_orig
fi

if [ -f $HOME/.p10k.zsh ]; then
  mv $HOME/.p10k.zsh $HOME/.p10k.zsh_orig
fi

ln -sf ${SCRIPT_DIR}/zsh/.zshrc $HOME/.zshrc
ln -sf ${SCRIPT_DIR}/zsh/.p10k.zsh $HOME/.p10k.zsh

echo -e "\n${GREEN}Installation completed! ${NC}"
read -p "Press Enter to run zsh!"
source $HOME/.bashrc
# run ZSH and configure p10k
zsh -c "source $HOME/.zshrc &&  echo -e \"\n\e[0;33mTo configure p10k run: p10k configure \033[0m\" ; zsh"
