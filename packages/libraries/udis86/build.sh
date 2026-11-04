#!/usr/bin/env bash
set -euo pipefail

cd "$KUMO_SOURCE"
./autogen.sh

cd "$KUMO_BUILD"
"$KUMO_SOURCE/configure" \
  --host="$TARGET" \
  --prefix=/usr \
  --enable-shared \
  --disable-static \
  --with-python=python3

make -j"$(getconf _NPROCESSORS_ONLN)"
make DESTDIR="$KUMO_DESTDIR" install

mkdir -p "$KUMO_DESTDIR/usr/share/licenses/udis86"
if [[ -f "$KUMO_SOURCE/LICENSE" ]]; then
  cp "$KUMO_SOURCE/LICENSE" "$KUMO_DESTDIR/usr/share/licenses/udis86/"
fi
