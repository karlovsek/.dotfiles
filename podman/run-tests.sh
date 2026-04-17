#!/bin/bash
###############################################################################
# run-tests.sh — Build and run dotfiles validation on all supported distros
#
# Usage:
#   ./podman/run-tests.sh                    # Run all tests
#   ./podman/run-tests.sh ubuntu             # Run only Ubuntu test
#   ./podman/run-tests.sh rocky              # Run only Rocky test
#
# Set GITHUB_PAT to avoid API rate limits:
#   GITHUB_PAT=ghp_xxx ./podman/run-tests.sh
#
# Supports both docker and podman (auto-detected).
###############################################################################
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
GIT_PREFIX="/home/testuser/.local"  # must match ARG GIT_PREFIX in Dockerfiles

# Auto-detect container runtime
if command -v podman >/dev/null 2>&1; then
  RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
  RUNTIME=docker
else
  echo "Error: neither podman nor docker found in PATH"
  exit 1
fi

echo "Using container runtime: $RUNTIME"

OVERALL_PASS=0
OVERALL_FAIL=0

run_test() {
  local name="$1"
  local dockerfile="$2"
  local tag="dotfiles-test-${name}"
  echo ""
  echo "========================================"
  echo " Building: $name ($dockerfile)"
  echo "========================================"
  $RUNTIME build \
    --build-arg GITHUB_PAT="${GITHUB_PAT:-}" \
    -f "$SCRIPT_DIR/$dockerfile" \
    -t "$tag" \
    "$REPO_ROOT"

  echo ""
  echo "========================================"
  echo " Running validation: $name"
  echo "========================================"
  if $RUNTIME run --rm "$tag"; then
    echo ""
    echo "========================================"
    echo " $name: ALL TESTS PASSED"
    echo "========================================"
    OVERALL_PASS=$((OVERALL_PASS + 1))
  else
    echo ""
    echo "========================================"
    echo " $name: SOME TESTS FAILED"
    echo "========================================"
    OVERALL_FAIL=$((OVERALL_FAIL + 1))
  fi

  # Extract git artifacts if needed
  mkdir -p "$ARTIFACTS_DIR/$name"
  local container_id
  container_id=$($RUNTIME create "$tag")
  $RUNTIME cp "${container_id}:${GIT_PREFIX}/bin/git" "$ARTIFACTS_DIR/$name/git" 2>/dev/null || true
  $RUNTIME cp "${container_id}:${GIT_PREFIX}/libexec/git-core" "$ARTIFACTS_DIR/$name/git-core" 2>/dev/null || true
  $RUNTIME rm "$container_id" >/dev/null
  echo "Artifacts saved to: $ARTIFACTS_DIR/$name/"
}

# Determine which tests to run
targets="${1:-all}"

case "$targets" in
  ubuntu)
    run_test ubuntu Dockerfile.test-ubuntu
    ;;
  rocky)
    run_test rocky Dockerfile.test-rocky
    ;;
  all)
    run_test ubuntu Dockerfile.test-ubuntu
    run_test rocky  Dockerfile.test-rocky
    ;;
  *)
    echo "Unknown target: $targets"
    echo "Usage: $0 [ubuntu|rocky|all]"
    exit 1
    ;;
esac

echo ""
echo "========================================"
echo " Overall: $OVERALL_PASS passed, $OVERALL_FAIL failed"
echo "========================================"
[ "$OVERALL_FAIL" -eq 0 ]
