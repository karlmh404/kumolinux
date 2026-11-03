#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
mkdir -p "$CACHE_DIR/packages"
urls=(
  https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz
  https://ftp.gnu.org/gnu/coreutils/coreutils-9.8.tar.xz
  https://git.kernel.org/pub/scm/utils/dash/dash.git/snapshot/dash-0.5.12.tar.gz
  https://ftp.gnu.org/gnu/diffutils/diffutils-3.12.tar.xz
  https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz
  https://ftp.gnu.org/gnu/grep/grep-3.12.tar.xz
  https://ftp.gnu.org/gnu/gzip/gzip-1.14.tar.xz
  https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz
  https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz
  https://github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.xz
  https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.41/util-linux-2.41.2.tar.xz
  https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-4.0.5.tar.xz/download
  https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/kmod-34.2.tar.xz
  https://github.com/shadow-maint/shadow/releases/download/4.18.0/shadow-4.18.0.tar.xz
  https://github.com/systemd/systemd/archive/refs/tags/v258.1.tar.gz
  https://zlib.net/fossils/zlib-1.3.1.tar.gz
  https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz
  https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.76.tar.xz
  https://github.com/besser82/libxcrypt/releases/download/v4.4.38/libxcrypt-4.4.38.tar.xz
)
for url in "${urls[@]}"; do
  file="${url##*/}"
  [[ "$file" == download ]] && file=procps-ng-4.0.5.tar.xz
  [[ -f "$CACHE_DIR/packages/$file" ]] || curl --fail --location --retry 3 --output "$CACHE_DIR/packages/$file" "$url"
done
(cd "$CACHE_DIR/packages" && sha256sum ./*)
