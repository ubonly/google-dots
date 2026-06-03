// shell.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

ShellRoot {

    // ── Global notification server (must be a single instance) ─────────────
    NotificationServer {
        id: notifServer
        actionsSupported:     false
        bodySupported:        true
        bodyMarkupSupported:  false
        bodyImagesSupported:  false
        imageSupported:       true
        persistenceSupported: true
        keepOnReload:         true

        onNotification: function(notif) {
            console.log("[notif] received:", notif.appName, "|", notif.summary, "|", notif.body)
            notif.tracked = true
            // Mirror into the notification center history (so it persists past the toast)
            for (var i = 0; i < _notifCenters.length; i++) {
                if (_notifCenters[i]) _notifCenters[i].pushNotification(notif)
            }
        }
    }

    property var _notifCenters: []
    function toggleNotificationCenter() {
        for (var i = 0; i < _notifCenters.length; i++) {
            if (_notifCenters[i]) _notifCenters[i].isOpen = !_notifCenters[i].isOpen
        }
    }


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
                                    m[id] = c["class"] || ""
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

            // Media Popup
            MediaPopup {
                id: mediaPopupInst
                screenRef: modelData
            }

            // Notifications stream (top-right)
            NotificationsPopup {
                id: notifPopupInst
                screenRef: modelData
                notificationsModel: notifServer.trackedNotifications.values
            }

            // Notification Center (bottom-right popup)
            NotificationCenterPopup {
                id: notifCenterInst
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

                var ncList = _notifCenters.slice()
                ncList.push(notifCenterInst)
                _notifCenters = ncList
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

                var ncList = _notifCenters.slice()
                var ncIdx = ncList.indexOf(notifCenterInst)
                if (ncIdx >= 0) ncList.splice(ncIdx, 1)
                _notifCenters = ncList
            }

            // ── Данные для мини-иконок ───────────────────────────────────
            property int  wifiBars: 0
            property bool btOn:     false
            property int  volume:   50
            property string kbLayout: "US"
            property bool isRecording: false

            Process {
                id: recordCheckProc
                command: ["bash", "-c", "pgrep wl-screenrec >/dev/null && echo 'yes' || echo 'no'"]
                running: true
                stdout: SplitParser {
                    onRead: function(line) {
                        screenItem.isRecording = (line.trim() === "yes")
                    }
                }
            }
            Timer { interval: 1000; repeat: true; running: true; onTriggered: recordCheckProc.running = true }

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

            // ── Keyboard layout detection ──────────────────────────────
            Process {
                id: kbProc
                command: ["bash", "-c", "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[0].active_keymap' 2>/dev/null"]
                running: true
                stdout: SplitParser {
                    onRead: function(line) {
                        var raw = line.trim()
                        if (raw.toLowerCase().indexOf("russian") >= 0)       screenItem.kbLayout = "RU"
                        else if (raw.toLowerCase().indexOf("english") >= 0)  screenItem.kbLayout = "US"
                        else if (raw.toLowerCase().indexOf("german") >= 0)   screenItem.kbLayout = "DE"
                        else if (raw.toLowerCase().indexOf("french") >= 0)   screenItem.kbLayout = "FR"
                        else if (raw.toLowerCase().indexOf("spanish") >= 0)  screenItem.kbLayout = "ES"
                        else if (raw.toLowerCase().indexOf("ukraine") >= 0)  screenItem.kbLayout = "UA"
                        else if (raw.length > 0 && raw.length <= 3)          screenItem.kbLayout = raw.toUpperCase()
                        else if (raw.length > 3)                             screenItem.kbLayout = raw.substring(0, 2).toUpperCase()
                        else                                                  screenItem.kbLayout = "US"
                    }
                }
            }
            Timer { interval: 2000; repeat: true; running: true; onTriggered: kbProc.running = true }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            Process {
                id: kbSwitchProc
                command: ["hyprctl", "switchxkblayout", "all", "next"]
                running: false
                onRunningChanged: {
                    if (!running) kbProc.running = true
                }
            }

            // ══════════════════════════════════════════════════════════════
            //  CHROMEOS-STYLE BOTTOM BAR
            // ══════════════════════════════════════════════════════════════
            PanelWindow {
                screen: modelData
                anchors { bottom: true; left: true; right: true }
                implicitHeight: 48

                // Резервируем высоту панели
                exclusiveZone: 48

                WlrLayershell.layer:     WlrLayer.Top
                WlrLayershell.namespace: "quickshell-dock"
                color: "transparent"

                // ── Full-width bar background ──────────────────────────────
                Rectangle {
                    id: barBg
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height + 32
                    radius: 32
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.95)

                    // Subtle top border
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.05)
                    }
                }

                // ── Far-left: G launcher button ────────────────────────────
                Rectangle {
                    id: launcherBtn
                    anchors {
                        left: parent.left; leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    width: 38; height: 38; radius: 19
                    color: (appLauncherInst && appLauncherInst.isOpen) || launcherBtnArea.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.16)
                        : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "G"
                        font { pixelSize: 18; family: "Google Sans"; weight: Font.Bold }
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }

                        MouseArea {
                            id: launcherBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appLauncherInst.toggle()
                        }
                    }

                    // ── Center: Workspace buttons directly on the bar ──────────
                    Row {
                        id: dockRow
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: 10
                            WorkspaceAppButton {
                                wsId: index + 1
                                clientsByWs: screenItem.clientsByWs
                            }
                        }

                        Loader {
                            // Disabled by default
                            active: false // SystemTray.items.values && SystemTray.items.values.length > 0
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

                    // ── Right side: ChromeOS-style status area ─────────────────
                    Row {
                        id: rightArea
                        anchors {
                            right: parent.right; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        // ── Stop Recording Indicator ──────────────────
                        Rectangle {
                            id: stopRecordPill
                            width: 38; height: 38; radius: 19
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 0.2, 0.2, 0.2)
                            border.color: Qt.rgba(1, 0.2, 0.2, 0.5)
                            border.width: 1
                            visible: screenItem.isRecording

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: stopRecordPill.visible
                                NumberAnimation { to: 0.5; duration: 1000; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 12; height: 12
                                radius: 2
                                color: Qt.rgba(1, 0.2, 0.2, 0.9)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var p = Qt.createQmlObject('import Quickshell.Io 1.0; Process { command: ["killall", "-SIGINT", "wl-screenrec"] }', stopRecordPill, "killProc")
                                    p.running = true
                                    screenItem.isRecording = false
                                }
                            }
                        }

                    // ── 0. Media Pill ────────────────────────────
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        anchors.verticalCenter: parent.verticalCenter
                        color: mediaPopupInst.isOpen ? Qt.rgba(0.7, 0.6, 1.0, 0.8) : (mediaArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                        border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1

                        Image {
                            id: mediaImg
                            anchors.centerIn: parent
                            width: 18; height: 18
                            source: "assets/icons/music-note.svg"
                            sourceSize: Qt.size(18, 18)
                            smooth: true
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: mediaImg
                            source: mediaImg
                            color: mediaPopupInst.isOpen ? Qt.rgba(0.1, 0.1, 0.1, 1.0) : Qt.rgba(1, 1, 1, 0.90)
                        }

                        MouseArea {
                            id: mediaArea
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mediaPopupInst.isOpen = !mediaPopupInst.isOpen
                            }
                        }
                    }

                    Rectangle {
                        id: combinedPill
                        width: combinedRow.implicitWidth
                        height: 38; radius: 19
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
                        clip: true

                        Row {
                            id: combinedRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Item {
                                id: notifSection
                                visible: notifCenterInst.history.length > 0
                                width: 42; height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: height / 2
                                    color: notifCenterInst.isOpen
                                        ? Qt.rgba(0.7, 0.6, 1.0, 0.8)
                                        : (notifBadgeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: notifCenterInst.history.length
                                    color: notifCenterInst.isOpen
                                        ? Qt.rgba(0.1, 0.1, 0.1, 1.0)
                                        : Qt.rgba(1, 1, 1, 0.95)
                                    font { pixelSize: 13; family: "Google Sans"; weight: Font.Bold }
                                }

                                MouseArea {
                                    id: notifBadgeArea
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: notifCenterInst.isOpen = !notifCenterInst.isOpen
                                }
                            }

                            Item {
                                visible: notifCenterInst.history.length > 0
                                width: 2; height: 38
                                Rectangle {
                                    width: 2; height: 20
                                    anchors.centerIn: parent
                                    color: Qt.rgba(1, 1, 1, 0.20)
                                }
                            }

                            Item {
                                id: dateSection
                                width: dateTxt.implicitWidth + 24; height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: height / 2
                                    color: "transparent"
                                }

                                Text {
                                    id: dateTxt
                                    anchors.centerIn: parent
                                    text: Qt.formatDateTime(clock.date, "MMM d")
                                    color: Qt.rgba(1, 1, 1, 0.90)
                                    font { pixelSize: 13; family: "Google Sans"; weight: Font.Bold }
                                }
                            }

                            Item {
                                width: 2; height: 38
                                Rectangle {
                                    width: 2; height: 20
                                    anchors.centerIn: parent
                                    color: Qt.rgba(1, 1, 1, 0.20)
                                }
                            }

                            Item {
                                id: statusSection
                                width: wifiTimeRow.implicitWidth + 28; height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: height / 2
                                    color: qsPopupInst.popupVisible
                                        ? Qt.rgba(0.7, 0.6, 1.0, 0.8)
                                        : (statusArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                                }

                                Row {
                                    id: wifiTimeRow
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Item {
                                        width: 18; height: 18
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: dockWifiImg
                                            anchors.fill: parent
                                            source: {
                                                if (screenItem.wifiBars <= 0) return "assets/icons/wifi-off.svg"
                                                if (screenItem.wifiBars === 1) return "assets/icons/network-wifi-1-bar.svg"
                                                if (screenItem.wifiBars === 2) return "assets/icons/network-wifi-2-bar.svg"
                                                if (screenItem.wifiBars === 3) return "assets/icons/network-wifi-3-bar.svg"
                                                return "assets/icons/signal-wifi-4-bar.svg"
                                            }
                                            sourceSize: Qt.size(18, 18)
                                            smooth: true
                                            visible: false
                                        }
                                        ColorOverlay {
                                            anchors.fill: dockWifiImg
                                            source: dockWifiImg
                                            color: qsPopupInst.popupVisible
                                                ? Qt.rgba(0.1, 0.1, 0.1, 1.0)
                                                : Qt.rgba(1, 1, 1, 0.90)
                                        }
                                    }

                                    Text {
                                        id: timeTxt
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Qt.formatDateTime(clock.date, "HH:mm")
                                        color: qsPopupInst.popupVisible
                                            ? Qt.rgba(0.1, 0.1, 0.1, 1.0)
                                            : Qt.rgba(1, 1, 1, 0.95)
                                        font { pixelSize: 13; family: "Google Sans"; weight: Font.Bold }
                                    }
                                }

                                MouseArea {
                                    id: statusArea
                                    anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
        }
    }
}
