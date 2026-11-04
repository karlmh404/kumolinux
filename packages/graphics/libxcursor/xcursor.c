#include "Xcursor.h"
#include <stdlib.h>
#include <string.h>

const char *XcursorLibraryPath(void) {
    return "/usr/share/icons";
}

XcursorImages *XcursorShapeLoadImages(unsigned int shape, const char *theme, int size) {
    (void)shape;
    (void)theme;
    (void)size;
    return NULL;
}

XcursorImages *XcursorFileLoadImages(FILE *file, int size) {
    (void)file;
    (void)size;
    return NULL;
}

void XcursorImagesDestroy(XcursorImages *images) {
    if (!images) return;
    if (images->images) {
        for (int i = 0; i < images->nimage; i++) {
            if (images->images[i]) {
                if (images->images[i]->pixels) free(images->images[i]->pixels);
                free(images->images[i]);
            }
        }
        free(images->images);
    }
    if (images->name) free(images->name);
    free(images);
}
