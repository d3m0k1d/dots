import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

PanelMenu {
    id: menu
    contentHeight: body.implicitHeight

    property string section: "output"
    property string trigger: "output"
    property bool allowBoost: false
    property bool fullMixerAvailable: false
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink)
    readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && !node.isSink)
    readonly property var streams: Pipewire.nodes.values.filter(node => node.audio && node.isStream)

    function toggle(page) {
        if (visible && section === page) visible = false;
        else { trigger = page; section = page; visible = true; }
    }
    onSectionChanged: scrollArea.contentY = 0

    PwObjectTracker { objects: menu.visible ? Pipewire.nodes.values : [] }
    AudioRoutes { id: routes; active: menu.visible && menu.section === "apps" }

    component Label: MenuLabel {}
    component Button: MenuButton {}
    component AudioRow: Column {
        id: row
        required property var node
        property bool showTargets: false
        readonly property var route: routes.snapshot.streams[String(node.id)] ?? null
        readonly property bool isDefault: !node.isStream && node === (node.isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource)
        spacing: 6
        Label {
            width: parent.width
            text: (row.isDefault ? "✓ " : "") + (row.node.description || row.node.nickname || row.node.name)
        }
        Label {
            width: parent.width
            color: "#aaaaaa"
            font.pixelSize: 12
            text: row.node.isStream ? (row.node.isSink ? "Recording stream" : "Playback stream")
                : row.isDefault ? "Default device" : "Available device"
        }
        Button {
            visible: !row.node.isStream
            width: parent.width
            text: row.isDefault ? "Selected" : "Use this device"
            enabled: row.node.ready && !row.isDefault
            onClicked: {
                if (row.node.isSink) Pipewire.preferredDefaultAudioSink = row.node;
                else Pipewire.preferredDefaultAudioSource = row.node;
            }
        }
        Row {
            width: parent.width
            spacing: 10
            Button {
                width: 80
                text: row.node.audio?.muted ? "Unmute" : "Mute"
                enabled: row.node.ready
                onClicked: row.node.audio.muted = !row.node.audio.muted
            }
            Label {
                width: parent.width - 90
                height: 36
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round((row.node.audio?.volume ?? 0) * 100) + "%"
            }
        }
        Controls.Slider {
            id: volumeSlider
            width: parent.width
            height: 26
            from: 0
            to: menu.allowBoost ? 1.5 : 1
            stepSize: 0.01
            enabled: row.node.ready
            value: row.node.audio?.volume ?? 0
            onMoved: row.node.audio.volume = value
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: volumeSlider.availableWidth
                height: 4
                color: "#303030"
                radius: 2
                Rectangle { width: volumeSlider.visualPosition * parent.width; height: parent.height; color: "white"; radius: 2 }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: 12
                height: 12
                radius: 6
                color: volumeSlider.pressed ? "#bbbbbb" : "white"
            }
        }
        Column {
            width: parent.width
            visible: row.node.isStream
            spacing: 6
            Label {
                width: parent.width
                visible: (row.node.properties["media.name"] ?? "").length > 0
                text: row.node.properties["media.name"] ?? ""
                color: "#aaaaaa"
                font.pixelSize: 12
            }
            Button {
                width: parent.width
                enabled: routes.available && row.route !== null && !routes.busy
                text: row.route ? (row.route.direction === "output" ? "Output: " : "Input: ") + row.route.targetName + "  ▾" : "Routing unavailable for this stream"
                onClicked: row.showTargets = !row.showTargets
            }
            Column {
                width: parent.width
                spacing: 6
                visible: row.showTargets && row.route !== null
                Repeater {
                    model: row.route ? routes.snapshot.devices[row.route.direction] : []
                    Button {
                        required property var modelData
                        width: parent.width
                        enabled: !routes.busy && modelData.serial.length > 0
                        text: (modelData.index === row.route?.target ? "✓ " : "") + modelData.description
                        onClicked: {
                            routes.move(row.node.id, modelData);
                            row.showTargets = false;
                        }
                    }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: "#202020" }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        radius: 15
        focus: true
        Keys.onEscapePressed: menu.visible = false
        Flickable {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            contentHeight: body.implicitHeight
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: MenuScrollBar {
                id: scrollbar
            }
            Column {
                id: body
                width: scrollArea.width - (scrollbar.visible ? 16 : 0)
                spacing: 12
                Row {
                    width: parent.width
                    Label { text: "Sound"; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    Button { text: "×"; width: 36; onClicked: menu.visible = false }
                }
                Row {
                    width: parent.width
                    spacing: 6
                    Button { width: (parent.width - 12) / 3; text: (menu.section === "output" ? "✓ " : "") + "Output"; onClicked: menu.section = "output" }
                    Button { width: (parent.width - 12) / 3; text: (menu.section === "input" ? "✓ " : "") + "Input"; onClicked: menu.section = "input" }
                    Button { width: (parent.width - 12) / 3; text: (menu.section === "apps" ? "✓ " : "") + "Apps"; onClicked: menu.section = "apps" }
                }
                Label {
                    width: parent.width
                    text: !Pipewire.ready ? "Waiting for PipeWire…" : menu.section === "output" ? "Playback devices"
                        : menu.section === "input" ? "Microphones / capture devices" : "Application mixer"
                }
                Label {
                    width: parent.width
                    visible: menu.section === "apps" && routes.message.length > 0
                    text: routes.message
                    font.pixelSize: 12
                }
                Repeater {
                    model: menu.section === "output" ? menu.outputs : menu.section === "input" ? menu.inputs : menu.streams
                    AudioRow {
                        required property var modelData
                        width: body.width
                        node: modelData
                    }
                }
                Label {
                    width: parent.width
                    visible: Pipewire.ready && (menu.section === "output" ? menu.outputs.length === 0 : menu.section === "input" ? menu.inputs.length === 0 : menu.streams.length === 0)
                    text: menu.section === "apps" ? "No application audio streams. Start playback or recording to see them here." : "No audio devices available."
                    color: "#aaaaaa"
                }
                Button {
                    width: parent.width
                    text: (menu.allowBoost ? "[✓] " : "[ ] ") + "Allow amplification up to 150%"
                    onClicked: menu.allowBoost = !menu.allowBoost
                }
                Label {
                    visible: menu.allowBoost
                    width: parent.width
                    text: "Above 100% may cause clipping and loud audio."
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }
                Button {
                    width: parent.width
                    text: menu.fullMixerAvailable ? "Full mixer / ports / card profiles…" : "Full mixer: install pavucontrol"
                    enabled: menu.fullMixerAvailable
                    onClicked: {
                        menu.visible = false;
                        Quickshell.execDetached(["pavucontrol"]);
                    }
                }
                Label {
                    width: parent.width
                    text: "Apps routing changes only the selected live stream, not system defaults. Native PipeWire/JACK streams may require a patchbay. Use the full mixer for device ports and card profiles."
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }
            }
        }
    }
}
