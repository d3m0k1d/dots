import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

PanelMenu {
    id: menu
    required property var controller
    readonly property var player: controller.player
    property real position: 0
    property bool showPlayers: false
    contentHeight: body.implicitHeight

    function toggle() { visible = !visible; }
    function formatTime(seconds) {
        const time = Math.max(0, Math.floor(Number(seconds) || 0));
        const hours = Math.floor(time / 3600);
        const minutes = Math.floor(time / 60) % 60;
        return (hours ? hours + ":" + String(minutes).padStart(2, "0") : String(minutes)) + ":" + String(time % 60).padStart(2, "0");
    }
    function updatePosition() { position = player?.positionSupported ? player.position : 0; }
    function seekPosition(seconds) {
        if (player?.canSeek && player.positionSupported && player.lengthSupported && player.length > 0)
            player.position = Math.max(0, Math.min(player.length, seconds));
    }
    onPlayerChanged: { updatePosition(); scrollArea.contentY = 0; }
    onVisibleChanged: { if (visible) updatePosition(); }
    Timer {
        interval: 1000
        running: menu.visible && (menu.player?.isPlaying ?? false) && (menu.player?.positionSupported ?? false)
        repeat: true
        onTriggered: menu.updatePosition()
    }
    Connections {
        target: menu.player
        function onPositionChanged() { menu.updatePosition(); }
        function onTrackChanged() { menu.updatePosition(); }
    }
    component Label: MenuLabel {}
    component Button: MenuButton { textAlignment: Text.AlignHCenter }
    component Slider: Controls.Slider {
        id: slider
        height: 26
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: "#303030"
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: "white" }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 12
            height: 12
            radius: 6
            color: slider.pressed ? "#bbbbbb" : "white"
        }
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
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: MenuScrollBar {
                id: scrollbar
            }
            Column {
                id: body
                width: scrollArea.width - (scrollbar.visible ? 16 : 0)
                spacing: 10
                Row {
                    width: parent.width
                    Label { text: "Media"; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    Button { text: "×"; width: 36; onClicked: menu.visible = false }
                }
                Button {
                    width: parent.width
                    text: (menu.controller.selectedPlayer ? "Player: " : "Auto: ") + (menu.player?.identity ?? "none") + "  ▾"
                    onClicked: menu.showPlayers = !menu.showPlayers
                }
                Column {
                    width: parent.width
                    spacing: 6
                    visible: menu.showPlayers
                    Button { width: parent.width; text: "Automatic · prefer playing"; onClicked: { menu.controller.selectedPlayer = ""; menu.showPlayers = false; } }
                    Repeater {
                        model: menu.controller.players
                        Button {
                            required property var modelData
                            width: parent.width
                            text: (menu.player === modelData ? "✓ " : "") + modelData.identity
                            onClicked: { menu.controller.selectedPlayer = modelData.dbusName; menu.showPlayers = false; }
                        }
                    }
                }
                Label {
                    width: parent.width
                    visible: !menu.player
                    text: "No media players detected. Start music or video in a player with MPRIS support."
                    color: "#aaaaaa"
                }
                Column {
                    width: parent.width
                    spacing: 10
                    visible: menu.player !== null
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: 96
                            height: 96
                            color: "#101010"
                            radius: 10
                            clip: true
                            Label { anchors.centerIn: parent; text: "󰎆"; font.pixelSize: 32; visible: cover.status !== Image.Ready }
                            Image {
                                id: cover
                                anchors.fill: parent
                                source: menu.visible && /^(file:|https:|data:image\/)/.test(menu.player?.trackArtUrl ?? "") ? menu.player.trackArtUrl : ""
                                sourceSize.width: 192
                                sourceSize.height: 192
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                mipmap: true
                            }
                        }
                        Column {
                            width: parent.width - 108
                            spacing: 6
                            Label { width: parent.width; text: menu.player?.trackTitle || "Unknown track"; font.bold: true; maximumLineCount: 3; elide: Text.ElideRight }
                            Label { width: parent.width; text: menu.player?.trackArtist ?? ""; color: "#aaaaaa"; maximumLineCount: 2; elide: Text.ElideRight }
                            Label { width: parent.width; text: menu.player?.trackAlbum ?? ""; color: "#aaaaaa"; font.pixelSize: 12; maximumLineCount: 1; elide: Text.ElideRight }
                        }
                    }
                    Slider {
                        id: seek
                        property var dragPlayer: null
                        property int dragTrack: -1
                        width: parent.width
                        from: 0
                        to: Math.max(1, menu.player?.length ?? 0)
                        value: menu.position
                        stepSize: 1
                        enabled: (menu.player?.canSeek ?? false) && (menu.player?.positionSupported ?? false) && (menu.player?.lengthSupported ?? false) && menu.player.length > 0
                        onPressedChanged: {
                            if (pressed) { dragPlayer = menu.player; dragTrack = menu.player.uniqueId; }
                            else if (dragPlayer === menu.player && dragTrack === menu.player?.uniqueId) menu.seekPosition(value);
                        }
                        onMoved: { if (!pressed) menu.seekPosition(value); }
                    }
                    Label {
                        width: parent.width
                        text: (menu.player?.positionSupported ? menu.formatTime(seek.pressed ? seek.value : menu.position) : "--:--") + " / "
                            + (menu.player?.lengthSupported ? menu.formatTime(menu.player.length) : "--:--")
                        color: "#aaaaaa"
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        Button { width: (parent.width - 16) / 3; text: "󰒮"; enabled: menu.player?.canGoPrevious ?? false; onClicked: menu.player.previous() }
                        Button { width: (parent.width - 16) / 3; text: menu.player?.isPlaying ? "Pause" : "Play"; enabled: menu.player?.canTogglePlaying ?? false; onClicked: menu.player.togglePlaying() }
                        Button { width: (parent.width - 16) / 3; text: "󰒭"; enabled: menu.player?.canGoNext ?? false; onClicked: menu.player.next() }
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        Button {
                            width: (parent.width - 8) / 2
                            text: (menu.player?.shuffle ? "✓ " : "") + "Shuffle"
                            enabled: (menu.player?.canControl ?? false) && (menu.player?.shuffleSupported ?? false)
                            onClicked: menu.player.shuffle = !menu.player.shuffle
                        }
                        Button {
                            width: (parent.width - 8) / 2
                            text: "Loop: " + (menu.player ? MprisLoopState.toString(menu.player.loopState) : "None")
                            enabled: (menu.player?.canControl ?? false) && (menu.player?.loopSupported ?? false)
                            onClicked: menu.player.loopState = menu.player.loopState === MprisLoopState.None ? MprisLoopState.Track : menu.player.loopState === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None
                        }
                    }
                    Label { visible: menu.player?.volumeSupported ?? false; text: "Player volume · " + Math.round((menu.player?.volume ?? 0) * 100) + "%" }
                    Slider {
                        visible: menu.player?.volumeSupported ?? false
                        width: parent.width
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: menu.player?.volume ?? 0
                        enabled: menu.player?.canControl ?? false
                        onMoved: menu.player.volume = value
                    }
                    Button {
                        width: parent.width
                        text: "Open player"
                        enabled: menu.player?.canRaise ?? false
                        onClicked: { menu.visible = false; menu.player.raise(); }
                    }
                }
            }
        }
    }
}
