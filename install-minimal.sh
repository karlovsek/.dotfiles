#!/bin/bash
###############################################################################
# install-minimal.sh — Bootstrap a complete Linux dev environment
#
# Usage:
#   bash install-minimal.sh                  # Interactive install
#   bash install-minimal.sh --force-update   # Re-download all tools to latest
#   bash install-minimal.sh --dry-run        # Preview without making changes
#
# Environment:
#   GITHUB_PAT=ghp_xxx  Set a GitHub personal access token to avoid API
#                        rate limits when fetching latest release versions.
#
# What it installs (all to ~/.local, no sudo required):
#   nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, btop, bfs, broot, zoxide,
#   bat, eza, gdu, lazygit, lazydocker, zellij, fnm (Node.js), jq, 7zip, gah
#
# Git from source (with HTTPS support):
#   If the system git is below v2.32 (required by lazygit), the script offers
#   to compile git from source. This is a 3-step process:
#
#     Step 1 — OpenSSL (if headers are missing)
#       Downloads OpenSSL 1.1.1w and compiles it into ~/.local so that curl
#       and git can link against it for TLS/HTTPS support.
#
#     Step 2 — libcurl (if curl-config / pkg-config libcurl are missing)
#       Downloads curl 8.11.1 and compiles it with --with-openssl pointing
#       to the OpenSSL built in Step 1. This gives git a working HTTP client.
#
#     Step 3 — git itself
#       Downloads git 2.51.0 from kernel.org and compiles it with the curl
#       and OpenSSL from above. The result includes git-remote-https in
#       ~/.local/libexec/git-core/, enabling clone/push over HTTPS.
#
#   After compilation, the script verifies that git-remote-https exists.
#   If any step fails, a warning is printed and the system git is kept.
#
# Testing:
#   The podman/ directory contains Docker-based validation for this script.
#   Both Ubuntu 22.04 and Rocky Linux 8 (GLIBC 2.28) are tested:
#
#     ./podman/run-tests.sh              # Run all tests (Ubuntu + Rocky)
#     ./podman/run-tests.sh ubuntu       # Run only Ubuntu test
#     ./podman/run-tests.sh rocky        # Run only Rocky test
#
#   Supports both docker and podman (auto-detected). Set GITHUB_PAT to avoid
#   rate limits during builds. See podman/validate.sh for the full test suite
#   (11 sections: binaries, versions, symlinks, logs, ZSH plugins, nvim Lazy,
#   git HTTPS, GLIBC tree-sitter compat, dry-run, fuzzy-kill, git status).
#
#   To build and run a single test container manually:
#     docker build --build-arg GITHUB_PAT="$GITHUB_PAT" \
#       -f podman/Dockerfile.test-ubuntu -t dotfiles-test-ubuntu .
#     docker run --rm dotfiles-test-ubuntu
#
###############################################################################
set -e

INSTALL_DIR="$HOME/.local"

# Parse command-line arguments
FORCE_UPDATE=false
DRY_RUN=false
for arg in "$@"; do
  case $arg in
    --force-update)
      FORCE_UPDATE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--force-update] [--dry-run]"
      exit 1
      ;;
  esac
done

INSTALL_BIN_DIR="$INSTALL_DIR/bin"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Setup logging
LOG_FILE="$HOME/.dotfiles-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "=== Install started at $(date) ==="

read -p $'\e[0;33mPress Enter to install all programs into '"$INSTALL_DIR"$' \033[0m'

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

# Scratch directory for downloads (cleaned up on exit)
SCRATCH_DIR=$(mktemp -d)
trap 'rm -rf "$SCRATCH_DIR"' EXIT

# Setup GitHub authentication if GITHUB_PAT is provided
if [ -n "${GITHUB_PAT:-}" ]; then
  GITHUB_AUTH_ARGS=(-H "Authorization: token ${GITHUB_PAT}")
  echo -e "${GREEN}Using GitHub Personal Access Token for API requests${NC}"
else
  GITHUB_AUTH_ARGS=()
  echo -e "${YELLOW}No GITHUB_PAT found - using unauthenticated GitHub API (rate limited)${NC}"
fi

###############################################################################
# Helper functions
###############################################################################

# Compare versions: returns 0 if $1 <= $2, 1 if $1 > $2
compare_versions() {
  if [ "$1" = "$2" ]; then
    return 0
  fi
  if [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; then
    return 0
  else
    return 1
  fi
}

# Prompt for update (respects --force-update)
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

# Get latest version tag from GitHub releases using jq
get_latest_version() {
  local repo=$1
  local strip_prefix=${2:-v}  # prefix to strip, default "v"
  local tag
  tag=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]+"${GITHUB_AUTH_ARGS[@]}"}" \
    "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
  if [ -z "$tag" ] || [ "$tag" = "null" ]; then
    echo ""
    return 1
  fi
  echo "$tag" | sed "s/^${strip_prefix}//"
}

