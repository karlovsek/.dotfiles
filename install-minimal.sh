#!/bin/bash

INSTALL_DIR="$HOME/.local"

# Parse command-line arguments
FORCE_UPDATE=false
for arg in "$@"; do
  case $arg in
    --force-update)
      FORCE_UPDATE=true
      shift
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--force-update]"
      exit 1
      ;;
  esac
done

echo -e "\e[0;33m\nPress Enter to install all programs into $INSTALL_DIR \033[0m"
read -p ""

INSTALL_BIN_DIR="$INSTALL_DIR/bin"
mkdir -p "$INSTALL_BIN_DIR"

export PATH="$PATH:$INSTALL_BIN_DIR"

if ! grep -q -e "\$PATH.*${INSTALL_BIN_DIR}" "$HOME/.bashrc"; then
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

# Setup GitHub authentication if GITHUB_PAT is provided
if [ -n "${GITHUB_PAT:-}" ]; then
  GITHUB_AUTH_ARGS=(-H "Authorization: token ${GITHUB_PAT}")
  echo -e "${GREEN}Using GitHub Personal Access Token for API requests${NC}"
else
  GITHUB_AUTH_ARGS=()
  echo -e "${YELLOW}No GITHUB_PAT found - using unauthenticated GitHub API (rate limited)${NC}"
fi

# Helper function to compare versions
# Returns 0 if $1 <= $2, 1 if $1 > $2
compare_versions() {
  if [ "$1" = "$2" ]; then
    return 0
  fi
  # Check if first version is the lesser one
  if [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; then
    return 0
  else
    return 1
  fi
}

# Helper function to prompt for update
prompt_update() {
  local tool_name=$1
  local current_version=$2
  local latest_version=$3

  echo -e "${YELLOW}New version available: $tool_name $current_version -> $latest_version${NC}"

  if [ "$FORCE_UPDATE" = true ]; then
    echo "Forcing update (--force-update flag is set)"
    return 0
  fi

  echo -ne "Update $tool_name? (Y/n): "
  read answer
  answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
  if [[ "$answer" == "y" || -z "$answer" ]]; then
    return 0
  else
    return 1
  fi
}

if which jq >/dev/null 2>&1; then
  current_version=$(jq --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/jqlang/jq/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^jq-//')

  echo -e "${GREEN}jq exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "jq" "$current_version" "$latest_version"; then
      echo "Updating jq to ${latest_version}..."
      gah install jqlang/jq --unattended
      echo -e "${GREEN}jq updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}jq does not exist, installing it ... ${NC}"
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/jqlang/jq/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^jq-//')
  if [ -z "$latest_version" ]; then
    echo -e "${RED}Failed to fetch jq version from GitHub API${NC}"
    exit 1
  fi
  if ! curl -o ~/.local/bin/jq -L https://github.com/jqlang/jq/releases/download/jq-${latest_version}/jq-linux-amd64; then
    echo -e "${RED}Failed to download jq${NC}"
    exit 1
  fi
  chmod +x ~/.local/bin/jq
fi

if which gah >/dev/null 2>&1; then
  current_version=$(gah version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/marverix/gah/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}gah exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "gah" "$current_version" "$latest_version"; then
      echo "Updating gah to ${latest_version}..."
      bash -c "$(curl -fsSL https://raw.githubusercontent.com/marverix/gah/refs/heads/master/tools/install.sh)"
      echo -e "${GREEN}gah updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}gah does not exist, installing it ... ${NC}"
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/marverix/gah/refs/heads/master/tools/install.sh)"
fi

if which 7zz >/dev/null 2>&1; then
  current_version=$(7zz | grep 7-Zip | awk '{print $3}' | grep -oE '[0-9]+\.[0-9]+')
  # 7zip doesn't have a GitHub API, so we use a hardcoded latest version that we update periodically
  latest_version="24.09"

  echo -e "${GREEN}7zip exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "7zip" "$current_version" "$latest_version"; then
      echo "Updating 7zip to ${latest_version}..."
      version_no_dot=$(echo $latest_version | tr -d '.')
      curl -OL https://www.7-zip.org/a/7z${version_no_dot}-linux-x64.tar.xz
      tar -xvf 7z${version_no_dot}-linux-x64.tar.xz 7zz
      chmod +x 7zz && mv 7zz "$INSTALL_BIN_DIR"
      rm 7z${version_no_dot}-linux-x64.tar.xz
      echo -e "${GREEN}7zip updated successfully!${NC}"
    fi
  fi
else
  version="24.09"
  version_no_dot=$(echo $version | tr -d '.')

  echo "7zip does not exist, installing ${version} ..."

  if ! curl -OL https://www.7-zip.org/a/7z${version_no_dot}-linux-x64.tar.xz; then
    echo -e "${RED}Failed to download 7zip${NC}"
    exit 1
  fi
  tar -xvf 7z${version_no_dot}-linux-x64.tar.xz 7zz
  chmod +x 7zz && mv 7zz "$INSTALL_BIN_DIR"

  # clean
  rm 7z${version_no_dot}-linux-x64.tar.xz
fi

# get current curl version
if command -v curl >/dev/null 2>&1; then
  curl_version=$(curl --version | head -n 1 | awk '{print $2}')
  echo "Curl version ${curl_version} installed"
else
  echo "curl is not installed"
  exit 1
fi

if which nvim >/dev/null 2>&1; then
  current_version=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/neovim/neovim-releases/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}NeoVim exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "NeoVim" "$current_version" "$latest_version"; then
      echo "Updating NeoVim to ${latest_version}..."
      nvim_archive=nvim-linux-x86_64.tar.gz
      curl -OL https://github.com/neovim/neovim-releases/releases/download/v${latest_version}/${nvim_archive}
      tar -xf ${nvim_archive} --strip-components=1 -C $INSTALL_DIR
      rm ${nvim_archive}
      echo -e "${GREEN}NeoVim updated successfully!${NC}"
    fi
  fi
