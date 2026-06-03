// ScreenCapture.qml — Chrome OS-style Screen Capture toolbar
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: capture
    property var screenRef
    property bool isOpen: false

    screen: screenRef
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture"
    property bool isCapturing: captureProc.running
    WlrLayershell.keyboardFocus: (isOpen && !isCapturing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: isOpen
    color: "transparent"

    onIsOpenChanged: {
        if (!isOpen) {
            isDragging = false
        }
    }

    // ── State ──────────────────────────────────────────────────────────────
    // "screenshot" or "record"
    property string captureType: "screenshot"
    // "fullscreen", "region", or "window"
    property string captureMode: "region"

    // ── Palette ────────────────────────────────────────────────────────────
    readonly property color barBg:        Qt.rgba(0.12, 0.13, 0.19, 0.92)
    readonly property color barBorder:    Qt.rgba(1, 1, 1, 0.06)
    readonly property color btnDefault:   Qt.rgba(1, 1, 1, 0.0)
    readonly property color btnHover:     Qt.rgba(1, 1, 1, 0.08)
    readonly property color btnActive:    Qt.rgba(0.30, 0.55, 1.0, 0.25)
    readonly property color accentColor:  Qt.rgba(0.40, 0.65, 1.0, 1.0)
    readonly property color textPrimary:  Qt.rgba(1, 1, 1, 0.92)
    readonly property color textSecondary:Qt.rgba(1, 1, 1, 0.45)
    readonly property color dividerColor: Qt.rgba(1, 1, 1, 0.10)

    // ── Native Region Selection ───────────────────────────────────────────
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurX: 0
    property real dragCurY: 0
    property bool isDragging: false

    readonly property real selX: Math.min(dragStartX, dragCurX)
    readonly property real selY: Math.min(dragStartY, dragCurY)
    readonly property real selW: Math.abs(dragCurX - dragStartX)
    readonly property real selH: Math.abs(dragCurY - dragStartY)

    // ── Commands ──────────────────────────────────────────────────────────
    function getCommand() {
        var ts = "$(date +%Y-%m-%d_%H-%M-%S)"
        if (captureType === "screenshot") {
            if (captureMode === "fullscreen") return "mkdir -p \"$HOME/Pictures\"; hyprshot -s -m output -m \"" + capture.screenRef.name + "\" -o \"$HOME/Pictures\" -f Screenshot_" + ts + ".png"
            if (captureMode === "window")     return "mkdir -p \"$HOME/Pictures\"; hyprshot -z -s -m window -o \"$HOME/Pictures\" -f Screenshot_" + ts + ".png"
            if (captureMode === "region")     return "mkdir -p \"$HOME/Pictures\"; hyprshot -z -s -m region -o \"$HOME/Pictures\" -f Screenshot_" + ts + ".png"
        } else {
            var vid = "$HOME/Videos/Screenrecord_" + ts + ".mp4"
            if (captureMode === "fullscreen") return "mkdir -p \"$HOME/Videos\"; wl-screenrec -o \"" + capture.screenRef.name + "\" -f \"" + vid + "\""
            if (captureMode === "window")     return "mkdir -p \"$HOME/Videos\"; wl-screenrec -f \"" + vid + "\""
            if (captureMode === "region")     return "mkdir -p \"$HOME/Videos\"; wl-screenrec -f \"" + vid + "\""
        }
        return ""
    }

    Process {
        id: captureProc
        command: ["bash", "-c", ""]
        onRunningChanged: {
            if (!running && capture.isOpen) {
                capture.isOpen = false
            }
        }
    }

    function doCapture(hideFirst) {
        if (hideFirst) capture.isOpen = false
        var cmd = getCommand()
        if (!cmd) return
        captureProc.command = ["bash", "-c", cmd]
        captureProc.running = true
    }

    function openRegionImmediate() {
        // Run grimblast which handles freezing and selection natively without our UI
        captureProc.command = ["bash", "-c", "grimblast --freeze copy area"]
        captureProc.running = true
    }

    function openFullscreenWait() {
        captureType = "screenshot"
        captureMode = "fullscreen"
        isOpen = true
        focusCatcher.forceActiveFocus()
    }

    function toggle() {
        isOpen = !isOpen
        if (isOpen) {
            captureType = "screenshot"
            captureMode = "region"
            focusCatcher.forceActiveFocus()
        }
    }

    Item {
        id: focusCatcher
        focus: capture.isOpen
        Keys.onReturnPressed: capture.doCapture(true)
        Keys.onEnterPressed: capture.doCapture(true)
        Keys.onEscapePressed: capture.isOpen = false
    }

    // ── Dimming and Cutout ────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: capture.isOpen && (capture.captureMode === "region" || capture.captureMode === "fullscreen" || capture.captureMode === "window")
        
        // Base dimming if not dragging
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
            visible: !capture.isDragging
        }

        // 4 rectangles for cutout when dragging
        Item {
            anchors.fill: parent
            visible: capture.isDragging
            
            Rectangle { x: 0; y: 0; width: parent.width; height: capture.selY; color: Qt.rgba(0,0,0,0.4) }
            Rectangle { x: 0; y: capture.selY + capture.selH; width: parent.width; height: parent.height - (capture.selY + capture.selH); color: Qt.rgba(0,0,0,0.4) }
            Rectangle { x: 0; y: capture.selY; width: capture.selX; height: capture.selH; color: Qt.rgba(0,0,0,0.4) }
            Rectangle { x: capture.selX + capture.selW; y: capture.selY; width: parent.width - (capture.selX + capture.selW); height: capture.selH; color: Qt.rgba(0,0,0,0.4) }
            
            Rectangle {
                x: capture.selX; y: capture.selY; width: capture.selW; height: capture.selH
                color: "transparent"
                border.color: capture.accentColor
                border.width: 1
            }
        }
    }

    // ── Interaction / Drawing ─────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        cursorShape: capture.captureMode === "region" ? Qt.CrossCursor : Qt.ArrowCursor

        onPressed: function(mouse) {
            if (capture.captureMode === "region") {
                capture.dragStartX = mouse.x
                capture.dragStartY = mouse.y
                capture.dragCurX = mouse.x
                capture.dragCurY = mouse.y
                capture.isDragging = true
            } else if (capture.captureMode === "fullscreen") {
                capture.doCapture(true)
            } else {
                capture.isOpen = false
            }
        }

        onPositionChanged: function(mouse) {
            if (capture.isDragging) {
                capture.dragCurX = mouse.x
                capture.dragCurY = mouse.y
            }
        }

        onReleased: function(mouse) {
            if (capture.isDragging) {
                capture.isDragging = false
                capture.doCustomRegionCapture()
            }
        }
    }

    function doCustomRegionCapture() {
        if (selW < 10 || selH < 10) {
            isOpen = false
            return
        }
        var absX = Math.round(capture.screenRef.x + capture.selX)
        var absY = Math.round(capture.screenRef.y + capture.selY)
        var absW = Math.round(capture.selW)
        var absH = Math.round(capture.selH)
        var geometry = absX + "," + absY + " " + absW + "x" + absH

        var ts = "$(date +%Y-%m-%d_%H-%M-%S)"
        var cmd = ""
        if (captureType === "screenshot") {
            cmd = "mkdir -p \"$HOME/Pictures\"; grim -g \"" + geometry + "\" \"$HOME/Pictures/Screenshot_" + ts + ".png\" && setsid -f wl-copy --type image/png < \"$HOME/Pictures/Screenshot_" + ts + ".png\" >/dev/null 2>&1"
        } else {
            cmd = "mkdir -p \"$HOME/Videos\"; wl-screenrec -g \"" + geometry + "\" -f \"$HOME/Videos/Screenrecord_" + ts + ".mp4\""
        }

        capture.isOpen = false
        captureProc.command = ["bash", "-c", cmd]
        captureProc.running = true
    }

    // ── Main layout (Capture button + Toolbar) ────────────────────────────
    Column {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 16
        }
        spacing: 12

        // ── Floating "Capture" / "Record" button ─────────────────────────────────
        Rectangle {
            id: captureButton
            visible: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: captureButtonRow.implicitWidth + 32
            height: 40
            radius: 20
            color: captureBtnArea.containsMouse
                ? Qt.rgba(0.12, 0.14, 0.22, 0.98)
                : Qt.rgba(0.10, 0.12, 0.18, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            // Entrance animation
            opacity: (capture.isOpen && capture.captureMode !== "region") ? 1.0 : 0.0
            transformOrigin: Item.Bottom

            Row {
                id: captureButtonRow
                anchors.centerIn: parent
                spacing: 8

                Image {
                    id: captureBtnIcon
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    source: capture.captureType === "screenshot"
                        ? "assets/icons/screenshot.svg"
                        : "assets/icons/screen-record.svg"
                    sourceSize: Qt.size(18, 18)
                    visible: false
                }
                ColorOverlay {
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    source: captureBtnIcon
                    color: capture.textPrimary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: capture.captureType === "screenshot" ? "Capture" : "Record"
                    color: capture.textPrimary
                    font { pixelSize: 14; family: "Google Sans"; weight: Font.Medium }
                }
            }

            MouseArea {
                id: captureBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: capture.doCapture(true)
            }
        }

        // ── Toolbar pill ──────────────────────────────────────────────────
        Rectangle {
            id: toolbar
            anchors.horizontalCenter: parent.horizontalCenter
            width: toolbarRow.implicitWidth + 24
            height: 52
            radius: 26
            color: capture.barBg
            border.color: capture.barBorder
            border.width: 1

            // Entrance animation
            opacity: (capture.isOpen && !capture.isDragging) ? 1.0 : 0.0
            transformOrigin: Item.Bottom

            // Block clicks from dismissing
            MouseArea { anchors.fill: parent; onClicked: {} }

            RowLayout {
                id: toolbarRow
                anchors.centerIn: parent
                spacing: 4

                // ═══════════════ Block 1: Capture Type ═══════════════
                // Screenshot button
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureType === "screenshot"
                        ? capture.btnActive
                        : screenshotArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureType === "screenshot" ? capture.accentColor : "transparent"
                    border.width: capture.captureType === "screenshot" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: screenshotIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/screenshot.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: screenshotIcon
                        color: Qt.rgba(1, 1, 1, capture.captureType === "screenshot" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: screenshotArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureType = "screenshot"
                    }
                }

                // Record button
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureType === "record"
                        ? capture.btnActive
                        : recordArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureType === "record" ? capture.accentColor : "transparent"
                    border.width: capture.captureType === "record" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: recordIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/screen-record.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: recordIcon
                        color: Qt.rgba(1, 1, 1, capture.captureType === "record" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: recordArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureType = "record"
                    }
                }

                // ═══════════════ Divider 1 ═══════════════
                Rectangle {
                    width: 1; height: 28
                    color: capture.dividerColor
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                // ═══════════════ Block 2: Capture Mode ═══════════════
                // Fullscreen
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureMode === "fullscreen"
                        ? capture.btnActive
                        : fullscreenArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureMode === "fullscreen" ? capture.accentColor : "transparent"
                    border.width: capture.captureMode === "fullscreen" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: fullscreenIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/fullscreen.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: fullscreenIcon
                        color: Qt.rgba(1, 1, 1, capture.captureMode === "fullscreen" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: fullscreenArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureMode = "fullscreen"
                    }
                }

                // Region
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureMode === "region"
                        ? capture.btnActive
                        : regionArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureMode === "region" ? capture.accentColor : "transparent"
                    border.width: capture.captureMode === "region" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: regionIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/crop-region.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: regionIcon
                        color: Qt.rgba(1, 1, 1, capture.captureMode === "region" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: regionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureMode = "region"
                    }
                }

                // Window
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: capture.captureMode === "window"
                        ? capture.btnActive
                        : windowArea.containsMouse ? capture.btnHover : capture.btnDefault
                    border.color: capture.captureMode === "window" ? capture.accentColor : "transparent"
                    border.width: capture.captureMode === "window" ? 1.5 : 0
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: windowIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/window-capture.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: windowIcon
                        color: Qt.rgba(1, 1, 1, capture.captureMode === "window" ? 1.0 : 0.6)
                    }

                    MouseArea {
                        id: windowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.captureMode = "window"
                    }
                }

                // ═══════════════ Divider 2 ═══════════════
                Rectangle {
                    width: 1; height: 28
                    color: capture.dividerColor
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                // ═══════════════ Block 3: Settings + Close ═══════════════
                // Settings (placeholder)
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: settingsArea.containsMouse ? capture.btnHover : capture.btnDefault
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: settingsIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/settings.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: settingsIcon
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }

                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {} // Placeholder
                    }
                }

                // Close
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: closeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.15) : capture.btnDefault
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: closeIcon
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "assets/icons/close.svg"
                        sourceSize: Qt.size(20, 20)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: closeIcon
                        color: closeArea.containsMouse ? Qt.rgba(1, 0.5, 0.5, 1.0) : Qt.rgba(1, 1, 1, 0.6)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.isOpen = false
                    }
                }
            }
        }
    }
}
