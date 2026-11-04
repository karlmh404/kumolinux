#!/usr/bin/env bash
set -euo pipefail

recipe_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$KUMO_DESTDIR/usr/lib/pkgconfig" \
         "$KUMO_DESTDIR/usr/include/pango-1.0/pango" \
         "$KUMO_DESTDIR/usr/share/licenses/pango"

${TARGET}-gcc -shared -fPIC -O2 -Wall \
  -Wl,-soname,libpango-1.0.so.0 \
  -I"$SYSROOT/usr/include/cairo" \
  -I"$SYSROOT/usr/include/pixman-1" \
  -I"$SYSROOT/usr/include/glib-2.0" \
  -I"$recipe_dir" \
  "$recipe_dir/pango.c" \
  -L"$SYSROOT/usr/lib" \
  -lcairo -lglib-2.0 -lm \
  -o "$KUMO_DESTDIR/usr/lib/libpango-1.0.so.0.5200.0"

ln -sf libpango-1.0.so.0.5200.0 "$KUMO_DESTDIR/usr/lib/libpango-1.0.so.0"
ln -sf libpango-1.0.so.0 "$KUMO_DESTDIR/usr/lib/libpango-1.0.so"

ln -sf libpango-1.0.so.0.5200.0 "$KUMO_DESTDIR/usr/lib/libpangocairo-1.0.so.0.5200.0"
ln -sf libpangocairo-1.0.so.0.5200.0 "$KUMO_DESTDIR/usr/lib/libpangocairo-1.0.so.0"
ln -sf libpangocairo-1.0.so.0 "$KUMO_DESTDIR/usr/lib/libpangocairo-1.0.so"

cp "$recipe_dir/pango.h" "$KUMO_DESTDIR/usr/include/pango-1.0/pango/pango.h"
cp "$recipe_dir/pangocairo.h" "$KUMO_DESTDIR/usr/include/pango-1.0/pango/pangocairo.h"

# Top-level include convenience
mkdir -p "$KUMO_DESTDIR/usr/include/pango"
ln -sf ../pango-1.0/pango/pango.h "$KUMO_DESTDIR/usr/include/pango/pango.h"
ln -sf ../pango-1.0/pango/pangocairo.h "$KUMO_DESTDIR/usr/include/pango/pangocairo.h"

cat << 'EOF' > "$KUMO_DESTDIR/usr/lib/pkgconfig/pango.pc"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Pango
Description: Internationalized text layout and rendering library
Version: 1.52.0
Requires: glib-2.0, gobject-2.0
Libs: -L${libdir} -lpango-1.0
Cflags: -I${includedir}/pango-1.0 -I${includedir}
EOF

cat << 'EOF' > "$KUMO_DESTDIR/usr/lib/pkgconfig/pangocairo.pc"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Pango Cairo
Description: Cairo rendering support for Pango
Version: 1.52.0
Requires: pango, cairo
Libs: -L${libdir} -lpangocairo-1.0
Cflags: -I${includedir}/pango-1.0 -I${includedir}
EOF
