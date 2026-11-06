// Mist Launcher — Kumo Linux Mist Desktop
// Application launcher: fuzzy search over real .desktop files.
// NOT TESTED: requires Qt6/Quickshell built for x86_64-kumo-linux-gnu.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kumo.mist 1.0

Window {
    id: root
    width: 700
    height: 460
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowModal
    modality: Qt.ApplicationModal

    readonly property color bgDark: "#1e293b"
    readonly property color bgSurface: "rgba(30, 41, 59, 0.88)"
    readonly property color accent: "#38bdf8"
    readonly property color text: "#f8fafc"
    readonly property color textDim: "rgba(248, 250, 252, 0.60)"
    readonly property color activeBg: "rgba(56, 189, 248, 0.18)"
    readonly property color borderCol: "rgba(56, 189, 248, 0.35)"
    readonly property int corner: 14

    MistBridge { id: bridge }

    property string favorites: ""
    property string searchText: ""
    property bool commandMode: searchText.startsWith(">")
    property var allApps: (bridge.applications && bridge.applications !== "")
        ? JSON.parse(bridge.applications) : []
    property var results: []
    property int currentIndex: 0

    Component.onCompleted: bridge.refreshApplications()
    onVisibleChanged: if (visible) bridge.refreshApplications()

    Rectangle {
        id: searchBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.corner
            color: root.bgSurface
            border.color: root.borderCol
            border.width: 1
            layer.enabled: true
            layer.effect: DropShadow { verticalOffset: 6; radius: 16; color: "#000000"; samples: 12 }
        }
        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            Text { text: commandMode ? "›" : ""; font.pointSize: 15; color: root.accent }
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: commandMode ? "Run command…" : "Search applications…"
                color: root.text
                placeholderTextColor: root.textDim
                font.pointSize: 14
                background: Rectangle { color: "transparent" }
                onTextChanged: { root.filter(); searchText = text }
                Keys.onPressed: {
                    if (event.key === Qt.Key_Escape) { root.visible = false; event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.launchCurrent(); event.accepted = true }
                    else if (event.key === Qt.Key_Down) { root.moveSelection(1); event.accepted = true }
                    else if (event.key === Qt.Key_Up) { root.moveSelection(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Tab) { root.toggleCommandMode(); event.accepted = true }
                }
            }
        }
    }

    ListView {
        id: resultsList
        anchors.top: searchBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        model: root.results
        currentIndex: root.currentIndex
        highlightFollowsCurrentItem: true
        spacing: 6
        delegate: Rectangle {
            width: ListView.view.width
            height: 52
            radius: 10
            color: ListView.isCurrentItem ? root.activeBg : "transparent"
            border.color: ListView.isCurrentItem ? root.accent : "transparent"
            border.width: 1
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                Image {
                    source: modelData.icon ? ("icon://" + modelData.icon) : ""
                    width: 28; height: 28
                    fillMode: Image.PreserveAspectFit
                    clip: true
                    sourceSize: { width: 28; height: 28 }
                    Text { visible: !modelData.icon; anchors.centerIn: parent; text: "⬡"; font.pointSize: 12; color: root.accent }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: modelData.name; font.pointSize: 12; font.bold: ListView.isCurrentItem; color: root.text; elide: Text.ElideRight }
                    Text { text: modelData.comment; font.pointSize: 9; color: root.textDim; elide: Text.ElideRight }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: resultsList.currentIndex = index
                onClicked: root.launch(modelData)
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 10
        spacing: 16
        Repeater {
            model: [
                { text: "Lock", action: "bridge.lock()" },
                { text: "Logout", action: "bridge.logout()" },
                { text: "Restart", action: "bridge.restart()" },
                { text: "Shutdown", action: "bridge.shutdown()" }
            ]
            delegate: ToolButton {
                text: modelData.text
                font.pointSize: 10
                color: root.textDim
                background: Rectangle { color: "transparent"; radius: 8 }
                pressedBackground: Rectangle { color: root.activeBg; radius: 8 }
                onClicked: eval(modelData.action)
            }
        }
    }

    function toggleCommandMode() {
        if (commandMode) searchField.text = searchField.text.slice(1);
        else searchField.text = ">" + searchField.text;
        searchField.focus = true;
    }
    function fuzzyScore(text, pattern) {
        if (!pattern) return 0;
        var t = text.toLowerCase();
        var p = pattern.toLowerCase();
        if (p === "") return 0;
        if (t.indexOf(p) === 0) return 100;
        if (t.indexOf(p) !== -1) return 50;
        return 0;
    }
    function filter() {
        var pattern = commandMode ? searchField.text.slice(1) : searchField.text;
        var res = [];
        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i];
            var name = app.name || "";
            var comment = app.comment || "";
            var score = commandMode ? 100 : Math.max(fuzzyScore(name, pattern), fuzzyScore(comment, pattern));
            if (commandMode || score > 0) {
                res.push({ name: name, comment: comment, icon: app.icon, exec: app.exec, path: app.path, score: score });
            }
        }
        res.sort(function (a, b) {
            var af = root.favorites.indexOf(a.path) !== -1 ? 1 : 0;
            var bf = root.favorites.indexOf(b.path) !== -1 ? 1 : 0;
            if (af !== bf) return bf - af;
            if (b.score !== a.score) return b.score - a.score;
            return a.name.localeCompare(b.name);
        });
        root.results = res;
        root.currentIndex = 0;
        if (res.length > 0) resultsList.currentIndex = 0;
    }
    function moveSelection(delta) {
        var ni = root.currentIndex + delta;
        if (ni < 0) ni = root.results.length - 1;
        if (ni >= root.results.length) ni = 0;
        root.currentIndex = ni;
        resultsList.currentIndex = ni;
    }
    function launch(item) {
        root.visible = false;
        if (item && item.exec) bridge.launchApp(item.exec);
    }
    function launchCurrent() {
        if (root.results.length > 0) root.launch(root.results[root.currentIndex]);
        else if (commandMode && searchField.text.length > 1) bridge.invoke(searchField.text.slice(1));
        root.visible = false;
    }
}
