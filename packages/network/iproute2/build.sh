#!/usr/bin/env bash
set -euo pipefail
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
cd "$KUMO_SOURCE"
./configure --prefix /usr --libbpf_force off
make -j"$jobs"
make DESTDIR="$KUMO_DESTDIR" PREFIX=/usr SBINDIR=/usr/sbin install
