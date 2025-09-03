# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository that provides configuration and installation scripts for a complete Linux development environment. The repository uses symlinks to connect configuration files from the repository to their expected locations in the home directory.

## Key Architecture

The repository is organized by application/tool:
- **nvim/** - Neovim configuration using LazyVim framework with custom plugins
- **zsh/** - ZSH shell configuration with Oh My ZSH, plugins, and Powerlevel10k theme
- **vim/** - Traditional Vim configuration
- **tmux/** - Terminal multiplexer configuration
- **git/** - Git configuration
- **eza/** - Modern `ls` replacement configuration
- **zellij/** - Alternative terminal multiplexer configuration
- **bin/** - Custom scripts and utilities

## Installation Commands

### Full Installation
```bash
# Clone and run full installation
git clone https://github.com/karlovsek/.dotfiles.git $HOME/.dotfiles && bash $HOME/.dotfiles/install.sh
```

### Minimal Installation (Installs tools without requiring sudo)
```bash
# Installs to ~/.local without requiring system packages
git clone https://github.com/karlovsek/.dotfiles.git $HOME/.dotfiles && bash $HOME/.dotfiles/install-minimal.sh
```

## Common Development Commands

### Neovim Plugin Management
```bash
# Open Neovim and manage plugins with LazyVim
nvim
# Inside Neovim: :Lazy to open plugin manager
```

### Update Tools (for minimal installation)
```bash
# Re-run the install script to update tools to latest versions
bash $HOME/.dotfiles/install-minimal.sh
```

### Apply Configuration Changes
```bash
# After modifying dotfiles, recreate symlinks
# For ZSH
ln -sf $HOME/.dotfiles/zsh/.zshrc $HOME/.zshrc
ln -sf $HOME/.dotfiles/zsh/.p10k.zsh $HOME/.p10k.zsh

# For Neovim
ln -sf $HOME/.dotfiles/nvim $HOME/.config/nvim

# For Git
ln -sf $HOME/.dotfiles/git/.gitconfig $HOME/.gitconfig

# For Tmux
ln -sf $HOME/.dotfiles/tmux/.tmux.conf $HOME/.tmux.conf
ln -sf $HOME/.dotfiles/tmux/.tmux.conf.local $HOME/.tmux.conf.local
```

## Installation Process Architecture

### install-minimal.sh
- Installs everything to `$HOME/.local` (no sudo required)
- Downloads and installs the latest versions of development tools from GitHub releases
- Tools installed: nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, btop, bfs, broot, zoxide, bat, eza, lazygit, lazydocker, zellij, fnm (for Node.js)
- Creates symlinks for configuration files
- Installs Oh My ZSH and plugins

### install.sh  
- Optionally installs additional TUI tools via separate repository
- Sets ZSH as default shell (requires sudo)
- Creates configuration symlinks
- Lighter weight than install-minimal.sh

## Neovim Configuration

Uses LazyVim as a base configuration framework with custom plugins in `nvim/lua/plugins/`:
- Package management via lazy.nvim
- Custom keymaps in `lua/config/keymaps.lua`
- Custom options in `lua/config/options.lua`
- Plugin configurations for debugging (DAP), completions (blink-cmp), formatting (conform), and more

## ZSH Configuration

- Framework: Oh My ZSH with Powerlevel10k theme
- Plugins: fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting, zsh-vi-mode
- History file: `~/.zsh_history`
- FZF integration for fuzzy finding
- Custom PATH management for `~/.local/bin`

## Important Notes

1. The minimal installation script (`install-minimal.sh`) is self-contained and doesn't require system package managers
2. All tools are installed to `$HOME/.local` to avoid requiring root permissions
3. Configuration files are managed via symlinks - modify files in the repository, not in their installed locations
4. The repository tracks its own plugin/tool versions and updates them when the install scripts are re-run