# Install or update a tool via gah (GitHub Asset Helper)
# Usage: install_or_update_gah <name> <repo> <version_cmd>
install_or_update_gah() {
  local name=$1
  local repo=$2
  local version_cmd=$3

  if command -v "$name" >/dev/null 2>&1; then
    local current_version
    current_version=$(eval "$version_cmd" 2>/dev/null || echo "unknown")
    local latest_version
    latest_version=$(get_latest_version "$repo") || true

    echo -e "${GREEN}${name} exists (v${current_version}, latest: v${latest_version})${NC}"

    if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
      if prompt_update "$name" "$current_version" "$latest_version"; then
        if [ "$DRY_RUN" = true ]; then
          echo -e "${YELLOW}[DRY RUN] Would update $name to $latest_version via gah${NC}"
        else
          if ! gah install "$repo" --unattended; then
            echo -e "${YELLOW}Warning: Failed to update $name${NC}"
          else
            echo -e "${GREEN}${name} updated successfully!${NC}"
          fi
        fi
      fi
    fi
  else
    echo -e "${YELLOW}${name} does not exist, installing it...${NC}"
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would install $name via gah${NC}"
    else
      if ! gah install "$repo" --unattended; then
        echo -e "${YELLOW}Warning: Failed to install $name${NC}"
      fi
    fi
  fi
}

# Get GLIBC version
get_glibc_version() {
  ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1
}

# Fix tree-sitter for systems with GLIBC < 2.29
# The pre-built tree-sitter binary requires GLIBC >= 2.29. On older systems
# (e.g. RHEL 8 / CentOS 8 with GLIBC 2.28), we replace it with a compatible build.
fix_treesitter_glibc() {
  local glibc_version
  glibc_version=$(get_glibc_version)

  # compare_versions returns 0 (true) when $1 <= $2, so this triggers when glibc < 2.29
  if ! compare_versions "2.29" "$glibc_version"; then
    local mason_treesitter_dir="$HOME/.local/share/nvim/mason/packages/tree-sitter-cli"
    local compat_binary="${SCRIPT_DIR}/tree-sitter-glibc_2.28"

    if [ ! -f "$compat_binary" ]; then
      echo -e "${YELLOW}Warning: GLIBC ${glibc_version} detected but compatible tree-sitter binary not found at ${compat_binary}${NC}"
      return 0
    fi

    if [ -d "$mason_treesitter_dir" ]; then
      echo -e "${YELLOW}GLIBC ${glibc_version} < 2.29 detected, replacing tree-sitter with compatible build...${NC}"
      cp "$compat_binary" "$mason_treesitter_dir/tree-sitter-linux-x64"
      chmod +x "$mason_treesitter_dir/tree-sitter-linux-x64"
      echo -e "${GREEN}Tree-sitter compatibility fix applied!${NC}"
    else
      echo -e "${YELLOW}GLIBC ${glibc_version} < 2.29 detected but mason tree-sitter-cli not yet installed (will retry after plugin sync)${NC}"
    fi
  fi
}

# Ensure tree-sitter-cli is installed via mason, then apply GLIBC fix if needed.
# Called after Lazy sync since mason installs happen asynchronously during sync.
ensure_treesitter_glibc_fix() {
  local glibc_version
  glibc_version=$(get_glibc_version)

  # Only needed on systems with GLIBC < 2.29
  if compare_versions "2.29" "$glibc_version"; then
    return 0
  fi

  local mason_treesitter_dir="$HOME/.local/share/nvim/mason/packages/tree-sitter-cli"

  # If mason hasn't installed tree-sitter-cli yet, trigger it explicitly and wait
  if [ ! -d "$mason_treesitter_dir" ]; then
    echo -e "${YELLOW}GLIBC ${glibc_version} < 2.29: ensuring mason installs tree-sitter-cli...${NC}"
    nvim --headless +"lua require('lazy').load({ plugins = { 'mason.nvim' } })" +"MasonInstall tree-sitter-cli" +"sleep 15" +"qa" 2>&1 || true
  fi

  # Now apply the fix
  fix_treesitter_glibc
}

###############################################################################
# Tool installations
###############################################################################

# -- jq (installed first, used by get_latest_version) -------------------------
if command -v jq >/dev/null 2>&1; then
  current_version=$(jq --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  # jq is needed before get_latest_version works, so use raw curl+grep here
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]+"${GITHUB_AUTH_ARGS[@]}"}" \
    "https://api.github.com/repos/jqlang/jq/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^jq-//')

  echo -e "${GREEN}jq exists (v${current_version}, latest: v${latest_version})${NC}"

  if ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "jq" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update jq to ${latest_version}${NC}"
      else
        gah install jqlang/jq --unattended
        echo -e "${GREEN}jq updated successfully!${NC}"
      fi
    fi
  fi
else
  echo -e "${YELLOW}jq does not exist, installing it...${NC}"
  latest_version=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]+"${GITHUB_AUTH_ARGS[@]}"}" \
    "https://api.github.com/repos/jqlang/jq/releases/latest" | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^jq-//')
  if [ -z "$latest_version" ]; then
    echo -e "${RED}Failed to fetch jq version from GitHub API${NC}"
    exit 1
  fi
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install jq ${latest_version}${NC}"
  else
    if ! curl -o "$INSTALL_BIN_DIR/jq" -L "https://github.com/jqlang/jq/releases/download/jq-${latest_version}/jq-linux-amd64"; then
      echo -e "${RED}Failed to download jq${NC}"
      exit 1
    fi
    chmod +x "$INSTALL_BIN_DIR/jq"
  fi
fi

