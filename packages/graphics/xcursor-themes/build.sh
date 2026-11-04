#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$KUMO_DESTDIR/usr/share/icons/default"
cp -a "$KUMO_SOURCE/root/usr/share/icons/default/." "$KUMO_DESTDIR/usr/share/icons/default/"
