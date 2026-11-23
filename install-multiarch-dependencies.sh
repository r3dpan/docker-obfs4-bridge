#!/bin/bash
set -e

arch="$1"

case "$arch" in
  amd64) pkg_prefix="x86-64";;
  arm64) pkg_prefix="aarch64";;
  *) echo "unsupported architecture: ${arch}" >&2; exit 1;;
esac

dpkg --add-architecture "${arch}"

apt-get update

apt-get install -y --no-install-recommends \
    automake \
    git \
    ca-certificates \
    build-essential \
    pkg-config \
    libevent-dev:${arch} \
    zlib1g-dev:${arch} \
    libssl-dev:${arch} \
    liblzma-dev:${arch} \
    libzstd-dev:${arch} \
    gcc-${pkg_prefix}-linux-gnu \
    binutils-${pkg_prefix}-linux-gnu