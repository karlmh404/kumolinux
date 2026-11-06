#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
meson setup "$KUMO_BUILD" \
    --cross-file "$KUMO_BUILD/kumo-cross.ini" \
    --prefix=/usr --buildtype=release \
    -Dsystemd=false -Dman-pages=disabled
ninja -C "$KUMO_BUILD" -j"$(getconf _NPROCESSORS_ONLN)"
DESTDIR="$KUMO_DESTDIR" ninja -C "$KUMO_BUILD" install
echo "[mako] Package staged successfully
