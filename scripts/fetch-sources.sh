#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
need python3; need curl; need sha256sum
mkdir -p "$DISTFILES_DIR"
for component in crosstool_ng linux busybox; do
  file="$(manifest_value "$component" filename)"; url="$(manifest_value "$component" url)"; sha="$(manifest_value "$component" sha256)"
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "$component has an unpinned SHA-256 in config/versions.toml"
  if [[ -e "$DISTFILES_DIR/$file" ]]; then
    printf '%s  %s\n' "$sha" "$DISTFILES_DIR/$file" | sha256sum -c - || die "cached archive is corrupt: $file (not overwritten)"
  else
    tmp="$DISTFILES_DIR/.$file.part"; rm -f -- "$tmp"
    curl --fail --location --proto '=https' --tlsv1.2 -o "$tmp" "$url"
    printf '%s  %s\n' "$sha" "$tmp" | sha256sum -c - || { rm -f -- "$tmp"; die "checksum mismatch: $file"; }
    mv -- "$tmp" "$DISTFILES_DIR/$file"
  fi
done

