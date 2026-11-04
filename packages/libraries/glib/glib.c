#include "glib.h"
#include "glib-object.h"
#include "gio.h"
#include <stdlib.h>
#include <string.h>

void g_free(gpointer mem) {
    if (mem) free(mem);
}

gpointer g_malloc(gsize n_bytes) {
    return malloc(n_bytes);
}

gpointer g_malloc0(gsize n_bytes) {
    return calloc(1, n_bytes);
}

void g_error_free(GError *error) {
    if (error) {
        if (error->message) free(error->message);
        free(error);
    }
}

void g_object_unref(gpointer object) {
    if (object) free(object);
}

gpointer g_object_ref(gpointer object) {
    return object;
}

GSettingsSchemaSource *g_settings_schema_source_get_default(void) {
    return NULL;
}

GSettingsSchema *g_settings_schema_source_lookup(GSettingsSchemaSource *source, const gchar *schema_id, gboolean recursive) {
    (void)source;
    (void)schema_id;
    (void)recursive;
    return NULL;
}

gboolean g_settings_schema_has_key(GSettingsSchema *schema, const gchar *name) {
    (void)schema;
    (void)name;
    return FALSE;
}

void g_settings_schema_unref(GSettingsSchema *schema) {
    if (schema) free(schema);
}

GSettings *g_settings_new(const gchar *schema_id) {
    (void)schema_id;
    return NULL;
}

gboolean g_settings_set_string(GSettings *settings, const gchar *key, const gchar *value) {
    (void)settings;
    (void)key;
    (void)value;
    return FALSE;
}

gboolean g_settings_set_int(GSettings *settings, const gchar *key, gint value) {
    (void)settings;
    (void)key;
    (void)value;
    return FALSE;
}

void g_settings_sync(void) {
    return;
}
