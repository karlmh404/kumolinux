#!/usr/bin/env bash
set -euo pipefail

# sdbus-c++ - High-level C++ D-Bus library
# Uses CMake, links against system-installed libsystemd

mkdir -p "$KUMO_DESTDIR"

cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
  -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DSDBUSCPP_BUILD_LIBSYSTEMD=OFF \
  -DSDBUSCPP_BUILD_TESTS=OFF \
  -DSDBUSCPP_BUILD_CODEGEN=OFF \
  -DSDBUSCPP_BUILD_EXAMPLES=OFF \
  -DSDBUSCPP_BUILD_DOCS=OFF

cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"

DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"

echo "[sdbus-cpp] Package staged successfully"
