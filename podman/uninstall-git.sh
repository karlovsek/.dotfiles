#!/bin/bash
set -e

PREFIX="$HOME/.local"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--prefix PREFIX]

Options:
  --prefix  PATH   installation prefix (default: \$HOME/.local)
  -h, --help       show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)  PREFIX="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

REMOVED=0

if [[ -f "$PREFIX/bin/git" ]]; then
  rm -f "$PREFIX/bin/git"
  echo "Removed: $PREFIX/bin/git"
  REMOVED=$((REMOVED + 1))
else
  echo "Not found:  $PREFIX/bin/git"
fi

if [[ -d "$PREFIX/libexec/git-core" ]]; then
  rm -rf "$PREFIX/libexec/git-core"
  echo "Removed: $PREFIX/libexec/git-core/"
  REMOVED=$((REMOVED + 1))
else
  echo "Not found:  $PREFIX/libexec/git-core/"
fi


if [[ $REMOVED -eq 0 ]]; then
  echo "Nothing to remove."
else
  echo ""
  echo "Uninstall complete."
fi
