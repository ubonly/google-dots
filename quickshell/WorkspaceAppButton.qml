// WorkspaceAppButton.qml
// Чисто динамический воркспейс:
//   пусто → точка
//   открыто окно → иконка этого окна (из class)

import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    property int wsId: 1
    property var clientsByWs: ({})

    readonly property bool   isFocused:   Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace !== undefined && Hyprland.focusedWorkspace.id === wsId
    readonly property string windowClass: (clientsByWs && clientsByWs[wsId]) ? clientsByWs[wsId] : ""
    readonly property bool   hasWindows:  windowClass !== ""

    implicitWidth:  44
    implicitHeight: 44

    // ── ПУСТО: точка ─────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        visible: !root.hasWindows
        width:  root.isFocused ? 8 : 5
        height: width
        radius: width / 2
        color:  root.isFocused
                ? Qt.rgba(0.55, 0.82, 1.0, 0.90)
                : Qt.rgba(0.40, 0.60, 0.90, 0.38)
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation  { duration: 180 } }
    }

    // ── ЕСТЬ ОКНО: иконка ────────────────────────────────────────────────
    Item {
        anchors.centerIn: parent
        visible: root.hasWindows

        Rectangle {
            anchors.centerIn: parent
            width:  root.isFocused ? 38 : (mouse.containsMouse ? 35 : 32)
            height: width
            radius: 11
            color:  root.isFocused
                    ? Qt.rgba(0.12, 0.32, 0.75, 0.28)
                    : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: root.isFocused ? Qt.rgba(0.40, 0.68, 1.0, 0.38) : "transparent"
            border.width: 1
            Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color  { ColorAnimation  { duration: 160 } }
        }

        Image {
            id: iconImg
            anchors.centerIn: parent
            width:  root.isFocused ? 24 : 20
            height: width
            source: root.hasWindows ? "image://icon/" + root.windowClass : ""
            smooth: true; mipmap: true
            fillMode: Image.PreserveAspectFit
            opacity: root.isFocused ? 1.0 : 0.72
            scale:   mouse.containsMouse ? 1.12 : 1.0
            Behavior on width   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // ── Тултип ───────────────────────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.top; bottomMargin: 6; horizontalCenter: parent.horizontalCenter }
        width:  ttLabel.implicitWidth + 18; height: 22; radius: 7
        color:  Qt.rgba(0.04, 0.06, 0.14, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.09); border.width: 1
        opacity: mouse.containsMouse ? 1.0 : 0.0; z: 20
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Text {
            id: ttLabel; anchors.centerIn: parent
            text:  root.hasWindows ? root.windowClass : ("Workspace " + root.wsId)
            color: Qt.rgba(1, 1, 1, 0.82)
            font { pixelSize: 11; family: "Google Sans"; weight: Font.Medium }
        }
    }

    // ── Мышь ─────────────────────────────────────────────────────────────
    MouseArea {
        id: mouse; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("workspace " + root.wsId)
    }
}
