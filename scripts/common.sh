#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
CACHE_DIR="$REPO_ROOT/cache"
DISTFILES_DIR="$CACHE_DIR/distfiles"
WORK_DIR="$REPO_ROOT/work"
OUT_DIR="$REPO_ROOT/out"
TOOLCHAIN_DIR="$OUT_DIR/toolchain"
TARGET=x86_64-kumo-linux-gnu
export REPO_ROOT CONFIG_DIR CACHE_DIR DISTFILES_DIR WORK_DIR OUT_DIR TOOLCHAIN_DIR TARGET

log() { printf '[kumo] %s\n' "$*"; }
die() { printf '[kumo] ERROR: %s\n' "$*" >&2; exit 1; }
jobs() { local n; n="$(nproc 2>/dev/null || echo 2)"; (( n > 1 )) && echo $((n-1)) || echo 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required host tool missing: $1 (run make setup)"; }
manifest_value() {
  local section="$1" key="$2"
  python3 - "$CONFIG_DIR/versions.toml" "$section" "$key" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f: d=tomllib.load(f)
print(d[sys.argv[2]][sys.argv[3]])
PY
}
archive_for() { manifest_value "$1" filename; }
source_dir_for() { printf '%s/sources/%s\n' "$WORK_DIR" "${1}"; }
extract_source() {
  local component="$1" name="$2" archive dest
  archive="$DISTFILES_DIR/$(archive_for "$component")"; dest="$(source_dir_for "$name")"
  [[ -f "$archive" ]] || die "missing $archive; run make fetch"
  if [[ ! -f "$dest/.kumo-extracted" ]]; then
    rm -rf -- "$dest"; mkdir -p "$dest"
    tar -xf "$archive" -C "$dest" --strip-components=1
    touch "$dest/.kumo-extracted"
  fi
  printf '%s\n' "$dest"
}
require_toolchain() {
  [[ -x "$TOOLCHAIN_DIR/bin/$TARGET-gcc" ]] || die "Kumo toolchain missing; run make toolchain"
  export PATH="$TOOLCHAIN_DIR/bin:$PATH" CROSS_COMPILE="$TARGET-"
}

