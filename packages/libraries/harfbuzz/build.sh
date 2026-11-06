#!/usr/bin/env bash
set -euo pipefail

# Harfbuzz - OpenType text shaping engine
# Cross-compiled with meson for Kumo Linux

cd "$KUMO_SOURCE"

# Create build directory
mkdir -p "$KUMO_BUILD"

# Determine sysroot path
SYSROOT="$KUMO_BUILD/../sysroot"

# Fix pkg-config .pc files in sysroot to use correct prefix for cross-compilation
# Add missing variables that meson needs
for pcfile in "$SYSROOT"/usr/lib/pkgconfig/*.pc "$SYSROOT"/usr/share/pkgconfig/*.pc; do
    if [ -f "$pcfile" ]; then
        sed -i "s|^prefix=.*|prefix=${SYSROOT}/usr|" "$pcfile"
        sed -i "s|^exec_prefix=.*|exec_prefix=\${prefix}|" "$pcfile"
        sed -i "s|^libdir=.*|libdir=\${exec_prefix}/lib|" "$pcfile"
        sed -i "s|^includedir=.*|includedir=\${prefix}/include|" "$pcfile"
        # Add missing variables meson needs
        if ! grep -q "^bindir=" "$pcfile"; then
            echo "bindir=\${exec_prefix}/bin" >> "$pcfile"
        fi
        if ! grep -q "^datadir=" "$pcfile"; then
            echo "datadir=\${prefix}/share" >> "$pcfile"
        fi
        if ! grep -q "^pkgdatadir=" "$pcfile"; then
            # Extract package name from .pc filename (e.g., glib-2.0.pc -> glib-2.0)
            pcname=$(basename "$pcfile" .pc)
            echo "pkgdatadir=\${datadir}/${pcname}" >> "$pcfile"
        fi
    fi
done

# Set up meson cross-compilation environment
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/lib/pkgconfig"
export PKG_CONFIG_PATH=""

MESON="/home/kewl/kumo/work/host-tools/meson/meson.py"

python3 "$MESON" setup "$KUMO_BUILD" "$KUMO_SOURCE" \
    --cross-file "$KUMO_BUILD/kumo-cross.ini" \
    --prefix=/usr \
    --buildtype=release \
    -Dgraphite=disabled \
    -Dicu=disabled \
    -Dchafa=disabled \
    -Dcairo=disabled \
    -Dtests=disabled \
    -Ddocs=disabled

python3 "$MESON" compile -C "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"

DESTDIR="$KUMO_DESTDIR" python3 "$MESON" install -C "$KUMO_BUILD"

echo "[harfbuzz] Package staged successfully"
