#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
zstd="$WORK_DIR/host-tools/zstd"
if ! command -v zstd >/dev/null 2>&1 && [[ ! -x "$zstd/programs/zstd" ]]; then
  archive="$CACHE_DIR/packages/zstd-1.5.7.tar.gz"
  [[ -f "$archive" ]] || die 'zstd source missing; run scripts/fetch-base-sources.sh'
  rm -rf "$zstd"; mkdir -p "$zstd"
  tar -xf "$archive" -C "$zstd" --strip-components=1
  make -C "$zstd" -j"$(jobs)" zstd-release
fi
