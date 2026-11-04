#!/usr/bin/env bash
set -euo pipefail

cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD"   -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake"   -DCMAKE_INSTALL_PREFIX=/usr   -DCMAKE_BUILD_TYPE=Release
cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"
DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"

# Ensure CMake consumers use the host hyprwayland-scanner from PATH during cross builds
sed -i 's|COMMAND "${BINDIR}/hyprwayland-scanner"|COMMAND hyprwayland-scanner|g' \
  "$KUMO_DESTDIR/usr/lib/cmake/hyprwayland-scanner/hyprwayland-scanner-config.cmake"

host_root="$TOOLCHAIN_DIR/../../work/host-tools"
host_pugi="$TOOLCHAIN_DIR/../../work/packages/pugixml/source"
mkdir -p "$host_root/bin" "$host_root/pkgconfig"
c++ -std=c++23 -O2 -pthread   -I"$host_pugi/src"   -DSCANNER_VERSION='"0.4.0"'   "$KUMO_SOURCE/src/main.cpp" "$host_pugi/src/pugixml.cpp"   -o "$host_root/bin/hyprwayland-scanner"
printf '%s\n'   "hyprwayland_scanner=$host_root/bin/hyprwayland-scanner"   ""   "Name: HyprWayland Scanner"   "Description: Host C++ Wayland protocol scanner"   "Version: 0.4.0"   > "$host_root/pkgconfig/hyprwayland-scanner.pc"
