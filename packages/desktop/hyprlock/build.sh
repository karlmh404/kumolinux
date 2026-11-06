#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
mkdir -p "$KUMO_BUILD"

# Patch CMake version requirements to match available dependencies
sed -i "s|find_package(hyprwayland-scanner 0.4.4 REQUIRED)|find_package(hyprwayland-scanner 0.4.0 REQUIRED)|g" "$KUMO_SOURCE/CMakeLists.txt"
sed -i "s/hyprlang>=0.6.0/hyprlang>=0.4.0/g" "$KUMO_SOURCE/CMakeLists.txt"
sed -i "s/hyprutils>=0.2.0/hyprutils>=0.1.0/g" "$KUMO_SOURCE/CMakeLists.txt"

SYSROOT="$KUMO_BUILD/../sysroot"
cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
    -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DEGL_INCLUDE_DIR="$SYSROOT/usr/include/EGL" \
    -DEGL_LIBRARY="$SYSROOT/usr/lib/libEGL.so" \
    -DGLES3_INCLUDE_DIR="$SYSROOT/usr/include/GLES3" \
    -DGLES3_LIBRARY="$SYSROOT/usr/lib/libGLESv2.so" \
    -DOPENGL_egl_LIBRARY="$SYSROOT/usr/lib/libEGL.so" \
    -DOPENGL_gles3_LIBRARY="$SYSROOT/usr/lib/libGLESv2.so"

cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"
DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"
echo "[hyprlock] Package staged successfully"
