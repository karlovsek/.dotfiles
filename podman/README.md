# Building a portable static git with HTTPS support

The Dockerfiles in this directory build git 2.51.0 as a **fully static binary** (musl libc,
no shared library dependencies) with HTTPS support via a minimal libcurl (OpenSSL + zlib only).
The same binary works on Ubuntu, Rocky Linux, and any other Linux x86_64 distro.

## Quick start — build everything and extract artifacts

```bash
cd ~/.dotfiles/podman
bash run-tests.sh
```

This builds both images, runs all tests (including a live `git clone https://github.com/...`),
and extracts the binaries into `artifacts/`:

```
artifacts/
  ubuntu/
    git                  # the static git binary
    git-core/            # helper programs (git-remote-https, etc.)
  rocky/
    git
    git-core/
```

## Build only git (no dotfiles, no tests)

The `git-builder` stage is a standalone Alpine build — no dotfiles involved.
Target it directly with `--target git-builder`:

```bash
cd ~/.dotfiles/podman

podman build --target git-builder -t git-static .

# Extract
mkdir -p artifacts/git
cid=$(podman create git-static)
podman cp "${cid}:/root/.local/bin/git"          artifacts/git/git
podman cp "${cid}:/root/.local/libexec/git-core" artifacts/git/git-core
podman rm "$cid"
```

Both Dockerfiles (`Dockerfile` and `Dockerfile.rocky`) share the same `git-builder` stage,
so either file produces the same static binary.

---

## Build and extract one distro at a time

### Ubuntu 22.04

```bash
cd ~/.dotfiles/podman

# Build
podman build -f Dockerfile -t dotfiles-test-ubuntu .

# Test (optional)
podman run --rm dotfiles-test-ubuntu

# Extract
mkdir -p artifacts/ubuntu
cid=$(podman create dotfiles-test-ubuntu)
podman cp "${cid}:/root/.local/bin/git"            artifacts/ubuntu/git
podman cp "${cid}:/root/.local/libexec/git-core"   artifacts/ubuntu/git-core
podman rm "$cid"
```

### Rocky Linux 8.5

```bash
cd ~/.dotfiles/podman

# Build
podman build -f Dockerfile.rocky -t dotfiles-test-rocky .

# Test (optional)
podman run --rm dotfiles-test-rocky

# Extract
mkdir -p artifacts/rocky
cid=$(podman create dotfiles-test-rocky)
podman cp "${cid}:/root/.local/bin/git"            artifacts/rocky/git
podman cp "${cid}:/root/.local/libexec/git-core"   artifacts/rocky/git-core
podman rm "$cid"
```

## Verify the artifact

```bash
# Confirm it is a static binary (no shared lib deps)
file artifacts/ubuntu/git
# → ELF 64-bit LSB executable, x86-64, statically linked, stripped

ldd artifacts/ubuntu/git
# → not a dynamic executable

# Confirm HTTPS helper is present
ls artifacts/ubuntu/git-core/git-remote-https

# Confirm it works (GIT_EXEC_PATH and GIT_CONFIG_NOSYSTEM required when running outside Docker)
GIT_EXEC_PATH=$PWD/artifacts/ubuntu/git-core \
GIT_CONFIG_NOSYSTEM=1 \
  artifacts/ubuntu/git clone --depth 1 https://github.com/karlovsek/.dotfiles.git /tmp/test-clone
```

## Install / uninstall

```bash
# Install (auto-detects distro from /etc/os-release)
bash install-git.sh

# Or specify distro and prefix
bash install-git.sh --distro ubuntu --prefix ~/.local

# Uninstall
bash uninstall-git.sh
```

The install script copies `git-core/` to `$PREFIX/libexec/git-core` and creates a
relocatable **wrapper script** at `$PREFIX/bin/git`. The wrapper resolves its own
location at runtime using `dirname`, then sets `GIT_EXEC_PATH` and
`GIT_CONFIG_NOSYSTEM=1` before exec-ing the real binary. This means every caller
(lazygit, editors, scripts) gets the correct env vars automatically.

## Notes

- **CA certificates on Rocky/RHEL**: Rocky stores CA certs at
  `/etc/pki/tls/certs/ca-bundle.crt` while the binary (built on Alpine) expects
  `/etc/ssl/certs/ca-certificates.crt`. The Dockerfile.rocky creates the needed symlink.
  If you deploy the binary to another RHEL-based system, create the same symlink or set
  `GIT_SSL_CAINFO=/etc/pki/tls/certs/ca-bundle.crt`.

- **GITHUB_PAT**: pass `--build-arg GITHUB_PAT=<token>` to avoid GitHub API rate limits
  during `install-minimal.sh`.
