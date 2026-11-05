#!/usr/bin/env bash
set -euo pipefail

# 0. Lower cmake version requirement to match host CMake 3.28.3
sed -i 's|cmake_minimum_required(VERSION 3.30)|cmake_minimum_required(VERSION 3.28)|g' "$KUMO_SOURCE/CMakeLists.txt"

# 1. Version header
cat << 'EOF' > "$KUMO_SOURCE/src/version.h"
#pragma once
#define GIT_COMMIT_HASH    "v0.45.2"
#define GIT_BRANCH         "main"
#define GIT_COMMIT_MESSAGE "Hyprland 0.45.2 for Kumo Linux"
#define GIT_COMMIT_DATE    "2026-11-04"
#define GIT_DIRTY          ""
#define GIT_TAG            "v0.45.2"
#define GIT_COMMITS        "0"
EOF

if [[ -f "$KUMO_SOURCE/scripts/generateVersion.sh" ]]; then
  sed -i 's|cp -fr ./src/version.h.in ./src/version.h|test -f ./src/version.h \|\| cp -fr ./src/version.h.in ./src/version.h|g' "$KUMO_SOURCE/scripts/generateVersion.sh" || true
fi

# 2. GCC 16 / C++26 compatibility adjustments
# ofstream::native_handle() is not yet implemented in GCC 16 libstdc++
sed -i 's|auto handle = logOfs.native_handle();|// auto handle = logOfs.native_handle();|g' "$KUMO_SOURCE/src/debug/Log.cpp"
sed -i 's|fcntl(handle, F_SETFD, FD_CLOEXEC);|// fcntl(handle, F_SETFD, FD_CLOEXEC);|g' "$KUMO_SOURCE/src/debug/Log.cpp"

# Include <cstdint> for uint32_t under GCC 16
sed -i '1i #include <cstdint>' "$KUMO_SOURCE/hyprpm/src/core/PluginManager.hpp"
sed -i '1i #include <cstdint>' "$KUMO_SOURCE/hyprpm/src/core/DataState.hpp"

# Include <climits> for LONG_MAX under GCC 16
sed -i '1i #include <climits>' "$KUMO_SOURCE/src/pch/pch.hpp"
sed -i '1i #include <climits>' "$KUMO_SOURCE/src/helpers/MiscFunctions.cpp"
sed -i '1i #include <climits>' "$KUMO_SOURCE/src/helpers/Monitor.cpp"

# Include <cstring> for strcmp/strcpy under GCC 16
sed -i '1i #include <cstring>' "$KUMO_SOURCE/src/render/OpenGL.cpp"
sed -i '1i #include <cstring>' "$KUMO_SOURCE/src/pch/pch.hpp"

# 2. Link OpenGL::GLES2 instead of OpenGL::GL for Wayland GLES2/3
sed -i 's|target_link_libraries(Hyprland OpenGL::EGL OpenGL::GL|target_link_libraries(Hyprland OpenGL::EGL OpenGL::GLES2|g' "$KUMO_SOURCE/CMakeLists.txt"

# 3. Configure
cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
  -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release \
  -DNO_XWAYLAND=ON \
  -DLEGACY_RENDERER=ON \
  -DNO_SYSTEMD=OFF

# 4. Build
cmake --build "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"

# 5. Install
DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"

# 6. Configure default hyprland.conf to use weston-terminal by default
if [[ -f "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf" ]]; then
  sed -i 's|\$terminal = kitty|\$terminal = weston-terminal|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  mkdir -p "$KUMO_DESTDIR/etc/hypr"
  cp "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf" "$KUMO_DESTDIR/etc/hypr/hyprland.conf"
fi

# 7. Comment out references to programs not in the Kumo repository
if [[ -f "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf" ]]; then
  sed -i 's|^$fileManager = dolphin|# $fileManager = dolphin  # dolphin not in repo|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^$menu = wofi --show drun|# $menu = wofi --show drun  # wofi not in repo|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bind = $mainMod, E, exec, $fileManager|# bind = $mainMod, E, exec, $fileManager  # dolphin not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bind = $mainMod, R, exec, $menu|# bind = $mainMod, R, exec, $menu  # wofi not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindel = ,XF86AudioRaiseVolume, exec, wpctl|# bindel = ,XF86AudioRaiseVolume, exec, wpctl  # wpctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindel = ,XF86AudioLowerVolume, exec, wpctl|# bindel = ,XF86AudioLowerVolume, exec, wpctl  # wpctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindel = ,XF86AudioMute, exec, wpctl|# bindel = ,XF86AudioMute, exec, wpctl  # wpctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindel = ,XF86AudioMicMute, exec, wpctl|# bindel = ,XF86AudioMicMute, exec, wpctl  # wpctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindel = ,XF86MonBrightnessUp, exec, brightnessctl|# bindel = ,XF86MonBrightnessUp, exec, brightnessctl  # brightnessctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindel = ,XF86MonBrightnessDown, exec, brightnessctl|# bindel = ,XF86MonBrightnessDown, exec, brightnessctl  # brightnessctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindl = , XF86AudioNext, exec, playerctl|# bindl = , XF86AudioNext, exec, playerctl  # playerctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindl = , XF86AudioPause, exec, playerctl|# bindl = , XF86AudioPause, exec, playerctl  # playerctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindl = , XF86AudioPlay, exec, playerctl|# bindl = , XF86AudioPlay, exec, playerctl  # playerctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
  sed -i 's|^bindl = , XF86AudioPrev, exec, playerctl|# bindl = , XF86AudioPrev, exec, playerctl  # playerctl not installed|g' "$KUMO_DESTDIR/usr/share/hypr/hyprland.conf"
fi

