#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
echo "SCRIPT_DIR=${SCRIPT_DIR}"

if which nvim >/dev/null; then
	echo "NeoVim exists"
else
	echo "NeoVim does not exist, installing it ..."
	wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
	tar -xvf nvim-linux64.tar.gz --strip-components=1 -C ~/.local

	# clean
	rm nvim-linux64.tar.gz
fi

if which zsh >/dev/null; then
	echo "ZSH exists"
else
	echo "ZSH does not exist, installing it ..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)"
fi

if which rg >/dev/null; then
	echo "RG exists"
else
	echo "RG does not exist, installing it ..."
	mkdir -p ~/.local/bin

	wget https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
	tar -xvf ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
	mv ripgrep-13.0.0-x86_64-unknown-linux-musl/rg ~/.local/bin

	#clean
	rm -fr ripgrep-13.0.0-x86_64-unknown-linux-musl ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz
fi

if which fzf >/dev/null; then
	echo "fzf exists"
else
	echo "Installing fzf"
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	~/.fzf/install
fi

if which htop >/dev/null; then
	echo "htop exists"
else
	echo "Installing htop"
	wget https://github.com/htop-dev/htop/releases/download/3.2.2/htop-3.2.2.tar.xz
	tar -xvf htop-3.2.2.tar.xz
	cd htop-3.2.2
	./autogen.sh && ./configure --prefix=$HOME/.local/bin && make && make install
	#clean
	cd ..
	rm -fr htop-3.2.2 htop-3.2.2.tar.xz
fi

if which fasd >/dev/null; then
	echo "fasd exists"
else
	echo "Installing fasd"
	wget https://github.com/clvv/fasd/zipball/1.0.1 -O fasd.zip
	unzip -p fasd.zip clvv-fasd-4822024/fasd >~/.local/bin/fasd
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
	echo "ln -s ${SCRIPT_DIR}/nvim $HOME/.config/nvim"
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
