#!/usr/bin/env bash
set -euo pipefail

MISTDIR="$KUMO_SOURCE"

mkdir -p "$KUMO_DESTDIR/usr/bin"
cat > "$KUMO_DESTDIR/usr/bin/mist" << MISTEOF
#!/usr/bin/env bash
set -euo pipefail
export XDG_CURRENT_DESKTOP=Mist
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Mist
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    echo "mist: XDG_RUNTIME_DIR is not set; are you on a logind session?" >&2
    exit 1
fi
exec Hyprland
MISTEOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist"

cat > "$KUMO_DESTDIR/usr/bin/mist-panel" << PANELEOF
#!/usr/bin/env bash
exec qml6 /usr/share/mist/qml/mist-panel.qml "$@"
PANELEOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist-panel"

cat > "$KUMO_DESTDIR/usr/bin/mist-launcher" << LAUNCHEREOF
#!/usr/bin/env bash
exec qml6 /usr/share/mist/qml/mist-launcher.qml "$@"
LAUNCHEREOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist-launcher"

mkdir -p "$KUMO_DESTDIR/usr/share/mist/qml"
cp "$MISTDIR/qml/mist-panel.qml" "$KUMO_DESTDIR/usr/share/mist/qml/"
cp "$MISTDIR/qml/mist-launcher.qml" "$KUMO_DESTDIR/usr/share/mist/qml/"

if [ -d "$MISTDIR/cpp" ]; then
    mkdir -p "$KUMO_DESTDIR/usr/lib/qt6/qml/org/kumo/mist"
    cp "$MISTDIR/cpp/qmldir" "$KUMO_DESTDIR/usr/lib/qt6/qml/org/kumo/mist/"
    cp -r "$MISTDIR/cpp" "$KUMO_DESTDIR/usr/share/mist/cpp"
fi

mkdir -p "$KUMO_DESTDIR/usr/share/kumo/mist/wallpapers"
cp "$MISTDIR/wallpapers/kumo-mist.png" "$KUMO_DESTDIR/usr/share/kumo/mist/wallpapers/"
cat > "$KUMO_DESTDIR/usr/share/kumo/mist/wallpapers/hyprpaper.conf" << HYPEOF
preload = /usr/share/kumo/mist/wallpapers/kumo-mist.png
wallpaper = /usr/share/kumo/mist/wallpapers/kumo-mist.png
HYPEOF

mkdir -p "$KUMO_DESTDIR/usr/share/kumo/mist/themes"
cp "$MISTDIR/themes/Mist-Dark.theme" "$KUMO_DESTDIR/usr/share/kumo/mist/themes/"
cp "$MISTDIR/themes/Mist-Light.theme" "$KUMO_DESTDIR/usr/share/kumo/mist/themes/"

mkdir -p "$KUMO_DESTDIR/etc/skel/.config/foot"
if [ -f "$MISTDIR/foot/mist-foot.ini" ]; then
    cp "$MISTDIR/foot/mist-foot.ini" "$KUMO_DESTDIR/etc/skel/.config/foot/foot.ini"
fi

mkdir -p "$KUMO_DESTDIR/usr/share/applications"
cat > "$KUMO_DESTDIR/usr/share/applications/mist-panel.desktop" << DEOF
[Desktop Entry]
Name=Mist Panel
Comment=Kumo Mist desktop panel
Exec=mist-panel
Type=Application
Category=System;
DEOF
cat > "$KUMO_DESTDIR/usr/share/applications/mist-launcher.desktop" << DEOF
[Desktop Entry]
Name=Mist Launcher
Comment=Kumo Mist application launcher
Exec=mist-launcher
Type=Application
Category=System;
DEOF
cat > "$KUMO_DESTDIR/usr/share/applications/mist-settings.desktop" << DEOF
[Desktop Entry]
Name=Mist Settings
Comment=Kumo Mist settings application
Exec=mist-settings
Type=Application
Category=Settings;System;
DEOF
cat > "$KUMO_DESTDIR/usr/share/applications/foot.desktop" << DEOF
[Desktop Entry]
Name=Foot Terminal
Comment=Kumo Mist terminal (Wayland)
Exec=foot
Type=Application
Category=Terminal;System;
DEOF

mkdir -p "$KUMO_DESTDIR/etc/systemd/user"
cat > "$KUMO_DESTDIR/etc/systemd/user/mist-session.target" << UNITEOF
[Unit]
Description=Mist Desktop Session
Requires=mako.service
After=graphical-session.target
UNITEOF
cat > "$KUMO_DESTDIR/etc/systemd/user/mako.service" << UNITEOF
[Unit]
Description=Mist Notification Daemon
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/mako
Restart=on-failure

[Install]
WantedBy=mist-session.target
UNITEOF

echo "[mist] Package staged successfully
