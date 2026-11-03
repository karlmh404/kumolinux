#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
CHOST="$TARGET" ./configure --prefix=/usr
make -j"$(nproc)"
make DESTDIR="$KUMO_DESTDIR" install
