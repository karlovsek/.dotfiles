
<!-- @sessions/CLAUDE.sessions.md -->

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
  - **fuzzy-kill** - Interactive fuzzy process finder and killer
  - **watch_file_change.sh** - File watcher utility

## Installation

```bash
# Clone and run installation (no sudo required)
git clone https://github.com/karlovsek/.dotfiles.git $HOME/.dotfiles && bash $HOME/.dotfiles/install-minimal.sh

# Force update all tools to latest versions
bash $HOME/.dotfiles/install-minimal.sh --force-update
```

`install-minimal.sh` installs everything to `$HOME/.local`, downloads tools from GitHub releases, creates symlinks, and installs Oh My ZSH and plugins. Tools: nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, btop, bfs, broot, zoxide, bat, eza, lazygit, lazydocker, zellij, fnm (for Node.js), gdu.

Set `GITHUB_PAT` env var to avoid GitHub API rate limits during installation.

Other flags:
```bash
bash install-minimal.sh --dry-run        # Preview what would be installed without making changes
bash install-minimal.sh --force-update   # Re-download all tools to their latest versions
```

## Git from Source (with HTTPS Support)

If the system git is below v2.32 (required by lazygit), `install-minimal.sh` offers to compile git from source with full HTTPS support. This is a 3-step dependency chain, all installed to `~/.local` (no root required):

1. **OpenSSL** (only if system headers are missing) — Downloads OpenSSL 1.1.1w and compiles it so that curl and git can link against it for TLS.
2. **libcurl** (only if `curl-config` / `pkg-config libcurl` are missing) — Downloads curl 8.11.1 and compiles it with `--with-openssl` pointing to the OpenSSL from step 1.
3. **git** — Downloads git 2.51.0 from kernel.org and compiles it against the above. The result includes `git-remote-https` in `~/.local/libexec/git-core/`, enabling clone/push/fetch over HTTPS.

After compilation, the script verifies that `git-remote-https` exists. If any step fails, a warning is printed and the system git is kept as a fallback.

For environments where compilation isn't possible (no `make`/`gcc`), the Docker test infrastructure pre-builds a statically-linked git in an Alpine stage and copies it into the test container — see `podman/Dockerfile.test-ubuntu` for that approach.

## Testing with Docker/Podman

The `podman/` directory contains a full CI-style validation suite:

```bash
./podman/run-tests.sh              # Run all tests (Ubuntu 22.04 + Rocky Linux 8)
./podman/run-tests.sh ubuntu       # Run only Ubuntu test
./podman/run-tests.sh rocky        # Run only Rocky test (GLIBC 2.28, tests tree-sitter compat)
```

Both `docker` and `podman` are auto-detected. Set `GITHUB_PAT` to avoid rate limits:
```bash
GITHUB_PAT=ghp_xxx ./podman/run-tests.sh
```

The test suite (`podman/validate.sh`) covers 11 areas: binary existence, minimum version checks, symlinks, install log, ZSH plugins, nvim Lazy loading, git HTTPS support, GLIBC/tree-sitter compatibility, dry-run mode, fuzzy-kill, and git repo status.

To build and run a single container manually:
```bash
docker build --build-arg GITHUB_PAT="$GITHUB_PAT" \
  -f podman/Dockerfile.test-ubuntu -t dotfiles-test-ubuntu .
docker run --rm dotfiles-test-ubuntu
```

## Symlink Management

Configuration files are managed via symlinks. After modifying dotfiles:

```bash
ln -sf $HOME/.dotfiles/zsh/.zshrc $HOME/.zshrc
ln -sf $HOME/.dotfiles/zsh/.p10k.zsh $HOME/.p10k.zsh
ln -sf $HOME/.dotfiles/nvim $HOME/.config/nvim
ln -sf $HOME/.dotfiles/git/.gitconfig $HOME/.gitconfig
ln -sf $HOME/.dotfiles/tmux/.tmux.conf $HOME/.tmux.conf
ln -sf $HOME/.dotfiles/tmux/.tmux.conf.local $HOME/.tmux.conf.local
```

Always modify files in the repository, not at their installed symlink locations.

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

## Fuzzy-Kill Tool

A custom interactive process manager that combines htop's clarity with fzf's fuzzy-finding capabilities.

**Location:** `bin/fuzzy-kill`

**Features:**
- Fuzzy search across all running processes
- Multi-select processes with Tab key
- Color-coded CPU/memory display
- Interactive kill with signal selection (TERM, KILL, INT, etc.)
- Preview window with detailed process information
- Safety features (critical process protection, dry-run mode)

**Usage:**
```bash
fuzzy-kill                    # Interactive process selector
fk                           # Short alias
fkk                          # Force kill mode (SIGKILL)
fku                          # Only your processes
fkd                          # Dry-run mode (safe preview)

# With options:
fuzzy-kill --filter chrome   # Pre-filter by name
fuzzy-kill --user $USER      # Filter by user
fuzzy-kill --signal KILL     # Use SIGKILL
fuzzy-kill --sort mem        # Sort by memory
```

## Important Notes

- Installing nvim plugins in `--headless` mode produces error output but doesn't break installation
- The `nvim/` directory has a `.gitignore` that excludes lazy.nvim state/cache - plugin state is not committed

