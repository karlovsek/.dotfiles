# Quick install command
`git clone https://github.com/karlovsek/.dotfiles.git $HOME/.dotfiles && bash $HOME/.dotfiles/install.sh`


## Minimal
Requirements:
* git zip curl 
* build-essential # For NeoVim-treesiter, htop 
* libncurses5-dev libncursesw5-dev autoconf # For htop

`git clone https://github.com/karlovsek/.dotfiles.git $HOME/.dotfiles && bash $HOME/.dotfiles/install-minimal.sh`

# .dotfiles

1. Clone this repository
2. Run `install.sh`
3. Open up new window to initiate `zsh` shell

### Current issues

- installing `nvim` plugins in `--headless` causes error output, but doesn't break installation
