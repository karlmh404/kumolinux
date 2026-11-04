#ifndef __GLIB_H__
#define __GLIB_H__

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* gpointer;
typedef const void* gconstpointer;
typedef char gchar;
typedef int gint;
typedef int gboolean;
typedef unsigned int guint;
typedef uint32_t guint32;
typedef int32_t gint32;
typedef uint64_t guint64;
typedef int64_t gint64;
typedef float gfloat;
typedef double gdouble;
typedef size_t gsize;
typedef ssize_t gssize;

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

typedef struct _GError {
    guint32 domain;
    gint code;
    gchar *message;
} GError;

void g_free(gpointer mem);
gpointer g_malloc(gsize n_bytes);
gpointer g_malloc0(gsize n_bytes);
void g_error_free(GError *error);

#ifdef __cplusplus
}
#endif

#endif /* __GLIB_H__ */
