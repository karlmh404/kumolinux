#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"; require_toolchain
src="$(extract_source busybox busybox)"; build="$WORK_DIR/busybox-build"; mkdir -p "$build"
if [[ -x "$build/busybox" ]] && file "$build/busybox" | grep -q 'statically linked'; then
  log 'static BusyBox already complete'
  exit 0
fi
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" defconfig
sed -i \
  -e 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' \
  -e 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' \
  -e 's/^CONFIG_DPKG=y$/# CONFIG_DPKG is not set/' \
  -e 's/^CONFIG_DPKG_DEB=y$/# CONFIG_DPKG_DEB is not set/' \
  -e 's/^CONFIG_RPM=y$/# CONFIG_RPM is not set/' \
  -e 's/^CONFIG_RPM2CPIO=y$/# CONFIG_RPM2CPIO is not set/' \
  -e 's/^CONFIG_SELINUX=y$/# CONFIG_SELINUX is not set/' \
  -e 's/^CONFIG_FEATURE_INETD_RPC=y$/# CONFIG_FEATURE_INETD_RPC is not set/' \
  "$build/.config"
grep -qx 'CONFIG_STATIC=y' "$build/.config" || die 'failed to enable static BusyBox build'
make -C "$src" O="$build" ARCH=x86_64 CROSS_COMPILE="$CROSS_COMPILE" -j"$(jobs)"
file "$build/busybox" | grep -q 'statically linked' || die 'BusyBox is not static'

