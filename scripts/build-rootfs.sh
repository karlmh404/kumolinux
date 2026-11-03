#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"; require_toolchain
build="$WORK_DIR/busybox-build"; [[ -x "$build/busybox" ]] || die 'BusyBox missing; run make busybox'
root="$OUT_DIR/rootfs"; rm -rf -- "$root"; mkdir -p "$root"
make -C "$(source_dir_for busybox)" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" CONFIG_PREFIX="$root" install
mkdir -p "$root"/{dev,etc,home,lib,lib64,mnt,opt,proc,root,run,sbin,sys,tmp,usr/bin,usr/lib,usr/sbin,var}
rm -f -- "$root/sbin/init" "$root/init"
cp -a "$REPO_ROOT/rootfs/overlay/." "$root/"
cp -a "$root/sbin/init" "$root/init"
chmod 0755 "$root/init" "$root/sbin/init"; chmod 1777 "$root/tmp"
for p in var/lib/dpkg var/lib/rpm etc/apt etc/dnf etc/pacman.conf; do [[ ! -e "$root/$p" ]] || die "forbidden host/distro path leaked: /$p"; done
grep -R -E -i 'Ubuntu|Debian|Fedora|Arch Linux|Alpine' "$root/etc" && die 'foreign distribution identity detected' || true

