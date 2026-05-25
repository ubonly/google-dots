// shell.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {

    // ── Глобальный список лаунчеров (заполняется из Variants) ─────────────
    property var _launchers: []
    property var _captures: []
    property var _clipboards: []

    function _toggleAllLaunchers() {
        for (var i = 0; i < _launchers.length; i++) {
            if (_launchers[i])
                _launchers[i].toggle()
        }
    }

    function toggleClipboard() {
        if (_clipboards.length > 0) {
            _clipboards[0].toggle()
        }
    }

    function _openRegionImmediate() {
        for (var i = 0; i < _captures.length; i++) {
            if (_captures[i]) _captures[i].openRegionImmediate()
        }
    }

    function _openFullscreenWait() {
        for (var i = 0; i < _captures.length; i++) {
            if (_captures[i]) _captures[i].openFullscreenWait()
        }
    }

    // ── IPC: qs ipc call launcher toggle ──────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle() { _toggleAllLaunchers() }
    }

    IpcHandler {
        target: "clipboard_ui"
        function toggle() { toggleClipboard() }
    }

    // ── IPC: qs ipc call screenshot region ──────────────────────────────────
    IpcHandler {
        target: "screenshot"
        function region() { _openRegionImmediate() }
        function fullscreen() { _openFullscreenWait() }
    }

    // ── IPC: qs ipc call TEST_ALIVE (для fallback bind) ──────────────────
    IpcHandler {
        target: "TEST_ALIVE"
        function call() { return "alive" }
    }

    // ── GlobalShortcut: Super+R → toggle launcher ──────────────────────────
    GlobalShortcut {
        name: "searchToggleRelease"
        onPressed: _toggleAllLaunchers()
    }

    // ── GlobalShortcut: Super+V → toggle clipboard ────────────────────────
    GlobalShortcut {
        name: "clipboardToggle"
        onPressed: toggleClipboard()
    }

    // ── GlobalShortcut: Super+Shift+S → Region Capture (Immediate) ────────
    GlobalShortcut {
        name: "captureRegion"
        onPressed: _openRegionImmediate()
    }

    // ── GlobalShortcut: PrintScreen → Fullscreen Capture (Wait) ────────────
    GlobalShortcut {
        name: "captureFullscreen"
        onPressed: _openFullscreenWait()
    }

    // ── TopBar + Dock на каждом экране ────────────────────────────────────
    Variants {
        id: screenVariants
        model: Quickshell.screens

        Item {
            id: screenItem
            property var modelData

            property var clientsByWs: ({})
            property string _buf: ""

            Process {
                id: hyprctlProc
                command: ["hyprctl", "clients", "-j"]
                running: true
                stdout: SplitParser {
                    onRead: function(line) { screenItem._buf += line }
                }
                onRunningChanged: {
                    if (!running) {
                        try {
                            var arr = JSON.parse(screenItem._buf)
                            var m = {}
                            for (var i = 0; i < arr.length; i++) {
                                var c = arr[i]
                                var id = c.workspace ? c.workspace.id : -1
                                if (id > 0 && !m[id])
                                    m[id] = (c["class"] || "").toLowerCase()
                            }
                            screenItem.clientsByWs = m
                        } catch(e) {}
                        screenItem._buf = ""
                    } else {
                        screenItem._buf = ""
                    }
                }
            }

            Timer {
                interval: 1500; repeat: true; running: true
                onTriggered: hyprctlProc.running = true
            }

            // QuickSettings popup (отдельный PanelWindow, теперь будет снизу)
            QuickSettingsPopup {
                id: qsPopupInst
                screenRef: modelData
                settingsWindow: settingsInst
            }

            // System Settings window
            SettingsWindow {
                id: settingsInst
                screenRef: modelData
            }

            // App Launcher
            AppLauncher {
                id: appLauncherInst
                screenRef: modelData
            }

            // Screen Capture
            ScreenCapture {
                id: screenCaptureInst
                screenRef: modelData
            }

            // Clipboard History
            ClipboardPopup {
                id: clipboardInst
                screenRef: modelData
            }

            Component.onCompleted: {
                var list = _launchers.slice()
                list.push(appLauncherInst)
                _launchers = list

                var clist = _captures.slice()
                clist.push(screenCaptureInst)
                _captures = clist
                
                var clipList = _clipboards.slice()
                clipList.push(clipboardInst)
                _clipboards = clipList
            }
            Component.onDestruction: {
                var list = _launchers.slice()
                var idx = list.indexOf(appLauncherInst)
                if (idx >= 0) list.splice(idx, 1)
                _launchers = list

                var clist = _captures.slice()
                var cidx = clist.indexOf(screenCaptureInst)
                if (cidx >= 0) clist.splice(cidx, 1)
                _captures = clist
                
                var clipList = _clipboards.slice()
                var clipIdx = clipList.indexOf(clipboardInst)
                if (clipIdx >= 0) clipList.splice(clipIdx, 1)
                _clipboards = clipList
            }

            // ── Данные для мини-иконок в кнопке быстрых настроек ───────────
            property int  wifiBars: 0
            property bool btOn:     false
            property int  volume:   50

            Process {
                id: wifiBarProc
                command: ["bash", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}' || echo '-1'"]
                running: true
                stdout: SplitParser {
                    onRead: function(line) {
                        var v = parseInt(line.trim())
                        if (isNaN(v) || v < 0)    screenItem.wifiBars = 0
                        else if (v < 25)          screenItem.wifiBars = 1
                        else if (v < 50)          screenItem.wifiBars = 2
                        else if (v < 75)          screenItem.wifiBars = 3
                        else                      screenItem.wifiBars = 4
                    }
                }
            }
            Timer { interval: 5000; repeat: true; running: true; onTriggered: wifiBarProc.running = true }

            Process {
                id: btBarProc
                command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 'on' || echo 'off'"]
                running: true
                stdout: SplitParser { onRead: function(line) { screenItem.btOn = line.trim() === "on" } }
            }
            Timer { interval: 8000; repeat: true; running: true; onTriggered: btBarProc.running = true }

            Process {
                id: volBarProc
                command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf \"%d\", $2*100}'"]
                running: true
                stdout: SplitParser {
                    onRead: function(line) {
                        var v = parseInt(line.trim())
                        if (!isNaN(v)) screenItem.volume = v
                    }
                }
            }
            Timer { interval: 3000; repeat: true; running: true; onTriggered: volBarProc.running = true }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            PanelWindow {
                screen: modelData
                anchors { bottom: true; left: true; right: true }
                implicitHeight: 70
                
                // ЭТО РЕШАЕТ КОНФЛИКТ С ОКНАМИ: мы резервируем высоту панели
                exclusiveZone: 70 

                WlrLayershell.layer:     WlrLayer.Top
                WlrLayershell.namespace: "quickshell-dock"
                color: "transparent"

                Rectangle {
                    id: dockContainer
                    anchors {
                        bottom: parent.bottom; bottomMargin: 14
                        horizontalCenter: parent.horizontalCenter
                    }
                    width:  dockRow.implicitWidth + 28
                    height: 56; radius: 18
                    color:        Qt.rgba(0.05, 0.07, 0.12, 0.60)
                    border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1

                    RowLayout {
                        id: dockRow
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                        spacing: 2

                        Repeater {
                            model: 10
                            WorkspaceAppButton {
                                wsId: index + 1
                                clientsByWs: screenItem.clientsByWs
                            }
                        }

                        Loader {
                            active: SystemTray.items.values && SystemTray.items.values.length > 0
                            sourceComponent: Row {
                                spacing: 0
                                DockSeparator {}
                                Repeater {
                                    model: SystemTray.items
                                    TrayIcon { trayItem: modelData }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
                    width: dockContainer.width * 0.55; height: 1
                    color: Qt.rgba(0.30, 0.55, 1.0, 0.18); radius: 1
                }

                // ── Левый блок (Кнопка лаунчера + Часы) ─────────────
                Row {
                    anchors {
                        left: parent.left; leftMargin: 16
                        verticalCenter: dockContainer.verticalCenter
                    }
                    spacing: 12

                    // Кнопка App Launcher
                    Rectangle {
                        id: launcherBtn
                        width: 36; height: 36; radius: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: (appLauncherInst && appLauncherInst.isOpen) || launcherBtnArea.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.14)
                            : Qt.rgba(1, 1, 1, 0.07)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // ChromeOS-style "G" logo
                        Text {
                            anchors.centerIn: parent
                            text: "G"
                            font { pixelSize: 20; family: "Google Sans"; weight: Font.Bold }
                            color: "white"
                        }

                        MouseArea {
                            id: launcherBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appLauncherInst.toggle()
                        }
                    }

                    // Часы
                    Text {
                        text:  Qt.formatDateTime(clock.date, "hh:mm")
                        color: Qt.rgba(1, 1, 1, 0.92)
                        font { pixelSize: 16; family: "Google Sans"; weight: Font.SemiBold }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text:  Qt.formatDateTime(clock.date, "MMM d")
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font { pixelSize: 13; family: "Google Sans"; weight: Font.Medium }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ── Правый блок (Пилюля быстрых настроек) ─────────────
                Rectangle {
                    id: qsBtn
                    width:  qsRow.implicitWidth + 20
                    height: 32
                    radius: 16
                    anchors {
                        right: parent.right; rightMargin: 16
                        verticalCenter: dockContainer.verticalCenter
                    }

                        color: qsBtnArea.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.14)
                            : Qt.rgba(1, 1, 1, 0.07)
                        border.color: Qt.rgba(1, 1, 1, 0.09)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 130 } }

                        Row {
                            id: qsRow
                            anchors.centerIn: parent
                            spacing: 8

                            // WiFi полоски
                            Row {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        property int idx: index
                                        width:  2.5
                                        height: 6 + idx * 3
                                        radius: 1.2
                                        anchors.bottom: parent.bottom
                                        color: (screenItem.wifiBars > idx)
                                            ? Qt.rgba(1.0, 1.0, 1.0, 0.90)
                                            : Qt.rgba(1.0, 1.0, 1.0, 0.22)
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }
                            }

                            // Bluetooth точка
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: screenItem.btOn
                                    ? Qt.rgba(0.60, 0.72, 1.0, 1.0)
                                    : Qt.rgba(1.0, 1.0, 1.0, 0.24)
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }

                            // Громкость
                            Row {
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: screenItem.volume <= 0 ? "🔇" : "🔊"
                                    font.pixelSize: 11
                                    color: Qt.rgba(1, 1, 1, 0.78)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 24; height: 4; radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                    Rectangle {
                                        width:  Math.max(2, parent.width * (screenItem.volume / 100))
                                        height: parent.height; radius: parent.radius
                                        color:  Qt.rgba(1, 1, 1, 0.82)
                                        Behavior on width { NumberAnimation { duration: 180 } }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: qsBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                if (qsPopupInst)
                                    qsPopupInst.popupVisible = !qsPopupInst.popupVisible
                            }
                        }
                    }
                }
            }
        }
    }
