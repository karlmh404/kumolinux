#ifndef __PANGO_H__
#define __PANGO_H__

#include <glib.h>
#include <glib-object.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PANGO_SCALE 1024

typedef enum {
    PANGO_STYLE_NORMAL,
    PANGO_STYLE_OBLIQUE,
    PANGO_STYLE_ITALIC
} PangoStyle;

typedef enum {
    PANGO_WEIGHT_THIN = 100,
    PANGO_WEIGHT_ULTRALIGHT = 200,
    PANGO_WEIGHT_LIGHT = 300,
    PANGO_WEIGHT_BOOK = 380,
    PANGO_WEIGHT_NORMAL = 400,
    PANGO_WEIGHT_MEDIUM = 500,
    PANGO_WEIGHT_SEMIBOLD = 600,
    PANGO_WEIGHT_BOLD = 700,
    PANGO_WEIGHT_ULTRABOLD = 800,
    PANGO_WEIGHT_HEAVY = 900,
    PANGO_WEIGHT_ULTRAHEAVY = 1000
} PangoWeight;

typedef enum {
    PANGO_ALIGN_LEFT,
    PANGO_ALIGN_CENTER,
    PANGO_ALIGN_RIGHT
} PangoAlignment;

typedef enum {
    PANGO_ELLIPSIZE_NONE,
    PANGO_ELLIPSIZE_START,
    PANGO_ELLIPSIZE_MIDDLE,
    PANGO_ELLIPSIZE_END
} PangoEllipsizeMode;

typedef struct _PangoRectangle {
    int x;
    int y;
    int width;
    int height;
} PangoRectangle;

typedef struct _PangoFontDescription PangoFontDescription;
typedef struct _PangoLayout PangoLayout;

PangoFontDescription *pango_font_description_new(void);
void pango_font_description_free(PangoFontDescription *desc);
void pango_font_description_set_family(PangoFontDescription *desc, const char *family);
void pango_font_description_set_family_static(PangoFontDescription *desc, const char *family);
void pango_font_description_set_size(PangoFontDescription *desc, int size);
void pango_font_description_set_absolute_size(PangoFontDescription *desc, double size);
void pango_font_description_set_style(PangoFontDescription *desc, PangoStyle style);
void pango_font_description_set_weight(PangoFontDescription *desc, PangoWeight weight);

void pango_layout_set_font_description(PangoLayout *layout, const PangoFontDescription *desc);
void pango_layout_set_text(PangoLayout *layout, const char *text, int length);
void pango_layout_set_alignment(PangoLayout *layout, PangoAlignment alignment);
void pango_layout_set_width(PangoLayout *layout, int width);
void pango_layout_set_ellipsize(PangoLayout *layout, PangoEllipsizeMode ellipsize);
void pango_layout_get_size(PangoLayout *layout, int *width, int *height);
void pango_layout_get_pixel_extents(PangoLayout *layout, PangoRectangle *ink_rect, PangoRectangle *logical_rect);
int pango_layout_get_unknown_glyphs_count(PangoLayout *layout);

#ifdef __cplusplus
}
#endif

#endif /* __PANGO_H__ */
