#!/usr/bin/env bash
set -euo pipefail
src="$KUMO_SOURCE"; dst="$KUMO_DESTDIR"; sys="$TOOLCHAIN_DIR/$TARGET/sysroot"
mkdir -p "$dst/usr/lib" "$dst/usr/bin" "$dst/usr/share/licenses/glibc-runtime"
find "$sys/lib" -maxdepth 1 \( -type f -o -type l \) -name '*.so*' -exec cp -a -t "$dst/usr/lib" {} +
[[ -d "$sys/usr/lib/gconv" ]] && cp -a "$sys/usr/lib/gconv" "$dst/usr/lib/"
for tool in ldd getconf getent iconv locale localedef; do
  for candidate in "$sys/usr/bin/$tool" "$sys/bin/$tool"; do
    [[ -e "$candidate" ]] && cp -a "$candidate" "$dst/usr/bin/$tool" && break
  done
done
