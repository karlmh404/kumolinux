#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
autoreconf -fi
cd "$KUMO_BUILD"
"$KUMO_SOURCE/configure" --host="$TARGET" --build=x86_64-pc-linux-gnu --prefix=/usr --disable-static
make -j"$(nproc)"
make DESTDIR="$KUMO_DESTDIR" install
