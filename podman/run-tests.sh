#!/bin/bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

run_test() {
  local name="$1"
  local dockerfile="$2"
  local tag="dotfiles-test-${name}"
  echo ""
  echo "========================================"
  echo " Building: $name ($dockerfile)"
  echo "========================================"
  podman build \
    --build-arg GITHUB_PAT="${GITHUB_PAT:-}" \
    -f "$SCRIPT_DIR/$dockerfile" \
    -t "$tag" \
    "$SCRIPT_DIR"

  echo ""
  echo "========================================"
  echo " Running tests: $name"
  echo "========================================"
  podman run --rm "$tag"
}

run_test ubuntu Dockerfile
run_test rocky  Dockerfile.rocky
