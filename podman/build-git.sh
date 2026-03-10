#!/bin/bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"

GIT_VERSION="2.51.0"
GIT_PREFIX="/root/.local"  # must match ARG GIT_PREFIX in Dockerfiles
TARGETS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [TARGET...] [--git-version VERSION]

Targets:
  ubuntu    Build for Ubuntu 22.04
  rocky     Build for Rocky Linux 8.5
  all       Build for both (default)

Options:
  -v, --git-version VERSION   git version to build (default: $GIT_VERSION)
  -h, --help                  Show this help

Examples:
  $(basename "$0")
  $(basename "$0") ubuntu
  $(basename "$0") ubuntu rocky --git-version 2.48.0
  $(basename "$0") all --git-version 2.50.0
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--git-version) GIT_VERSION="$2"; shift 2 ;;
    ubuntu|rocky|all) TARGETS+=("$1"); shift ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=("all")
[[ " ${TARGETS[*]} " == *" all "* ]] && TARGETS=("ubuntu" "rocky")

build_git() {
  local name="$1"
  local dockerfile="$2"
  local tag="git-static-${name}-${GIT_VERSION}"
  local out_dir="$ARTIFACTS_DIR/$name"

  echo ""
  echo "========================================"
  echo " Building git ${GIT_VERSION} for ${name}"
  echo "========================================"

  podman build \
    --target git-builder \
    --build-arg GIT_VERSION="${GIT_VERSION}" \
    --build-arg GIT_PREFIX="${GIT_PREFIX}" \
    -f "$SCRIPT_DIR/$dockerfile" \
    -t "$tag" \
    "$SCRIPT_DIR"

  mkdir -p "$out_dir"
  local cid
  cid=$(podman create "$tag")
  podman cp "${cid}:${GIT_PREFIX}/bin/git"          "$out_dir/git"
  podman cp "${cid}:${GIT_PREFIX}/libexec/git-core" "$out_dir/git-core"
  podman rm "$cid"

  echo ""
  echo "Artifact: $out_dir/git"
  echo "  $(file "$out_dir/git")"

  echo ""
  echo "--- Testing extracted binary ---"
  GIT_EXEC_PATH="$out_dir/git-core" \
  GIT_CONFIG_NOSYSTEM=1 \
    "$out_dir/git" ls-remote --heads https://github.com/karlovsek/.dotfiles.git >/dev/null 2>&1 \
    && echo "PASS: git https (${name})" \
    || echo "FAIL: git https (${name})"
  echo "  $(GIT_EXEC_PATH="$out_dir/git-core" GIT_CONFIG_NOSYSTEM=1 "$out_dir/git" --version)"
}

for target in "${TARGETS[@]}"; do
  case "$target" in
    ubuntu) build_git ubuntu Dockerfile ;;
    rocky)  build_git rocky  Dockerfile.rocky ;;
  esac
done
