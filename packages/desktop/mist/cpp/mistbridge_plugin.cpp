#include <qqml.h>
#include "mistbridge.h"

static QObject *mistbridge_singleton(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    if (!MistBridge::instance())
        new MistBridge(nullptr);
    return MistBridge::instance();
}

class MistBridgePlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface)
public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(uri == QLatin1String("org.kumo.mist"));
        qmlRegisterSingletonType<MistBridge>(uri, 1, 0, "MistBridge", mistbridge_singleton);
    }
};

#include "mistbridge_plugin.moc"