else
  version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/neovim/neovim/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)
  if [ -z "$version" ]; then
    echo -e "${RED}Failed to fetch NeoVim version from GitHub API${NC}"
    exit 1
  fi

  echo "NeoVim does not exist, installing ${version} ..."

  nvim_archive=nvim-linux-x86_64.tar.gz

  if ! curl -OL https://github.com/neovim/neovim-releases/releases/download/${version}/${nvim_archive}; then
    echo -e "${RED}Failed to download NeoVim${NC}"
    exit 1
  fi
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
  current_version=$(fd --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}fd exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "fd" "$current_version" "$latest_version"; then
      echo "Updating fd to ${latest_version}..."
      gah install sharkdp/fd --unattended
      echo -e "${GREEN}fd updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}fd does not exist, installing it ... ${NC}"
  gah install sharkdp/fd --unattended
fi

if which sshs >/dev/null 2>&1; then
  current_version=$(sshs --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/quantumsheep/sshs/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}sshs exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "sshs" "$current_version" "$latest_version"; then
      echo "Updating sshs to ${latest_version}..."
      gah install quantumsheep/sshs --unattended
      echo -e "${GREEN}sshs updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}sshs does not exist, installing it ... ${NC}"
  gah install quantumsheep/sshs --unattended
fi

if which rg >/dev/null 2>&1; then
  current_version=$(rg --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)

  echo -e "${GREEN}ripgrep exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "ripgrep" "$current_version" "$latest_version"; then
      echo "Updating ripgrep to ${latest_version}..."
      gah install BurntSushi/ripgrep --unattended
      echo -e "${GREEN}ripgrep updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}ripgrep does not exist, installing it ... ${NC}"
  gah install BurntSushi/ripgrep --unattended
fi

if which lstr >/dev/null 2>&1; then
  current_version=$(lstr --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/bgreenwell/lstr/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}lstr exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "lstr" "$current_version" "$latest_version"; then
      echo "Updating lstr to ${latest_version}..."
      gah install bgreenwell/lstr --unattended
      echo -e "${GREEN}lstr updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}lstr does not exist, installing it ... ${NC}"
  gah install bgreenwell/lstr --unattended
fi

if which fzf >/dev/null 2>&1; then
  echo -e "${GREEN}fzf exists ($(fzf --version | awk '{print $1}')) ${NC}"
else
  echo -e "${YELLOW}Installing fzf ${NC}"
  git clone -q --depth 1 https://github.com/junegunn/fzf.git $INSTALL_DIR/fzf
  $INSTALL_DIR/fzf/install --key-bindings --completion --update-rc
fi

if which htop >/dev/null 2>&1; then
  current_version=$(htop --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/htop-dev/htop/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)

  echo -e "${GREEN}htop exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "htop" "$current_version" "$latest_version"; then
      echo "Updating htop to ${latest_version}..."
      curl --progress-bar -OL https://github.com/htop-dev/htop/releases/download/${latest_version}/htop-${latest_version}.tar.xz
      tar -xf htop-${latest_version}.tar.xz
      cd htop-${latest_version}
      ./autogen.sh >/dev/null && ./configure --prefix=$INSTALL_DIR >/dev/null && make >/dev/null && make install >/dev/null
      cd ..
      rm -fr htop-${latest_version} htop-${latest_version}.tar.xz
      echo -e "${GREEN}htop updated successfully!${NC}"
    fi
  fi
