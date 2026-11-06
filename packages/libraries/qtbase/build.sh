#!/usr/bin/env bash
set -euo pipefail

# Qt 6 base - Cross-compiled for Kumo Linux

cd "$KUMO_SOURCE"
mkdir -p "$KUMO_BUILD"

SYSROOT="$KUMO_BUILD/../sysroot"
LIBDIR="$SYSROOT/usr/lib"
if [ -d "$SYSROOT/usr/lib64" ]; then
    LIBDIR="$SYSROOT/usr/lib64"
fi

# GLIB2 CMake config
mkdir -p "$LIBDIR/cmake/GLIB2"
cat > "$LIBDIR/cmake/GLIB2/GLIB2Config.cmake" << GLIBCONF
set(GLIB2_FOUND TRUE)
set(GLIB2_INCLUDE_DIRS "${SYSROOT}/usr/include/glib-2.0")
if(NOT TARGET glib-2.0)
add_library(glib-2.0 SHARED IMPORTED)
set_target_properties(glib-2.0 PROPERTIES
    IMPORTED_LOCATION "${LIBDIR}/libglib-2.0.so"
    INTERFACE_INCLUDE_DIRECTORIES "${SYSROOT}/usr/include/glib-2.0")
endif()
if(NOT TARGET GObject-2.0)
add_library(GObject-2.0 SHARED IMPORTED)
set_target_properties(GObject-2.0 PROPERTIES
    IMPORTED_LOCATION "${LIBDIR}/libgobject-2.0.so"
    INTERFACE_INCLUDE_DIRECTORIES "${SYSROOT}/usr/include/glib-2.0")
endif()
if(NOT TARGET GLIB2::GLIB2)
add_library(GLIB2::GLIB2 ALIAS glib-2.0)
endif()
GLIBCONF

# Fontconfig CMake config
mkdir -p "$LIBDIR/cmake/Fontconfig"
cat > "$LIBDIR/cmake/Fontconfig/FontconfigConfig.cmake" << FONTCONF
set(Fontconfig_FOUND TRUE)
set(Fontconfig_INCLUDE_DIRS "${SYSROOT}/usr/include/fontconfig")
if(NOT TARGET fontconfig)
add_library(fontconfig SHARED IMPORTED)
set_target_properties(fontconfig PROPERTIES
    IMPORTED_LOCATION "${LIBDIR}/libfontconfig.so"
    INTERFACE_INCLUDE_DIRECTORIES "${SYSROOT}/usr/include/fontconfig")
endif()
if(NOT TARGET Fontconfig::Fontconfig)
add_library(Fontconfig::Fontconfig ALIAS fontconfig)
endif()
FONTCONF

# FreeType CMake config
mkdir -p "$LIBDIR/cmake/FreeType"
cat > "$LIBDIR/cmake/FreeType/FreeTypeConfig.cmake" << FREETYPECONF
set(Freetype_FOUND TRUE)
set(Freetype_INCLUDE_DIRS "${SYSROOT}/usr/include/freetype2")
if(NOT TARGET freetype)
add_library(freetype SHARED IMPORTED)
set_target_properties(freetype PROPERTIES
    IMPORTED_LOCATION "${LIBDIR}/libfreetype.so"
    INTERFACE_INCLUDE_DIRECTORIES "${SYSROOT}/usr/include/freetype2")
endif()
if(NOT TARGET Freetype::Freetype)
add_library(Freetype::Freetype ALIAS freetype)
endif()
FREETYPECONF

# Xkbcommon CMake config
mkdir -p "$LIBDIR/cmake/Xkbcommon"
cat > "$LIBDIR/cmake/Xkbcommon/XkbcommonConfig.cmake" << XKBANF
set(Xkbcommon_FOUND TRUE)
set(Xkbcommon_INCLUDE_DIRS "${SYSROOT}/usr/include/xkbcommon")
if(NOT TARGET xkbcommon)
add_library(xkbcommon SHARED IMPORTED)
set_target_properties(xkbcommon PROPERTIES
    IMPORTED_LOCATION "${LIBDIR}/libxkbcommon.so"
    INTERFACE_INCLUDE_DIRECTORIES "${SYSROOT}/usr/include/xkbcommon")
