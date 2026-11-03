#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"; require_toolchain
src="$(extract_source linux linux)"; build="$WORK_DIR/kernel-build"
modules="$OUT_DIR/kernel-modules"
mkdir -p "$build" "$OUT_DIR/boot" "$OUT_DIR/kernel"
rm -rf -- "$modules"
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" x86_64_defconfig
"$src/scripts/kconfig/merge_config.sh" -m -O "$build" "$build/.config" \
  "$CONFIG_DIR/kernel.fragment" "$CONFIG_DIR/kernel-hardware.fragment"
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" -j"$(jobs)" bzImage modules
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" \
  INSTALL_MOD_PATH="$modules" INSTALL_MOD_STRIP=1 modules_install
kernel_release="$(make -s -C "$src" O="$build" ARCH=x86_64 kernelrelease)"
depmod -b "$modules" "$kernel_release"
cp "$build/arch/x86/boot/bzImage" "$OUT_DIR/boot/vmlinuz-kumo"
cp "$build/.config" "$OUT_DIR/kernel/config"
printf '%s\n' "$kernel_release" > "$OUT_DIR/kernel/release"
