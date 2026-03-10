#!/bin/bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
GIT_PREFIX="/root/.local"  # must match ARG GIT_PREFIX in Dockerfiles

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

  mkdir -p "$ARTIFACTS_DIR/$name"
  container_id=$(podman create "$tag")
  podman cp "${container_id}:${GIT_PREFIX}/bin/git" "$ARTIFACTS_DIR/$name/git"
  podman cp "${container_id}:${GIT_PREFIX}/libexec/git-core" "$ARTIFACTS_DIR/$name/git-core"
  podman rm "$container_id"
  echo "Artifact saved: $ARTIFACTS_DIR/$name/git + git-core/"
}

run_test ubuntu Dockerfile
run_test rocky  Dockerfile.rocky
