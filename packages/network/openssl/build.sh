#!/usr/bin/env bash
set -euo pipefail
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
cd "$KUMO_BUILD"
"$KUMO_SOURCE/Configure" linux-x86_64 \
  --prefix=/usr --openssldir=/etc/ssl --libdir=lib \
  shared no-tests
make -j"$jobs"
make DESTDIR="$KUMO_DESTDIR" install_sw
