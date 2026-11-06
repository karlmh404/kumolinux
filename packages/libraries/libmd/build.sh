#!/usr/bin/env bash
set -euo pipefail

# libmd - Message digest functions (BSD)

cd "$KUMO_SOURCE"

mkdir -p "$KUMO_BUILD"

cd "$KUMO_BUILD"
"$KUMO_SOURCE/configure" --host=x86_64-kumo-linux-gnu --build=x86_64-pc-linux-gnu --prefix=/usr --disable-nls --disable-static 2>&1 | tail -5

make -j"$(getconf _NPROCESSORS_ONLN)"

make DESTDIR="$KUMO_DESTDIR" install

echo "[libmd] Package staged successfully"
