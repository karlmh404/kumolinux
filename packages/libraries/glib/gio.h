#ifndef __GIO_H__
#define __GIO_H__

#include <glib.h>
#include <glib-object.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _GSettings GSettings;
typedef struct _GSettingsSchemaSource GSettingsSchemaSource;
typedef struct _GSettingsSchema GSettingsSchema;

GSettingsSchemaSource *g_settings_schema_source_get_default(void);
GSettingsSchema *g_settings_schema_source_lookup(GSettingsSchemaSource *source, const gchar *schema_id, gboolean recursive);
gboolean g_settings_schema_has_key(GSettingsSchema *schema, const gchar *name);
void g_settings_schema_unref(GSettingsSchema *schema);

GSettings *g_settings_new(const gchar *schema_id);
gboolean g_settings_set_string(GSettings *settings, const gchar *key, const gchar *value);
gboolean g_settings_set_int(GSettings *settings, const gchar *key, gint value);
void g_settings_sync(void);

#ifdef __cplusplus
}
#endif

#endif /* __GIO_H__ */
