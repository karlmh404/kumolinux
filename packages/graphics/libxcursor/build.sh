#!/usr/bin/env bash
set -euo pipefail

recipe_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$KUMO_DESTDIR/usr/lib/pkgconfig" "$KUMO_DESTDIR/usr/include/X11/Xcursor" "$KUMO_DESTDIR/usr/share/licenses/libxcursor"

${TARGET}-gcc -shared -fPIC -O2 -Wall \
  -Wl,-soname,libXcursor.so.1 \
  -I"$recipe_dir" \
  "$recipe_dir/xcursor.c" \
  -o "$KUMO_DESTDIR/usr/lib/libXcursor.so.1.0.2"

ln -sf libXcursor.so.1.0.2 "$KUMO_DESTDIR/usr/lib/libXcursor.so.1"
ln -sf libXcursor.so.1 "$KUMO_DESTDIR/usr/lib/libXcursor.so"

cp "$recipe_dir/Xcursor.h" "$KUMO_DESTDIR/usr/include/X11/Xcursor/Xcursor.h"

cat << 'EOF' > "$KUMO_DESTDIR/usr/lib/pkgconfig/xcursor.pc"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Xcursor
Description: X Cursor compatibility library
Version: 1.2.2
Libs: -L${libdir} -lXcursor
Cflags: -I${includedir}
EOF

cat << 'EOF' > "$KUMO_DESTDIR/usr/share/licenses/libxcursor/LICENSE"
MIT License

Copyright (c) 2026 Kumo Linux Authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
