// ClipboardPopup.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: clipboardPopup
    property var screenRef
    property bool isOpen: false
    
    screen: screenRef
    
    // Make it a full screen transparent overlay to easily center the popup
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    visible: isOpen
    color: "transparent"
    
    // Palette
    readonly property color bgSolid:       Qt.rgba(0.08, 0.10, 0.15, 0.95)
    readonly property color bgItemHover:   Qt.rgba(1, 1, 1, 0.08)
    readonly property color textPrimary:   Qt.rgba(1, 1, 1, 0.92)
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.50)
    readonly property color borderColor:   Qt.rgba(1, 1, 1, 0.08)
    readonly property color accentColor:   Qt.rgba(0.40, 0.65, 1.0, 1.0)
    
    property var historyData: []
    
    function toggle() {
        isOpen = !isOpen
        if (isOpen) {
            refreshProc.running = true
        }
    }
    
    Process {
        id: refreshProc
        command: ["python3", "/home/ubonly/.config/quickshell/cliphist.py"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    clipboardPopup.historyData = JSON.parse(line)
                } catch(e) {
                    console.log("Error parsing cliphist JSON")
                }
            }
        }
    }
    
    // Restore item
    function restoreItem(id, type) {
        var cmd = ""
        if (type === "file") {
            cmd = "echo '" + id + "' | cliphist decode | wl-copy --type text/uri-list"
        } else {
            cmd = "echo '" + id + "' | cliphist decode | wl-copy"
        }
        
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
        proc.command = ["bash", "-c", cmd]
        proc.running = true
        clipboardPopup.isOpen = false
    }
    
    // Delete item
    function deleteItem(id) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', clipboardPopup)
        proc.command = ["bash", "-c", "echo '" + id + "' | cliphist delete"]
        proc.running = true
        // refresh slightly after deletion
        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 100; running: true; onTriggered: refreshProc.running = true }', clipboardPopup)
    }

    Item {
        id: focusCatcher
        focus: clipboardPopup.isOpen
        Keys.onEscapePressed: clipboardPopup.isOpen = false
    }

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: 360
        height: Math.min(500, Math.max(150, listContainer.implicitHeight + 80))
        radius: 20
        color: clipboardPopup.bgSolid
        border.color: clipboardPopup.borderColor
        border.width: 1
        clip: true
        
        // Entrance animation
        scale: clipboardPopup.isOpen ? 1.0 : 0.95
        opacity: clipboardPopup.isOpen ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    text: "Clipboard"
                    font.family: "chillax"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: clipboardPopup.textPrimary
                }
            }
            
            // List
            ScrollView {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4
                    model: clipboardPopup.historyData
                    
                    delegate: Rectangle {
                        width: listView.width
                        height: modelData.type === "image" ? 100 : 64
                        radius: 12
                        color: mouseArea.containsMouse ? clipboardPopup.bgItemHover : "transparent"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            
                            // Icon based on type
                            Text {
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                color: clipboardPopup.textSecondary
                                text: {
                                    if (modelData.type === "image") return "\ue3f4" // image
                                    if (modelData.type === "file") return "\ue24d"  // file_copy
                                    if (modelData.preview.startsWith("http")) return "\ue157" // link
                                    return "\ue0b6" // notes/text
                                }
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            // Content
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                // Text/File preview
                                ColumnLayout {
                                    anchors.fill: parent
                                    visible: modelData.type !== "image"
                                    spacing: 2
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.type === "file" ? modelData.filename : modelData.preview
                                        font.family: "chillax"
                                        font.pixelSize: 14
                                        color: clipboardPopup.textPrimary
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }
                                    
                                    Text {
                                        visible: modelData.type === "file"
                                        text: "File"
                                        font.family: "chillax"
                                        font.pixelSize: 11
                                        color: clipboardPopup.textSecondary
                                    }
                                }
                                
                                // Image thumbnail
                                Rectangle {
                                    anchors.fill: parent
                                    visible: modelData.type === "image"
                                    radius: 8
                                    color: "transparent"
                                    clip: true
                                    
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.type === "image" ? modelData.imagePath : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                            }
                            
                            // Delete Button
                            Rectangle {
                                width: 28; height: 28
                                radius: 14
                                color: delMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.2) : "transparent"
                                visible: mouseArea.containsMouse
                                Layout.alignment: Qt.AlignVCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 18
                                    color: delMouse.containsMouse ? "#ff5555" : clipboardPopup.textSecondary
                                    text: "\ue5cd" // close
                                }
                                
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: clipboardPopup.deleteItem(modelData.id)
                                }
                            }
                        }
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            // Don't trigger copy if clicking delete button
                            onClicked: (mouse) => {
                                // The delete button's MouseArea is above this one, 
                                // so this won't fire if delete is clicked.
                                clipboardPopup.restoreItem(modelData.id, modelData.type)
                            }
                            z: -1
                        }
                    }
                }
            }
            
            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: clipboardPopup.historyData.length === 0
                
                Text {
                    anchors.centerIn: parent
                    text: "No items in clipboard"
                    font.family: "chillax"
                    font.pixelSize: 14
                    color: clipboardPopup.textSecondary
                }
            }
        }
    }
}
