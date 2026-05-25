// SettingsWindow.qml — ChromeOS-style System Settings
// Two-pane layout: left sidebar navigation + right content area.
// Catppuccin Mocha palette, Material Symbols SVG icons.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: settingsRoot
    property var  screenRef
    property bool settingsVisible: false

    screen: screenRef
    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: settingsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: settingsVisible

    // ══════════════════════════════════════════════════════════════════════
    //  PALETTE
    // ══════════════════════════════════════════════════════════════════════
    readonly property color bgColor:       "#0d0d14"
    readonly property color cardBg:        "#1e1e2e"
    readonly property color activeItem:    "#cba6f7"
    readonly property color activeBg:      "#3b2d5e"
    readonly property color textPrimary:   "#cdd6f4"
    readonly property color textSecondary: "#6c7086"
    readonly property color dividerColor:  Qt.rgba(1,1,1,0.06)
    readonly property color searchBg:      "#313244"
    readonly property color switchOnColor: "#cba6f7"
    readonly property color switchOffColor:"#45475a"
    readonly property color switchKnob:    "#cdd6f4"

    // ══════════════════════════════════════════════════════════════════════
    //  STATE
    // ══════════════════════════════════════════════════════════════════════
    property int  currentPage: 0
    property bool wifiEnabled: true
    property bool mobileData: false

    property string wifiSSID:   "..."
    property int    wifiSignal: 0
    property bool   wifiOn:     true

    Process { id: wifiCheck; running: false
        command: ["bash","-c","nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '/^yes/{print $2\"|\"$3;exit}'"]
        stdout: SplitParser { onRead: function(l){
            var p = l.trim().split("|")
            if (p.length >= 1 && p[0] !== "") {
                settingsRoot.wifiSSID = p[0]
                settingsRoot.wifiSignal = parseInt(p[1]) || 0
                settingsRoot.wifiOn = true
            } else {
                settingsRoot.wifiSSID = "Not connected"
                settingsRoot.wifiSignal = 0
                settingsRoot.wifiOn = false
            }
        }}
    }
    Process { id: settingsCmdProc; command: []; running: false
        onRunningChanged: { if (!running) wifiCheck.running = true }
    }
    Timer { interval: 5000; repeat: true; running: settingsRoot.settingsVisible; onTriggered: wifiCheck.running = true }
    onSettingsVisibleChanged: { if (settingsVisible) { currentPage = 0; wifiCheck.running = true } }

    // ══════════════════════════════════════════════════════════════════════
    //  HELPER: SVG icon with color overlay
    // ══════════════════════════════════════════════════════════════════════
    component SvgIcon: Item {
        property string iconSource: ""
        property color  iconColor:  settingsRoot.textPrimary
        property int    iconSize:   20

        implicitWidth: iconSize; implicitHeight: iconSize

        Image {
            id: _svgImg
            anchors.fill: parent
            source: iconSource
            sourceSize: Qt.size(parent.width, parent.height)
            visible: false
        }
        ColorOverlay {
            anchors.fill: _svgImg
            source: _svgImg
            color: parent.iconColor
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  INLINE COMPONENTS
    // ══════════════════════════════════════════════════════════════════════

    // ── SettingsRow ─────────────────────────────────────────────────────
    component SettingsRow: Rectangle {
        id: srow
        property string iconSource: ""
        property string title:     ""
        property string subtitle:  ""
        property bool   hasSwitch: false
        property bool   switchVal: false
        property bool   hasChevron: false
        property bool   showDivider: true
        signal switchToggled()
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 60
        color: rowArea.containsMouse ? Qt.rgba(1,1,1,0.03) : "transparent"
        radius: 12
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                color: Qt.rgba(1,1,1,0.06)
                SvgIcon {
                    anchors.centerIn: parent
                    iconSource: srow.iconSource; iconSize: 20
                    iconColor: settingsRoot.textPrimary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    text: srow.title; font.pixelSize: 13
                    font.family: "Google Sans"; font.weight: Font.Medium
                    color: settingsRoot.textPrimary
                }
                Text {
                    text: srow.subtitle; font.pixelSize: 11
                    font.family: "Google Sans"
                    color: settingsRoot.textSecondary
                    visible: srow.subtitle !== ""
                }
            }

            SvgIcon {
                visible: srow.hasChevron
                iconSource: "assets/icons/chevron-right.svg"
                iconSize: 20; iconColor: settingsRoot.textSecondary
            }

            Rectangle {
                visible: srow.hasSwitch
                implicitWidth: 44; implicitHeight: 24; radius: 12
                color: srow.switchVal ? settingsRoot.switchOnColor : settingsRoot.switchOffColor
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: srow.switchVal ? parent.width - width - 3 : 3
                    color: settingsRoot.switchKnob
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: srow.switchToggled()
                }
            }
        }

        Rectangle {
            visible: srow.showDivider
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                      leftMargin: 66; rightMargin: 16 }
            height: 1; color: settingsRoot.dividerColor
        }

        MouseArea {
            id: rowArea; anchors.fill: parent; z: -1
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: srow.clicked()
        }
    }

    // ── NavItem ─────────────────────────────────────────────────────────
    component NavItem: Rectangle {
        id: navItem
        property string navIconSource: ""
        property string navTitle: ""
        property string navSub:   ""
        property int    navIndex: 0
        property bool   isActive: settingsRoot.currentPage === navIndex

        Layout.fillWidth: true
        implicitHeight: 48
        radius: 14
        color: isActive ? settingsRoot.activeBg
             : (navMA.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 10

            SvgIcon {
                iconSource: navItem.navIconSource; iconSize: 20
                iconColor: navItem.isActive ? settingsRoot.activeItem : settingsRoot.textPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text {
                    text: navItem.navTitle
                    font.pixelSize: 13; font.family: "Google Sans"
                    font.weight: Font.Medium
                    color: navItem.isActive ? settingsRoot.activeItem : settingsRoot.textPrimary
                }
                Text {
                    text: navItem.navSub
                    font.pixelSize: 10; font.family: "Google Sans"
                    color: navItem.isActive
                        ? Qt.rgba(0.80, 0.65, 0.97, 0.70)
                        : settingsRoot.textSecondary
                    visible: navItem.navSub !== ""
                }
            }
        }

        MouseArea {
            id: navMA; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: settingsRoot.currentPage = navItem.navIndex
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  MAIN LAYOUT
    // ══════════════════════════════════════════════════════════════════════

    // Click-away to close
    MouseArea {
        anchors.fill: parent
        onClicked: settingsRoot.settingsVisible = false
    }

    // Escape to close
    Keys.onEscapePressed: settingsRoot.settingsVisible = false

    Rectangle {
        id: mainWindow
        anchors.centerIn: parent
        width:  Math.min(parent.width - 80, 920)
        height: Math.min(parent.height - 100, 620)
        radius: 20
        color:  settingsRoot.bgColor
        border.color: Qt.rgba(1,1,1,0.06)
        border.width: 1

        // Prevent click-through to dismiss area
        MouseArea { anchors.fill: parent }

        // ── Window close button ──────────────────────────────────────────
        Rectangle {
            z: 10
            anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 12 }
            width: 28; height: 28; radius: 14
            color: closeBtnMA.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            SvgIcon {
                anchors.centerIn: parent
                iconSource: "assets/icons/close.svg"
                iconSize: 16; iconColor: settingsRoot.textPrimary
            }
            MouseArea {
                id: closeBtnMA; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: settingsRoot.settingsVisible = false
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ══════════════════════════════════════════════════════════════
            //  LEFT SIDEBAR
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: "transparent"

                Flickable {
                    anchors {
                        fill: parent
                        topMargin: 16; leftMargin: 12
                        rightMargin: 8; bottomMargin: 12
                    }
                    contentHeight: sidebarCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: sidebarCol
                        width: parent.width
                        spacing: 2

                        // Title
                        Text {
                            text: "Settings"
                            font.pixelSize: 20; font.family: "Google Sans"
                            font.weight: Font.Bold
                            color: settingsRoot.activeItem
                            Layout.leftMargin: 4
                            Layout.bottomMargin: 10
                        }

                        NavItem { navIconSource: "assets/icons/wifi.svg";              navTitle: "Network";             navSub: "Wi-Fi";                        navIndex: 0 }
                        NavItem { navIconSource: "assets/icons/bluetooth.svg";          navTitle: "Bluetooth";           navSub: "On";                           navIndex: 1 }
                        NavItem { navIconSource: "assets/icons/desktop-windows.svg";    navTitle: "Device";              navSub: "Keyboard, mouse, print";       navIndex: 2 }
                        NavItem { navIconSource: "assets/icons/wallpaper.svg";          navTitle: "Wallpaper and style"; navSub: "Dark theme, screen saver";     navIndex: 3 }
                        NavItem { navIconSource: "assets/icons/accessibility.svg";      navTitle: "Accessibility";       navSub: "Screen reader, magnification"; navIndex: 4 }
                        NavItem { navIconSource: "assets/icons/build.svg";              navTitle: "System preferences";  navSub: "Storage, power, language";     navIndex: 5 }
                        NavItem { navIconSource: "assets/icons/info.svg";               navTitle: "About ChromeOS";      navSub: "Updates, help";                navIndex: 6 }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // Vertical separator
            Rectangle {
                Layout.preferredWidth: 1; Layout.fillHeight: true
                Layout.topMargin: 16; Layout.bottomMargin: 16
                color: settingsRoot.dividerColor
            }

            // ══════════════════════════════════════════════════════════════
            //  RIGHT CONTENT AREA
            // ══════════════════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors {
                        fill: parent
                        topMargin: 12; leftMargin: 20
                        rightMargin: 20; bottomMargin: 16
                    }
                    spacing: 14

                    // ── Search bar ────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 440
                        Layout.alignment: Qt.AlignHCenter
                        implicitHeight: 40; radius: 20
                        color: settingsRoot.searchBg

                        RowLayout {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
                            spacing: 10

                            SvgIcon {
                                iconSource: "assets/icons/search.svg"
                                iconSize: 18; iconColor: settingsRoot.textSecondary
                            }
                            Text {
                                text: "Search settings"
                                font.pixelSize: 13; font.family: "Google Sans"
                                color: settingsRoot.textSecondary
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // ── Content card ──────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: settingsRoot.cardBg
                        clip: true

                        Flickable {
                            anchors {
                                fill: parent
                                topMargin: 8; bottomMargin: 8
                                leftMargin: 4; rightMargin: 4
                            }
                            contentHeight: contentCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: contentCol
                                width: parent.width
                                spacing: 0

                                // ═══════════════════════════════════════
                                //  PAGE 0: NETWORK
                                // ═══════════════════════════════════════
                                ColumnLayout {
                                    visible: settingsRoot.currentPage === 0
                                    Layout.fillWidth: true
                                    spacing: 0

                                    // Section title
                                    Text {
                                        text: "Network"
                                        font.pixelSize: 15; font.family: "Google Sans"
                                        font.weight: Font.SemiBold
                                        color: settingsRoot.textPrimary
                                        Layout.leftMargin: 16; Layout.topMargin: 8
                                        Layout.bottomMargin: 12
                                    }

                                    // ── Wi-Fi Hero Card ─────────────────────
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 10; Layout.rightMargin: 10
                                        Layout.bottomMargin: 14
                                        implicitHeight: wifiCardCol.implicitHeight + 28
                                        radius: 16
                                        color: settingsRoot.wifiOn ? settingsRoot.activeBg : Qt.rgba(1,1,1,0.04)
                                        border.color: settingsRoot.wifiOn
                                            ? Qt.rgba(0.80, 0.65, 0.97, 0.20) : Qt.rgba(1,1,1,0.06)
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 180 } }

                                        ColumnLayout {
                                            id: wifiCardCol
                                            anchors {
                                                top: parent.top; topMargin: 14
                                                left: parent.left; leftMargin: 16
                                                right: parent.right; rightMargin: 16
                                            }
                                            spacing: 10

                                            // Top row: icon + info + switch
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 14

                                                Rectangle {
                                                    Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 22
                                                    color: settingsRoot.wifiOn
                                                        ? Qt.rgba(0.80, 0.65, 0.97, 0.20)
                                                        : Qt.rgba(1,1,1,0.06)
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    SvgIcon {
                                                        anchors.centerIn: parent
                                                        iconSource: "assets/icons/wifi.svg"
                                                        iconSize: 24
                                                        iconColor: settingsRoot.wifiOn
                                                            ? settingsRoot.activeItem
                                                            : settingsRoot.textSecondary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        text: "Wi-Fi"
                                                        font.pixelSize: 15; font.family: "Google Sans"
                                                        font.weight: Font.SemiBold
                                                        color: settingsRoot.textPrimary
                                                    }
                                                    Text {
                                                        text: settingsRoot.wifiOn ? settingsRoot.wifiSSID : "Off"
                                                        font.pixelSize: 12; font.family: "Google Sans"
                                                        color: settingsRoot.wifiOn
                                                            ? Qt.rgba(0.80, 0.65, 0.97, 0.85)
                                                            : settingsRoot.textSecondary
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                // Toggle switch
                                                Rectangle {
                                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                                    color: settingsRoot.wifiOn
                                                        ? settingsRoot.switchOnColor
                                                        : settingsRoot.switchOffColor
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    Rectangle {
                                                        width: 20; height: 20; radius: 10
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        x: settingsRoot.wifiOn ? parent.width - width - 3 : 3
                                                        color: settingsRoot.switchKnob
                                                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            settingsCmdProc.command = settingsRoot.wifiOn
                                                                ? ["nmcli", "radio", "wifi", "off"]
                                                                : ["nmcli", "radio", "wifi", "on"]
                                                            settingsCmdProc.running = true
                                                        }
                                                    }
                                                }
                                            }

                                            // Signal bar + details
                                            Rectangle {
                                                visible: settingsRoot.wifiOn
                                                Layout.fillWidth: true
                                                implicitHeight: 32
                                                radius: 8
                                                color: Qt.rgba(0,0,0,0.15)

                                                RowLayout {
                                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                                    spacing: 8

                                                    SvgIcon {
                                                        iconSource: {
                                                            if (settingsRoot.wifiSignal >= 75) return "assets/icons/signal-wifi-4-bar.svg"
                                                            if (settingsRoot.wifiSignal >= 50) return "assets/icons/network-wifi-3-bar.svg"
                                                            if (settingsRoot.wifiSignal >= 25) return "assets/icons/network-wifi-2-bar.svg"
                                                            return "assets/icons/network-wifi-1-bar.svg"
                                                        }
                                                        iconSize: 16
                                                        iconColor: settingsRoot.activeItem
                                                    }

                                                    Text {
                                                        text: "Signal: " + settingsRoot.wifiSignal + "%"
                                                        font.pixelSize: 11; font.family: "Google Sans"
                                                        color: Qt.rgba(0.80, 0.65, 0.97, 0.80)
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    Text {
                                                        text: "Connected"
                                                        font.pixelSize: 11; font.family: "Google Sans"
                                                        font.weight: Font.SemiBold
                                                        color: settingsRoot.activeItem
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── Other network rows ──────────────────
                                    SettingsRow {
                                        iconSource: "assets/icons/lan.svg"; title: "Ethernet"
                                        subtitle: "No network"
                                    }

                                    SettingsRow {
                                        iconSource: "assets/icons/sim-card.svg"; title: "Mobile data"
                                        subtitle: "No network"
                                        hasChevron: true; hasSwitch: true
                                        switchVal: settingsRoot.mobileData
                                        onSwitchToggled: settingsRoot.mobileData = !settingsRoot.mobileData
                                    }

                                    SettingsRow {
                                        iconSource: "assets/icons/vpn-key.svg"; title: "VPN"
                                        subtitle: ""
                                        hasChevron: true
                                        showDivider: false
                                    }

                                    // "Add connection"
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        color: addConnMA.containsMouse ? Qt.rgba(1,1,1,0.03) : "transparent"
                                        radius: 12
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                            spacing: 10

                                            SvgIcon {
                                                iconSource: "assets/icons/add-link.svg"
                                                iconSize: 18; iconColor: settingsRoot.activeItem
                                            }
                                            Text {
                                                text: "Add connection"
                                                font.pixelSize: 13; font.family: "Google Sans"
                                                font.weight: Font.Medium
                                                color: settingsRoot.activeItem
                                                Layout.fillWidth: true
                                            }
                                            SvgIcon {
                                                iconSource: "assets/icons/chevron-right.svg"
                                                iconSize: 16; iconColor: settingsRoot.textSecondary
                                            }
                                        }

                                        MouseArea {
                                            id: addConnMA; anchors.fill: parent
                                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }

                                // ═══════════════════════════════════════
                                //  PAGE 1: BLUETOOTH
                                // ═══════════════════════════════════════
                                ColumnLayout {
                                    visible: settingsRoot.currentPage === 1
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: "Bluetooth"
                                        font.pixelSize: 15; font.family: "Google Sans"
                                        font.weight: Font.SemiBold
                                        color: settingsRoot.textPrimary
                                        Layout.leftMargin: 16; Layout.topMargin: 8
                                        Layout.bottomMargin: 4
                                    }

                                    SettingsRow {
                                        iconSource: "assets/icons/bluetooth.svg"; title: "Bluetooth"
                                        subtitle: "On"; hasSwitch: true
                                        switchVal: true
                                    }
                                    SettingsRow {
                                        iconSource: "assets/icons/add.svg"; title: "Pair new device"
                                        subtitle: ""; showDivider: false
                                    }
                                }

                                // ═══════════════════════════════════════
                                //  PAGES 2+: PLACEHOLDER
                                // ═══════════════════════════════════════
                                ColumnLayout {
                                    visible: settingsRoot.currentPage >= 2
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: {
                                            var titles = ["","","Device","Wallpaper and style",
                                                "Accessibility","System preferences","About ChromeOS"]
                                            return titles[settingsRoot.currentPage] || "Settings"
                                        }
                                        font.pixelSize: 15; font.family: "Google Sans"
                                        font.weight: Font.SemiBold
                                        color: settingsRoot.textPrimary
                                        Layout.leftMargin: 16; Layout.topMargin: 8
                                        Layout.bottomMargin: 4
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 120

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Coming soon"
                                            font.pixelSize: 13; font.family: "Google Sans"
                                            font.italic: true
                                            color: Qt.rgba(1,1,1,0.18)
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
}
