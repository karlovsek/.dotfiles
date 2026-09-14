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
#   nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, broot, zoxide,
#   bat, eza, delta, gdu, lazygit, lazydocker, zellij, node, jq, 7zip
#
#   Most of the above (everything except zsh, htop, and node's npm globals)
#   are installed and version-managed via mise (https://mise.jdx.dev) using
#   the tool list in mise/config.toml. Run `mise outdated` / `mise upgrade`
#   directly at any time instead of re-running this whole script.
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

export PATH="$INSTALL_BIN_DIR:$PATH"

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
  # Export the standard env var so downstream installers (mise, etc.) that
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

# Get GLIBC version
get_glibc_version() {
  ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1
}

# Fix tree-sitter for systems with old GLIBC.
# Pre-built tree-sitter binaries (npm and mason) require GLIBC >= 2.29.
# On older systems (e.g. RHEL 8 / Rocky 8 with GLIBC 2.28), we replace the
# copies found under the known node/npm roots below with a compatible build
# stored in the repo as tree-sitter-glibc_2.28.
fix_treesitter_glibc() {
  local glibc_version
  glibc_version=$(get_glibc_version)

  # No detectable glibc (musl/Alpine, or `ldd` missing) must NOT be treated as
  # "older than 2.29" — the compat binary is glibc-linked and useless there.
  if [ -z "$glibc_version" ]; then
    return 0
  fi

  # compare_versions returns 0 (true) when $1 <= $2, so this triggers when glibc < 2.29
  if ! compare_versions "2.29" "$glibc_version"; then
    local compat_binary="${SCRIPT_DIR}/tree-sitter-glibc_2.28"

    if [ ! -f "$compat_binary" ]; then
      echo -e "${YELLOW}Warning: GLIBC ${glibc_version} detected but compatible tree-sitter binary not found at ${compat_binary}${NC}"
      return 0
    fi

    if [ "$DRY_RUN" = true ]; then
      echo -e "${YELLOW}[DRY RUN] Would replace tree-sitter binaries with the GLIBC ${glibc_version}-compatible build${NC}"
      return 0
    fi

    echo -e "${YELLOW}GLIBC ${glibc_version} < 2.29: replacing tree-sitter binaries with compatible build...${NC}"

    # 1. Put compat binary on PATH so nvim-treesitter / tree-sitter-manager
    #    finds it. --remove-destination because this path may itself be a
    #    symlink into a mason/gah package, which plain cp would write through;
    #    non-fatal because ETXTBSY (a tree-sitter still running from here) must
    #    not abort the whole installer under `set -e`.
    if cp --remove-destination "$compat_binary" "$INSTALL_BIN_DIR/tree-sitter" 2>/dev/null &&
       chmod +x "$INSTALL_BIN_DIR/tree-sitter" 2>/dev/null; then
      echo -e "${GREEN}  Installed to $INSTALL_BIN_DIR/tree-sitter${NC}"
    else
      echo -e "${YELLOW}  Warning: could not install $INSTALL_BIN_DIR/tree-sitter${NC}"
    fi

    # 2. Replace vendored tree-sitter-cli binaries. Step 1 above is not enough
    #    on its own: mason prepends its own bin dir to PATH, and an npm global
    #    install shadows $INSTALL_BIN_DIR, so those copies are replaced too.
    #    Only known node/npm roots are scanned -- a `find` over all of $HOME can
    #    take many minutes on machines with large source or build trees, during
    #    which the installer prints nothing and looks like it has hung.
    local xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"
    local ts_roots=(
      "${FNM_DIR:-$xdg_data/fnm}"
      "$xdg_data/pnpm"
      "$xdg_data/nvim/mason/packages"
      "$INSTALL_DIR/lib/node_modules"
      "$HOME/.nvm"
      "$HOME/.npm-global"
      "$HOME/.volta"
      "$HOME/.asdf/installs/nodejs"
      "$HOME/node_modules"
    )
    # `|| npm_global_root=""` is required: a bare assignment from a failing
    # command substitution aborts the whole installer under `set -e`.
    local npm_global_root=""
    if command -v npm >/dev/null 2>&1; then
      npm_global_root=$(npm root -g 2>/dev/null) || npm_global_root=""
      [ -n "$npm_global_root" ] && ts_roots+=("$npm_global_root")
    fi

    local npm_ts_bin
    local replaced=0
    while IFS= read -r npm_ts_bin; do
      # NOTE: these paths are already resolved to physical files by the
      # readlink -f below, so a shared pnpm/npm content store IS rewritten in
      # place and every project linking it changes too. That is intended here:
      # on a GLIBC < 2.29 host every copy in that store is unrunnable anyway.
      # --remove-destination unlinks first so cp cannot fail on, or write
      # through, a hardlink that still points at the old inode.
      # Failures are warned about, not fatal -- a single unwritable copy (root
      # owned global prefix, ETXTBSY on a running binary) must not abort the
      # installer part-way through.
      if cp --remove-destination "$compat_binary" "$npm_ts_bin" 2>/dev/null &&
         chmod +x "$npm_ts_bin" 2>/dev/null; then
        echo -e "${GREEN}  Replaced npm binary: $npm_ts_bin${NC}"
        replaced=$((replaced + 1))
      else
        echo -e "${YELLOW}  Warning: could not replace $npm_ts_bin (skipped)${NC}"
      fi
    done < <(
      # -L so a symlinked root (or a pnpm-style symlinked package dir) is
      # descended; without it `find` silently yields nothing for such a root.
      # Resolve to physical paths, then dedupe. A symlink forest (pnpm, nvm
      # aliases) reaches ONE physical binary by many paths, and plain `sort -u`
      # over the found paths would rewrite that same file once per path.
      # Deduping on the resolved path -- rather than on device:inode -- is what
      # makes hardlinks still work: two hardlinked copies share an inode but are
      # distinct directory entries that each need their own replacement.
      # Under -L a working symlink already satisfies -type f, so no -type l arm
      # is needed; adding one would match only DANGLING links, which cp would
      # then materialise into a stray copy of the binary.
      find -L "${ts_roots[@]}" \
        -path "*/node_modules/tree-sitter-cli/tree-sitter" \
        -type f -print0 2>/dev/null \
        | xargs -0 -r readlink -f -- 2>/dev/null | sort -u
    )

    # 3. Replace mason's copy if it exists
    local mason_treesitter_dir="$xdg_data/nvim/mason/packages/tree-sitter-cli"
    if [ -d "$mason_treesitter_dir" ]; then
      if cp --remove-destination "$compat_binary" \
           "$mason_treesitter_dir/tree-sitter-linux-x64" 2>/dev/null &&
         chmod +x "$mason_treesitter_dir/tree-sitter-linux-x64" 2>/dev/null; then
        echo -e "${GREEN}  Replaced mason binary${NC}"
        replaced=$((replaced + 1))
      else
        echo -e "${YELLOW}  Warning: could not replace mason binary${NC}"
      fi
    fi

    if [ "$replaced" -eq 0 ]; then
      echo -e "${YELLOW}Warning: no vendored tree-sitter binary was found to replace.${NC}"
      echo -e "${YELLOW}  $INSTALL_BIN_DIR/tree-sitter is in place, but a copy under a node_modules${NC}"
      echo -e "${YELLOW}  or mason path may still require GLIBC 2.29 at runtime.${NC}"
    else
      echo -e "${GREEN}Tree-sitter GLIBC compatibility fix applied (${replaced} replaced)!${NC}"
    fi
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
    (
      cd "$SCRATCH_DIR"
      wget "https://www.openssl.org/source/openssl-${openssl_src_version}.tar.gz"
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
    (
      cd "$SCRATCH_DIR"
      wget "https://curl.se/download/curl-${curl_src_version}.tar.gz"
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
  (
    cd "$SCRATCH_DIR"
    wget "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${git_new_version}.tar.gz"
    tar -xzf "git-${git_new_version}.tar.gz"
    cd "git-${git_new_version}"
    LDFLAGS="$LOCAL_LDFLAGS" \
    ./configure --without-tcltk --prefix="$INSTALL_DIR"
    make NO_GETTEXT=1 NO_TCLTK=1 install
  ) || { echo -e "${YELLOW}Warning: git compilation failed; keeping system git.${NC}"; return 0; }
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

  # Only needed on systems with GLIBC < 2.29. An empty version means musl or a
  # missing `ldd`; the glibc-linked compat binary is useless there.
  if [ -z "$glibc_version" ] || compare_versions "2.29" "$glibc_version"; then
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would ensure mason tree-sitter-cli is installed and apply the GLIBC ${glibc_version} tree-sitter fix${NC}"
    return 0
  fi

  local mason_treesitter_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages/tree-sitter-cli"

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

# -- mise (tool version manager) ----------------------------------------------
# Replaces gah and the hand-rolled curl/tar installers below for every tool
# that publishes prebuilt release binaries. The tool list, pinned versions,
# and per-tool asset overrides live in mise/config.toml (symlinked below),
# not in this script — add new tools there.
MISE_BIN_PATH="$INSTALL_BIN_DIR/mise"

if ! command -v mise >/dev/null 2>&1 && [ ! -x "$MISE_BIN_PATH" ]; then
  echo -e "${YELLOW}mise does not exist, installing it...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install mise via https://mise.run${NC}"
  else
    if ! curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_BIN_PATH" sh; then
      echo -e "${RED}Failed to install mise${NC}"
    fi
  fi
elif [ "$FORCE_UPDATE" = true ]; then
  echo -e "${GREEN}mise exists ($(mise --version 2>/dev/null)), force-updating...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would run: mise self-update -y${NC}"
  else
    mise self-update -y || echo -e "${YELLOW}Warning: mise self-update failed${NC}"
  fi
else
  echo -e "${GREEN}mise exists ($(mise --version 2>/dev/null))${NC}"
fi

# Symlink the tracked mise config into place (same backup pattern as the
# other symlinks further down this script: don't clobber a real file with
# our symlink on a second run).
mkdir -p "$HOME/.config/mise"
if [ -f "$HOME/.config/mise/config.toml" ] && [ ! -L "$HOME/.config/mise/config.toml" ]; then
  mv "$HOME/.config/mise/config.toml" "$HOME/.config/mise/config.toml.orig"
fi
ln -sfn "${SCRIPT_DIR}/mise/config.toml" "$HOME/.config/mise/config.toml"

if [ "$ASSUME_YES" = true ]; then
  export MISE_YES=1
fi

# Activate shims for the rest of THIS script (later `command -v nvim`,
# `command -v zellij`, `command -v lazygit` checks, and the `nvim --headless`
# Lazy-sync call all need mise-installed tools on PATH).
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash --shims)"

  # Persist bash activation to ~/.bashrc for future interactive bash logins
  # (zsh already gets `eval "$(mise activate zsh)"` via zsh/.zshrc). Without
  # this, mise-managed tools (nvim, fd, rg, ...) would only be on PATH for the
  # remainder of THIS script's own execution, not for future bash shells --
  # a real regression from the pre-mise behavior of adding $INSTALL_BIN_DIR
  # to ~/.bashrc directly.
  if [ "$DRY_RUN" != true ] && ! grep -qF 'mise activate bash' "$HOME/.bashrc" 2>/dev/null; then
    echo "Adding mise activation to $HOME/.bashrc"
    printf '\nif command -v mise >/dev/null 2>&1; then\n  eval "$(mise activate bash)"\nfi\n' >> "$HOME/.bashrc"
  fi
fi

mise_install_ok=false
if command -v mise >/dev/null 2>&1; then
  echo -e "${GREEN}Installing/verifying mise-managed tools (see mise/config.toml)...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would run: mise install${NC}"
    mise install --dry-run || true
    mise_install_ok=true
  elif mise install; then
    mise_install_ok=true
  else
    echo -e "${YELLOW}Warning: mise install failed${NC}"
  fi

  mise_outdated=$(mise outdated 2>/dev/null) || true
  if [ -n "$mise_outdated" ]; then
    echo -e "${YELLOW}Outdated mise-managed tools:${NC}"
    echo "$mise_outdated"
    if [ "$FORCE_UPDATE" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would run: mise upgrade${NC}"
      else
        mise upgrade || echo -e "${YELLOW}Warning: mise upgrade failed${NC}"
      fi
    elif [ "$DRY_RUN" = true ]; then
      mise upgrade --dry-run || true
    elif [ -t 0 ] && [ "$ASSUME_YES" != true ]; then
      mise upgrade --interactive || echo -e "${YELLOW}Warning: mise upgrade --interactive failed${NC}"
    else
      echo -e "${YELLOW}(non-interactive: skipping interactive upgrade prompt — re-run with --force-update to upgrade all)${NC}"
    fi
  fi
else
  echo -e "${YELLOW}Warning: mise not available on PATH; skipping mise-managed tool installs${NC}"
fi

# nvim (installed above via mise, github:neovim/neovim-releases) may need the
# GLIBC 2.28 compat tree-sitter binary; safe to call unconditionally, it
# no-ops on GLIBC >= 2.29.
fix_treesitter_glibc

# -- One-time cleanup: stale pre-mise binaries ---------------------------------
# Machines that ran an earlier version of this script have copies of these
# tools installed directly (via gah or curl+tar) in $INSTALL_BIN_DIR, which
# would otherwise sit on PATH ahead of nothing in particular and just waste
# disk. mise's shims already take priority on PATH regardless, so this is
# cleanup rather than a correctness fix.
cleanup_pre_mise_artifacts() {
  local targets=(
    "$INSTALL_BIN_DIR/jq" "$INSTALL_BIN_DIR/gah" "$INSTALL_BIN_DIR/7zz"
    "$INSTALL_BIN_DIR/nvim" "$INSTALL_BIN_DIR/fd" "$INSTALL_BIN_DIR/sshs"
    "$INSTALL_BIN_DIR/rg" "$INSTALL_BIN_DIR/lstr" "$INSTALL_BIN_DIR/broot"
    "$INSTALL_BIN_DIR/zoxide" "$INSTALL_BIN_DIR/bat" "$INSTALL_BIN_DIR/eza"
    "$INSTALL_BIN_DIR/delta" "$INSTALL_BIN_DIR/gdu" "$INSTALL_BIN_DIR/lazygit"
    "$INSTALL_BIN_DIR/lazydocker" "$INSTALL_BIN_DIR/zellij"
    "$INSTALL_DIR/fzf" "$INSTALL_DIR/share/nvim/runtime" "$INSTALL_DIR/lib/nvim"
    "$INSTALL_DIR/share/fnm"
  )
  local to_remove=() t resolved
  for t in "${targets[@]}"; do
    [ -e "$t" ] || [ -L "$t" ] || continue
    # Never remove something that is itself a symlink into the dotfiles repo
    # (e.g. this script's own fuzzy-kill symlinks would never appear in the
    # list above, but be defensive about future additions to $targets).
    resolved=$(readlink -f "$t" 2>/dev/null || true)
    case "$resolved" in
      "$SCRIPT_DIR"/*) continue ;;
    esac
    to_remove+=("$t")
  done

  if [ "${#to_remove[@]}" -eq 0 ]; then
    return 0
  fi

  echo -e "${YELLOW}Removing stale pre-mise artifacts:${NC}"
  printf '  %s\n' "${to_remove[@]}"

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would remove the paths listed above${NC}"
    return 0
  fi

  rm -rf "${to_remove[@]}"
  echo -e "${GREEN}Cleanup complete.${NC}"
}

# Capture whether fnm's directory existed BEFORE cleanup runs -- cleanup
# itself deletes $INSTALL_DIR/share/fnm as one of its targets, so checking
# after cleanup would make the advisory below unreachable on a real run.
fnm_dir_existed=false
[ -d "$HOME/.local/share/fnm" ] && fnm_dir_existed=true

if [ "$mise_install_ok" = true ]; then
  cleanup_pre_mise_artifacts
else
  echo -e "${YELLOW}Skipping pre-mise cleanup: mise-managed tools are not confirmed in place${NC}"
fi

if [ "$fnm_dir_existed" = true ]; then
  echo -e "${YELLOW}Note: fnm's install script may have added FNM_PATH / 'fnm env' lines to"
  echo -e "  ~/.bashrc when this machine was first set up. Node is now managed by mise"
  echo -e "  (mise/config.toml); you can remove any such lines by hand if you no longer"
  echo -e "  use fnm directly.${NC}"
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

# -- htop (build from source) -------------------------------------------------
if command -v htop >/dev/null 2>&1; then
  current_version=$(htop --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') || true
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

  # Persist TAR_OPTIONS so future sessions (including nvim-treesitter parser
  # installs outside this script) inherit --touch automatically.
  for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$_rc" ] && ! grep -qF "TAR_OPTIONS" "$_rc" 2>/dev/null; then
      printf '\nexport TAR_OPTIONS="--no-same-owner --touch"\n' >> "$_rc"
      echo "  Added TAR_OPTIONS to $_rc"
    fi
  done
fi
rm -f "$_utime_test"

# lazygit, lazydocker, zellij: installed via mise above.

# Install fuzzy-kill (fuzzy process finder and killer)
if [ -f "${SCRIPT_DIR}/bin/fuzzy-kill" ]; then
  echo -e "${GREEN}Installing fuzzy-kill...${NC}"
  ln -sf "${SCRIPT_DIR}/bin/fuzzy-kill" "$INSTALL_BIN_DIR/fuzzy-kill"
  ln -sf "${SCRIPT_DIR}/bin/fuzzy-kill" "$INSTALL_BIN_DIR/fk" # Short alias
  chmod +x "${SCRIPT_DIR}/bin/fuzzy-kill"
  echo -e "${GREEN}fuzzy-kill installed (alias: fk)${NC}"
fi

# Node.js is installed via mise (see mise/config.toml: node = "23").

# Install npm packages required by nvim mason (markdown + treesitter tooling)
if command -v npm >/dev/null 2>&1; then
  echo -e "${GREEN}Installing npm packages for nvim (tree-sitter-cli, markdownlint-cli2, markdown-toc)...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would install npm packages${NC}"
    fix_treesitter_glibc
  else
    npm install -g tree-sitter-cli markdownlint-cli2 markdown-toc
    command -v mise >/dev/null 2>&1 && mise reshim
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
  # [ ! -L ] so a re-run cannot overwrite the saved original with the
  # symlink this script created on the previous run.
  if [ -f "$HOME/.vimrc" ] && [ ! -L "$HOME/.vimrc" ]; then
    mv "$HOME/.vimrc" "$HOME/.vimrc_orig"
  fi
  # [ ! -L ] so a re-run cannot overwrite the saved original with the
  # symlink this script created on the previous run.
  if [ -f "$HOME/.vimcommon" ] && [ ! -L "$HOME/.vimcommon" ]; then
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
    ensure_treesitter_glibc_fix
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
  # [ ! -L ] so a re-run cannot overwrite the saved original with the
  # symlink this script created on the previous run.
  if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    mv "$HOME/.gitconfig" "$HOME/.gitconfig_orig"
  fi
  ln -sf "${SCRIPT_DIR}/git/.gitconfig" "$HOME/.gitconfig"
  echo -e "\t${GREEN}Symlinks created!${NC}"

  # The tracked .gitconfig includes ~/.gitconfig.local for machine-specific
  # settings. Git ignores a missing include *silently*, so seed the file with
  # a header instead of leaving the indirection undiscoverable.
  if [ "$DRY_RUN" != true ] && [ ! -e "$HOME/.gitconfig.local" ]; then
    cat > "$HOME/.gitconfig.local" <<'GITCONFIG_LOCAL'
# Machine-specific git settings. Deliberately NOT tracked by the dotfiles repo.
# Example -- trust a repo living on a mount only this machine has:
#   [safe]
#   \tdirectory = /mnt/somewhere
GITCONFIG_LOCAL
    echo -e "\t${GREEN}Created ~/.gitconfig.local for machine-specific settings${NC}"
  fi
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

if command -v lazygit >/dev/null 2>&1; then
  echo -e "${GREEN}lazygit exists${NC}"

  if confirm_yn "Create lazygit config symlink? (Y/n): " y; then
    mkdir -p "$HOME/.config/lazygit"
    ln -sf "${SCRIPT_DIR}/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
    echo -e "\t${GREEN}Symlinks created!${NC}"
  else
    echo "You can create the lazygit config symlink as:"
    echo "ln -sf ${SCRIPT_DIR}/lazygit/config.yml $HOME/.config/lazygit/config.yml"
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
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY RUN] Would symlink zsh/.zshrc and zsh/.p10k.zsh into \$HOME${NC}"
else
  # [ ! -L ] so a re-run cannot overwrite the saved original with the
  # symlink this script created on the previous run.
  if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc_orig"
  fi

  # [ ! -L ] so a re-run cannot overwrite the saved original with the
  # symlink this script created on the previous run.
  if [ -f "$HOME/.p10k.zsh" ] && [ ! -L "$HOME/.p10k.zsh" ]; then
    mv "$HOME/.p10k.zsh" "$HOME/.p10k.zsh_orig"
  fi

  ln -sf "${SCRIPT_DIR}/zsh/.zshrc" "$HOME/.zshrc"
  ln -sf "${SCRIPT_DIR}/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
fi

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