#ifndef __PANGO_CAIRO_H__
#define __PANGO_CAIRO_H__

#if __has_include(<pango/pango.h>)
#include <pango/pango.h>
#else
#include "pango.h"
#endif
#include <cairo.h>

#ifdef __cplusplus
extern "C" {
#endif

PangoLayout *pango_cairo_create_layout(cairo_t *cr);
void pango_cairo_show_layout(cairo_t *cr, PangoLayout *layout);

#ifdef __cplusplus
}
#endif

#endif /* __PANGO_CAIRO_H__ */
