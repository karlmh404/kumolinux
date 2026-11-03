#!/usr/bin/env bash
set -euo pipefail
install -Dm755 "$KUMO_SOURCE/kumo-hello" "$KUMO_DESTDIR/usr/bin/kumo-hello"
