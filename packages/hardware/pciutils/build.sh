#!/usr/bin/env bash
set -euo pipefail
make -C "$KUMO_SOURCE" -j"$(nproc)" CC="$CC" OPT="$CFLAGS" LDFLAGS="$LDFLAGS" CROSS_COMPILE="$TARGET-" HOST="$TARGET" PREFIX=/usr SBINDIR=/usr/bin IDSDIR=/usr/share/hwdata ZLIB=yes DNS=no SHARED=no
make -C "$KUMO_SOURCE" CC="$CC" OPT="$CFLAGS" LDFLAGS="$LDFLAGS" CROSS_COMPILE="$TARGET-" HOST="$TARGET" PREFIX=/usr SBINDIR=/usr/bin IDSDIR=/usr/share/hwdata ZLIB=yes DNS=no SHARED=no DESTDIR="$KUMO_DESTDIR" install install-lib
rm -f "$KUMO_DESTDIR/usr/bin/update-pciids" "$KUMO_DESTDIR/usr/sbin/update-pciids"
mkdir -p "$KUMO_DESTDIR/usr/sbin"
ln -sf /usr/bin/lspci "$KUMO_DESTDIR/usr/sbin/lspci"
ln -sf /usr/bin/setpci "$KUMO_DESTDIR/usr/sbin/setpci"
install -Dm644 "$KUMO_SOURCE/pci.ids" "$KUMO_DESTDIR/usr/share/hwdata/pci.ids"
