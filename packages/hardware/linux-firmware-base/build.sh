#!/usr/bin/env bash
set -euo pipefail
firmware="$KUMO_DESTDIR/usr/lib/firmware"
licenses="$KUMO_DESTDIR/usr/share/licenses/linux-firmware-base"
mkdir -p "$firmware" "$licenses"
for item in regulatory.db regulatory.db.p7s amd-ucode rtl_nic; do
  if [[ -e "$KUMO_SOURCE/$item" ]]; then cp -a "$KUMO_SOURCE/$item" "$firmware/"; fi
done
cp "$KUMO_SOURCE/WHENCE" "$licenses/"
for item in "$KUMO_SOURCE"/LICENCE.* "$KUMO_SOURCE"/LICENSE.*; do
  [[ -f "$item" ]] && cp "$item" "$licenses/"
done
printf '%s\n' 'Kumo installs an intentionally small, unmodified upstream subset.' 'Each blob remains governed by the license identified in upstream WHENCE.' 'The layout permits later vendor-specific firmware split packages.' > "$licenses/SPLIT-NOTICE"
