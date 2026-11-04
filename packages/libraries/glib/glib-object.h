#ifndef __GLIB_OBJECT_H__
#define __GLIB_OBJECT_H__

#include "glib.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _GObject GObject;
typedef size_t GType;

void g_object_unref(gpointer object);
gpointer g_object_ref(gpointer object);

#ifdef __cplusplus
}
#endif

#endif /* __GLIB_OBJECT_H__ */
