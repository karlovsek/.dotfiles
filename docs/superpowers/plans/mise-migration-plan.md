# Replace gah (and the hand-rolled curl/tar installers) with mise in install-minimal.sh

## Context

`install-minimal.sh` installs ~20 CLI tools into `~/.local`. Today that is done three
different ways: via `gah install <repo> --unattended` (8 tools), via bespoke
curl+tar blocks (9 tools, each with its own exists/latest/prompt/dry-run branches),
and via a GitHub `releases/latest` API call per tool (`get_latest_version`) that
burns unauthenticated rate limit fast.

This plan replaces gah and the hand-rolled installers with
[mise](https://mise.jdx.dev) (GitHub-backed tool version manager), collapsing the
"which tool, which version, which asset" concern into one TOML file
(`mise/config.toml`), with a ~40-line glue section left in the script (bootstrap
mise, `mise install`, `mise upgrade`).

**Not moved to mise** (mise doesn't cover these, same as gah before it): zsh
(zsh-bin installer), htop (source build, no prebuilt binaries), git-from-source,
oh-my-zsh + plugins (git clones), symlinks, the tree-sitter GLIBC fix, the
curl/tar restricted-environment wrapper guards, npm-global packages. These stay
exactly as they are today.

This plan document is the spec — it was produced by an earlier planning session,
reviewed, and its open decisions (node → mise, musl policy for delta, cleanup
scope) were explicitly confirmed by the project owner. Treat it as authoritative;
where an implementation subagent hits a judgment call not covered here, prefer the
narrowest change consistent with the intent stated in each task, and note the call
made in its report.

## Global Constraints

- Every new code path in `install-minimal.sh` must respect the script's existing
  conventions: `$DRY_RUN` prints a `[DRY RUN]` line and performs no side effect;
  `$FORCE_UPDATE` skips confirmation prompts; `$ASSUME_YES` (also true whenever
  stdin is not a TTY) must never block on interactive input.
- Use the existing color vars (`${GREEN}`, `${YELLOW}`, `${RED}`, `${NC}`) and
  `echo -e` style already used throughout the script for any new output.
- Do not reorder unrelated sections. Only touch the blocks named in each task.
- `set -e` is active for the whole script. Any new command whose failure should
  be non-fatal (a `mise` subcommand that might legitimately fail on a machine
  without network, for instance) needs its own `|| true` / `|| echo warning`,
  matching the pattern already used throughout the file (e.g. `get_latest_version`
  callers use `|| true`).
- Keep `compare_versions`, `confirm_yn`, `prompt_update`, and `get_latest_version`
  — they are still used by the htop block, which is NOT migrated to mise (no
  prebuilt htop binaries exist). Only `install_or_update_gah` is dead code once
  this plan lands; remove it.
- `install-minimal.sh` has no automated test suite of its own; correctness is
  checked with `bash -n install-minimal.sh` (syntax) and, where feasible,
  `shellcheck install-minimal.sh` (pre-existing warnings may remain, but no NEW
  warnings should be introduced by the diff). The real functional test is the
  podman suite (Task 4), which is not run automatically by every task — task
  reviewers should read the diff carefully instead.

## Task 1: Create `mise/config.toml`

Create a new file at `mise/config.toml` (repo root, new `mise/` directory) with
exactly this content:

```toml
# Global mise config — managed by ~/.dotfiles, symlinked by install-minimal.sh
# to ~/.config/mise/config.toml. Add new mise-managed tools here rather than
# hand-rolling another curl+tar block in install-minimal.sh.
[settings]
experimental = false

[tools]
jq = "latest"
"7zip" = "latest"
fd = "latest"
ripgrep = "latest"
zoxide = "latest"
bat = "latest"
eza = "latest"
lazygit = "latest"
lazydocker = "latest"
zellij = "latest"
fzf = "latest"
broot = "latest"
gdu = "latest"
"github:bgreenwell/lstr" = "latest"
"github:quantumsheep/sshs" = { version = "latest", asset_pattern = "sshs-linux-amd64-musl", bin = "sshs" }
"github:dandavison/delta" = { version = "latest", asset_pattern = "delta-{{version}}-x86_64-unknown-linux-musl.tar.gz" }
"github:neovim/neovim-releases" = { version = "latest", asset_pattern = "nvim-linux-x86_64.tar.gz" }
node = "23"
```

No other changes in this task. This is a new file only — nothing else in the repo
should be touched.

**Verification:** `python3 -c "import tomllib,sys; tomllib.load(open('mise/config.toml','rb'))"`
(or any TOML parser available) must parse the file without error. If `mise` itself
is installed on the machine running this task, `mise config ls -f mise/config.toml`
(or `MISE_CONFIG_FILE=mise/config.toml mise ls`) is a stronger check but is not
required — do not install mise just to run it.

## Task 2: Rewrite `install-minimal.sh` — replace gah/curl/tar installers with mise

This is the core task. It touches one file, `install-minimal.sh`, in several
distinct places. Work from the file as it exists on disk — line numbers below are
a guide from the pre-migration version and may have drifted; locate each block by
the unique comment/text shown, not by line number.

### 2a. Header comment (top of file, `Usage`/`What it installs` block)

Update the tool inventory line:

```
#   nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, btop, bfs, broot, zoxide,
#   bat, eza, delta, gdu, lazygit, lazydocker, zellij, fnm (Node.js), jq, 7zip, gah
```

to:

```
#   nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, btop, bfs, broot, zoxide,
#   bat, eza, delta, gdu, lazygit, lazydocker, zellij, node, jq, 7zip
#
#   Most of the above (everything except zsh, htop, and node's npm globals)
#   are installed and version-managed via mise (https://mise.jdx.dev) using
#   the tool list in mise/config.toml. Run `mise outdated` / `mise upgrade`
#   directly at any time instead of re-running this whole script.
```

Also update the comment at (originally) line 132-134:

```
  # Export the standard env var so downstream installers (gah, etc.) that
  # respect GITHUB_TOKEN also authenticate and avoid the 60/hour unauth limit.
```

to:

```
  # Export the standard env var so downstream installers (mise, etc.) that
  # respect GITHUB_TOKEN also authenticate and avoid the 60/hour unauth limit.
```

### 2b. Remove `install_or_update_gah`

Delete the whole function (comment header `# Install or update a tool via gah
(GitHub Asset Helper)` through its closing `}`). Nothing calls it after this
task's other edits land. Do NOT remove `get_latest_version`, `compare_versions`,
`confirm_yn`, or `prompt_update` — all four remain in use by the htop block later
in the file.

### 2c. Replace the jq / gah / 7zip blocks with the new mise bootstrap section

Delete, as one contiguous removal, everything from the comment
`# -- jq (installed first — both get_latest_version and gah depend on it) ------`
through the end of the 7zip `if/else fi` block (the block that downloads
`7z${version_no_dot}-linux-x64.tar.xz`). This removes: `fetch_jq_latest_version`,
`install_jq_binary`, the jq if/else, the gah if/else, and the 7zip if/else.

In their place, insert this new section (adjust only if the surrounding code
truly requires it — this is meant to be used close to verbatim):

```bash
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
fi

if command -v mise >/dev/null 2>&1; then
  echo -e "${GREEN}Installing/verifying mise-managed tools (see mise/config.toml)...${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would run: mise install${NC}"
    mise install --dry-run || true
  else
    mise install
  fi

  mise_outdated=$(mise outdated 2>/dev/null)
  if [ -n "$mise_outdated" ]; then
    echo -e "${YELLOW}Outdated mise-managed tools:${NC}"
    echo "$mise_outdated"
    if [ "$FORCE_UPDATE" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would run: mise upgrade${NC}"
      else
        mise upgrade
      fi
    elif [ "$DRY_RUN" = true ]; then
      mise upgrade --dry-run || true
    elif [ -t 0 ] && [ "$ASSUME_YES" != true ]; then
      mise upgrade --interactive
    else
      echo "(non-interactive: skipping interactive upgrade prompt — re-run with --force-update to upgrade all)"
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
cleanup_pre_mise_artifacts

if [ -d "$HOME/.local/share/fnm" ]; then
  echo -e "${YELLOW}Note: fnm's install script may have added FNM_PATH / 'fnm env' lines to"
  echo -e "  ~/.bashrc when this machine was first set up. Node is now managed by mise"
  echo -e "  (mise/config.toml); you can remove any such lines by hand if you no longer"
  echo -e "  use fnm directly.${NC}"
fi
```

Notes for the implementer:
- `cleanup_pre_mise_artifacts` must be defined and called only once — do not
  duplicate it if a later block in this task also seems like a natural place
  for cleanup.
- `~/.local/share/fnm` itself IS removed by `cleanup_pre_mise_artifacts` (it's
  in the `targets` array); only the rc-file lines are left for the user,
  because a `sed`/regex strip against `~/.bashrc` risks corrupting unrelated
  content and fnm's installer output format isn't a stable contract to parse.
  This is a deliberate, narrower scope than "removes... the FNM_PATH lines" in
  earlier drafts of this plan — flag it in your task report as a ruling, not
  a gap.

### 2d. Remove the NeoVim block

Delete the whole `# -- NeoVim ---...` if/else block (from that comment through
its closing `fi`, immediately before `# -- ZSH ----`). nvim is now installed by
the mise section added in 2c (`github:neovim/neovim-releases` in
`mise/config.toml`), which runs earlier in the script.

Do NOT touch the `# -- ZSH ----` block immediately after it — zsh is not
migrated to mise (see Global Constraints) and stays exactly as-is.

### 2e. Remove the gah-based fd/sshs/rg/lstr/fzf block

Delete, as one contiguous removal, everything from the comment
`# -- gah-based tools (DRY: all follow the same pattern) -----------------------`
through the end of the fzf if/else block (ends right before the
`# -- htop (build from source) -------------------------------------------------`
comment). This removes the `install_or_update_gah "fd" ...` call, the sshs
direct-download if/else, the `install_or_update_gah "rg" ...` and
`install_or_update_gah "lstr" ...` calls, and the fzf git-clone if/else.

Do NOT touch the htop block that follows — it stays exactly as-is (uses
`get_latest_version` and `prompt_update`, both kept per Global Constraints).

### 2f. Remove the broot/zoxide/bat/eza/delta/gdu block

First, delete the `# NOTE: btop and bfs installers were previously staged
here but are disabled...` comment block — it references
`install_or_update_gah`-style helpers, which no longer exist after this task.

Then delete, as one contiguous removal, everything from
`# -- broot (with update support) ----------------------------------------------`
through the end of the gdu if/else block (ends right before
`###############################################################################`
/ `# Guards: curl wrapper and tar wrapper for restricted environments`). This
removes: the broot if/else, the `install_or_update_gah "zoxide" ...`, `"bat"`,
and `"eza"` calls, the pinned-version delta if/else (including `DELTA_VERSION`,
`DELTA_ARCHIVE`, `DELTA_DIR`), and the gdu if/else.

Do NOT touch the "Guards: curl wrapper and tar wrapper" section that follows —
unrelated to package installer choice, stays exactly as-is.

### 2g. Remove the lazygit/lazydocker/zellij gah calls

Delete these three calls (they appear together, after the tar-wrapper guard
section, before the fuzzy-kill symlink block):

```bash
install_or_update_gah "lazygit" "jesseduffield/lazygit" \
  "lazygit --version | grep -oP 'version=\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1"

install_or_update_gah "lazydocker" "jesseduffield/lazydocker" \
  "lazydocker --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

install_or_update_gah "zellij" "zellij-org/zellij" \
  "zellij --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"
```

Replace with nothing (or, if you prefer, a one-line comment noting these are
mise-managed — `# lazygit, lazydocker, zellij: installed via mise above.`).

Do NOT touch the "Install fuzzy-kill" block immediately after — unrelated,
stays exactly as-is.

### 2h. Remove the "Node.js via fnm" section

Delete the whole section, from the
`###############################################################################`
/ `# Node.js via fnm` header comment through the closing `fi` of the
`if command -v node...else...fi` block (immediately before the
"Install npm packages required by nvim mason" block). Node is now installed by
the mise section added in 2c (`node = "23"` in `mise/config.toml`).

Replace the deleted section's header comment with a single line:

```bash
# Node.js is installed via mise (see mise/config.toml: node = "23").
```

### 2i. `mise reshim` after the npm-globals install

In the "Install npm packages required by nvim mason" block, immediately after
the line `npm install -g tree-sitter-cli markdownlint-cli2 markdown-toc`, add:

```bash
    command -v mise >/dev/null 2>&1 && mise reshim
```

This ensures `tree-sitter`, `markdownlint-cli2`, and `markdown-toc` are also
exposed through mise's shims dir (node/npm are mise-managed as of this plan, so
their global bin dir lives under mise's node install, not `$INSTALL_BIN_DIR`).
Leave the rest of that block — including the `fix_treesitter_glibc` calls in
both the dry-run and real branches — untouched.

### Verification for Task 2

- `bash -n install-minimal.sh` must succeed (syntax check only, no execution).
- `grep -n 'install_or_update_gah\|gah install\|get_latest_version "neovim' install-minimal.sh`
  must return no matches (confirms the dead function and the old gah/nvim call
  sites are gone). `get_latest_version` itself (the function definition, and its
  two remaining call sites in the htop block) legitimately still matches
  `get_latest_version` — only make sure `get_latest_version "neovim` (the old
  nvim call site) is gone.
- `grep -c 'get_latest_version' install-minimal.sh` should be around 5-6 (one
  definition + the two htop call sites' `get_latest_version "htop-dev/htop" ""`
  each appearing twice, plus the doc comment inside the function) — sanity, not
  an exact contract.
- Read through the resulting file top to bottom once and confirm the
  `mise install` / `mise upgrade` section physically appears BEFORE
  `compile_git_if_needed` is called, and BEFORE the htop block (htop's
  `get_latest_version` call needs jq, which is now installed by mise).

## Task 3: Update `zsh/.zshrc`

Three independent, small edits to `zsh/.zshrc`:

1. Add mise shell activation after the Powerlevel10k instant-prompt block
   (the block that sources `p10k-instant-prompt-*.zsh`) and before the
   `export ZSH="$HOME/.oh-my-zsh"` line:

   ```zsh
   # Activate mise (tool version manager) — installs shims for mise-managed
   # tools onto PATH and hooks cd to pick up per-directory .mise.toml files.
   # mise prints nothing on activation, so this is safe above the p10k
   # instant-prompt boundary... but keep it AFTER instant-prompt anyway,
   # matching install-minimal.sh's ordering assumptions and avoiding any
   # stdout-before-instant-prompt lint warnings from p10k.
   if (( $+commands[mise] )); then
     eval "$(mise activate zsh)"
   fi
   ```

   Place this new block immediately after the `if [[ -r
   "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
   ... fi` block, before the `# Path to your oh-my-zsh installation.` comment.

2. Remove the `FZF_BASE` fallback line. Currently:

   ```zsh
   if [ -n "${commands[fzf-share]}" ]; then
   # For nix
     source "$(fzf-share)/key-bindings.zsh"
     source "$(fzf-share)/completion.zsh"
     FZF_BASE=$(fzf-share)
   else
     export FZF_BASE=$HOME/.local/fzf
   fi
   ```

   Change the `else` branch's body from `export FZF_BASE=$HOME/.local/fzf` to
   nothing meaningful to do — since fzf is now mise-managed (binary only, no
   `$HOME/.local/fzf` checkout exists anymore), replace the whole `if/else/fi`
   with just the nix-specific sourcing, unconditionally guarded by the same
   `fzf-share` check, i.e.:

   ```zsh
   if [ -n "${commands[fzf-share]}" ]; then
   # For nix
     source "$(fzf-share)/key-bindings.zsh"
     source "$(fzf-share)/completion.zsh"
   fi
   ```

   (Drop the `FZF_BASE=$(fzf-share)` assignment too — nothing in this repo
   reads `$FZF_BASE` once the `else` branch is gone; confirm with
   `grep -rn FZF_BASE` across the repo before deleting, and if some other file
   does read it, keep the assignment in the `if` branch only.)

3. Remove the line `[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh` entirely (it's a
   single line, standalone, a few lines above the zoxide block). The Oh My Zsh
   `fzf` plugin (already enabled in the `plugins=(...)` array earlier in this
   file) calls `fzf --zsh` itself when fzf is on PATH, which mise's shim now
   provides — this line is redundant and the file it sources (`~/.fzf.zsh`) is
   no longer created by anything.

4. Remove the fnm block near the end of the file:

   ```zsh
   FNM_PATH="$HOME/.local/share/fnm"
   if [ -d "$FNM_PATH" ]; then
     export PATH="$FNM_PATH:$PATH"
     eval "$(fnm env --shell zsh)"
   fi
   ```

   Delete these 4 lines entirely. Node is now installed via mise (see
   `mise/config.toml`), and mise's `zsh activate` (added in edit 1 above)
   already puts node's mise shim on PATH.

### Verification for Task 3

- `zsh -n zsh/.zshrc` (syntax check only) must succeed if zsh is available in
  the task environment; if zsh isn't installed, at minimum confirm the file
  has no unbalanced `if`/`fi` by eye and note in the report that the zsh
  syntax check couldn't run.
- `grep -n 'FZF_BASE\|fnm env\|FNM_PATH\|\.fzf\.zsh' zsh/.zshrc` should return
  no matches after the edit (aside from anything intentionally kept per point
  2's caveat about other readers of `$FZF_BASE`).

## Task 4: Update the podman test suite

Three files change: `podman/validate.sh`, `podman/test.sh`,
`podman/Dockerfile.test-ubuntu`, `podman/Dockerfile.test-rocky`.

### 4a. `podman/validate.sh`

- Update the PATH export near the top:

  ```bash
  export PATH="$HOME/.local/bin:$HOME/.local/fzf/bin:$HOME/.local/share/fnm:$PATH"
  ```

  to:

  ```bash
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  ```

  (Drop the now-nonexistent `~/.local/fzf/bin` and `~/.local/share/fnm`
  entries; add the mise shims dir.)

- In section "1. Binary existence tests", replace the `check_binary "gah" "gah"
  "version"` line with a check that mise itself is present and, separately,
  that it has every configured tool installed:

  ```bash
  check_binary "mise" "mise" "--version"
  ```

  Immediately after the existing `check_binary` calls in that section (still
  inside section 1, after the `check_binary "zellij"` line), add:

  ```bash
  if command -v mise >/dev/null 2>&1; then
    missing_mise_tools=$(mise ls --missing 2>/dev/null)
    if [ -z "$missing_mise_tools" ]; then
      pass "mise: all configured tools installed"
    else
      fail "mise: missing tools -- $missing_mise_tools"
    fi
  else
    fail "mise -- binary not found, can't check installed tools"
  fi
  ```

  Leave every other `check_binary` line in section 1 unchanged — jq, 7zz,
  nvim, zsh, fd, sshs, rg, lstr, fzf, htop, broot, zoxide, bat, eza, delta,
  gdu, lazygit, lazydocker, zellij are all still expected to exist on PATH
  (via mise shims now, instead of gah/curl installs), so their checks don't
  need to change.

- Add a new section 12 at the end of the file (after "11. Git repo status",
  before the "Summary" block), which verifies the install script is
  idempotent on a second run:

  ```bash
  ###############################################################################
  echo -e "\n${BOLD}${CYAN}=== 12. Idempotency (second run) ===${NC}"
  ###############################################################################

  if command -v mise >/dev/null 2>&1; then
    before_outdated=$(mise outdated 2>/dev/null)

    if bash "$DOTFILES/install-minimal.sh" --yes < /dev/null > /tmp/second-run.log 2>&1; then
      pass "second run of install-minimal.sh exits cleanly"
    else
      fail "second run of install-minimal.sh failed (see /tmp/second-run.log)"
    fi

    missing_after_second_run=$(mise ls --missing 2>/dev/null)
    if [ -z "$missing_after_second_run" ]; then
      pass "mise: all tools still installed after second run"
    else
      fail "mise: tools missing after second run -- $missing_after_second_run"
    fi

    after_outdated=$(mise outdated 2>/dev/null)
    if [ "$before_outdated" = "$after_outdated" ]; then
      pass "mise outdated list unchanged across second run (no surprise re-installs)"
    else
      fail "mise outdated list changed across second run"
    fi
  else
    skip "mise not found, can't check idempotency"
  fi
  ```

  Update the `echo` header comment at the top of the file (the numbered list
  of what this script tests, lines 5-15) to add item 12 (idempotency) and
  remove/adjust the stale "10. fuzzy-kill" numbering if it collides — the
  existing list is 1-10 in the header comment but the file actually has 11
  sections (git repo status is section 11, undocumented in the header list);
  fix the header comment to list all 12 sections accurately while you're
  there.

### 4b. `podman/test.sh`

Apply the equivalent, smaller-scope changes (this file is a simpler/older
sibling of `validate.sh`, used elsewhere in the podman flow — check
`podman/Dockerfile*` and `podman/run-tests.sh` to confirm which of
`test.sh`/`validate.sh` is actually wired into the current test flow before
deciding whether `test.sh` is dead code; if it's unused by any Dockerfile or
`run-tests.sh`, say so in your report instead of guessing at its updates):

- Update `export PATH="$HOME/.local/bin:$HOME/.local/fzf/bin:$PATH"` to
  `export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"`.
- Replace `check "gah" gah version` with `check "mise" mise --version`.

### 4c. `podman/Dockerfile.test-ubuntu` and `podman/Dockerfile.test-rocky`

Find the `RUN export PATH=... && printf '\ny\ny\ny\ny\ny\n' | GITHUB_PAT=...
bash /home/testuser/.dotfiles/install-minimal.sh --force-update 2>&1 || true`
line in each file. This already runs the script once; `validate.sh`'s new
section 12 (added in 4a) runs it a second time at test time, so no change is
needed here for idempotency specifically. Do, however, widen the PATH export
on this line to match validate.sh's new PATH (mise shims), since some Docker
layer caching setups run intermediate `RUN` steps that assume tools are
already on PATH:

```
RUN export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" \
```

Make this exact substitution (only the `export PATH=...` prefix) in both
Dockerfiles; leave the rest of each `RUN` line, and everything else in both
files, untouched.

### Verification for Task 4

- `bash -n podman/validate.sh` and `bash -n podman/test.sh` must both succeed.
- `grep -rn 'gah\|\.local/fzf\|\.local/share/fnm' podman/` should return no
  matches after the edits (aside from anything you deliberately decided to
  leave and explained in your report, e.g. if `test.sh` turns out to be dead
  code and you chose not to touch it).
- This task does NOT need to actually run the podman containers (no docker/
  podman guarantee in the task environment) — a careful read-through plus the
  syntax checks above is the bar. Note in your report whether you were able to
  run `./podman/run-tests.sh` and what happened if you did.

## Task 5: Update documentation

Two files: the root `CLAUDE.md` and `README.md`. Both currently mention gah;
neither currently documents `mise/config.toml`.

### 5a. `CLAUDE.md`

In the `## Installation` section, change:

```
`install-minimal.sh` installs everything to `$HOME/.local`, downloads tools from GitHub releases, creates symlinks, and installs Oh My ZSH and plugins. Tools: nvim, zsh, fd, sshs, ripgrep, lstr, fzf, htop, btop, bfs, broot, zoxide, bat, eza, delta, gdu, lazygit, lazydocker, zellij, fnm (for Node.js), jq, 7zip, gah.
```

to:

```
`install-minimal.sh` installs everything to `$HOME/.local`, downloads tools from GitHub releases, creates symlinks, and installs Oh My ZSH and plugins. Most tools are installed and version-managed via [mise](https://mise.jdx.dev) (config in `mise/config.toml`, symlinked to `~/.config/mise/config.toml`): nvim, fd, sshs, ripgrep, lstr, fzf, broot, zoxide, bat, eza, delta, gdu, lazygit, lazydocker, zellij, node, jq, 7zip. A few tools are installed outside mise because no prebuilt binaries exist or mise doesn't cover them: zsh (zsh-bin), htop (built from source), git (optionally compiled from source, see below).

Use `mise outdated` / `mise upgrade` directly to check for and apply tool updates without re-running the whole install script.
```

Add a short new subsection right after `## Symlink Management` (before
`## Neovim Configuration`), documenting the mise symlink alongside the others
already listed there — actually, simpler: just add this one line to the
existing symlink list in that section:

```
ln -sfn $HOME/.dotfiles/mise/config.toml $HOME/.config/mise/config.toml
```

### 5b. `README.md`

`README.md` doesn't currently name gah or any specific tool, so no changes are
strictly required there. Read it and confirm; if you find any stale reference
to gah, fnm, or the old tool list, fix it, but don't invent new content — this
file is intentionally minimal.

### Verification for Task 5

- Read both files back after editing and confirm no remaining mentions of
  `gah` (`grep -n gah CLAUDE.md README.md` → no output) except inside this
  plan file itself, which isn't part of this task's scope.
