FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root

RUN apt-get update && apt-get install -y \
    curl \
    git \
    make \
    gcc \
    autoconf \
    automake \
    libncurses-dev \
    xz-utils \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/karlovsek/.dotfiles.git /root/.dotfiles

WORKDIR /tmp

ARG GITHUB_PAT
RUN printf '\nn\n\n\n\n\n' | GITHUB_PAT="${GITHUB_PAT}" bash /root/.dotfiles/install-minimal.sh || true

COPY test.sh /root/test.sh
CMD ["/bin/bash", "/root/test.sh"]
