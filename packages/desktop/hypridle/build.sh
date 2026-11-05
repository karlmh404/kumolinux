#!/usr/bin/env bash
set -euo pipefail

# hypridle - Idle management daemon for Hyprland

# Patch CMakeLists.txt to accept available dependency versions
sed -i 's/find_package(hyprwayland-scanner 0.4.4 REQUIRED)/find_package(hyprwayland-scanner 0.4.0 REQUIRED)/g' "$KUMO_SOURCE/CMakeLists.txt"
sed -i 's/hyprlang>=0.6.0/hyprlang>=0.4.0/g' "$KUMO_SOURCE/CMakeLists.txt"
sed -i 's/hyprutils>=0.2.0/hyprutils>=0.1.0/g' "$KUMO_SOURCE/CMakeLists.txt"
sed -i 's/sdbus-c++>=0.2.0/sdbus-c++>=1.0.0/g' "$KUMO_SOURCE/CMakeLists.txt"
sed -i 's/hyprland-protocols>=0.6.0/hyprland-protocols>=0.4.0/g' "$KUMO_SOURCE/CMakeLists.txt"

mkdir -p "$KUMO_DESTDIR"

cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
  -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"

DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"

echo "[hypridle] Package staged successfully"
