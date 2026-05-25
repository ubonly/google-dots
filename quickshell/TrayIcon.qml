// TrayIcon.qml — иконка системного трея
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: root
    property SystemTrayItem trayItem

    implicitWidth:  32
    implicitHeight: 44

    Rectangle {
        anchors.centerIn: parent
        width:  28
        height: 28
        radius: 8
        color:  mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Image {
            anchors.centerIn: parent
            width:  20
            height: 20
            source: root.trayItem ? root.trayItem.icon : ""
            smooth: true
            antialiasing: true

            scale: mouse.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id:           mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (event) => {
            if (!root.trayItem) return
            if (event.button === Qt.LeftButton) {
                root.trayItem.activate()
            } else {
                root.trayItem.secondaryActivate()
            }
        }
    }
}
