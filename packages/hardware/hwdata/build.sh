#!/usr/bin/env bash
set -euo pipefail
cd "$KUMO_SOURCE"
./configure --prefix=/usr --datadir=/usr/share
make hwdata.pc
make DESTDIR="$KUMO_DESTDIR" install
