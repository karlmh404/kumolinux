#include "pango.h"
#include "pangocairo.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

struct _PangoFontDescription {
    char family[64];
    double size;
    cairo_font_slant_t slant;
    cairo_font_weight_t weight;
};

struct _PangoLayout {
    cairo_t *cr;
    char *text;
    PangoFontDescription font;
    int width;
    PangoAlignment align;
    PangoEllipsizeMode ellipsize;
};

PangoFontDescription *pango_font_description_new(void) {
    PangoFontDescription *d = calloc(1, sizeof(*d));
    if (d) {
        strcpy(d->family, "sans-serif");
        d->size = 12.0;
        d->slant = CAIRO_FONT_SLANT_NORMAL;
        d->weight = CAIRO_FONT_WEIGHT_NORMAL;
    }
    return d;
}

void pango_font_description_free(PangoFontDescription *desc) {
    if (desc) free(desc);
}

void pango_font_description_set_family(PangoFontDescription *desc, const char *family) {
    if (desc && family) {
        strncpy(desc->family, family, sizeof(desc->family) - 1);
        desc->family[sizeof(desc->family) - 1] = '\0';
    }
}

void pango_font_description_set_family_static(PangoFontDescription *desc, const char *family) {
    pango_font_description_set_family(desc, family);
}

void pango_font_description_set_size(PangoFontDescription *desc, int size) {
    if (desc) desc->size = (double)size / PANGO_SCALE;
}

void pango_font_description_set_absolute_size(PangoFontDescription *desc, double size) {
    if (desc) desc->size = size / PANGO_SCALE;
}

void pango_font_description_set_style(PangoFontDescription *desc, PangoStyle style) {
    if (desc) desc->slant = (style != PANGO_STYLE_NORMAL) ? CAIRO_FONT_SLANT_ITALIC : CAIRO_FONT_SLANT_NORMAL;
}

void pango_font_description_set_weight(PangoFontDescription *desc, PangoWeight weight) {
    if (desc) desc->weight = (weight > PANGO_WEIGHT_NORMAL) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL;
}

PangoLayout *pango_cairo_create_layout(cairo_t *cr) {
    PangoLayout *l = calloc(1, sizeof(*l));
    if (l) {
        l->cr = cr;
        strcpy(l->font.family, "sans-serif");
        l->font.size = 12.0;
        l->font.slant = CAIRO_FONT_SLANT_NORMAL;
        l->font.weight = CAIRO_FONT_WEIGHT_NORMAL;
    }
    return l;
}

void pango_layout_set_font_description(PangoLayout *layout, const PangoFontDescription *desc) {
    if (layout && desc) layout->font = *desc;
}

void pango_layout_set_text(PangoLayout *layout, const char *text, int length) {
    if (!layout) return;
    if (layout->text) free(layout->text);
    if (!text) { layout->text = NULL; return; }
    if (length < 0) length = strlen(text);
    layout->text = malloc(length + 1);
    if (layout->text) {
        memcpy(layout->text, text, length);
        layout->text[length] = '\0';
    }
}

void pango_layout_set_alignment(PangoLayout *layout, PangoAlignment alignment) {
    if (layout) layout->align = alignment;
}

void pango_layout_set_width(PangoLayout *layout, int width) {
    if (layout) layout->width = width;
}

void pango_layout_set_ellipsize(PangoLayout *layout, PangoEllipsizeMode ellipsize) {
    if (layout) layout->ellipsize = ellipsize;
}

void pango_layout_get_size(PangoLayout *layout, int *width, int *height) {
    if (!layout || !layout->text) {
        if (width) *width = 0;
        if (height) *height = 0;
        return;
    }
    cairo_t *cr = layout->cr;
    cairo_surface_t *dummy = NULL;
    if (!cr) {
        dummy = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1, 1);
        cr = cairo_create(dummy);
    }
    cairo_select_font_face(cr, layout->font.family, layout->font.slant, layout->font.weight);
    cairo_set_font_size(cr, layout->font.size > 0 ? layout->font.size : 12.0);
    cairo_text_extents_t ext;
    cairo_text_extents(cr, layout->text, &ext);
    if (width) *width = (int)ceil((ext.x_advance > 0 ? ext.x_advance : ext.width) * PANGO_SCALE);
    if (height) *height = (int)ceil((ext.height > 0 ? ext.height * 1.3 : layout->font.size * 1.3) * PANGO_SCALE);
    if (dummy) {
        cairo_destroy(cr);
        cairo_surface_destroy(dummy);
    }
}

void pango_layout_get_pixel_extents(PangoLayout *layout, PangoRectangle *ink_rect, PangoRectangle *logical_rect) {
    int w = 0, h = 0;
    pango_layout_get_size(layout, &w, &h);
    if (logical_rect) {
        logical_rect->x = 0;
        logical_rect->y = 0;
        logical_rect->width = w / PANGO_SCALE;
        logical_rect->height = h / PANGO_SCALE;
    }
    if (ink_rect) {
        ink_rect->x = 0;
        ink_rect->y = 0;
        ink_rect->width = w / PANGO_SCALE;
        ink_rect->height = h / PANGO_SCALE;
    }
}

int pango_layout_get_unknown_glyphs_count(PangoLayout *layout) {
    (void)layout;
    return 0;
}

void pango_cairo_show_layout(cairo_t *cr, PangoLayout *layout) {
    if (!cr || !layout || !layout->text) return;
    cairo_select_font_face(cr, layout->font.family, layout->font.slant, layout->font.weight);
    cairo_set_font_size(cr, layout->font.size > 0 ? layout->font.size : 12.0);
    cairo_show_text(cr, layout->text);
}
