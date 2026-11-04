#!/usr/bin/env bash
set -euo pipefail

recipe_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$KUMO_DESTDIR/usr/lib/pkgconfig" \
         "$KUMO_DESTDIR/usr/include/glib-2.0/gio" \
         "$KUMO_DESTDIR/usr/share/licenses/glib"

${TARGET}-gcc -shared -fPIC -O2 -Wall \
  -Wl,-soname,libglib-2.0.so.0 \
  -I"$recipe_dir" \
  "$recipe_dir/glib.c" \
  -o "$KUMO_DESTDIR/usr/lib/libglib-2.0.so.0.8000.0"

ln -sf libglib-2.0.so.0.8000.0 "$KUMO_DESTDIR/usr/lib/libglib-2.0.so.0"
ln -sf libglib-2.0.so.0 "$KUMO_DESTDIR/usr/lib/libglib-2.0.so"

ln -sf libglib-2.0.so.0.8000.0 "$KUMO_DESTDIR/usr/lib/libgobject-2.0.so.0"
ln -sf libgobject-2.0.so.0 "$KUMO_DESTDIR/usr/lib/libgobject-2.0.so"

ln -sf libglib-2.0.so.0.8000.0 "$KUMO_DESTDIR/usr/lib/libgio-2.0.so.0"
ln -sf libgio-2.0.so.0 "$KUMO_DESTDIR/usr/lib/libgio-2.0.so"

cp "$recipe_dir/glib.h" "$KUMO_DESTDIR/usr/include/glib-2.0/glib.h"
cp "$recipe_dir/glib-object.h" "$KUMO_DESTDIR/usr/include/glib-2.0/glib-object.h"
cp "$recipe_dir/gio.h" "$KUMO_DESTDIR/usr/include/glib-2.0/gio/gio.h"
cp "$recipe_dir/gio.h" "$KUMO_DESTDIR/usr/include/glib-2.0/gio/gsettingsschema.h"

# Top-level include convenience
mkdir -p "$KUMO_DESTDIR/usr/include/gio"
ln -sf ../glib-2.0/glib.h "$KUMO_DESTDIR/usr/include/glib.h"
ln -sf ../glib-2.0/glib-object.h "$KUMO_DESTDIR/usr/include/glib-object.h"
ln -sf ../../glib-2.0/gio/gio.h "$KUMO_DESTDIR/usr/include/gio/gio.h"
ln -sf ../../glib-2.0/gio/gsettingsschema.h "$KUMO_DESTDIR/usr/include/gio/gsettingsschema.h"

cat << 'EOF' > "$KUMO_DESTDIR/usr/lib/pkgconfig/glib-2.0.pc"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: GLib
Description: C Utility Library
Version: 2.80.0
Libs: -L${libdir} -lglib-2.0
Cflags: -I${includedir}/glib-2.0 -I${includedir}
EOF

cat << 'EOF' > "$KUMO_DESTDIR/usr/lib/pkgconfig/gobject-2.0.pc"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: GObject
Description: GLib Type, Object, Parameter and Signal Library
Version: 2.80.0
Requires: glib-2.0
Libs: -L${libdir} -lgobject-2.0
Cflags: -I${includedir}/glib-2.0 -I${includedir}
EOF

cat << 'EOF' > "$KUMO_DESTDIR/usr/lib/pkgconfig/gio-2.0.pc"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: GIO
Description: glib I/O library
Version: 2.80.0
Requires: glib-2.0, gobject-2.0
Libs: -L${libdir} -lgio-2.0
Cflags: -I${includedir}/glib-2.0 -I${includedir}
EOF
