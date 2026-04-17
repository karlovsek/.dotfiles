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
ASSUME_YES=${ASSUME_YES:-false}
for arg in "$@"; do
  case $arg in
    --force-update)
      FORCE_UPDATE=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --yes|-y)
      ASSUME_YES=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--force-update] [--dry-run] [--yes]"
      exit 1
      ;;
  esac
done

# If stdin is not a TTY (CI, piped install, container), default to --yes so
# read prompts don't hang the script.
if [ ! -t 0 ]; then
  ASSUME_YES=true
fi
export ASSUME_YES

INSTALL_BIN_DIR="$INSTALL_DIR/bin"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Setup logging
LOG_FILE="$HOME/.dotfiles-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "=== Install started at $(date) ==="

if [ "$ASSUME_YES" != true ]; then
  read -r -p $'\e[0;33mPress Enter to install all programs into '"$INSTALL_DIR"$' \033[0m' _
fi

mkdir -p "$INSTALL_BIN_DIR"

export PATH="$PATH:$INSTALL_BIN_DIR"

if ! grep -qF "${INSTALL_BIN_DIR}" "$HOME/.bashrc" 2>/dev/null; then
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
  # Export the standard env var so downstream installers (gah, etc.) that
  # respect GITHUB_TOKEN also authenticate and avoid the 60/hour unauth limit.
  export GITHUB_TOKEN="${GITHUB_TOKEN:-$GITHUB_PAT}"
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

# Read a yes/no answer with a prompt. Defaults to "yes" when stdin is not a
# TTY (e.g., CI / piped installs) so the script doesn't hang. $1 is the prompt
# text, $2 is the default ("y" or "n"). Returns 0 for yes, 1 for no.
confirm_yn() {
  local prompt=$1
  local default=${2:-y}
  local answer=""

  if [ ! -t 0 ] || [ "${ASSUME_YES:-false}" = true ]; then
    echo "${prompt}(non-interactive: defaulting to ${default})"
    [ "$default" = "y" ]
    return
  fi

  echo -ne "$prompt"
  read -r answer
  answer=$(tr '[:upper:]' '[:lower:]' <<<"$answer")
  if [ -z "$answer" ]; then
    answer=$default
  fi
  [ "$answer" = "y" ] || [ "$answer" = "yes" ]
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

  confirm_yn "Update $tool_name? (Y/n): " y
}

