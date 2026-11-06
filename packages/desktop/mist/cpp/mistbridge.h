#ifndef MISTBRIDGE_H
#define MISTBRIDGE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QProcess>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>

class MistBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString activeWorkspace READ activeWorkspace NOTIFY activeWorkspaceChanged)
    Q_PROPERTY(QStringList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QString activeApp READ activeApp NOTIFY activeAppChanged)
    Q_PROPERTY(QString clock READ clock NOTIFY clockChanged)
    Q_PROPERTY(QString date READ date NOTIFY dateChanged)
    Q_PROPERTY(qreal volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted NOTIFY mutedChanged)
    Q_PROPERTY(QString network READ network NOTIFY networkChanged)
    Q_PROPERTY(bool netConnected READ netConnected NOTIFY netConnectedChanged)
    Q_PROPERTY(bool bluetooth READ bluetooth NOTIFY bluetoothChanged)
    Q_PROPERTY(qreal battery READ battery NOTIFY batteryChanged)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY batteryChargingChanged)
    Q_PROPERTY(bool batteryPresent READ batteryPresent NOTIFY batteryPresentChanged)
    Q_PROPERTY(bool dnd READ dnd NOTIFY dndChanged)
    Q_PROPERTY(QString applications READ applications NOTIFY applicationsChanged)

public:
    explicit MistBridge(QObject *parent = nullptr);
    static MistBridge *instance();

    QString activeWorkspace() const { return m_activeWorkspace; }
    QStringList workspaces() const { return m_workspaces; }
    QString activeApp() const { return m_activeApp; }
    QString clock() const { return m_clock; }
    QString date() const { return m_date; }
    qreal volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    QString network() const { return m_network; }
    bool netConnected() const { return m_netConnected; }
    bool bluetooth() const { return m_bluetooth; }
    qreal battery() const { return m_battery; }
    bool batteryCharging() const { return m_batteryCharging; }
    bool batteryPresent() const { return m_batteryPresent; }
    bool dnd() const { return m_dnd; }
    QString applications() const { return m_applications; }

    Q_INVOKABLE void invoke(const QString &command);
    Q_INVOKABLE void launchTerminal();
    Q_INVOKABLE void launchLauncher();
    Q_INVOKABLE void switchWorkspace(const QString &name);
    Q_INVOKABLE void launchApp(const QString &exec);
    Q_INVOKABLE void lock();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void shutdown();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void toggleDnd();
    Q_INVOKABLE void refreshApplications();

signals:
    void activeWorkspaceChanged();
    void workspacesChanged();
    void activeAppChanged();
    void clockChanged();
    void dateChanged();
    void volumeChanged();
    void mutedChanged();
    void networkChanged();
    void netConnectedChanged();
    void bluetoothChanged();
    void batteryChanged();
    void batteryChargingChanged();
    void batteryPresentChanged();
    void dndChanged();
    void applicationsChanged();

private:
    void poll();
    QString sh(const QString &cmd) const;
    QString readFirstFile(const QStringList &paths) const;
    QString desktopValue(const QString &text, const QString &key) const;
    QJsonObject parseDesktopFile(const QString &path) const;

    QTimer m_pollTimer;
    QProcess m_proc;
    QString m_activeWorkspace = "1";
    QStringList m_workspaces = {"1","2","3","4","5","6","7","8","9"};
    QString m_activeApp = "Desktop";
    QString m_clock;
    QString m_date;
    qreal m_volume = 0;
    bool m_muted = false;
    QString m_network = "\u2014";
    bool m_netConnected = false;
    bool m_bluetooth = false;
    qreal m_battery = -1;
    bool m_batteryCharging = false;
    bool m_batteryPresent = false;
    bool m_dnd = false;
    QString m_applications;
};

#endif // MISTBRIDGE_H
