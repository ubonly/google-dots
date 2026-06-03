// NotificationCard.qml — ChromeOS / Material You notification card
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: card

    // notification data (set from delegate)
    property var    notification: null
    property string appName:      notification ? (notification.appName  || "Notification") : "Notification"
    property string summary:      notification ? (notification.summary  || "")             : ""
    property string bodyText:     notification ? (notification.body     || "")             : ""
    property string appIcon:      notification ? (notification.appIcon  || "")             : ""
    property var    notifTime:    notification ? notification.time : new Date()

    // collapsed by default
    property bool expanded: false

    // mocha palette
    readonly property color cBg:        "#1c1c1f"
    readonly property color cBgHover:   "#26262a"
    readonly property color cIconBg:    "#3a3a3d"
    readonly property color cTextDim:   "#a8a8ad"
    readonly property color cTextBody:  "#c8c8cc"
    readonly property color cTextTitle: "#ffffff"

    // container — height animates smoothly
    implicitHeight: cardLayout.implicitHeight + 28
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    radius: 20
    color: cBg
    border.color: Qt.rgba(1, 1, 1, 0.04)
    border.width: 1
    clip: true

    // fade-in animation when added to listview
    opacity: 0
    transform: Translate { id: slideIn; y: -12 }
    Component.onCompleted: {
        opacity = 1
        slideIn.y = 0
        dismissTimer.start()
    }
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // autodismiss with hover pause
    Timer {
        id: dismissTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (card.notification) card.notification.tracked = false
        }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                dismissTimer.stop()
            } else {
                dismissTimer.interval = 1000
                dismissTimer.restart()
            }
        }
    }

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        // header row — always visible
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // app icon (round)
            Rectangle {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                radius: 9
                color: card.cIconBg
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: card.appIcon
                    sourceSize.width:  32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source.toString().length > 0 && status === Image.Ready
                }
            }

            // app name
            Text {
                text: card.appName
                color: card.cTextDim
                font { pixelSize: 12; family: "Google Sans"; weight: Font.Medium }
                elide: Text.ElideRight
                Layout.maximumWidth: 120
            }

            // dot separator
            Text { text: "•"; color: card.cTextDim; font.pixelSize: 12 }

            // when collapsed: show summary text inline (sender / message title)
            Text {
                text: card.summary
                color: card.cTextTitle
                font { pixelSize: 12; family: "Google Sans"; weight: Font.Medium }
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: !card.expanded
            }

            // spacer — only when expanded (pushes time and chevron right)
            Item { Layout.fillWidth: true; visible: card.expanded }

            // time
            Text {
                text: card._formatTime(card.notifTime)
                color: card.cTextDim
                font { pixelSize: 12; family: "Google Sans" }
            }

            // chevron button — rotates: ∧ expanded, ∨ collapsed
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: chevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Image {
                    id: chevIcon
                    anchors.centerIn: parent
                    width: 14; height: 14
                    sourceSize: Qt.size(14, 14)
                    source: "assets/icons/expand-less.svg"
                    smooth: true
                    visible: false
                    rotation: card.expanded ? 0 : 180
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                ColorOverlay {
                    anchors.fill: chevIcon
                    source: chevIcon
                    color: card.cTextDim
                    rotation: card.expanded ? 0 : 180
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: chevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.expanded = !card.expanded
                }
            }
        }

        // expanded body
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 2
            visible: card.expanded
            opacity: card.expanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            // summary (title)
            Text {
                Layout.fillWidth: true
                text: card.summary
                color: card.cTextTitle
                font { pixelSize: 14; family: "Google Sans"; weight: Font.Bold }
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                visible: text.length > 0
            }

            // body
            Text {
                Layout.fillWidth: true
                text: card.bodyText
                color: card.cTextBody
                font { pixelSize: 13; family: "Google Sans" }
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                visible: text.length > 0
            }
        }
    }

    // helpers
    function _formatTime(t) {
        if (!t) return "now"
        var now = new Date()
        var diffSec = Math.floor((now.getTime() - t.getTime()) / 1000)
        if (diffSec < 60)    return "now"
        if (diffSec < 3600)  return Math.floor(diffSec / 60)   + "m"
        if (diffSec < 86400) return Math.floor(diffSec / 3600) + "h"
        return Qt.formatDateTime(t, "HH:mm")
    }
}
