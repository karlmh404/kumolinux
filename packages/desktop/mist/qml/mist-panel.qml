// Mist Panel — Kumo Linux Mist Desktop
// Floating glass panel built with Qt Quick / Quickshell.
// Real system state via MistBridge C++ singleton (org.kumo.mist).
// NOT TESTED: requires Qt6/Quickshell built for x86_64-kumo-linux-gnu.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kumo.mist 1.0

Window {
    id: root
    width: 1120
    height: 52
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    x: (Screen.width - width) / 2
    y: 24

    readonly property color bgDark: "#1e293b"
    readonly property color bgSurface: "rgba(30, 41, 59, 0.80)"
    readonly property color accent: "#38bdf8"
    readonly property color accentDim: "rgba(56, 189, 248, 0.50)"
    readonly property color text: "#f8fafc"
    readonly property color textDim: "rgba(248, 250, 252, 0.60)"
    readonly property color activeBg: "rgba(56, 189, 248, 0.18)"
    readonly property color borderCol: "rgba(56, 189, 248, 0.35)"
    readonly property int corner: 16

    MistBridge { id: bridge }

    Rectangle {
        id: panelSurface
        anchors.fill: parent
        anchors.margins: 1
        radius: root.corner
        color: root.bgSurface
        border.color: root.borderCol
        border.width: 1
        layer.enabled: true
        layer.effect: DropShadow {
            anchor: Qt.ItemPadding
            horizontalOffset: 0
            verticalOffset: 10
            radius: 24
            color: "#000000"
            samples: 16
        }
    }

    Row {
        id: panelRow
        anchors.fill: panelSurface
        anchors.margins: 14
        spacing: 16

        Column {
            id: leftCol
            width: 260
            spacing: 4
            Row {
                height: 40
                spacing: 8
                Text { text: "☁"; font.pointSize: 20; color: root.accent }
                ToolButton {
                    text: "Mist"
                    font.pointSize: 12
                    font.bold: true
                    color: root.text
                    background: Rectangle { color: "transparent"; radius: 8 }
                    pressedBackground: Rectangle { color: root.activeBg; radius: 8 }
                    onClicked: bridge.launchLauncher()
                    ToolTip.visible: pressed
                    ToolTip.text: "Application launcher (Super+Space)"
                    ToolTip.delay: 600
                }
            }
            Row {
                id: wsRow
                spacing: 7
                Repeater {
                    model: bridge.workspaces
                    delegate: Rectangle {
                        width: 30; height: 30
                        radius: 8
                        color: modelData === bridge.activeWorkspace ? root.accent : "transparent"
                        border.color: modelData === bridge.activeWorkspace ? root.accent : root.borderCol
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pointSize: 11
                            font.bold: modelData === bridge.activeWorkspace
                            color: modelData === bridge.activeWorkspace ? root.bgDark : root.textDim
                        }
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            onClicked: bridge.switchWorkspace(modelData)
                            onEntered: parent.color = root.activeBg
                            onExited: parent.color = (modelData === bridge.activeWorkspace) ? root.accent : "transparent"
                        }
                    }
                }
            }
            Rectangle {
                height: 32
                radius: 8
                color: "transparent"
                border.color: root.borderCol
                border.width: 1
                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6
                    Text { text: "⬡"; font.pointSize: 11; color: root.accent }
                    Text {
                        text: bridge.activeApp
                        font.pointSize: 10
                        color: root.textDim
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Column {
            width: 200
            spacing: 2
            Text {
                text: bridge.clock
                font.pointSize: 16
                font.bold: true
                color: root.text
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: bridge.date
                font.pointSize: 9
                color: root.textDim
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            id: rightCol
            spacing: 14
            IndicatorButton {
                id: btnBt
                icon: ""
                active: bridge.bluetooth
                tooltip: bridge.bluetooth ? "Bluetooth (on)" : "Bluetooth (off)"
                onClicked: bridge.invoke("bluetoothctl power toggle")
                panelAccent: root.accent
                panelActiveBg: root.activeBg
                panelBorderCol: root.borderCol
                panelText: root.text
                panelTextDim: root.textDim
            }
            IndicatorButton {
                icon: bridge.netConnected ? "" : ""
                active: bridge.netConnected
                text: bridge.network
                tooltip: bridge.netConnected ? "Network (connected)" : "Network (disconnected)"
                onClicked: bridge.invoke("nmcli networking toggle")
                panelAccent: root.accent
                panelActiveBg: root.activeBg
                panelBorderCol: root.borderCol
                panelText: root.text
                panelTextDim: root.textDim
            }
            IndicatorButton {
                icon: bridge.muted ? "" : (bridge.volume > 0.6 ? "" : bridge.volume > 0.2 ? "" : "")
                active: !bridge.muted
                text: Number(bridge.volume).toFixed(0) + "%"
                tooltip: bridge.muted ? "Audio (muted)" : "Audio"
                onClicked: bridge.invoke("wpctl set-mute @DEFAULT_AUDIO_SINK toggle")
                panelAccent: root.accent
                panelActiveBg: root.activeBg
                panelBorderCol: root.borderCol
                panelText: root.text
                panelTextDim: root.textDim
            }
            IndicatorButton {
                visible: bridge.batteryPresent
                icon: bridge.batteryCharging ? "" : (bridge.battery > 0.8 ? "" : bridge.battery > 0.5 ? "" : bridge.battery > 0.2 ? "" : "")
                text: bridge.battery >= 0 ? Number(bridge.battery).toFixed(0) + "%" : "—"
                active: bridge.battery > 0.25
                tooltip: bridge.batteryPresent ? "Battery" : "Battery (n/a)"
                panelAccent: root.accent
                panelActiveBg: root.activeBg
                panelBorderCol: root.borderCol
                panelText: root.text
                panelTextDim: root.textDim
            }
            IndicatorButton {
                icon: bridge.dnd ? "" : ""
                active: !bridge.dnd
                tooltip: bridge.dnd ? "Do Not Disturb (on)" : "Notifications"
                onClicked: bridge.toggleDnd
                panelAccent: root.accent
                panelActiveBg: root.activeBg
                panelBorderCol: root.borderCol
                panelText: root.text
                panelTextDim: root.textDim
            }
            ToolButton {
                text: "⏹"
                font.pointSize: 14
                color: root.text
                background: Rectangle { color: "transparent"; radius: 8 }
                pressedBackground: Rectangle { color: root.activeBg; radius: 8 }
                menu: PowerMenu {}
                onClicked: powerMenu.open()
            }
        }
    }

    component IndicatorButton : Rectangle {
        property string icon: ""
        property bool active: false
        property string text: ""
        property string tooltip: ""
        property var onClicked: null
        property color panelAccent: "#38bdf8"
        property color panelActiveBg: "rgba(56, 189, 248, 0.18)"
        property color panelBorderCol: "rgba(56, 189, 248, 0.35)"
        property color panelText: "#f8fafc"
        property color panelTextDim: "rgba(248, 250, 252, 0.60)"
        width: 52; height: 36
        radius: 10
        color: active ? panelActiveBg : "transparent"
        border.color: active ? panelAccent : panelBorderCol
        border.width: 1
        Row {
            anchors.centerIn: parent
            spacing: 4
            Text { text: icon; font.pointSize: 12; color: active ? panelAccent : panelTextDim }
            Text {
                text: parent.text
                font.pointSize: 9
                color: parent.active ? panelText : panelTextDim
                visible: parent.text !== ""
            }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (parent.onClicked) parent.onClicked()
            onEntered: parent.color = panelActiveBg
            onExited: parent.color = parent.active ? panelActiveBg : "transparent"
        }
        ToolTip.visible: btnMouse.containsMouse
        ToolTip.text: parent.tooltip
        ToolTip.delay: 600
    }

    component PowerMenu : Menu {
        id: powerMenu
        MenuItem { text: "Lock"; onTriggered: bridge.lock() }
        MenuItem { text: "Logout"; onTriggered: bridge.logout() }
        MenuSeparator {}
        MenuItem { text: "Restart"; onTriggered: bridge.restart() }
        MenuItem { text: "Shutdown"; onTriggered: bridge.shutdown() }
        MenuItem { text: "Suspend"; onTriggered: bridge.suspend() }
    }
}
