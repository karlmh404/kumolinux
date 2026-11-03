#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
case "${1:-}" in --distclean) rm -rf -- "$WORK_DIR" "$OUT_DIR";; '') rm -rf -- "$WORK_DIR/kernel-build" "$WORK_DIR/busybox-build" "$OUT_DIR/boot" "$OUT_DIR/kernel" "$OUT_DIR/rootfs";; *) die "usage: $0 [--distclean]";; esac

