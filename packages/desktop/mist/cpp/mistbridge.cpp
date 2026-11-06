#include "mistbridge.h"
#include <QGuiApplication>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QRegularExpression>
#include <algorithm>

static MistBridge *g_self = nullptr;

MistBridge::MistBridge(QObject *parent)
    : QObject(parent)
{
    g_self = this;
    m_pollTimer.setInterval(1000);
    m_pollTimer.setSingleShot(false);
    connect(&m_pollTimer, &QTimer::timeout, this, &MistBridge::poll);
    m_pollTimer.start();
    poll();
}

MistBridge *MistBridge::instance() { return g_self; }

void MistBridge::poll()
{
    QDateTime now = QDateTime::currentDateTime();
    QString clock = now.toString("HH:mm");
    QString date = now.toString("ddd MMM d");
    if (clock != m_clock) { m_clock = clock; emit clockChanged(); }
    if (date != m_date) { m_date = date; emit dateChanged(); }

    QString hyprctl = sh("hyprctl -j workspaces 2>/dev/null");
    QJsonDocument wsDoc = QJsonDocument::fromJson(hyprctl.toUtf8());
    QStringList wsList;
    if (wsDoc.isArray()) {
        for (const QJsonValue &v : wsDoc.array()) {
            QJsonObject o = v.toObject();
            wsList.append(QString::number(o.value("id").toInt()));
        }
    }
    if (wsList.isEmpty()) wsList = {"1","2","3","4","5","6","7","8","9"};
    if (wsList != m_workspaces) { m_workspaces = wsList; emit workspacesChanged(); }

    QString activeWin = sh("hyprctl -j activewindow 2>/dev/null");
    QJsonDocument awDoc = QJsonDocument::fromJson(activeWin.toUtf8());
    QString activeApp = "Desktop";
    if (awDoc.isObject()) {
        QString cls = awDoc.object().value("class").toString();
        QString title = awDoc.object().value("title").toString();
        activeApp = !cls.isEmpty() ? cls : (!title.isEmpty() ? title : "Desktop");
    }
    if (activeApp != m_activeApp) { m_activeApp = activeApp; emit activeAppChanged(); }

    QString vol = sh("wpctl get-volume @DEFAULT_AUDIO_SINK 2>/dev/null || echo \"Volume: 0.5\"");
    bool muted = vol.contains("[MUTED]", Qt::CaseInsensitive);
    QRegularExpression volRx("Volume:\\\\s*([0-9.]+)");
    QRegularExpressionMatch m = volRx.match(vol);
    qreal volume = 0;
    if (m.hasMatch()) volume = m.captured(1).toDouble() * 100.0;
    if (volume != m_volume) { m_volume = volume; emit volumeChanged(); }
    if (muted != m_muted) { m_muted = muted; emit mutedChanged(); }

    QString net = sh("nmcli -t -f STATE connection show --active 2>/dev/null | head -1 || echo \"\"");
    QString network = "\\u2014";
    bool netConnected = false;
    if (net.contains("activated", Qt::CaseInsensitive)) {
        netConnected = true;
        QString ssid = sh("nmcli -t -f active,ssid dev wifi 2>/dev/null | grep \"^yes:\" | cut -d: -f2 | head -1");
        if (!ssid.isEmpty() && ssid != "--") network = ssid.trimmed();
        else network = "Connected";
    }
    if (network != m_network) { m_network = network; emit networkChanged(); }
    if (netConnected != m_netConnected) { m_netConnected = netConnected; emit netConnectedChanged(); }

    QString bt = sh("bluetoothctl show 2>/dev/null | grep \"Powered:\" || echo \"Powered: no\"");
    bool bluetooth = bt.contains("yes", Qt::CaseInsensitive);
    if (bluetooth != m_bluetooth) { m_bluetooth = bluetooth; emit bluetoothChanged(); }

    QString cap = readFirstFile(QStringList{
        "/sys/class/power_supply/BAT0/capacity",
        "/sys/class/power_supply/BAT1/capacity"});
    bool ok = false;
    qreal bat = cap.toInt(&ok);
    bool present = ok;
    bool charging = false;
    if (present) {
        QString stat = readFirstFile(QStringList{
            "/sys/class/power_supply/BAT0/status",
            "/sys/class/power_supply/BAT1/status"});
        charging = stat.contains("Charg", Qt::CaseInsensitive);
    }
    if (bat != m_battery) { m_battery = bat; emit batteryChanged(); }
    if (present != m_batteryPresent) { m_batteryPresent = present; emit batteryPresentChanged(); }
    if (charging != m_batteryCharging) { m_batteryCharging = charging; emit batteryChargingChanged(); }

    QString dndOut = sh("makoctl list 2>/dev/null || echo \"\"");
    bool dnd = dndOut.contains("do-not-disturb", Qt::CaseInsensitive) &&
               (dndOut.contains("enabled", Qt::CaseInsensitive) || dndOut.contains("on", Qt::CaseInsensitive));
    if (dnd != m_dnd) { m_dnd = dnd; emit dndChanged(); }
}
QString MistBridge::sh(const QString &cmd) const
{
    m_proc.start("sh", QStringList() << "-c" << cmd);
    if (!m_proc.waitForFinished(1500)) {
        m_proc.kill();
        m_proc.waitForFinished();
        return "";
    }
    return QString::fromUtf8(m_proc.readAllStandardOutput()).trimmed();
}

