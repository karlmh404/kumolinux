#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$KUMO_DESTDIR/usr/share/fonts/truetype"
cp -a "$KUMO_SOURCE/root/usr/share/fonts/truetype/dejavu" "$KUMO_DESTDIR/usr/share/fonts/truetype/dejavu"
