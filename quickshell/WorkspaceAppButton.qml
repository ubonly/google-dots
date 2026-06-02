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

    implicitWidth:  52
    implicitHeight: 52

    // ── ПУСТО: точка ─────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        visible: !root.hasWindows
        width:  root.isFocused ? 10 : 6
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
            width:  root.isFocused ? 44 : (mouse.containsMouse ? 40 : 36)
            height: width
            radius: 14
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
            width:  root.isFocused ? 28 : 24
            height: width

            property int attempt: 0
            property var candidates: {
                if (!root.hasWindows) return [];
                var cls = root.windowClass;

                // WM class → icon name aliases (WM class differs from icon name)
                var aliases = {
                    "zen":                    "zen-browser",
                    "Navigator":              "zen-browser",
                    "org.gnome.Nautilus":     "nautilus",
                    "code":                   "code-oss",
                    "Code":                   "code-oss",
                    "Spotify":                "com.spotify.Client",
                    "spotify":                "com.spotify.Client",
                };

                // WM class → direct file path (for apps not in any icon theme)
                var directPaths = {
                    "antigravity": "file:///usr/share/pixmaps/antigravity.png",
                };

                var low = cls.toLowerCase();
                var shr = cls.split('.').pop().toLowerCase();

                // Start with direct path if known
                var res = [];
                if (directPaths[cls])  res.push(directPaths[cls]);
                if (directPaths[low])  res.push(directPaths[low]);

                // Build name variants (alias first)
                var names = [];
                if (aliases[cls]) names.push(aliases[cls]);
                if (aliases[low]) names.push(aliases[low]);
                names.push(cls);
                if (low !== cls)                names.push(low);
                if (shr !== low && shr !== cls) names.push(shr);

                // Deduplicate
                var seen = {};
                var unique = [];
                for (var j = 0; j < names.length; j++) {
                    if (!seen[names[j]]) { seen[names[j]] = true; unique.push(names[j]); }
                }

                // 1st pass: Qt icon theme (system default — hicolor/Adwaita)
                for (var i = 0; i < unique.length; i++) {
                    res.push(Quickshell.iconPath(unique[i]));
                }

                // 2nd pass: direct file search in hicolor / flatpak / pixmaps
                var homeDir = "";
                try { homeDir = Quickshell.env("HOME") || ""; } catch (e) { homeDir = ""; }
                for (var i2 = 0; i2 < unique.length; i2++) {
                    var n = unique[i2];
                    res.push("file:///usr/share/icons/hicolor/scalable/apps/" + n + ".svg");
                    res.push("file:///usr/share/icons/hicolor/256x256/apps/"  + n + ".png");
                    res.push("file:///usr/share/icons/hicolor/48x48/apps/"    + n + ".png");
                    res.push("file:///var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/" + n + ".svg");
                    res.push("file:///var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/"  + n + ".png");
                    if (homeDir.length > 0) {
                        res.push("file://" + homeDir + "/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/" + n + ".svg");
                        res.push("file://" + homeDir + "/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps/"  + n + ".png");
                    }
                    res.push("file:///usr/share/pixmaps/"                     + n + ".png");
                }

                res.push(Quickshell.iconPath("application-x-executable"));
                return res;
            }

            source: (root.hasWindows && candidates.length > 0) ? candidates[attempt] : ""

            onStatusChanged: {
                if (status === Image.Error && attempt < candidates.length - 1)
                    attempt++;
            }

            Connections {
                target: root
                function onWindowClassChanged() { iconImg.attempt = 0; }
            }

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