# Get latest version tag from GitHub releases using jq.
# Pass empty string as $2 to skip prefix stripping (note the single-dash in
# ${2-v} — this treats unset and empty differently, unlike ${2:-v}).
get_latest_version() {
  local repo=$1
  local strip_prefix=${2-v}  # prefix to strip; unset => "v", empty => no strip
  local tag
  tag=$(curl -fsSL "${GITHUB_AUTH_ARGS[@]+"${GITHUB_AUTH_ARGS[@]}"}" \
    "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
  if [ -z "$tag" ] || [ "$tag" = "null" ]; then
    echo ""
    return 1
  fi
  if [ -n "$strip_prefix" ]; then
    echo "${tag#"$strip_prefix"}"
  else
    echo "$tag"
  fi
}

# Install or update a tool via gah (GitHub Asset Helper)
# Usage: install_or_update_gah <name> <repo> <version_cmd>
install_or_update_gah() {
  local name=$1
  local repo=$2
  local version_cmd=$3

  # Guard: gah itself must exist (or be a planned dry-run install) before we
  # try to install/update tools through it.
  if ! command -v gah >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] gah not installed; would install $name via gah${NC}"
      return 0
    else
      echo -e "${YELLOW}Warning: gah not found on PATH; skipping $name${NC}"
      return 0
    fi
  fi

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

# Fix tree-sitter for systems with old GLIBC.
# Pre-built tree-sitter binaries (npm and mason) require GLIBC >= 2.29.
# On older systems (e.g. RHEL 8 / Rocky 8 with GLIBC 2.28), we replace ALL
# copies with a compatible build stored in the repo as tree-sitter-glibc_2.28.
fix_treesitter_glibc() {
  local glibc_version
  glibc_version=$(get_glibc_version)

  # compare_versions returns 0 (true) when $1 <= $2, so this triggers when glibc < 2.29
  if ! compare_versions "2.29" "$glibc_version"; then
    local compat_binary="${SCRIPT_DIR}/tree-sitter-glibc_2.28"

    if [ ! -f "$compat_binary" ]; then
      echo -e "${YELLOW}Warning: GLIBC ${glibc_version} detected but compatible tree-sitter binary not found at ${compat_binary}${NC}"
      return 0
    fi

    echo -e "${YELLOW}GLIBC ${glibc_version} < 2.29: replacing tree-sitter binaries with compatible build...${NC}"

    # 1. Put compat binary on PATH so nvim-treesitter / tree-sitter-manager finds it
    cp "$compat_binary" "$INSTALL_BIN_DIR/tree-sitter"
    chmod +x "$INSTALL_BIN_DIR/tree-sitter"
    echo -e "${GREEN}  Installed to $INSTALL_BIN_DIR/tree-sitter${NC}"

    # 2. Replace the npm tree-sitter-cli binary (nvim-treesitter calls it by full path)
    local npm_ts_bin
    npm_ts_bin=$(find "$HOME" -path "*/node_modules/tree-sitter-cli/tree-sitter" -type f 2>/dev/null | head -1)
    if [ -n "$npm_ts_bin" ]; then
      cp "$compat_binary" "$npm_ts_bin"
      chmod +x "$npm_ts_bin"
      echo -e "${GREEN}  Replaced npm binary: $npm_ts_bin${NC}"
    fi

    # 3. Replace mason's copy if it exists
    local mason_treesitter_dir="$HOME/.local/share/nvim/mason/packages/tree-sitter-cli"
    if [ -d "$mason_treesitter_dir" ]; then
      cp "$compat_binary" "$mason_treesitter_dir/tree-sitter-linux-x64"
      chmod +x "$mason_treesitter_dir/tree-sitter-linux-x64"
      echo -e "${GREEN}  Replaced mason binary${NC}"
    fi

    echo -e "${GREEN}Tree-sitter GLIBC compatibility fix applied!${NC}"
  fi
}

# Compile git from source (with HTTPS support) if the system git is below
# 2.32 — required by lazygit and by several repos cloned later in this script.
# Must be called BEFORE the first `git clone` in the script.
#
# 3-step chain, all installed to $INSTALL_DIR:
#   1. OpenSSL  (only if system headers are missing)
#   2. libcurl  (only if curl-config / pkg-config libcurl are missing)
#   3. git      (compiled against the above, producing git-remote-https)
compile_git_if_needed() {
  local git_version
  git_version=$(git --version 2>/dev/null | awk '{print $3}')

  # compare_versions returns 0 when $1 <= $2; we want to trigger when
  # git_version < "2.32" (strict less-than).
  if [ -n "$git_version" ] && [ "$git_version" != "2.32" ] \
     && compare_versions "$git_version" "2.32"; then
    :
  else
    return 0
  fi

  echo "Your git version (${git_version:-none}) is below 2.32 (required by lazygit)."
  if ! confirm_yn "Do you want to update git from source? [y/N] " n; then
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would compile git from source${NC}"
    return 0
  fi

  export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig:$INSTALL_DIR/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  local LOCAL_LDFLAGS="-L$INSTALL_DIR/lib -L$INSTALL_DIR/lib64 -Wl,-rpath,$INSTALL_DIR/lib -Wl,-rpath,$INSTALL_DIR/lib64"
  export CPPFLAGS="-I$INSTALL_DIR/include"

  # Step 1: compile OpenSSL if headers are missing (required by curl for HTTPS)
  if ! pkg-config --exists openssl 2>/dev/null && ! [ -f /usr/include/openssl/ssl.h ]; then
    echo "OpenSSL headers not found; compiling OpenSSL from source..."
    local openssl_src_version="1.1.1w"
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
    local curl_src_version="8.11.1"
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
  local git_new_version="2.51.0"
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

  # If mason hasn't installed tree-sitter-cli yet, trigger it explicitly and
  # wait for the install to finish. We poll for the binary rather than using
  # a fixed sleep, since mason downloads vary with network speed.
  if [ ! -d "$mason_treesitter_dir" ]; then
    echo -e "${YELLOW}GLIBC ${glibc_version} < 2.29: ensuring mason installs tree-sitter-cli...${NC}"
    export TAR_OPTIONS="--no-same-owner --touch"
    # Launch mason install in background; poll for completion with a timeout.
    nvim --headless +"lua require('lazy').load({ plugins = { 'mason.nvim' } })" +"MasonInstall tree-sitter-cli" +"sleep 60" +"qa" 2>&1 &
    local nvim_pid=$!
    local waited=0
    local timeout=90
    while [ $waited -lt $timeout ]; do
      if [ -f "$mason_treesitter_dir/tree-sitter-linux-x64" ]; then
        echo -e "${GREEN}  mason tree-sitter-cli ready after ${waited}s${NC}"
        break
      fi
      sleep 2
      waited=$((waited + 2))
    done
    # Clean up the background nvim (ignore errors; it may already have exited)
    kill "$nvim_pid" 2>/dev/null || true
    wait "$nvim_pid" 2>/dev/null || true
    if [ ! -f "$mason_treesitter_dir/tree-sitter-linux-x64" ]; then
      echo -e "${YELLOW}  Warning: tree-sitter-cli still not present after ${timeout}s${NC}"
    fi
  fi

  # Now apply the fix
  fix_treesitter_glibc
}

###############################################################################
# Tool installations
###############################################################################

# -- jq (installed first — both get_latest_version and gah depend on it) ------
# We use direct curl+grep here instead of get_latest_version because jq isn't
# guaranteed to exist yet. Likewise, install/update is done via direct binary
# download rather than gah, since gah hasn't been installed yet either — this
# breaks the chicken-and-egg between jq, gah, and get_latest_version.
fetch_jq_latest_version() {
  curl -fsSL "${GITHUB_AUTH_ARGS[@]+"${GITHUB_AUTH_ARGS[@]}"}" \
    "https://api.github.com/repos/jqlang/jq/releases/latest" \
    | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^jq-//'
}

install_jq_binary() {
  local version=$1
  if ! curl -fsSL -o "$INSTALL_BIN_DIR/jq" \
      "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-linux-amd64"; then
    echo -e "${RED}Failed to download jq${NC}"
    return 1
  fi
  chmod +x "$INSTALL_BIN_DIR/jq"
}

if command -v jq >/dev/null 2>&1; then
  current_version=$(jq --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  latest_version=$(fetch_jq_latest_version)

  echo -e "${GREEN}jq exists (v${current_version}, latest: v${latest_version})${NC}"

  if [ -n "$latest_version" ] && ! compare_versions "$latest_version" "$current_version"; then
    if prompt_update "jq" "$current_version" "$latest_version"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update jq to ${latest_version}${NC}"
      else
        if install_jq_binary "$latest_version"; then
          echo -e "${GREEN}jq updated successfully!${NC}"
        fi
      fi
    fi
  fi
else
  echo -e "${YELLOW}jq does not exist, installing it...${NC}"
  latest_version=$(fetch_jq_latest_version)
  if [ -z "$latest_version" ]; then
    echo -e "${RED}Failed to fetch jq version from GitHub API${NC}"
    exit 1
  fi
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install jq ${latest_version}${NC}"
  else
    install_jq_binary "$latest_version" || exit 1
  fi
fi

# -- gah (GitHub Asset Helper — needed for many installs below) ---------------
# Must come after jq, since get_latest_version depends on jq.
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

# -- git (compile from source if below 2.32) ---------------------------------
# Must run BEFORE the first git clone (fzf, oh-my-zsh plugins, etc.) so that
# systems with an HTTPS-less system git can still perform those clones.
compile_git_if_needed

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
    # `-e no` skips /etc/shells and chsh — both require root.
    bash <(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install) -d "$INSTALL_DIR" -e no || true
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

# NOTE: btop and bfs installers were previously staged here but are disabled.
# If re-enabling, move them into install_or_update_gah-style helpers rather
# than duplicating the update/install branches.

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

# -- zoxide (upstream installer lacks auth — rate-limited without it) --------
install_or_update_gah "zoxide" "ajeetdsouza/zoxide" \
  "zoxide --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

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
  # Expand $INSTALL_BIN_DIR/curl-real at wrapper-install time so the wrapper
  # doesn't depend on $0 resolving to an absolute path.
  cat > "$INSTALL_BIN_DIR/curl" << CURL_WRAPPER
#!/bin/bash
# Rewrite github.com/{owner}/{repo}/archive/{sha}.tar.gz
# to codeload.github.com/{owner}/{repo}/tar.gz/{sha}
ARGS=()
for arg in "\$@"; do
  if [[ "\$arg" =~ ^https://github\.com/([^/]+)/([^/]+)/archive/([^/]+)\.tar\.gz$ ]]; then
    ARGS+=("https://codeload.github.com/\${BASH_REMATCH[1]}/\${BASH_REMATCH[2]}/tar.gz/\${BASH_REMATCH[3]}")
  else
    ARGS+=("\$arg")
  fi
done
exec "${INSTALL_BIN_DIR}/curl-real" "\${ARGS[@]}"
CURL_WRAPPER
  chmod +x "$INSTALL_BIN_DIR/curl"
fi

# Guard: check if setting file timestamps is restricted (container environments).
# tar extractions fail with "Cannot utime: Operation not permitted" when the
# kernel disallows utime calls, requiring --touch to skip timestamp restoration.
_utime_test=$(mktemp)
if ! touch -t 200001010000 "$_utime_test" 2>/dev/null; then
  echo "File timestamp changes restricted on this system; installing tar wrapper..."
  # Resolve tar at wrapper-install time so we don't depend on /usr/bin/tar
  # (homebrew / BSD systems may ship tar elsewhere). Fall back to /usr/bin/tar
  # if resolution fails or points to our own wrapper location.
  _real_tar=$(command -v tar 2>/dev/null || true)
  if [ -z "$_real_tar" ] || [ "$_real_tar" = "$INSTALL_BIN_DIR/tar" ]; then
    _real_tar="/usr/bin/tar"
  fi
  cat > "$INSTALL_BIN_DIR/tar" << TAR_WRAPPER
#!/bin/bash
ARGS=()
is_extract=false
has_touch=false
for arg in "\$@"; do
  case "\$arg" in
    -x*|--extract|--get) is_extract=true ;;
    --touch|-m) has_touch=true ;;
  esac
  [[ "\$arg" =~ ^-[a-zA-Z]*x[a-zA-Z]* ]] && is_extract=true
  ARGS+=("\$arg")
done
[[ "\$is_extract" == "true" && "\$has_touch" == "false" ]] && ARGS+=("--touch")
exec "${_real_tar}" "\${ARGS[@]}"
TAR_WRAPPER
  chmod +x "$INSTALL_BIN_DIR/tar"
fi
rm -f "$_utime_test"

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
    # On old GLIBC, replace the npm tree-sitter binary with compat build
    fix_treesitter_glibc
  fi
else
  echo -e "${YELLOW}npm not found, skipping tree-sitter-cli/markdownlint-cli2/markdown-toc${NC}"
fi

###############################################################################
# Symlinks and plugin installation
###############################################################################

echo ""
if confirm_yn "Create Vim symlinks? (Y/n): " y; then
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
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install vim plugins${NC}"
  elif command -v vim >/dev/null 2>&1; then
    echo -e "${GREEN}Installing vim plugins (this may take a moment)...${NC}"
    vim +'PlugInstall --sync' +qall
    echo -e "\t${GREEN}Vim plugins installed!${NC}"
  else
    echo -e "${YELLOW}vim not found; skipping plugin install${NC}"
  fi
else
  echo "You can create Vim symlinks as:"
  echo "ln -sf ${SCRIPT_DIR}/vim/.vimrc $HOME/.vimrc && ln -sf ${SCRIPT_DIR}/vim/.vimcommon $HOME/.vimcommon"
fi

echo ""
if confirm_yn "Create NeoVim symlinks? (Y/n): " y; then
  mkdir -p "$HOME/.config"
  ln -sfn "${SCRIPT_DIR}/nvim" "$HOME/.config/nvim"
  echo -e "\t${GREEN}Symlinks created!${NC}"

  # Install nvim plugins via lazy.nvim
  # Export TAR_OPTIONS so nvim-treesitter's internal tar calls get --touch
  # (prevents "Cannot utime: Operation not permitted" on FUSE/container mounts)
  export TAR_OPTIONS="--no-same-owner --touch"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install nvim plugins via Lazy sync${NC}"
  elif command -v nvim >/dev/null 2>&1; then
    echo -e "${GREEN}Installing nvim plugins (this may take a moment)...${NC}"
    nvim --headless -c "Lazy! sync" -c "qa" 2>&1 || true
    echo -e "\t${GREEN}Nvim plugins installed!${NC}"

    # On old GLIBC systems, ensure mason's tree-sitter-cli is replaced with a compatible build.
    # Uses ensure_treesitter_glibc_fix which will trigger MasonInstall if the dir doesn't exist yet.
    ensure_treesitter_glibc_fix
  else
    echo -e "${YELLOW}nvim not found; skipping Lazy sync${NC}"
  fi
else
  echo "You can create NeoVim symlinks as:"
  echo "ln -sfn ${SCRIPT_DIR}/nvim $HOME/.config/nvim"
fi

echo ""
if confirm_yn "Create Git config symlinks? (Y/n): " y; then
  if [ -f "$HOME/.gitconfig" ]; then
    mv "$HOME/.gitconfig" "$HOME/.gitconfig_orig"
  fi
  ln -sf "${SCRIPT_DIR}/git/.gitconfig" "$HOME/.gitconfig"
  echo -e "\t${GREEN}Symlinks created!${NC}"
fi

if command -v zellij >/dev/null 2>&1; then
  echo -e "${GREEN}zellij exists${NC}"

  if confirm_yn "Create Zellij symlinks? (Y/n): " y; then
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
elif [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY RUN] Would install oh-my-zsh${NC}"
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
  plugin_name=$(basename "$install_path")

  if [ ! -d "$install_path" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would install $plugin_name${NC}"
    else
      echo -e "${GREEN}Installing $plugin_name${NC}"
      git clone -q --depth=1 "$url" "$install_path"
    fi
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

# Drop into zsh only when running interactively. In CI / piped installs this
# would otherwise hang forever on the read prompt and then fail trying to
# exec an interactive zsh with no TTY.
if [ -t 0 ] && [ "$ASSUME_YES" != true ]; then
  read -r -p "Press Enter to run zsh!" _
  # shellcheck disable=SC1091
  source "$HOME/.bashrc"
  # run ZSH and configure p10k
  zsh -c "source $HOME/.zshrc &&  echo -e \"\n\e[0;33mTo configure p10k run: p10k configure \033[0m\" ; zsh"
else
  echo "(non-interactive run — skipping interactive zsh launch)"
fi
                                                                                                                                                                                                                                                                                                                    