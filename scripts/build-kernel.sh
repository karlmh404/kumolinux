#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"; require_toolchain
src="$(extract_source linux linux)"; build="$WORK_DIR/kernel-build"; mkdir -p "$build" "$OUT_DIR/boot" "$OUT_DIR/kernel"
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" x86_64_defconfig
"$src/scripts/kconfig/merge_config.sh" -m -O "$build" "$build/.config" "$CONFIG_DIR/kernel.fragment"
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" -j"$(jobs)" bzImage
cp "$build/arch/x86/boot/bzImage" "$OUT_DIR/boot/vmlinuz-kumo"; cp "$build/.config" "$OUT_DIR/kernel/config"

