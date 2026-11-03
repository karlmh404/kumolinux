#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
required=(gcc g++ ld ar strip readelf)
complete=true
for t in "${required[@]}"; do [[ -x "$TOOLCHAIN_DIR/bin/$TARGET-$t" ]] || complete=false; done
if "$complete"; then
  log 'toolchain already complete'
  "$TOOLCHAIN_DIR/bin/$TARGET-gcc" --version | head -n 1
  log "target: $("$TOOLCHAIN_DIR/bin/$TARGET-gcc" -dumpmachine)"
  "$TOOLCHAIN_DIR/bin/$TARGET-ld" --version | head -n 1
  exit 0
fi
for t in gcc make autoconf automake libtoolize bison flex gawk help2man; do need "$t"; done
src="$(extract_source crosstool_ng crosstool-ng)"; build="$WORK_DIR/crosstool-ng-build"; prefix="$WORK_DIR/crosstool-ng-host"
mkdir -p "$build" "$prefix" "$DISTFILES_DIR"
if [[ ! -x "$prefix/bin/ct-ng" ]]; then (cd "$src"; ./bootstrap); (cd "$build"; "$src/configure" --prefix="$prefix"; make -j"$(jobs)"; make install); fi
mkdir -p "$WORK_DIR/toolchain-build" "$TOOLCHAIN_DIR"
cp "$CONFIG_DIR/crosstool-ng.config" "$WORK_DIR/toolchain-build/.config"
(cd "$WORK_DIR/toolchain-build"; "$prefix/bin/ct-ng" olddefconfig; cp .config "$CONFIG_DIR/crosstool-ng.config"; "$prefix/bin/ct-ng" build)
for t in "${required[@]}"; do [[ -x "$TOOLCHAIN_DIR/bin/$TARGET-$t" ]] || die "toolchain output missing: $TARGET-$t"; done
[[ "$("$TOOLCHAIN_DIR/bin/$TARGET-gcc" -dumpmachine)" == "$TARGET" ]] || die 'toolchain target mismatch'
"$TOOLCHAIN_DIR/bin/$TARGET-gcc" --version | head -n 1
log "target: $("$TOOLCHAIN_DIR/bin/$TARGET-gcc" -dumpmachine)"
"$TOOLCHAIN_DIR/bin/$TARGET-ld" --version | head -n 1

