#!/bin/bash

RED='\033[0;31m'
YELLOW='\e[0;33m'
GREEN='\e[0;32m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
echo "SCRIPT_DIR=${SCRIPT_DIR}"

if which nvim >/dev/null; then
	echo -e "${GREEN}NeoVim exists ${NC}"
else
	echo "NeoVim does not exist, installing it ..."
	wget -q --show-progress https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
	tar -xf nvim-linux64.tar.gz --strip-components=1 -C ~/.local

	# clean
	rm nvim-linux64.tar.gz
fi

if which zsh >/dev/null; then
	echo -e "${GREEN}ZSH exists ${NC}"
else
	echo -e "${YELLOW}ZSH does not exist, installing it ... ${NC}"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)"
fi

if which rg >/dev/null; then
	echo -e "${GREEN}RG exists ${NC}"
else
	echo -e "${YELLOW}RG does not exist, installing it ...${NC}"
	mkdir -p ~/.local/bin

	wget -q --show-progress https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
	tar -xf ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
	mv ripgrep-13.0.0-x86_64-unknown-linux-musl/rg ~/.local/bin

	#clean
	rm -fr ripgrep-13.0.0-x86_64-unknown-linux-musl ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
fi

if which fzf >/dev/null; then
	echo -e "${GREEN} fzf exists ${NC}"
else
	echo -e "${YELLOW}Installing fzf ${NC}"
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	~/.fzf/install
fi

if which htop >/dev/null; then
	echo -e "${GREEN}htop exists ${NC}"
else
	echo -e "Installing htop${NC}"
	version="3.2.2"
	wget -q --show-progress https://github.com/htop-dev/htop/releases/download/${version}/htop-${version}.tar.xz
	tar -xf htop-${version}.tar.xz
	cd htop-${version}
	./autogen.sh > /dev/null && ./configure --prefix=$HOME/.local > /dev/null && make > /dev/null && make install
	#clean
	cd ..
	rm -fr htop-${version} htop-${version}.tar.xz
fi

if which fasd >/dev/null; then
	echo "fasd exists"
else
	echo "Installing fasd"
	wget -q --show-progress https://github.com/clvv/fasd/zipball/1.0.1 -O fasd.zip
	unzip -p fasd.zip clvv-fasd-4822024/fasd >~/.local/bin/fasd
	chmod +x ~/.local/bin/fasd
	#clean
	rm fasd.zip
fi

if which lazygit >/dev/null; then
	echo "lazygit exists"
else
	echo "Installing lazygit"
	version="0.40.2"
	wget -q --show-progress https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz
	tar -xf lazygit_${version}_Linux_x86_64.tar.gz
	mkdir -p ~/.local/bin
	mv lazygit ~/.local/bin/
	rm lazygit_${version}_Linux_x86_64.tar.gz LICENSE README.md
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
	echo -e "\tSymlinks created!"
else
	echo "You can create Vim symlinks as:"
	echo "ln -s ${SCRIPT_DIR}/vim/.vimrc ~/.vimrc && ln -s ${SCRIPT_DIR}/vim/.vimcommon ~/.vimcommon"
fi

echo -ne "\nCreate NeoVim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
	ln -s ${SCRIPT_DIR}/nvim $HOME/.config/nvim
	echo -e "\tSymlinks created!"
else
	echo "You can create NeoVim symlinks as:"
	mkdir -p $HOME/.config
	echo "ln -s ${SCRIPT_DIR}/nvim $HOME/.config/nvim"
fi

if which zellij >/dev/null; then
	echo "zellij exists"

	echo -ne "\nCreate Zellij symlinks? (Y/n): "
	read answer
	answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
	if [[ "$answer" == "y" || -z "$answer" ]]; then
		ln -s ${SCRIPT_DIR}/zellij $HOME/.config/zellij
		echo -e "\tSymlinks created!"
	else
		echo "You can create Zellij symlinks as:"
		mkdir -p $HOME/.config
		echo "ln -s ${SCRIPT_DIR}/zellij $HOME/.config/zellij"
	fi
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
