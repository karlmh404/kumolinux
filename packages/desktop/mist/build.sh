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

mkdir -p "$KUMO_DESTDIR/etc/skel/.config/hypr"
cat > "$KUMO_DESTDIR/etc/skel/.config/hypr/hyprland.conf" << HYPRCONF
# ============================================================================
# MIST — Kumo Linux Desktop Configuration for Hyprland
# ============================================================================

monitor=,preferred,auto,auto

###################
### MY PROGRAMS ###
###################

$terminal = foot
$fileManager = thunar
$menu = mist-launcher
$wallpaper = hyprpaper
$lock = hyprlock
$bar = mist-panel

#############################
### ENVIRONMENT VARIABLES ###
#############################

env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
env = XCURSOR_THEME,Kumo-Mist
env = GTK_THEME,Mist-Dark
env = QT_QPA_PLATFORMTHEME=qt5ct
env = QT_QPA_PLATFORM=wayland

#####################
### LOOK AND FEEL ###
#####################

general {
    gaps_in = 8
    gaps_out = 16
    border_size = 2
    resize_on_border = true
    allow_tearing = false
    layout = dwindle
}

col.active_border = rgba(56189ef8) rgba(167139efa7) 45deg
col.inactive_border = rgba(100116139bb)

decoration {
    rounding = 12
    active_opacity = 0.95
    inactive_opacity = 0.90
    shadow {
        enabled = true
        range = 8
        render_power = 3
        color = rgba(1523141ee)
    }
    blur {
        enabled = true
        size = 6
        passes = 2
        vibrancy = 0.2
    }
}

animations {
    enabled = yes
    bezier = easeOutQuint,0.23,1,0.32,1
    bezier = easeInOutCubic,0.65,0.05,0.36,1
    bezier = linear,0,0,1,1
    bezier = almostLinear,0.5,0.5,0.75,1.0
    bezier = quick,0.15,0,0.1,1
    bezier = misty,0.25,0.1,0.25,1
    animation = global, 1, 10, default
    animation = border, 1, 6, easeOutQuint
    animation = windows, 1, 6, easeOutQuint
    animation = windowsIn, 1, 5, easeOutQuint, popin 85%
    animation = windowsOut, 1, 2, linear, popin 85%
    animation = fadeIn, 1, 2, almostLinear
    animation = fadeOut, 1, 2, almostLinear
    animation = fade, 1, 4, quick
    animation = layers, 1, 4, easeOutQuint
    animation = layersIn, 1, 4, easeOutQuint, fade
    animation = layersOut, 1, 2, linear, fade
    animation = fadeLayersIn, 1, 2, almostLinear
    animation = fadeLayersOut, 1, 2, almostLinear
    animation = workspaces, 1, 2, almostLinear, fade
    animation = workspacesIn, 1, 1.5, almostLinear, fade
    animation = workspacesOut, 1, 2, almostLinear, fade
}

dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_status = master
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
}

decoration {
    cursor {
        size = 24
    }
}

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    touchpad {
        natural_scroll = false
    }
}

gestures {
    workspace_swipe = false
}

$mainMod = SUPER

bind = $mainMod, Q, exec, foot
bind = $mainMod, C, killactive,
bind = $mainMod, F, fullscreen,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, Space, exec, $menu
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, L, exec, $lock

bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

windowrulev2 = suppressevent maximize, class:.*
windowrulev2 = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0
windowrulev2 = float, class:^(mist-panel|mist-launcher)$
windowrulev2 = float, title:^(About)$

exec-once = mist-panel &
exec-once = hyprpaper -c /usr/share/kumo/mist/wallpapers/hyprpaper.conf &
exec-once = mako &
HYPRCONF

mkdir -p "$KUMO_DESTDIR/usr/share/mist/qml"
cp "$MISTDIR/qml/mist-panel.qml" "$KUMO_DESTDIR/usr/share/mist/qml/"
cp "$MISTDIR/qml/mist-launcher.qml" "$KUMO_DESTDIR/usr/share/mist/qml/"

if [ -d "$MISTDIR/cpp" ]; then
    mkdir -p "$KUMO_DESTDIR/usr/lib/qt6/qml/org/kumo/mist"
    cp "$MISTDIR/cpp/qmldir" "$KUMO_DESTDIR/usr/lib/qt6/qml/org/kumo/mist/"
fi

cat > "$KUMO_DESTDIR/usr/bin/mist-panel" << PANELEOF
#!/usr/bin/env bash
exec qml /usr/share/mist/qml/mist-panel.qml "$@"
PANELEOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist-panel"

cat > "$KUMO_DESTDIR/usr/bin/mist-launcher" << LAUNCHEREOF
#!/usr/bin/env bash
exec qml /usr/share/mist/qml/mist-launcher.qml "$@"
LAUNCHEREOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist-launcher"

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

echo "[mist] Package staged successfully"
