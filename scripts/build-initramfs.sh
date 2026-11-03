#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"; need cpio; need gzip
root="$OUT_DIR/rootfs"; [[ -x "$root/sbin/init" ]] || die 'rootfs missing'
mkdir -p "$OUT_DIR/boot"
(cd "$root"; find . -print0 | LC_ALL=C sort -z | cpio --null -o --format=newc --owner=0:0 --reproducible 2>/dev/null | gzip -n -9 > "$OUT_DIR/boot/initramfs-kumo.cpio.gz")

