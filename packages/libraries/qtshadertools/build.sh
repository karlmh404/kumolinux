#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
mkdir -p "$KUMO_BUILD"
SYSROOT="$KUMO_BUILD/../sysroot"
LIBDIR="$SYSROOT/usr/lib"
if [ -d "$SYSROOT/usr/lib64" ]; then
    LIBDIR="$SYSROOT/usr/lib64"
fi
cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
    -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_TESTS=OFF -DQT_BUILD_EXAMPLES=OFF
cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"
DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"
echo "[qt-module] Package staged successfully
