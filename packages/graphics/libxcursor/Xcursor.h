#ifndef _XCURSOR_H_
#define _XCURSOR_H_

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int XcursorBool;
typedef unsigned int XcursorPixel;

typedef struct _XcursorImage {
    unsigned int version;
    unsigned int size;
    unsigned int width;
    unsigned int height;
    unsigned int xhot;
    unsigned int yhot;
    unsigned int delay;
    XcursorPixel *pixels;
} XcursorImage;

typedef struct _XcursorImages {
    int nimage;
    XcursorImage **images;
    char *name;
} XcursorImages;

const char *XcursorLibraryPath(void);
XcursorImages *XcursorShapeLoadImages(unsigned int shape, const char *theme, int size);
XcursorImages *XcursorFileLoadImages(FILE *file, int size);
void XcursorImagesDestroy(XcursorImages *images);

#ifdef __cplusplus
}
#endif

#endif /* _XCURSOR_H_ */