endif()
if(NOT TARGET Xkbcommon::Xkbcommon)
add_library(Xkbcommon::Xkbcommon ALIAS xkbcommon)
endif()
XKBANF

# Expat CMake config
mkdir -p "$LIBDIR/cmake/Expat"
cat > "$LIBDIR/cmake/Expat/ExpatConfig.cmake" << EXPATCONF
set(Expat_FOUND TRUE)
set(Expat_INCLUDE_DIRS "${SYSROOT}/usr/include")
if(NOT TARGET expat)
add_library(expat SHARED IMPORTED)
set_target_properties(expat PROPERTIES
    IMPORTED_LOCATION "${LIBDIR}/libexpat.so"
    INTERFACE_INCLUDE_DIRECTORIES "${SYSROOT}/usr/include")
endif()
if(NOT TARGET Expat::Expat)
add_library(Expat::Expat ALIAS expat)
endif()
EXPATCONF

# Configure Qt6 for cross-compilation
cmake -S "$KUMO_SOURCE" -B "$KUMO_BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$KUMO_BUILD/kumo-toolchain.cmake" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH=/usr/local/qt6-host \
    -DFEATURE_pkg_config=ON \
    -DFEATURE_pkg_config_host_paths=OFF \
    -DFEATURE_relocatable=OFF \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_EXAMPLES=OFF \
    -DQT_BUILD_TOOLS=OFF \
    -DQT_NO_DEBUG=ON \
    -DQT_FEATURE_eglfs=OFF \
    -DQT_FEATURE_linuxfb=OFF \
    -DQT_FEATURE_kms=OFF \
    -DQT_FEATURE_wayland=ON \
    -DQT_FEATURE_xcb=OFF \
    -DQT_FEATURE_dbus=OFF \
    -DQT_FEATURE_sql=OFF \
    -DQT_FEATURE_network=OFF \
    -DQT_FEATURE_script=OFF \
    -DQT_FEATURE_concurrent=OFF \
    -DQT_FEATURE_testlib=OFF \
    -DQT_FEATURE_webengine=OFF \
    -DQT_FEATURE_webchannel=OFF \
    -DQT_FEATURE_websockets=OFF \
    -DQT_FEATURE_xmlpatterns=OFF \
    -DQT_FEATURE_linguist=OFF \
    -DQT_FEATURE_vulkan=OFF \
    -DQT_FEATURE_icu=OFF \
    -DQT_FEATURE_harfbuzz=OFF \
    -DQT_FEATURE_glib=OFF \
    -DQT_FEATURE_doubleconversion=ON \
    -DQT_FEATURE_freetype=ON \
    -DQT_FEATURE_fontconfig=ON \
    -DQT_FEATURE_png=ON \
    -DQT_FEATURE_input=ON \
    -DQT_FEATURE_evdev=ON \
    -DQT_FEATURE_libinput=ON \
    -DQT_FEATURE_xkbcommon=ON \
    -DQT_FEATURE_system_zlib=ON \
    -DQT_FEATURE_system_pcre2=OFF \
    -DQT_FEATURE_system_sqlite=OFF \
    -DQT_FEATURE_system_zstd=OFF \
    -DQT_FEATURE_system_jpeg=OFF \
    -DQT_FEATURE_system_tiff=OFF \
    -DQT_FEATURE_system_webp=OFF \
    -DQT_FEATURE_gif=OFF \
    -DQT_FEATURE_ico=OFF \
    -DQT_FEATURE_jp2=OFF \
    -DQT_FEATURE_mng=OFF \
    -DQT_FEATURE_tga=OFF \
    -DQT_FEATURE_tiff=OFF \
    -DQT_FEATURE_webp=OFF

cmake --build "$KUMO_BUILD" -j4

DESTDIR="$KUMO_DESTDIR" cmake --install "$KUMO_BUILD"

echo "[qtbase] Package staged successfully"