# -- gah (GitHub Asset Helper — needed for many installs below) ---------------
if command -v gah >/dev/null 2>&1; then
  current_version=$(gah version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(get_latest_version "marverix/gah") || true

  echo -e "${GREEN}gah exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "gah" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update gah${NC}"
      else
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/marverix/gah/refs/heads/master/tools/install.sh)"
        echo -e "${GREEN}gah updated successfully!${NC}"
      fi
    fi
  fi
else
  echo -e "${YELLOW}gah does not exist, installing it...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install gah${NC}"
  else
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/marverix/gah/refs/heads/master/tools/install.sh)"
  fi
fi

# -- 7zip ---------------------------------------------------------------------
SEVENZIP_VERSION="26.00"

if command -v 7zz >/dev/null 2>&1; then
  current_version=$(7zz | grep 7-Zip | awk '{print $3}' | grep -oE '[0-9]+\.[0-9]+')

  echo -e "${GREEN}7zip exists (v${current_version}, latest: v${SEVENZIP_VERSION})${NC}"

  if ! compare_versions "$SEVENZIP_VERSION" "$current_version"; then
    if prompt_update "7zip" "$current_version" "$SEVENZIP_VERSION"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update 7zip to ${SEVENZIP_VERSION}${NC}"
      else
        local_version_no_dot=$(echo "$SEVENZIP_VERSION" | tr -d '.')
        curl -fL -o "$SCRATCH_DIR/7z${local_version_no_dot}-linux-x64.tar.xz" "https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION}/7z${local_version_no_dot}-linux-x64.tar.xz"
        tar -xf "$SCRATCH_DIR/7z${local_version_no_dot}-linux-x64.tar.xz" -C "$SCRATCH_DIR" 7zz
        chmod +x "$SCRATCH_DIR/7zz" && mv "$SCRATCH_DIR/7zz" "$INSTALL_BIN_DIR"
        echo -e "${GREEN}7zip updated successfully!${NC}"
      fi
    fi
  fi
else
  version_no_dot=$(echo "$SEVENZIP_VERSION" | tr -d '.')

  echo "7zip does not exist, installing ${SEVENZIP_VERSION}..."

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install 7zip ${SEVENZIP_VERSION}${NC}"
  else
    if ! curl -fL -o "$SCRATCH_DIR/7z${version_no_dot}-linux-x64.tar.xz" "https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION}/7z${version_no_dot}-linux-x64.tar.xz"; then
      echo -e "${RED}Failed to download 7zip${NC}"
      exit 1
    fi
    tar -xf "$SCRATCH_DIR/7z${version_no_dot}-linux-x64.tar.xz" -C "$SCRATCH_DIR" 7zz
    chmod +x "$SCRATCH_DIR/7zz" && mv "$SCRATCH_DIR/7zz" "$INSTALL_BIN_DIR"
  fi
fi

# -- curl (check only) -------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  curl_version=$(curl --version | head -n 1 | awk '{print $2}')
  echo "Curl version ${curl_version} installed"
else
  echo "curl is not installed"
  exit 1
fi

# -- NeoVim -------------------------------------------------------------------
if command -v nvim >/dev/null 2>&1; then
  current_version=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(get_latest_version "neovim/neovim-releases") || true

  echo -e "${GREEN}NeoVim exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "NeoVim" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update NeoVim to ${latest_version}${NC}"
      else
        nvim_archive=nvim-linux-x86_64.tar.gz
        curl -fL -o "$SCRATCH_DIR/${nvim_archive}" "https://github.com/neovim/neovim-releases/releases/download/v${latest_version}/${nvim_archive}"
        tar -xf "$SCRATCH_DIR/${nvim_archive}" --strip-components=1 -C "$INSTALL_DIR"
        echo -e "${GREEN}NeoVim updated successfully!${NC}"
        fix_treesitter_glibc
      fi
    fi
  fi
else
  version=$(get_latest_version "neovim/neovim-releases") || true
  if [ -z "$version" ]; then
    echo -e "${RED}Failed to fetch NeoVim version from GitHub API${NC}"
    exit 1
  fi

  echo "NeoVim does not exist, installing v${version}..."

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install NeoVim ${version}${NC}"
  else
    nvim_archive=nvim-linux-x86_64.tar.gz
    if ! curl -fL -o "$SCRATCH_DIR/${nvim_archive}" "https://github.com/neovim/neovim-releases/releases/download/v${version}/${nvim_archive}"; then
      echo -e "${RED}Failed to download NeoVim${NC}"
      exit 1
    fi
    tar -xf "$SCRATCH_DIR/${nvim_archive}" --strip-components=1 -C "$INSTALL_DIR"
    fix_treesitter_glibc
  fi
fi

# -- ZSH ----------------------------------------------------------------------
if command -v zsh >/dev/null 2>&1; then
  echo -e "${GREEN}ZSH exists ($(zsh --version))${NC}"
else
  echo -e "${YELLOW}ZSH does not exist, installing it...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install ZSH${NC}"
  else
    bash <(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install) -d "$INSTALL_DIR" -e yes
  fi
fi

# -- gah-based tools (DRY: all follow the same pattern) -----------------------
install_or_update_gah "fd" "sharkdp/fd" \
  "fd --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