else
  # get the latest version of htop from github
  version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/htop-dev/htop/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)
  echo -e "${YELLOW}Installing htop ${version} ${NC}"

  curl --progress-bar -OL https://github.com/htop-dev/htop/releases/download/${version}/htop-${version}.tar.xz
  tar -xf htop-${version}.tar.xz
  cd htop-${version}
  ./autogen.sh >/dev/null && ./configure --prefix=$INSTALL_DIR >/dev/null && make >/dev/null && make install >/dev/null
  #clean
  cd ..
  rm -fr htop-${version} htop-${version}.tar.xz
fi

# if which btop >/dev/null 2>&1; then
#   current_version=$(btop --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
#   latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/aristocratos/btop/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

#   echo -e "${GREEN}btop exists (v${current_version}, latest: v${latest_version})${NC}"

#   if ! compare_versions "$latest_version" "$current_version"; then
#     if prompt_update "btop" "$current_version" "$latest_version"; then
#       echo "Updating btop to ${latest_version}..."
#       curl --progress-bar -OL https://github.com/aristocratos/btop/releases/download/v${latest_version}/btop-x86_64-linux-musl.tbz
#       tar -xf btop-x86_64-linux-musl.tbz
#       cd btop
#       PREFIX=~/.local make install
#       cd ..
#       rm -fr btop btop-x86_64-linux-musl.tbz
#       echo -e "${GREEN}btop updated successfully!${NC}"
#     fi
#   fi
# else
#   # get the latest version of btop from github
#   version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/aristocratos/btop/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)
#   echo -e "${YELLOW}Installing btop ${version} ${NC}"

#   curl --progress-bar -OL https://github.com/aristocratos/btop/releases/download/${version}/btop-x86_64-linux-musl.tbz
#   tar -xf btop-x86_64-linux-musl.tbz
#   cd btop
#   PREFIX=~/.local make install
#   cd ..

#   # clean
#   rm -fr btop btop-x86_64-linux-musl.tbz
# fi

# if which bfs >/dev/null 2>&1; then
#   current_version=$(bfs --version | grep "bfs " | grep -oE '[0-9]+\.[0-9]+')
#   latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/tavianator/bfs/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)
#
#   echo -e "${GREEN}bfs exists (v${current_version}, latest: v${latest_version})${NC}"
#
#   if ! compare_versions "$latest_version" "$current_version"; then
#     if prompt_update "bfs" "$current_version" "$latest_version"; then
#       echo "Updating bfs to ${latest_version}..."
#       curl --progress-bar -OL https://github.com/tavianator/bfs/archive/refs/tags/${latest_version}.zip
#       7zz x ${latest_version}.zip
#       cd bfs-${latest_version}
#       ./configure --enable-release --mandir=$HOME/.local/man --prefix=$HOME/.local
#       make -j$(nproc) >/dev/null
#       make install
#       cd ..
#       rm -fr bfs-${latest_version} ${latest_version}.zip
#       echo -e "${GREEN}bfs updated successfully!${NC}"
#     fi
#   fi
# else
#   # get the latest version of bfs from github
#   version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/tavianator/bfs/releases/latest" | grep '"tag_name":' | cut -d '"' -f4)
#   echo -e "${YELLOW}Installing bfs ${version} ${NC}"
#
#   curl --progress-bar -OL https://github.com/tavianator/bfs/archive/refs/tags/${version}.zip
#   7zz x ${version}.zip
#   cd bfs-${version}
#   ./configure --enable-release --mandir=$HOME/.local/man --prefix=$HOME/.local
#   make -j$(nproc) >/dev/null
#   make install
#
#   #clean
#   cd ..
#   rm -fr bfs-${version} ${version}.zip
# fi

if which broot >/dev/null 2>&1; then
  echo -e "${GREEN}broot exists ($(broot --version | awk '{print $2}')) ${NC}"
else
  # Install latest version of broot from official download
  echo -e "${YELLOW}Installing broot latest version ${NC}"

  curl --progress-bar -OL https://dystroy.org/broot/download/x86_64-unknown-linux-musl/broot
  chmod +x ./broot
  mv ./broot "$INSTALL_BIN_DIR"
  broot --version
fi

if which zoxide >/dev/null 2>&1; then
  echo -e "${GREEN}zoxide exists ($(zoxide --version)) ${NC}"
else
  echo "Installing zoxide"
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- --bin-dir $INSTALL_BIN_DIR
fi

