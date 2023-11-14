#!/bin/bash

RED='\033[0;31m'
YELLOW='\e[0;33m'
GREEN='\e[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
echo "SCRIPT_DIR=${SCRIPT_DIR}"

if which nvim 2>/dev/null; then
	echo -e "${GREEN}NeoVim exists ($(nvim --version | grep NVIM)) ${NC}"
else
	echo "NeoVim does not exist, installing it ..."
	wget -q --show-progress https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
	tar -xf nvim-linux64.tar.gz --strip-components=1 -C ~/.local

	# clean
	rm nvim-linux64.tar.gz
fi

if which zsh 2>/dev/null; then
	echo -e "${GREEN}ZSH exists ($(zsh --version)) ${NC}"
else
	echo -e "${YELLOW}ZSH does not exist, installing it ... ${NC}"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)"
fi

if which fd 2>/dev/null; then
	echo -e "${GREEN}fd exists ($(fd --version)) ${NC}"
else
	echo -e "${YELLOW}fd does not exist, installing it ... ${NC}"
	# get the latest version of fd from github
	version=$(curl --silent "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

	wget -q --show-progress https://github.com/sharkdp/fd/releases/download/${version}/fd-${version}-x86_64-unknown-linux-musl.tar.gz
	tar zxf fd-v${version}-x86_64-unknown-linux-musl.tar.gz
	mv fd-v${version}-x86_64-unknown-linux-musl/fd ~/.local/bin

	#clean
	rm -fr fd-v${version}-x86_64-unknown-linux-musl.tar.gz
fi

if which rg 2>/dev/null; then
	echo -e "${GREEN}RG exists ($(rg --version | grep rip)) ${NC}"
else
	echo -e "${YELLOW}RG does not exist, installing it ...${NC}"
	mkdir -p ~/.local/bin

	wget -q --show-progress https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
	tar -xf ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
	mv ripgrep-13.0.0-x86_64-unknown-linux-musl/rg ~/.local/bin

	#clean
	rm -fr ripgrep-13.0.0-x86_64-unknown-linux-musl ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
fi

if which fzf 2>/dev/null; then
	echo -e "${GREEN}fzf exists ($(fzf --version | awk '{print $1}')) ${NC}"
else
	echo -e "${YELLOW}Installing fzf ${NC}"
	git clone -q --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	~/.fzf/install
fi

if which htop 2>/dev/null; then
	echo -e "${GREEN}htop exists ($(htop --version)) ${NC}"
else
	# get the latest version of htop from github
	version=$(curl --silent "https://api.github.com/repos/htop-dev/htop/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
	echo -e "${YELLOW}Installing htop ${version} ${NC}"

	wget -q --show-progress https://github.com/htop-dev/htop/releases/download/${version}/htop-${version}.tar.xz
	tar -xf htop-${version}.tar.xz
	cd htop-${version}
	./autogen.sh >/dev/null && ./configure --prefix=$HOME/.local >/dev/null && make >/dev/null && make install >/dev/null
	#clean
	cd ..
	rm -fr htop-${version} htop-${version}.tar.xz
fi

if which fasd 2>/dev/null; then
	echo -e "${GREEN}fasd exists ($(fasd --version)) ${NC}"
else
	echo "Installing fasd"
	wget -q --show-progress https://github.com/clvv/fasd/zipball/1.0.1 -O fasd.zip
	unzip -p fasd.zip clvv-fasd-4822024/fasd >~/.local/bin/fasd
	chmod +x ~/.local/bin/fasd
	#clean
	rm fasd.zip
fi

if which lazygit 2>/dev/null; then
	echo -e "${GREEN}lazygit exists ($(lazygit --version | awk '{print $6}' | grep -oP "([[:digit:]]*\.?)+")) ${NC}"
else
	# get the latest version of lazygit from github
	version=$(curl --silent "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

	echo -e "${YELLOW}Installing lazygit ${version} ${NC}"

	wget -q --show-progress https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz
	tar -xf lazygit_${version}_Linux_x86_64.tar.gz
	mkdir -p ~/.local/bin
	mv lazygit ~/.local/bin/
	rm lazygit_${version}_Linux_x86_64.tar.gz LICENSE README.md
fi

if which zellij 2>/dev/null; then
	echo -e "${GREEN}zellij exists ($(zellij --version | awk '{print $2}')) ${NC}"
else
	# get the latest version of lazygit from github
	version=$(curl --silent "https://api.github.com/repos/zellij-org/zellij/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

	echo -e "${YELLOW}Installing zellij ${version} ${NC}"

	wget -q --show-progress https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-x86_64-unknown-linux-musl.tar.gz
	tar -xf zellij-x86_64-unknown-linux-musl.tar.gz
	mkdir -p ~/.local/bin
	mv zellij ~/.local/bin/
	rm zellij-x86_64-unknown-linux-musl.tar.gz
fi

echo -ne "\nCreate Vim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
	if [ -f ~/.vimrc ]; then
		mv ~/.vimrc ~/.vimrc_orig
	fi
	if [ -f ~/.vimcommon ]; then
		mv ~/.vimcommon ~/.vimcommon_orig
	fi
	ln -s ${SCRIPT_DIR}/vim/.vimrc ~/.vimrc
	ln -s ${SCRIPT_DIR}/vim/.vimcommon ~/.vimcommon
	echo -e "\t${GREEN}Symlinks created! ${NC}"
else
	echo "You can create Vim symlinks as:"
	echo "ln -s ${SCRIPT_DIR}/vim/.vimrc ~/.vimrc && ln -s ${SCRIPT_DIR}/vim/.vimcommon ~/.vimcommon"
fi

echo -ne "\nCreate NeoVim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
	mkdir -p $HOME/.config
	ln -s ${SCRIPT_DIR}/nvim $HOME/.config/nvim
	echo -e "\t${GREEN}Symlinks created! ${NC}"
else
	echo "You can create NeoVim symlinks as:"
	echo "ln -s ${SCRIPT_DIR}/nvim $HOME/.config/nvim"
fi

if which zellij 2>/dev/null; then
	echo -e "${GREEN}zellij exists ${NC}"

	echo -ne "Create Zellij symlinks? (Y/n): "
	read answer
	answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
	if [[ "$answer" == "y" || -z "$answer" ]]; then
		ln -s ${SCRIPT_DIR}/zellij $HOME/.config/zellij
		echo -e "\t${GREEN}Symlinks created! ${NC}"
	else
		echo "You can create Zellij symlinks as:"
		mkdir -p $HOME/.config
		echo "ln -s ${SCRIPT_DIR}/zellij $HOME/.config/zellij"
	fi
fi

# install oh my ZSH
if [ -d "$HOME/.oh-my-zsh" ]; then
	echo -e "${YELLOW}$HOME/.oh-my-zsh does exist. Skipping installing oh-my-zsh ${NC}"
else
	echo -e "Installing oh-my-zsh ${NC}"
	RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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

install_zsh_plugin https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
install_zsh_plugin https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
install_zsh_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
install_zsh_plugin https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo -ne "\nCreate zshrc and p10k symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
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
