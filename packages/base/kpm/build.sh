#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$KUMO_DESTDIR/usr/bin"
"${TARGET}-g++" --sysroot="$SYSROOT" -std=c++17 -O2 -Wall -Wextra -Wpedantic \
  "$KUMO_SOURCE/kpm.cpp" -lcurl -o "$KUMO_DESTDIR/usr/bin/kpm"
chmod 0755 "$KUMO_DESTDIR/usr/bin/kpm"
