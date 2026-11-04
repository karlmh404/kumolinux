#!/usr/bin/env bash
set -euo pipefail

host_build="$KUMO_BUILD/host"
mkdir -p "$host_build"
if [[ ! -x "$host_build/progs/tic" ]]; then
  (
    cd "$host_build"
    env -u CC -u CXX -u AR -u AS -u LD -u NM -u RANLIB -u READELF -u STRIP \
        -u CFLAGS -u CXXFLAGS -u LDFLAGS -u SYSROOT -u TARGET \
        -u PKG_CONFIG_SYSROOT_DIR -u PKG_CONFIG_LIBDIR -u PKG_CONFIG_PATH \
        "$KUMO_SOURCE/configure" --without-debug --without-ada --without-normal
    make -C include -j"$(nproc 2>/dev/null || echo 2)"
    make -C progs tic -j"$(nproc 2>/dev/null || echo 2)"
  ) || true
fi

if [[ -x "$host_build/progs/tic" ]]; then
  TIC_BIN="$host_build/progs/tic"
elif command -v tic >/dev/null 2>&1; then
  TIC_BIN="$(command -v tic)"
else
  echo "[ncurses-build] ERROR: No working tic compiler found" >&2
  exit 1
fi

target_build="$KUMO_BUILD/target"
mkdir -p "$target_build"
cd "$target_build"

"$KUMO_SOURCE/configure" \
  --host="$TARGET" \
  --build=x86_64-pc-linux-gnu \
  --prefix=/usr \
  --mandir=/usr/share/man \
  --with-shared \
  --without-debug \
  --without-normal \
  --without-ada \
  --enable-widec \
  --enable-pc-files \
  --with-pkg-config-libdir=/usr/lib/pkgconfig \
  --with-default-terminfo-dir=/usr/share/terminfo \
  --with-terminfo-dirs=/usr/share/terminfo \
  --with-build-cc=gcc \
  --disable-stripping

make -j"$(nproc 2>/dev/null || echo 2)"
make DESTDIR="$KUMO_DESTDIR" TIC_PATH="$TIC_BIN" install

# Compatibility linker scripts and symlinks for standard curses/ncurses callers
for lib in ncurses form panel menu; do
  if [[ -f "$KUMO_DESTDIR/usr/lib/lib${lib}w.so" ]]; then
    printf 'INPUT(-l%sw)\n' "$lib" > "$KUMO_DESTDIR/usr/lib/lib${lib}.so"
  fi
done

if [[ -f "$KUMO_DESTDIR/usr/lib/libncursesw.so" ]]; then
  printf 'INPUT(-lncursesw)\n' > "$KUMO_DESTDIR/usr/lib/libcurses.so"
  if [[ ! -e "$KUMO_DESTDIR/usr/lib/libtinfo.so" ]]; then
    printf 'INPUT(-lncursesw)\n' > "$KUMO_DESTDIR/usr/lib/libtinfo.so"
  fi
fi

# Compatibility header symlinks
mkdir -p "$KUMO_DESTDIR/usr/include"
for header in curses.h ncurses.h term.h termcap.h eti.h form.h menu.h panel.h; do
  if [[ -f "$KUMO_DESTDIR/usr/include/ncursesw/$header" && ! -f "$KUMO_DESTDIR/usr/include/$header" ]]; then
    ln -sf "ncursesw/$header" "$KUMO_DESTDIR/usr/include/$header"
  fi
done

# Compatibility pkg-config symlink
mkdir -p "$KUMO_DESTDIR/usr/lib/pkgconfig"
if [[ -f "$KUMO_DESTDIR/usr/lib/pkgconfig/ncursesw.pc" && ! -f "$KUMO_DESTDIR/usr/lib/pkgconfig/ncurses.pc" ]]; then
  ln -sf ncursesw.pc "$KUMO_DESTDIR/usr/lib/pkgconfig/ncurses.pc"
fi
