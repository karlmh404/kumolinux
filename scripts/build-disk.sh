#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
need mke2fs
root="$OUT_DIR/rootfs-base"
image="$OUT_DIR/images/kumo-root.img"
[[ -x "$root/usr/lib/systemd/systemd" ]] || die 'base rootfs missing systemd; run make base'
mkdir -p "$OUT_DIR/images"
truncate -s "${KUMO_DISK_SIZE:-4G}" "$image"
mke2fs -q -F -t ext4 -b 4096 -U 4b554d4f-0002-4000-8000-000000000002 \
  -L KUMO_ROOT -E root_owner=0:0,lazy_itable_init=0,lazy_journal_init=0 \
  -d "$root" "$image"
e2fsck -fn "$image"
log "persistent ext4 image: $image"