# -- sshs (direct binary download, not gah) -----------------------------------
if command -v sshs >/dev/null 2>&1; then
  current_version=$(sshs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(get_latest_version "quantumsheep/sshs") || true

  echo -e "${GREEN}sshs exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "sshs" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update sshs to ${latest_version}${NC}"
      else
        if ! curl -fsSL -o "$INSTALL_BIN_DIR/sshs" "https://github.com/quantumsheep/sshs/releases/download/${latest_version}/sshs-linux-amd64-musl"; then
          echo -e "${RED}Failed to download sshs${NC}"
        else
          chmod +x "$INSTALL_BIN_DIR/sshs"
          echo -e "${GREEN}sshs updated successfully!${NC}"
        fi
      fi
    fi
  fi
else
  latest_version=$(get_latest_version "quantumsheep/sshs") || true
  if [ -z "$latest_version" ]; then
    echo -e "${YELLOW}Warning: Failed to fetch sshs version from GitHub API, skipping${NC}"
  else
    echo -e "${YELLOW}sshs does not exist, installing v${latest_version} (musl)...${NC}"
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would install sshs ${latest_version}${NC}"
    else
      if ! curl -fsSL -o "$INSTALL_BIN_DIR/sshs" "https://github.com/quantumsheep/sshs/releases/download/${latest_version}/sshs-linux-amd64-musl"; then
        echo -e "${YELLOW}Warning: Failed to download sshs${NC}"
      else
        chmod +x "$INSTALL_BIN_DIR/sshs"
      fi
    fi
  fi
fi

install_or_update_gah "rg" "BurntSushi/ripgrep" \
  "rg --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

install_or_update_gah "lstr" "bgreenwell/lstr" \
  "lstr --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

# -- fzf (git clone based) ----------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
  current_version=$(fzf --version | awk '{print $1}')
  latest_version=$(get_latest_version "junegunn/fzf") || true

  echo -e "${GREEN}fzf exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "fzf" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update fzf to ${latest_version}${NC}"
      else
        if [ -d "$INSTALL_DIR/fzf" ]; then
          (cd "$INSTALL_DIR/fzf" && git fetch --depth 1 origin && git checkout FETCH_HEAD)
        else
          rm -rf "$INSTALL_DIR/fzf"
          git clone -q --depth 1 https://github.com/junegunn/fzf.git "$INSTALL_DIR/fzf"
        fi
        "$INSTALL_DIR/fzf/install" --key-bindings --completion --update-rc
        echo -e "${GREEN}fzf updated successfully!${NC}"
      fi
    fi
  fi
else
  echo -e "${YELLOW}Installing fzf${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install fzf${NC}"
  else
    git clone -q --depth 1 https://github.com/junegunn/fzf.git "$INSTALL_DIR/fzf"
    "$INSTALL_DIR/fzf/install" --key-bindings --completion --update-rc
  fi
fi

# -- htop (build from source) -------------------------------------------------
if command -v htop >/dev/null 2>&1; then
  current_version=$(htop --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(get_latest_version "htop-dev/htop" "") || true

  echo -e "${GREEN}htop exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "htop" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update htop to ${latest_version}${NC}"
      else
        curl --progress-bar -fL -o "$SCRATCH_DIR/htop-${latest_version}.tar.xz" "https://github.com/htop-dev/htop/releases/download/${latest_version}/htop-${latest_version}.tar.xz"
        (
          cd "$SCRATCH_DIR"
          tar -xf "htop-${latest_version}.tar.xz"
          cd "htop-${latest_version}"
          ./autogen.sh >/dev/null && ./configure --prefix="$INSTALL_DIR" >/dev/null && make >/dev/null && make install >/dev/null
        )
        echo -e "${GREEN}htop updated successfully!${NC}"
      fi
    fi
  fi
else
  version=$(get_latest_version "htop-dev/htop" "") || true
  echo -e "${YELLOW}Installing htop ${version}${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install htop ${version}${NC}"
  else
    curl --progress-bar -fL -o "$SCRATCH_DIR/htop-${version}.tar.xz" "https://github.com/htop-dev/htop/releases/download/${version}/htop-${version}.tar.xz"
    (
      cd "$SCRATCH_DIR"
      tar -xf "htop-${version}.tar.xz"
      cd "htop-${version}"
      ./autogen.sh >/dev/null && ./configure --prefix="$INSTALL_DIR" >/dev/null && make >/dev/null && make install >/dev/null
    )
  fi
fi

# if command -v btop >/dev/null 2>&1; then
#   current_version=$(btop --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
#   latest_version=$(get_latest_version "aristocratos/btop") || true
#
#   echo -e "${GREEN}btop exists (v${current_version}, latest: v${latest_version})${NC}"
#
#   if ! compare_versions "$latest_version" "$current_version"; then
#     if prompt_update "btop" "$current_version" "$latest_version"; then
#       echo "Updating btop to ${latest_version}..."
#       curl --progress-bar -fL -o "$SCRATCH_DIR/btop-x86_64-linux-musl.tbz" "https://github.com/aristocratos/btop/releases/download/v${latest_version}/btop-x86_64-linux-musl.tbz"
#       (
#         cd "$SCRATCH_DIR"
#         tar -xf btop-x86_64-linux-musl.tbz
#         cd btop
#         PREFIX=~/.local make install
#       )
#       echo -e "${GREEN}btop updated successfully!${NC}"
#     fi
#   fi
# else
#   version=$(get_latest_version "aristocratos/btop") || true
#   echo -e "${YELLOW}Installing btop ${version}${NC}"
#
#   curl --progress-bar -fL -o "$SCRATCH_DIR/btop-x86_64-linux-musl.tbz" "https://github.com/aristocratos/btop/releases/download/${version}/btop-x86_64-linux-musl.tbz"
#   (
#     cd "$SCRATCH_DIR"
#     tar -xf btop-x86_64-linux-musl.tbz
#     cd btop
#     PREFIX=~/.local make install
#   )
# fi

# if command -v bfs >/dev/null 2>&1; then
#   current_version=$(bfs --version | grep "bfs " | grep -oE '[0-9]+\.[0-9]+')
#   latest_version=$(get_latest_version "tavianator/bfs" "") || true
#
#   echo -e "${GREEN}bfs exists (v${current_version}, latest: v${latest_version})${NC}"
#
#   if ! compare_versions "$latest_version" "$current_version"; then
#     if prompt_update "bfs" "$current_version" "$latest_version"; then
#       echo "Updating bfs to ${latest_version}..."
#       curl --progress-bar -fL -o "$SCRATCH_DIR/${latest_version}.zip" "https://github.com/tavianator/bfs/archive/refs/tags/${latest_version}.zip"
#       (
#         cd "$SCRATCH_DIR"
#         7zz x "${latest_version}.zip"
#         cd "bfs-${latest_version}"
#         ./configure --enable-release --mandir="$HOME/.local/man" --prefix="$HOME/.local"
#         make -j$(nproc) >/dev/null
#         make install
#       )
#       echo -e "${GREEN}bfs updated successfully!${NC}"
#     fi
#   fi
# else
#   version=$(get_latest_version "tavianator/bfs" "") || true
#   echo -e "${YELLOW}Installing bfs ${version}${NC}"
#
#   curl --progress-bar -fL -o "$SCRATCH_DIR/${version}.zip" "https://github.com/tavianator/bfs/archive/refs/tags/${version}.zip"
#   (
#     cd "$SCRATCH_DIR"
#     7zz x "${version}.zip"
#     cd "bfs-${version}"
#     ./configure --enable-release --mandir="$HOME/.local/man" --prefix="$HOME/.local"
#     make -j$(nproc) >/dev/null
#     make install
#   )
# fi

# -- broot (with update support) ----------------------------------------------
if command -v broot >/dev/null 2>&1; then
  current_version=$(broot --version | awk '{print $2}')
  echo -e "${GREEN}broot exists (v${current_version})${NC}"

  # broot updates itself from the official download URL
  if [ "$FORCE_UPDATE" = true ]; then
    echo -e "${YELLOW}Force-updating broot...${NC}"
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would update broot${NC}"
    else
      curl --progress-bar -fL -o "$SCRATCH_DIR/broot" https://dystroy.org/broot/download/x86_64-unknown-linux-musl/broot
      chmod +x "$SCRATCH_DIR/broot"
      mv "$SCRATCH_DIR/broot" "$INSTALL_BIN_DIR"
      echo -e "${GREEN}broot updated to $(broot --version | awk '{print $2}')${NC}"
    fi
  fi
else
  echo -e "${YELLOW}Installing broot latest version${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install broot${NC}"
  else
    curl --progress-bar -fL -o "$SCRATCH_DIR/broot" https://dystroy.org/broot/download/x86_64-unknown-linux-musl/broot
    chmod +x "$SCRATCH_DIR/broot"
    mv "$SCRATCH_DIR/broot" "$INSTALL_BIN_DIR"
    broot --version
  fi
fi

# -- zoxide (with update support) ---------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
  current_version=$(zoxide --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo -e "${GREEN}zoxide exists (v${current_version})${NC}"

  if [ "$FORCE_UPDATE" = true ]; then
    echo -e "${YELLOW}Force-updating zoxide...${NC}"
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would update zoxide${NC}"
    else
      curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- --bin-dir "$INSTALL_BIN_DIR"
      echo -e "${GREEN}zoxide updated to $(zoxide --version)${NC}"
    fi
  fi
else
  echo "Installing zoxide"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install zoxide${NC}"
  else
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- --bin-dir "$INSTALL_BIN_DIR"
  fi
fi

install_or_update_gah "bat" "sharkdp/bat" \
  "bat --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

install_or_update_gah "eza" "eza-community/eza" \
  "eza --version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//'"

# -- gdu (direct binary download) ---------------------------------------------
if command -v gdu >/dev/null 2>&1; then
  current_version=$(gdu --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(get_latest_version "dundee/gdu") || true

  echo -e "${GREEN}gdu exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "gdu" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update gdu to ${latest_version}${NC}"
      else
        if ! curl -fsSL -o "$SCRATCH_DIR/gdu_linux_amd64_static.tgz" "https://github.com/dundee/gdu/releases/download/v${latest_version}/gdu_linux_amd64_static.tgz"; then
          echo -e "${YELLOW}Warning: Failed to download gdu${NC}"
        else
          tar -xzf "$SCRATCH_DIR/gdu_linux_amd64_static.tgz" -C "$SCRATCH_DIR" gdu_linux_amd64_static
          mv "$SCRATCH_DIR/gdu_linux_amd64_static" "$INSTALL_BIN_DIR/gdu"
          chmod +x "$INSTALL_BIN_DIR/gdu"
          echo -e "${GREEN}gdu updated successfully!${NC}"
        fi
      fi
    fi
  fi
else
  latest_version=$(get_latest_version "dundee/gdu") || true
  if [ -z "$latest_version" ]; then
    echo -e "${YELLOW}Warning: Failed to fetch gdu version from GitHub API, skipping${NC}"
  else
    echo -e "${YELLOW}gdu does not exist, installing v${latest_version} (static)...${NC}"
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would install gdu ${latest_version}${NC}"
    else
      if ! curl -fsSL -o "$SCRATCH_DIR/gdu_linux_amd64_static.tgz" "https://github.com/dundee/gdu/releases/download/v${latest_version}/gdu_linux_amd64_static.tgz"; then
        echo -e "${YELLOW}Warning: Failed to download gdu${NC}"
      else
        tar -xzf "$SCRATCH_DIR/gdu_linux_amd64_static.tgz" -C "$SCRATCH_DIR" gdu_linux_amd64_static
        mv "$SCRATCH_DIR/gdu_linux_amd64_static" "$INSTALL_BIN_DIR/gdu"
        chmod +x "$INSTALL_BIN_DIR/gdu"
      fi
    fi
  fi
fi

###############################################################################
# Guards: curl wrapper and tar wrapper for restricted environments
###############################################################################

# Guard: check if github.com/archive/{sha}.tar.gz returns 404.
# Some networks/servers return 404 for this URL format; codeload.github.com
# is the canonical equivalent and always works.
_probe_sha="a06c2e4415e9bc0346c6b86d401879ffb44058f7"
_probe_url="https://github.com/tree-sitter/tree-sitter-bash/archive/${_probe_sha}.tar.gz"
if ! curl -sf "${GITHUB_AUTH_ARGS[@]+"${GITHUB_AUTH_ARGS[@]}"}" --head "$_probe_url" >/dev/null 2>&1; then
  echo "GitHub archive URLs return 404 on this system; installing curl wrapper..."
  if [ ! -f "$INSTALL_BIN_DIR/curl-real" ]; then
    if [ -f "$INSTALL_BIN_DIR/curl" ]; then
      # Only wrap if the existing binary is NOT already our wrapper
      if ! grep -q "curl-real" "$INSTALL_BIN_DIR/curl" 2>/dev/null; then
        mv "$INSTALL_BIN_DIR/curl" "$INSTALL_BIN_DIR/curl-real"
      fi
    else
      ln -sf "$(command -v curl)" "$INSTALL_BIN_DIR/curl-real"
    fi
  fi
  cat > "$INSTALL_BIN_DIR/curl" << 'CURL_WRAPPER'
#!/bin/bash
# Rewrite github.com/{owner}/{repo}/archive/{sha}.tar.gz
# to codeload.github.com/{owner}/{repo}/tar.gz/{sha}
ARGS=()
for arg in "$@"; do
  if [[ "$arg" =~ ^https://github\.com/([^/]+)/([^/]+)/archive/([^/]+)\.tar\.gz$ ]]; then
    ARGS+=("https://codeload.github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/tar.gz/${BASH_REMATCH[3]}")
  else
    ARGS+=("$arg")
  fi
done
exec "$(dirname "$0")/curl-real" "${ARGS[@]}"
CURL_WRAPPER
  chmod +x "$INSTALL_BIN_DIR/curl"
fi

# Guard: check if setting file timestamps is restricted (container environments).
# tar extractions fail with "Cannot utime: Operation not permitted" when the
# kernel disallows utime calls, requiring --touch to skip timestamp restoration.
_utime_test=$(mktemp)
if ! touch -t 200001010000 "$_utime_test" 2>/dev/null; then
  echo "File timestamp changes restricted on this system; installing tar wrapper..."
  # Export TAR_OPTIONS so ALL tar invocations (including those from nvim-treesitter
  # and other tools that call tar internally) automatically get --touch.
  export TAR_OPTIONS="--no-same-owner --touch"
  cat > "$INSTALL_BIN_DIR/tar" << 'TAR_WRAPPER'
#!/bin/bash
ARGS=()
is_extract=false
has_touch=false
for arg in "$@"; do
  case "$arg" in
    -x*|--extract|--get) is_extract=true ;;
    --touch|-m) has_touch=true ;;
  esac
  [[ "$arg" =~ ^-[a-zA-Z]*x[a-zA-Z]* ]] && is_extract=true
  ARGS+=("$arg")
done
[[ "$is_extract" == "true" && "$has_touch" == "false" ]] && ARGS+=("--touch")
exec /usr/bin/tar "${ARGS[@]}"
TAR_WRAPPER
  chmod +x "$INSTALL_BIN_DIR/tar"
fi
rm -f "$_utime_test"

###############################################################################
# Git compilation (if lazygit needs git >= 2.32)
#
# Builds git from source with HTTPS support via a 3-step dependency chain:
#   1. OpenSSL  (only if system headers are missing)
#   2. libcurl  (only if curl-config / pkg-config libcurl are missing)
#   3. git      (compiled against the above, producing git-remote-https)
#
# Everything is installed to $INSTALL_DIR (~/.local) — no root required.
# See the file header for a detailed explanation.
###############################################################################

git_version=$(git --version | awk '{print $3}')
if [ "$(printf '%s\n' "2.32" "$git_version" | sort -V | head -n1)" = "$git_version" ] && [ "$git_version" != "2.32" ]; then
  echo "Your git version ($git_version) is below 2.32 (required by lazygit). Do you want to update git from source? [y/N]"
  read -r update_git
  if [ "$update_git" = "y" ] || [ "$update_git" = "Y" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would compile git from source${NC}"
    else
      export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig:$INSTALL_DIR/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
      LOCAL_LDFLAGS="-L$INSTALL_DIR/lib -L$INSTALL_DIR/lib64 -Wl,-rpath,$INSTALL_DIR/lib -Wl,-rpath,$INSTALL_DIR/lib64"
      export CPPFLAGS="-I$INSTALL_DIR/include"

      # Step 1: compile OpenSSL if headers are missing (required by curl for HTTPS)
      if ! pkg-config --exists openssl 2>/dev/null && ! [ -f /usr/include/openssl/ssl.h ]; then
        echo "OpenSSL headers not found; compiling OpenSSL from source..."
        openssl_src_version="1.1.1w"
        wget -P "$SCRATCH_DIR" "https://www.openssl.org/source/openssl-${openssl_src_version}.tar.gz"
        (
          cd "$SCRATCH_DIR"
          tar -xzf "openssl-${openssl_src_version}.tar.gz"
          cd "openssl-${openssl_src_version}"
          ./config --prefix="$INSTALL_DIR" --openssldir="$INSTALL_DIR/ssl" \
            shared no-tests
          make -j"$(nproc)"
          make install_sw
        ) || echo -e "${YELLOW}Warning: OpenSSL compilation failed; git may lack HTTPS support.${NC}"
      fi

      # Step 2: compile curl if headers are missing (required by git for HTTPS)
      if ! curl-config --libs >/dev/null 2>&1 && ! pkg-config --exists libcurl 2>/dev/null; then
        echo "libcurl-dev not found; compiling curl from source for HTTPS support..."
        curl_src_version="8.11.1"
        wget -P "$SCRATCH_DIR" "https://curl.se/download/curl-${curl_src_version}.tar.gz"
        (
          cd "$SCRATCH_DIR"
          tar -xzf "curl-${curl_src_version}.tar.gz"
          cd "curl-${curl_src_version}"
          LDFLAGS="$LOCAL_LDFLAGS" \
          ./configure --prefix="$INSTALL_DIR" --with-openssl \
            --without-libpsl --without-brotli --without-zstd --disable-ldap
          make -j"$(nproc)" install
        ) || echo -e "${YELLOW}Warning: curl compilation failed; git may lack HTTPS support.${NC}"
        export PATH="$INSTALL_BIN_DIR:$PATH"
      fi

      # Step 3: compile git
      git_new_version="2.51.0"
      wget -P "$SCRATCH_DIR" "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${git_new_version}.tar.gz"
      (
        cd "$SCRATCH_DIR"
        tar -xzf "git-${git_new_version}.tar.gz"
        cd "git-${git_new_version}"
        LDFLAGS="$LOCAL_LDFLAGS" \
        ./configure --without-tcltk --prefix="$INSTALL_DIR"
        make NO_GETTEXT=1 NO_TCLTK=1 install
      )
      echo "Git ${git_new_version} installed to $INSTALL_BIN_DIR"

      # Verify HTTPS support
      if ! ls "$INSTALL_DIR/libexec/git-core/git-remote-https" >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: git was compiled without HTTPS support.${NC}"
        echo -e "${YELLOW}Re-run install-minimal.sh to retry.${NC}"
      fi
    fi
  fi
fi

install_or_update_gah "lazygit" "jesseduffield/lazygit" \
  "lazygit --version | grep -oP 'version=\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1"

install_or_update_gah "lazydocker" "jesseduffield/lazydocker" \
  "lazydocker --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

install_or_update_gah "zellij" "zellij-org/zellij" \
  "zellij --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

# Install fuzzy-kill (fuzzy process finder and killer)
if [ -f "${SCRIPT_DIR}/bin/fuzzy-kill" ]; then
  echo -e "${GREEN}Installing fuzzy-kill...${NC}"
  ln -sf "${SCRIPT_DIR}/bin/fuzzy-kill" "$INSTALL_BIN_DIR/fuzzy-kill"
  ln -sf "${SCRIPT_DIR}/bin/fuzzy-kill" "$INSTALL_BIN_DIR/fk" # Short alias
  chmod +x "${SCRIPT_DIR}/bin/fuzzy-kill"
  echo -e "${GREEN}fuzzy-kill installed (alias: fk)${NC}"
fi

###############################################################################
# Node.js via fnm
###############################################################################

if command -v node >/dev/null 2>&1; then
  echo -e "${GREEN}node exists ($(node -v))${NC}"
else
  echo -e "${YELLOW}Installing fnm${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install fnm and Node.js${NC}"
  else
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
      echo -e "${RED}FNM not installed${NC}"
    fi
  fi
fi

# Install npm packages required by nvim mason (markdown + treesitter tooling)
if command -v npm >/dev/null 2>&1; then
  echo -e "${GREEN}Installing npm packages for nvim (tree-sitter-cli, markdownlint-cli2, markdown-toc)...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install npm packages${NC}"
  else
    npm install -g tree-sitter-cli markdownlint-cli2 markdown-toc
  fi
else
  echo -e "${YELLOW}npm not found, skipping tree-sitter-cli/markdownlint-cli2/markdown-toc${NC}"
fi

###############################################################################
# Symlinks and plugin installation
###############################################################################

echo -ne "\nCreate Vim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
  if [ -f "$HOME/.vimrc" ]; then
    mv "$HOME/.vimrc" "$HOME/.vimrc_orig"
  fi
  if [ -f "$HOME/.vimcommon" ]; then
    mv "$HOME/.vimcommon" "$HOME/.vimcommon_orig"
  fi
  ln -sf "${SCRIPT_DIR}/vim/.vimrc" "$HOME/.vimrc"
  ln -sf "${SCRIPT_DIR}/vim/.vimcommon" "$HOME/.vimcommon"
  echo -e "\t${GREEN}Symlinks created!${NC}"

  # Install vim-plug and plugins
  echo -e "${GREEN}Installing vim plugins (this may take a moment)...${NC}"
  vim +'PlugInstall --sync' +qall
  echo -e "\t${GREEN}Vim plugins installed!${NC}"
else
  echo "You can create Vim symlinks as:"
  echo "ln -sf ${SCRIPT_DIR}/vim/.vimrc $HOME/.vimrc && ln -sf ${SCRIPT_DIR}/vim/.vimcommon $HOME/.vimcommon"
fi

echo -ne "\nCreate NeoVim symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
  mkdir -p "$HOME/.config"
  ln -sfn "${SCRIPT_DIR}/nvim" "$HOME/.config/nvim"
  echo -e "\t${GREEN}Symlinks created!${NC}"

  # Install nvim plugins via lazy.nvim
  echo -e "${GREEN}Installing nvim plugins (this may take a moment)...${NC}"
  nvim --headless -c "Lazy! sync" -c "qa" 2>&1 || true
  echo -e "\t${GREEN}Nvim plugins installed!${NC}"

  # On old GLIBC systems, ensure mason's tree-sitter-cli is replaced with a compatible build.
  # Uses ensure_treesitter_glibc_fix which will trigger MasonInstall if the dir doesn't exist yet.
  ensure_treesitter_glibc_fix
else
  echo "You can create NeoVim symlinks as:"
  echo "ln -sfn ${SCRIPT_DIR}/nvim $HOME/.config/nvim"
fi

echo -ne "\nCreate Git config symlinks? (Y/n): "
read answer
answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
if [[ "$answer" == "y" || -z "$answer" ]]; then
  if [ -f "$HOME/.gitconfig" ]; then
    mv "$HOME/.gitconfig" "$HOME/.gitconfig_orig"
  fi
  ln -sf "${SCRIPT_DIR}/git/.gitconfig" "$HOME/.gitconfig"
  echo -e "\t${GREEN}Symlinks created!${NC}"
fi

if command -v zellij >/dev/null 2>&1; then
  echo -e "${GREEN}zellij exists${NC}"

  echo -ne "Create Zellij symlinks? (Y/n): "
  read answer
  answer=$(tr "[A-Z]" "[a-z]" <<<"$answer")
  if [[ "$answer" == "y" || -z "$answer" ]]; then
    mkdir -p "$HOME/.config"
    ln -sfn "${SCRIPT_DIR}/zellij" "$HOME/.config/zellij"
    echo -e "\t${GREEN}Symlinks created!${NC}"
  else
    echo "You can create Zellij symlinks as:"
    echo "ln -sfn ${SCRIPT_DIR}/zellij $HOME/.config/zellij"
  fi
fi

###############################################################################
# ZSH and Oh My ZSH
###############################################################################

# install oh my ZSH
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo -e "${YELLOW}$HOME/.oh-my-zsh does exist. Skipping installing oh-my-zsh${NC}"
else
  echo -e "Installing oh-my-zsh${NC}"
  #   CHSH       - 'no' means the installer will not change the default shell (default: yes)
  #   RUNZSH     - 'no' means the installer will not run zsh after the install (default: yes)
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# install oh my ZSH plugins, must be after installing oh-my-zsh
install_zsh_plugin() {
  local url=$1
  local install_path=$2
  local plugin_name
  plugin_name=$(basename "$2")

  if [ ! -d "$2" ]; then
    echo -e "${GREEN}Installing $plugin_name${NC}"
    git clone -q --depth=1 "$1" "$2"
  else
    echo -e "${YELLOW}${plugin_name} already installed${NC}"
  fi
}

install_zsh_plugin https://github.com/Aloxaf/fzf-tab "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab"
install_zsh_plugin https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
install_zsh_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
install_zsh_plugin https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-vi-mode"
install_zsh_plugin https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

echo -e "\n${YELLOW}Creating symlinks for zsh and p10k...${NC}"
if [ -f "$HOME/.zshrc" ]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc_orig"
fi

if [ -f "$HOME/.p10k.zsh" ]; then
  mv "$HOME/.p10k.zsh" "$HOME/.p10k.zsh_orig"
fi

ln -sf "${SCRIPT_DIR}/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "${SCRIPT_DIR}/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

echo ""
echo "=== Install finished at $(date) ==="
echo -e "\n${GREEN}Installation completed!${NC}"
read -p "Press Enter to run zsh!"
source "$HOME/.bashrc"
# run ZSH and configure p10k
zsh -c "source $HOME/.zshrc &&  echo -e \"\n\e[0;33mTo configure p10k run: p10k configure \033[0m\" ; zsh"
