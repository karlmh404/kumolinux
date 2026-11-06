#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
mkdir -p "$KUMO_BUILD"

SYSROOT="$KUMO_BUILD/../sysroot"
cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
    -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"
DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"
echo "[hyprpaper] Package staged successfully"
