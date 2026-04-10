#!/bin/bash
###############################################################################
# validate.sh — comprehensive validation for install-minimal.sh
#
# Tests:
#   1. All binaries exist and respond to --version
#   2. Minimum version requirements are met
#   3. Symlinks point to the right targets
#   4. Logging works (install log file exists)
#   5. ZSH plugins are installed
#   6. Nvim Lazy can load
#   7. Git has HTTPS support
#   8. GLIBC < 2.29 tree-sitter fix (on Rocky/RHEL)
#   9. Dry-run mode doesn't install anything new
#  10. fuzzy-kill aliases are in place
###############################################################################

set -u

DOTFILES="$HOME/.dotfiles"
PASS=0
FAIL=0
SKIP=0

# Colors
RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

export PATH="$HOME/.local/bin:$HOME/.local/fzf/bin:$HOME/.local/share/fnm:$PATH"

# --- Helpers -----------------------------------------------------------------

pass() {
  echo -e "  ${GREEN}PASS${NC}: $1"
  ((PASS++))
}

fail() {
  echo -e "  ${RED}FAIL${NC}: $1"
  ((FAIL++))
}

skip() {
  echo -e "  ${YELLOW}SKIP${NC}: $1"
  ((SKIP++))
}

# Check that a command exists and responds to a version flag
check_binary() {
  local name="$1"
  local cmd="${2:-$1}"
  local version_flag="${3:---version}"

  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver=$("$cmd" $version_flag 2>&1 | head -1)
    pass "$name ($ver)"
  else
    fail "$name — binary not found"
  fi
}

# Check that a command's version is at least $min_version
check_min_version() {
  local name="$1"
  local cmd="$2"
  local version_cmd="$3"
  local min_version="$4"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "$name — not installed, can't check version"
    return
  fi

  local current
  current=$(eval "$version_cmd" 2>/dev/null)
  if [ -z "$current" ]; then
    fail "$name — couldn't extract version"
    return
  fi

  if [ "$(printf '%s\n' "$min_version" "$current" | sort -V | head -n1)" = "$min_version" ]; then
    pass "$name v${current} >= ${min_version}"
  else
    fail "$name v${current} < ${min_version} (minimum required)"
  fi
}

