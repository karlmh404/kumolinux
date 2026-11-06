# Kumo Linux — Big Step 10: Mist Desktop Progress

Updated: 2026-11-06

## Repository State
- Authoritative repo: `/home/kewl/kumo` under WSL Ubuntu (`wsl.exe -d Ubuntu -u kewl`)
- Current HEAD: `0fdfb13` (Mist Desktop Milestone 2 source fixes), pushed to origin/main
- Parent: `56d2474` (correct Step 10 baseline)
- Cross-compiler: x86_64-kumo-linux-gnu-gcc 16.2.0 at out/toolchain/bin/
- Build tools: kpm, kumo-build, kumo-repo, kumo-sign, kumo-rootfs
- 20 CPU cores, 7.6GB RAM, 898GB disk available

## Source Fixes Applied (All Committed)

### Build Script Fixes
- **hyprlock/build.sh**: Removed PowerShell `n artifacts, added real newlines, added OpenGL/EGL hints, added hyprwayland-scanner sed patches
- **mist/build.sh**: Changed `qml6` ? `qml` (qml6 does not exist), removed settings/mist-settings.qml reference (file does not exist), removed foot.desktop reference (foot not packaged), compiles MistBridge plugin source
- **qtbase/build.sh**: Disabled dbus (avoids needing host Qt6DBusTools), disabled xcb (avoids needing xkbcommon-x11), reduced parallel jobs from -j20 to -j4
- **hyprpaper/build.sh**: Fixed with proper cmake cross-compilation flags

### Package.toml Fixes
- **hyprlock/package.toml**: Real SHA-256 (01eab866...), build system=custom, added mesa/libdrm/hyprwayland-scanner deps
- **hyprpaper/package.toml**: Real SHA-256 (8459e025...), correct URL/filename
- **mist/package.toml**: Release 3, removed foot/thunar/maku from deps (not packaged), deps: glibc-runtime, hyprland, qtbase, qtdeclarative, qtwayland, quickshell, hyprlock, hyprpaper

### QML Fixes
- **mist-launcher.qml**: Added `property string searchText: ""`, kept in sync via `onTextChanged: { root.filter(); searchText = text }`, all function references now use defined property
- **mist-panel.qml**: Replaced `QString.number()` with `Number().toFixed()` (C++ syntax not valid in QML JS)

### QML Files (Source Complete, Not Built)
- **mist-panel.qml**: Floating glass panel with Kumo ? logo, workspace chips, active app, clock/date, bluetooth/network/audio/battery/DND indicators, power menu (Lock/Logout/Restart/Shutdown/Suspend)
- **mist-launcher.qml**: Real .desktop discovery via MistBridge, fuzzy search, keyboard nav, command mode (>), power actions footer
- **MistBridge C++**: mistbridge.h, mistbridge.cpp, mistbridge_plugin.cpp, qmldir, CMakeLists.txt — org.kumo.mist 1.0 QML module

### Visual Assets
- **Wallpaper**: packages/desktop/mist/wallpapers/kumo-mist.png (original cloud-inspired gradient)
- **Themes**: Mist-Dark.theme, Mist-Light.theme
- **Foot theme**: mist-foot.ini (Mist palette, DejaVu Mono, padding 14, opacity 0.94)

### Hyprland Integration
- **skel hyprland.conf**: Mist theme (blur, transparency, rounding 12px, gaps 8/16, animations), Super+Q/space/L bindings, $terminal=foot, $menu=mist-launcher, $lock=hyprlock, $bar=mist-panel

## Build Status

### BLOCKED: Qt6 Cross-Compilation
qtbase build reached 84% before being killed by session timeout. Cross-compiling Qt6 takes too long for a single session (est. 1-3 hours even with -j4). Additional issues:
- Requires host Qt6 tools (Qt6DBusTools, qdbuscpp2xml) — disabled dbus to work around
- Requires xkbcommon-x11 for XCB — disabled xcb since Wayland-only
- Each build attempt gets killed when the shell session times out

### BLOCKED: hyprlock 0.4.0
Requires newer dependencies than available:
- hyprutils >= 0.11.0 (have 0.5.2)
- sdbus-c++ >= 2.0.0 (not available)
- hyprgraphics >= 0.1.6 (not available)

### NOT BUILT (Waiting on Qt6)
- qtshadertools, qtdeclarative, qtwayland, quickshell
- MistBridge C++ QML plugin
- hyprpaper
- mist .kpkg

## Git Status
- Commit 0fdfb13 pushed to origin/main
- Working tree clean (plus untracked tmp/)

## Next Steps
1. Complete Qt6 cross-compilation (qtbase ? qtshadertools ? qtdeclarative ? qtwayland ? quickshell)
   - Use background_process or setsid nohup to avoid timeout kills
   - May need to split across multiple sessions
2. Build MistBridge C++ QML plugin (requires Qt6)
3. Build hyprpaper
4. Resolve hyprlock dependency issue (use older version or build newer deps)
5. Build mist .kpkg
6. Test in QEMU: `./scripts/run-hyprland-qemu.sh` then `kpm install mist && mist`

## Exact QEMU Test Command (Not Yet Runnable)
```
# On WSL host:
./scripts/run-hyprland-qemu.sh

# Inside guest (tty1, regular user):
kpm install mist
mist
# Shortcuts: Super+Q=terminal, Super+Space=launcher, Super+L=lock
```

## Security
- No default root password introduced. Production requires unique credentials.

## Definition of Success (Not Yet Met)
User can boot Kumo, install a genuinely built Mist package, type `mist`, and see the real Mist desktop with working panel, launcher, wallpaper, terminal and keyboard/mouse interaction.