QString MistBridge::readFirstFile(const QStringList &paths) const
{
    for (const QString &p : paths) {
        QFile f(p);
        if (f.exists() && f.open(QIODevice::ReadOnly | QIODevice::Text))
            return f.readAll().trimmed();
    }
    return "";
}

QString MistBridge::desktopValue(const QString &text, const QString &key) const
{
    QString needle = key + "=";
    int pos = text.indexOf(needle, 0, Qt::CaseInsensitive);
    if (pos == -1) return QString();
    int start = pos + needle.size();
    int end = text.indexOf("\\n", start);
    if (end == -1) end = text.size();
    return text.mid(start, end - start).trimmed().remove(QChar(0x22));
}

QJsonObject MistBridge::parseDesktopFile(const QString &path) const
{
    QJsonObject entry;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return entry;
    QString text = f.readAll();
    f.close();
    if (desktopValue(text, "NoDisplay") == "true") return entry;
    if (desktopValue(text, "Hidden") == "true") return entry;
    QString name = desktopValue(text, "Name");
    if (name.isEmpty()) return entry;
    entry["name"] = name;
    entry["exec"] = desktopValue(text, "Exec");
    entry["icon"] = desktopValue(text, "Icon");
    entry["comment"] = desktopValue(text, "Comment");
    entry["categories"] = desktopValue(text, "Categories");
    entry["terminal"] = desktopValue(text, "Terminal");
    entry["path"] = path;
    return entry;
}

void MistBridge::refreshApplications()
{
    QJsonArray apps;
    QDir dir("/usr/share/applications");
    QStringList files = dir.entryList(QStringList() << "*.desktop", QDir::Files);
    std::sort(files.begin(), files.end());
    for (const QString &file : files) {
        QJsonObject obj = parseDesktopFile(dir.absoluteFilePath(file));
        if (!obj.value("name").toString().isEmpty())
            apps.append(obj);
    }
    QJsonDocument doc(apps);
    QString json = doc.toJson(QJsonDocument::Compact);
    if (json != m_applications) {
        m_applications = json;
        emit applicationsChanged();
    }
}

void MistBridge::launchApp(const QString &exec)
{
    QString cmd = exec;
    cmd.remove(QRegularExpression("%[fFuU]"));
    cmd = cmd.trimmed();
    invoke(cmd);
}

void MistBridge::invoke(const QString &command) { m_proc.start("sh", QStringList() << "-c" << command); }
void MistBridge::launchTerminal() { invoke("foot"); }
void MistBridge::launchLauncher() { invoke("mist-launcher"); }
void MistBridge::switchWorkspace(const QString &name) { invoke("hyprctl dispatch workspace " + name); }
void MistBridge::lock() { invoke("hyprlock"); }
void MistBridge::logout() { invoke("hyprctl dispatch exit"); }
void MistBridge::restart() { invoke("systemctl reboot"); }
void MistBridge::shutdown() { invoke("systemctl poweroff"); }
void MistBridge::suspend() { invoke("systemctl suspend"); }
void MistBridge::toggleDnd() { invoke("makoctl set-do-not-disturb toggle"); }

#include "mistbridge.moc"