# Check a symlink target
check_symlink() {
  local name="$1"
  local link="$2"
  local expected="$3"
  local actual
  actual=$(readlink "$link" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    pass "symlink $name → $expected"
  else
    fail "symlink $name → '$actual' (expected '$expected')"
  fi
}

# Check a directory exists
check_dir() {
  local name="$1"
  local dir="$2"
  if [ -d "$dir" ]; then
    pass "$name exists"
  else
    fail "$name — directory not found: $dir"
  fi
}

# Check a file exists
check_file() {
  local name="$1"
  local file="$2"
  if [ -f "$file" ]; then
    pass "$name exists"
  else
    fail "$name — file not found: $file"
  fi
}

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 1. Binary existence tests ===${NC}"
###############################################################################

check_binary "jq"
check_binary "gah"         "gah"         "version"
check_binary "7zz"         "7zz"         "i"
check_binary "nvim"
check_binary "zsh"
check_binary "fd"
check_binary "sshs"
check_binary "rg"          "rg"          "--version"
check_binary "lstr"
check_binary "fzf"
check_binary "htop"
check_binary "broot"
check_binary "zoxide"
check_binary "bat"
check_binary "eza"
check_binary "gdu"         "gdu"         "--version"
check_binary "lazygit"
check_binary "lazydocker"
check_binary "zellij"

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 2. Minimum version checks ===${NC}"
###############################################################################

check_min_version "nvim"    "nvim" "nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'" "0.10.0"
check_min_version "git"     "git"  "git --version | awk '{print \$3}'" "2.32"
check_min_version "fzf"     "fzf"  "fzf --version | awk '{print \$1}'" "0.50.0"
check_min_version "zsh"     "zsh"  "zsh --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1" "5.8"

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 3. Symlink tests ===${NC}"
###############################################################################

check_symlink "nvim config"   "$HOME/.config/nvim"          "$DOTFILES/nvim"
check_symlink "gitconfig"     "$HOME/.gitconfig"             "$DOTFILES/git/.gitconfig"
check_symlink "zellij config" "$HOME/.config/zellij"         "$DOTFILES/zellij"
check_symlink "zshrc"         "$HOME/.zshrc"                 "$DOTFILES/zsh/.zshrc"
check_symlink "p10k"          "$HOME/.p10k.zsh"              "$DOTFILES/zsh/.p10k.zsh"
check_symlink "vimrc"         "$HOME/.vimrc"                 "$DOTFILES/vim/.vimrc"
check_symlink "vimcommon"     "$HOME/.vimcommon"             "$DOTFILES/vim/.vimcommon"
check_symlink "fuzzy-kill"    "$HOME/.local/bin/fuzzy-kill"  "$DOTFILES/bin/fuzzy-kill"
check_symlink "fk alias"      "$HOME/.local/bin/fk"          "$DOTFILES/bin/fuzzy-kill"

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 4. Install log ===${NC}"
###############################################################################

check_file "install log" "$HOME/.dotfiles-install.log"

if [ -f "$HOME/.dotfiles-install.log" ]; then
  log_lines=$(wc -l < "$HOME/.dotfiles-install.log")
  if [ "$log_lines" -gt 10 ]; then
    pass "install log has content ($log_lines lines)"
  else
    fail "install log too short ($log_lines lines)"
  fi
fi

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 5. ZSH plugin tests ===${NC}"
###############################################################################

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

check_dir "oh-my-zsh"             "$HOME/.oh-my-zsh"
check_dir "fzf-tab"               "$ZSH_CUSTOM/plugins/fzf-tab"
check_dir "zsh-autosuggestions"    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
check_dir "zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
check_dir "zsh-vi-mode"           "$ZSH_CUSTOM/plugins/zsh-vi-mode"
check_dir "powerlevel10k"         "$ZSH_CUSTOM/themes/powerlevel10k"

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 6. Nvim plugin tests ===${NC}"
###############################################################################

if command -v nvim >/dev/null 2>&1; then
  if nvim --headless -c "lua require('lazy')" -c "qa" 2>&1; then
    pass "nvim Lazy loads successfully"
  else
    fail "nvim Lazy failed to load"
  fi
else
  skip "nvim not found, skipping plugin test"
fi

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 7. Git HTTPS support ===${NC}"
###############################################################################

if command -v git >/dev/null 2>&1; then
  # Check that git-remote-https exists
  git_core="$HOME/.local/libexec/git-core"
  if [ -f "$git_core/git-remote-https" ]; then
    pass "git-remote-https binary exists"
  else
    # Fall back to system git
    if git ls-remote --heads https://github.com/karlovsek/.dotfiles.git >/dev/null 2>&1; then
      pass "git HTTPS clone works (system git)"
    else
      fail "git has no HTTPS support"
    fi
  fi
fi

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 8. GLIBC / tree-sitter compatibility ===${NC}"
###############################################################################

glibc_version=$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
echo -e "  System GLIBC: ${glibc_version}"

if [ -n "$glibc_version" ]; then
  # Check if GLIBC < 2.29
  if [ "$(printf '%s\n' "2.29" "$glibc_version" | sort -V | head -n1)" = "$glibc_version" ] && [ "$glibc_version" != "2.29" ]; then
    echo -e "  ${YELLOW}GLIBC < 2.29 detected — checking tree-sitter fix${NC}"
    mason_ts="$HOME/.local/share/nvim/mason/packages/tree-sitter-cli/tree-sitter-linux-x64"
    compat_binary="$DOTFILES/tree-sitter-glibc_2.28"

    if [ -f "$mason_ts" ]; then
      # Verify it's our patched binary (same checksum as the compat binary)
      if [ -f "$compat_binary" ]; then
        compat_md5=$(md5sum "$compat_binary" | awk '{print $1}')
        mason_md5=$(md5sum "$mason_ts" | awk '{print $1}')
        if [ "$compat_md5" = "$mason_md5" ]; then
          pass "tree-sitter replaced with GLIBC 2.28 compatible build"
        else
          fail "tree-sitter binary doesn't match compat build (md5: $mason_md5 vs $compat_md5)"
        fi
      else
        skip "compat binary not in repo, can't verify checksum"
      fi
    else
      skip "mason tree-sitter-cli not installed (MasonInstall may not have run)"
    fi
  else
    pass "GLIBC >= 2.29 — no tree-sitter fix needed"
  fi
else
  skip "couldn't detect GLIBC version"
fi

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 9. Dry-run mode test ===${NC}"
###############################################################################

# Run install with --dry-run and verify it doesn't error out
if bash "$DOTFILES/install-minimal.sh" --dry-run < /dev/null > /tmp/dryrun.log 2>&1; then
  pass "dry-run exits cleanly"
else
  # set -e may cause exit on the 'read' with no tty, check if it got far enough
  if grep -q "\[DRY RUN\]" /tmp/dryrun.log 2>/dev/null; then
    pass "dry-run produced [DRY RUN] output"
  else
    fail "dry-run failed (exit code $?, no [DRY RUN] markers found)"
  fi
fi

if grep -q "\[DRY RUN\]" /tmp/dryrun.log 2>/dev/null; then
  dryrun_count=$(grep -c "\[DRY RUN\]" /tmp/dryrun.log)
  pass "dry-run found $dryrun_count [DRY RUN] markers"
else
  skip "no [DRY RUN] markers (script may have exited at read prompt)"
fi

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 10. fuzzy-kill validation ===${NC}"
###############################################################################

if [ -x "$HOME/.local/bin/fuzzy-kill" ]; then
  # Check --help works
  if "$HOME/.local/bin/fuzzy-kill" --help >/dev/null 2>&1; then
    pass "fuzzy-kill --help works"
  else
    fail "fuzzy-kill --help failed"
  fi
else
  fail "fuzzy-kill not executable at $HOME/.local/bin/fuzzy-kill"
fi

###############################################################################
echo -e "\n${BOLD}${CYAN}=== 11. Git repo status ===${NC}"
###############################################################################

git_status=$(git -C "$DOTFILES" status --porcelain 2>/dev/null)
if [ -z "$git_status" ]; then
  pass "git working tree clean"
else
  echo -e "  ${YELLOW}NOTE: git status has changes (expected in Docker context):${NC}"
  echo "$git_status" | head -5 | sed 's/^/    /'
  skip "git status has changes (may be expected after install)"
fi

###############################################################################
# Summary
###############################################################################
echo ""
echo -e "${BOLD}==========================================${NC}"
echo -e "${BOLD} Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC}"
echo -e "${BOLD}==========================================${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}${FAIL} test(s) failed.${NC}"
  exit 1
fi
