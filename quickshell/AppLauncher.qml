// AppLauncher.qml — Chrome OS-style full-screen app launcher
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: launcher
    property var screenRef
    property bool isOpen: false

    screen: screenRef
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: isOpen
    color: "transparent"

    // ── Palette ────────────────────────────────────────────────────────────
    readonly property color bgTint:       Qt.rgba(0.11, 0.12, 0.18, 0.96)
    readonly property color searchBg:     Qt.rgba(0.18, 0.20, 0.28, 1.0)
    readonly property color searchBorder: Qt.rgba(1, 1, 1, 0.05)
    readonly property color textPrimary:  Qt.rgba(1, 1, 1, 0.92)
    readonly property color textSecondary:Qt.rgba(1, 1, 1, 0.45)
    readonly property color hoverBg:      Qt.rgba(1, 1, 1, 0.07)

    // ── App loading ───────────────────────────────────────────────────────
    property var allApps: []
    property var filteredApps: []
    property string searchText: ""
    property int activeIndex: 0
    property string _buf: ""

    Process {
        id: listProc
        command: ["python3", Qt.resolvedUrl("list-apps.py").toString().replace("file://", "")]
        running: false
        stdout: SplitParser {
            onRead: function(line) { launcher._buf += line }
        }
        onRunningChanged: {
            if (!running && launcher._buf.length > 2) {
                try {
                    var arr = JSON.parse(launcher._buf)
                    arr.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    launcher.allApps = arr
                    launcher.filterApps()
                } catch(e) { console.log("parse error:", e) }
                launcher._buf = ""
            } else if (running) {
                launcher._buf = ""
            }
        }
    }

    Component.onCompleted: listProc.running = true

    function filterApps() {
        if (searchText === "") {
            filteredApps = allApps
        } else {
            var q = searchText.toLowerCase()
            var r = []
            for (var i = 0; i < allApps.length; i++) {
                if (allApps[i].name.toLowerCase().indexOf(q) >= 0)
                    r.push(allApps[i])
            }
            filteredApps = r
        }
    }

    function toggle() {
        isOpen = !isOpen
        if (isOpen) {
            searchText = ""
            activeIndex = 0
            filterApps()
            searchInput.text = ""
            searchInput.forceActiveFocus()
            listProc.running = true
        }
    }

    function launchApp(cmd) {
        Hyprland.dispatch("exec " + cmd)
        isOpen = false
    }

    // ── Full-screen background (transparent) ──────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.isOpen = false
        }
    }

    // ── Popup Window Container ─────────────────────────────────────────────
    Rectangle {
        id: popupWindow
        width: 640
        height: Math.min(760, parent.height - 120)
        anchors {
            left: parent.left
            leftMargin: 16
            bottom: parent.bottom
            bottomMargin: 86
        }
        color: launcher.bgTint
        radius: 24
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true

        // Entrance animation
        opacity: launcher.isOpen ? 1.0 : 0.0
        scale:   launcher.isOpen ? 1.0 : 0.96
        transformOrigin: Item.BottomLeft
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Block clicks from dismissing
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 0

            // ── Search bar ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 720
                Layout.alignment: Qt.AlignHCenter
                height: 48
                radius: 24
                color: launcher.searchBg
                border.color: launcher.searchBorder
                border.width: 1

                Row {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left; leftMargin: 16
                    }
                    spacing: 12

                    // Google-style "G" circle
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: Qt.rgba(0.26, 0.52, 0.96, 1.0)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "G"
                            font { pixelSize: 16; family: "Google Sans"; weight: Font.Bold }
                            color: "white"
                        }
                    }

                    TextInput {
                        id: searchInput
                        width: popupWindow.width - 120
                        anchors.verticalCenter: parent.verticalCenter
                        color: launcher.textPrimary
                        font { pixelSize: 15; family: "Google Sans" }
                        clip: true
                        selectByMouse: true
                        selectionColor: Qt.rgba(0.40, 0.60, 1.0, 0.30)

                        onTextChanged: {
                            launcher.searchText = text
                            launcher.activeIndex = 0
                            launcher.filterApps()
                        }

                        Keys.onEscapePressed: launcher.isOpen = false
                        
                        Keys.onPressed: function(event) {
                            if (launcher.filteredApps.length === 0) return;

                            var cols = appGrid.columns
                            var maxIdx = launcher.filteredApps.length - 1

                            if (event.key === Qt.Key_Right) {
                                launcher.activeIndex = Math.min(launcher.activeIndex + 1, maxIdx)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left) {
                                launcher.activeIndex = Math.max(launcher.activeIndex - 1, 0)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                launcher.activeIndex = Math.min(launcher.activeIndex + cols, maxIdx)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                launcher.activeIndex = Math.max(launcher.activeIndex - cols, 0)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                launcher.launchApp(launcher.filteredApps[launcher.activeIndex].exec)
                                event.accepted = true
                            }
                        }
                    }
                }

                // Placeholder
                Text {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left; leftMargin: 62
                    }
                    text: "Search your images, files, apps, and more..."
                    color: launcher.textSecondary
                    font { pixelSize: 15; family: "Google Sans" }
                    visible: searchInput.text === ""
                }
            }

            Item { Layout.preferredHeight: 12 }

            // ── App grid ──────────────────────────────────────────────
            Flickable {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                contentHeight: appGrid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                GridLayout {
                    id: appGrid
                    width: parent.width
                    columns: 5
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: launcher.filteredApps

                        Item {
                            id: cell
                            Layout.preferredWidth:  (appGrid.width - (appGrid.columns - 1) * 4) / appGrid.columns
                            Layout.preferredHeight: 110

                            property var app: launcher.filteredApps[index]

                            // Hover & Focus bg
                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: (cellMouse.containsMouse || index === launcher.activeIndex)
                                       ? launcher.hoverBg : "transparent"
                                border.color: (index === launcher.activeIndex) ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                // Icon with circular bg
                                Item {
                                    width: 56; height: 56
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 28
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        visible: appIcon.status !== Image.Ready
                                    }

                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: 44; height: 44
                                        source: "image://icon/" + cell.app.icon
                                        smooth: true; mipmap: true
                                        fillMode: Image.PreserveAspectFit
                                        scale: cellMouse.containsMouse ? 1.06 : 1.0
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.4
                                            }
                                        }
                                    }
                                }

                                // Name
                                Text {
                                    width: Math.min(100, cell.width - 12)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cell.app.name
                                    color: launcher.textPrimary
                                    font { pixelSize: 11; family: "Google Sans" }
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignHCenter
                                    lineHeight: 1.15
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: launcher.launchApp(cell.app.exec)
                            }
                        }
                    }
                }
            }
        }
    }
}
