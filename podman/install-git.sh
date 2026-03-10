#!/bin/bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"

PREFIX="$HOME/.local"
DISTRO=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--distro ubuntu|rocky] [--prefix PREFIX]

Options:
  --distro  ubuntu|rocky   artifact to install (auto-detected from /etc/os-release if omitted)
  --prefix  PATH           installation prefix (default: \$HOME/.local)
  -h, --help               show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro)  DISTRO="$2";  shift 2 ;;
    --prefix)  PREFIX="$2";  shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

# Auto-detect distro from /etc/os-release
if [[ -z "$DISTRO" ]]; then
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID:-}" in
      ubuntu)                               DISTRO=ubuntu ;;
      rhel|rocky|centos|almalinux|fedora)   DISTRO=rocky  ;;
      *)
        echo "Cannot auto-detect distro (ID=${ID:-unknown})."
        echo "Use --distro ubuntu or --distro rocky"
        exit 1
        ;;
    esac
    echo "Detected distro: $DISTRO (ID=$ID)"
  else
    echo "/etc/os-release not found. Use --distro ubuntu or --distro rocky"
    exit 1
  fi
fi

ARTIFACT_DIR="$ARTIFACTS_DIR/$DISTRO"

if [[ ! -f "$ARTIFACT_DIR/git" ]]; then
  echo "Artifact not found: $ARTIFACT_DIR/git"
  echo "Build it first with: bash build-git.sh $DISTRO"
  exit 1
fi

echo "Installing git from: $ARTIFACT_DIR"
echo "  Install prefix:    $PREFIX"

# Install helpers into libexec/git-core/ (this directory already includes
# the git binary itself as one of the entries)
mkdir -p "$PREFIX/bin" "$PREFIX/libexec"
cp -r "$ARTIFACT_DIR/git-core" "$PREFIX/libexec/git-core"

# Create a wrapper at bin/git that sets the required env vars so that every
# caller — lazygit, editors, scripts — gets them automatically, not just
# interactive shells.  GIT_CONFIG_NOSYSTEM suppresses the permission error on
# the system gitconfig that was compiled in for /root/.local/etc/gitconfig.
cat > "$PREFIX/bin/git" <<'WRAPPER'
#!/bin/sh
SELF_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
exec env \
  GIT_EXEC_PATH="$SELF_DIR/libexec/git-core" \
  GIT_CONFIG_NOSYSTEM=1 \
  "$SELF_DIR/libexec/git-core/git" "$@"
WRAPPER
chmod +x "$PREFIX/bin/git"

echo "Installed:"
echo "  $PREFIX/bin/git  (wrapper)"
echo "  $PREFIX/libexec/git-core/"

# On RHEL-based distros the CA bundle lives at a different path than what
# Alpine's OpenSSL defaults to — create the symlink if needed
if [[ "$DISTRO" == "rocky" ]] && [[ -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
  if [[ ! -e /etc/ssl/certs/ca-certificates.crt ]]; then
    echo ""
    echo "Creating CA cert symlink (requires sudo):"
    echo "  /etc/ssl/certs/ca-certificates.crt -> /etc/pki/tls/certs/ca-bundle.crt"
    sudo mkdir -p /etc/ssl/certs
    sudo ln -sf /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
  fi
fi

# Smoke test
echo ""
echo "--- Smoke test ---"
"$PREFIX/bin/git" --version

"$PREFIX/bin/git" ls-remote --heads https://github.com/karlovsek/.dotfiles.git >/dev/null 2>&1 \
  && echo "PASS: git https" \
  || echo "FAIL: git https"
