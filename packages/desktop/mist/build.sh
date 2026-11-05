#!/usr/bin/env bash
set -euo pipefail

# Mist Desktop Environment - Kumo Linux
# Installs session launcher, panel, launcher, and default configuration.

# 1. Session launcher: mist command starts the Mist graphical session
mkdir -p "$KUMO_DESTDIR/usr/bin"
cat > "$KUMO_DESTDIR/usr/bin/mist" << 'MISTEOF'
#!/usr/bin/env bash
# mist - Launch the Kumo Mist desktop session
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

# 2. Mist panel script
cat > "$KUMO_DESTDIR/usr/bin/mist-panel" << 'PANELEOF'
#!/usr/bin/env bash
# mist-panel - Simple Mist desktop panel
set -euo pipefail

PANEL_HEIGHT=30
PANEL_W=400
PANEL_X=20
PANEL_Y=20

exec weston-terminal \
    --geometry=${PANEL_W}x${PANEL_HEIGHT}+${PANEL_X}+${PANEL_Y} \
    --title="mist-panel" \
    --working-directory="$HOME" \
    -e 'bash -c "
        while true; do
            clear
            echo \"\033[1;36m\u2601 Mist\033[0m\"
            echo \"\"
            echo \"\033[1mWorkspaces:\033[0m\"
            hyprctl activeworkspace -j 2>/dev/null | jq -r \"[.id, .name] | join(\": \")\" 2>/dev/null || echo \"1: main\"
            echo \"\"
            echo \"\033[1mTime:\033[0m $(date \"+%H:%M:%S\")\"
            echo \"\033[1mDate:\033[0m $(date \"+%Y-%m-%d\")\"
            echo \"\"
            echo \"\033[1mKeys:\033[0m\"
            echo \"  Super+Q  Terminal\"
            echo \"  Super+Space  Launcher\"
            echo \"  Super+C  Close\"
            echo \"  Super+F  Fullscreen\"
            echo \"  Super+V  Floating\"
            echo \"  Super+M  Exit\"
            echo \"  Super+L  Lock\"
            sleep 2
        done
    "'
PANELEOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist-panel"

# 3. Mist launcher script
cat > "$KUMO_DESTDIR/usr/bin/mist-launcher" << 'LAUNCHEREOF'
#!/usr/bin/env bash
# mist-launcher - Simple Mist application launcher
set -euo pipefail

APP_DIRS=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/applications"
)

declare -a APPS=()
declare -a APP_NAMES=()

for dir in "${APP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        while IFS= read -r -d '' file; do
            name=$(grep -m1 "^Name=" "$file" 2>/dev/null | cut -d= -f2-)
            exec=$(grep -m1 "^Exec=" "$file" 2>/dev/null | cut -d= -f2- | sed 's/%.//g')
            if [ -n "$name" ] && [ -n "$exec" ]; then
                APPS+=("$exec")
                APP_NAMES+=("$name")
            fi
        done < <(find "$dir" -name "*.desktop" -print0 2>/dev/null)
    fi
done

if [ ${#APPS[@]} -eq 0 ]; then
    APPS=(weston-terminal hyprctl)
    APP_NAMES=("Terminal" "Hyprland Control")
fi

echo "\033[1;36m\u2601 Mist Launcher\033[0m"
echo "\033[1mSelect an application:\033[0m"
echo ""

for i in "${!APP_NAMES[@]}"; do
    echo "  $((i+1))) ${APP_NAMES[$i]}"
done

echo ""
echo "  0) Cancel"
echo ""
read -p "Choice: " choice

if [ "$choice" = "0" ] || [ -z "$choice" ]; then
    exit 0
fi

if [ "$choice" -ge 1 ] && [ "$choice" -le ${#APPS[@]} ]; then
    idx=$((choice-1))
    exec ${APPS[$idx]} &
fi
LAUNCHEREOF
chmod 0755 "$KUMO_DESTDIR/usr/bin/mist-launcher"

# 4. Mist Hyprland configuration
mkdir -p "$KUMO_DESTDIR/etc/skel/.config/hypr"
cat > "$KUMO_DESTDIR/etc/skel/.config/hypr/hyprland.conf" << 'HYPREOF'
# MIST - Kumo Linux Desktop Configuration for Hyprland

monitor=,preferred,auto,auto

$terminal = weston-terminal
$fileManager = thunar
$menu = mist-launcher
$wallpaper = hyprpaper
$lock = hyprlock
$bar = waybar

env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
env = XCURSOR_THEME,Kumo-Mist
env = GTK_THEME,Mist-Dark
env = QT_QPA_PLATFORMTHEME,qt5ct

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
}

gestures {
    workspace_swipe = false
}

$mainMod = SUPER

bind = $mainMod, Q, exec, weston-terminal
bind = $mainMod, C, killactive,
bind = $mainMod, F, fullscreen,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, Space, exec, mist-launcher
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
windowrulev2 = float, class:^(mist-launcher|mist-launcher)$
windowrulev2 = float, class:^(mist-panel|mist-panel)$
windowrulev2 = float, class:^(waybar)$
windowrulev2 = float, title:^(About)$

exec-once = mist-panel &
HYPREOF

# 5. Mist user session systemd units
mkdir -p "$KUMO_DESTDIR/etc/systemd/user"
cat > "$KUMO_DESTDIR/etc/systemd/user/mist-session.target" << 'UNITEOF'
[Unit]
Description=Mist Desktop Session
After=graphical-session.target
UNITEOF

# 6. Mist branding directories
mkdir -p "$KUMO_DESTDIR/usr/share/kumo/mist/wallpapers"
mkdir -p "$KUMO_DESTDIR/usr/share/kumo/mist/icons"
mkdir -p "$KUMO_DESTDIR/usr/share/kumo/mist/themes"

echo "[mist] Package staged successfully"