if which bat >/dev/null 2>&1; then
  current_version=$(bat --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}bat exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "bat" "$current_version" "$latest_version"; then
      echo "Updating bat to ${latest_version}..."
      gah install sharkdp/bat --unattended
      echo -e "${GREEN}bat updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}bat does not exist, installing it ... ${NC}"
  gah install sharkdp/bat --unattended
fi

if which eza >/dev/null 2>&1; then
  current_version=$(eza --version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/eza-community/eza/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

  echo -e "${GREEN}eza exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "eza" "$current_version" "$latest_version"; then
      echo "Updating eza to ${latest_version}..."
      gah install eza-community/eza --unattended
      echo -e "${GREEN}eza updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}eza does not exist, installing it ... ${NC}"
  gah install eza-community/eza --unattended
fi

# Latest lazygit needs newer version of git
# To have as little as possible dependencies, we compile git from source without https support
git_version=$(git --version | awk '{print $3}')
if [ "$(printf '%s\n' "2.30" "$git_version" | sort -V | head -n1)" = "$git_version" ] && [ "$git_version" != "2.30" ]; then
  echo "Your git version ($git_version) is below 2.30. Do you want to update git from source? [y/N]"
  read -r update_git
  if [ "$update_git" = "y" ] || [ "$update_git" = "Y" ]; then
    git_new_version="2.51.0"
    wget "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${git_new_version}.tar.gz"
    tar -xzf "git-${git_new_version}.tar.gz"
    cd "git-${git_new_version}" || exit 1
    ./configure --without-iconv --without-tcltk --prefix="$INSTALL_DIR"
    make NO_GETTEXT=1 NO_TCLTK=1 install
    cd ..
    rm -rf "git-${git_new_version}" "git-${git_new_version}.tar.gz"
    echo "Git has been updated and installed to $INSTALL_BIN_DIR"
  fi
fi

if which lazygit >/dev/null 2>&1; then
  current_version=$(lazygit --version | grep -oP 'version=\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | cut -c2-)

  echo -e "${GREEN}lazygit exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "lazygit" "$current_version" "$latest_version"; then
      echo "Updating lazygit to ${latest_version}..."
      gah install jesseduffield/lazygit --unattended
      echo -e "${GREEN}lazygit updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}lazygit does not exist, installing it ... ${NC}"
  gah install jesseduffield/lazygit --unattended
fi

if which lazydocker >/dev/null 2>&1; then
  current_version=$(lazydocker --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | cut -c2-)

  echo -e "${GREEN}lazydocker exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "lazydocker" "$current_version" "$latest_version"; then
      echo "Updating lazydocker to ${latest_version}..."
      gah install jesseduffield/lazydocker --unattended
      echo -e "${GREEN}lazydocker updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}lazydocker does not exist, installing it ... ${NC}"
  gah install jesseduffield/lazydocker --unattended
fi

if which zellij >/dev/null 2>&1; then
  current_version=$(zellij --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]}" "https://api.github.com/repos/zellij-org/zellij/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | cut -c2-)

  echo -e "${GREEN}zellij exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "zellij" "$current_version" "$latest_version"; then
      echo "Updating zellij to ${latest_version}..."
      gah install zellij-org/zellij --unattended
      echo -e "${GREEN}zellij updated successfully!${NC}"
    fi
  fi
else
  echo -e "${YELLOW}zellij does not exist, installing it ... ${NC}"
  gah install zellij-org/zellij --unattended
fi

# Install fuzzy-kill (fuzzy process finder and killer)
if [ -f "${SCRIPT_DIR}/bin/fuzzy-kill" ]; then
  echo -e "${GREEN}Installing fuzzy-kill...${NC}"
  ln -sf "${SCRIPT_DIR}/bin/fuzzy-kill" "$INSTALL_BIN_DIR/fuzzy-kill"
  ln -sf "${SCRIPT_DIR}/bin/fuzzy-kill" "$INSTALL_BIN_DIR/fk" # Short alias
  chmod +x "${SCRIPT_DIR}/bin/fuzzy-kill"
  echo -e "${GREEN}fuzzy-kill installed (alias: fk)${NC}"
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
    eval "$(fnm env --shell bash)"

    # Download and install Node.js:
    fnm install 23

    # Verify the installation:
    node -v
    npm -v
  else
    echo -e "${RED} FNM not installed ${NC}"
  fi
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

  # Install vim-plug and plugins
  echo -e "${GREEN}Installing vim plugins (this may take a moment)...${NC}"
  vim +'PlugInstall --sync' +qall
  echo -e "\t${GREEN}Vim plugins installed! ${NC}"

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

if which zellij >/dev/null 2>&1; then
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
