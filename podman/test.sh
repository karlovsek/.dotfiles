#!/bin/bash

DOTFILES="/root/.dotfiles"
PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"
    ((PASS++))
  else
    echo "FAIL: $name"
    ((FAIL++))
  fi
}

check_symlink() {
  local name="$1"
  local link="$2"
  local expected_target="$3"
  local actual_target
  actual_target=$(readlink "$link" 2>/dev/null)
  if [ "$actual_target" = "$expected_target" ]; then
    echo "PASS: symlink $name"
    ((PASS++))
  else
    echo "FAIL: symlink $name (got '$actual_target', expected '$expected_target')"
    ((FAIL++))
  fi
}

export PATH="$HOME/.local/bin:$HOME/.local/fzf/bin:$PATH"

echo "=== Binary tests ==="
check "jq"          jq --version
check "gah"         gah version
check "7zz"         7zz i
check "nvim"        nvim --version
check "nvim starts" nvim --headless -c "lua require('lazy')" -c "qa"
check "zsh"         zsh --version
check "fd"          fd --version
check "sshs"        sshs --version
check "rg"          rg --version
check "lstr"        lstr --version
check "fzf"         fzf --version
check "htop"        htop --version
check "broot"       broot --version
check "zoxide"      zoxide --version
check "bat"         bat --version
check "eza"         eza --version
check "gdu"         gdu --version
check "lazygit"     lazygit --version
check "lazydocker"  lazydocker --version
check "zellij"      zellij --version
check "fuzzy-kill executable"  test -x "$HOME/.local/bin/fuzzy-kill"
check "fk executable"          test -x "$HOME/.local/bin/fk"
check "git statically linked"  bash -c "ldd $HOME/.local/bin/git 2>&1 | grep -qE '(statically linked|not a dynamic)'"
check "git https"              bash -c "$HOME/.local/bin/git ls-remote --heads https://github.com/karlovsek/.dotfiles.git"

echo ""
echo "=== Symlink tests ==="
check_symlink "nvim"        "$HOME/.config/nvim"           "$DOTFILES/nvim"
check_symlink "gitconfig"   "$HOME/.gitconfig"             "$DOTFILES/git/.gitconfig"
check_symlink "zellij"      "$HOME/.config/zellij"         "$DOTFILES/zellij"
check_symlink "zshrc"       "$HOME/.zshrc"                 "$DOTFILES/zsh/.zshrc"
check_symlink "p10k"        "$HOME/.p10k.zsh"              "$DOTFILES/zsh/.p10k.zsh"
check_symlink "fuzzy-kill"  "$HOME/.local/bin/fuzzy-kill"  "$DOTFILES/bin/fuzzy-kill"

echo ""
echo "=== Git status test ==="
git_status=$(git -C "$DOTFILES" status --porcelain)
if [ -z "$git_status" ]; then
  echo "PASS: git status clean"
  ((PASS++))
else
  echo "FAIL: git status has changes:"
  echo "$git_status"
  ((FAIL++))
fi

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

[ "$FAIL" -eq 0 ]
