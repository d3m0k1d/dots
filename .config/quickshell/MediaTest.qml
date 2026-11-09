//@ pragma UseQApplication
import QtQuick
import Quickshell
import "." as Widgets

ShellRoot {
    id: test
    property int failures: 0
    function check(value, label) {
        console.log(value ? "PASS:" : "FAIL:", label);
        if (!value) failures++;
    }
    QtObject {
        id: paused
        property string dbusName: "test.paused"
        property string identity: "Paused player"
        property bool isPlaying: false
        property bool positionSupported: false
        property real position: 0
        signal trackChanged()
    }
    QtObject {
        id: playing
        property string dbusName: "test.playing"
        property string identity: "Playing player"
        property bool isPlaying: true
        property bool canTogglePlaying: true
        property bool canControl: true
        property bool canSeek: true
        property bool canGoNext: false
        property bool canGoPrevious: false
        property bool canRaise: false
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool volumeSupported: false
        property bool shuffleSupported: false
        property bool loopSupported: false
        property bool shuffle: false
        property int loopState: 0
        property int uniqueId: 1
        property real position: 42
        property real length: 180
        property real volume: 0.5
        property string trackTitle: "Test track"
        property string trackArtist: "Test artist"
        property string trackAlbum: "Test album"
        property string trackArtUrl: ""
        signal trackChanged()
    }
    Widgets.MediaController {
        id: controller
        players: []
    }
    Widgets.MediaMenu {
        id: menu
        controller: controller
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            check(controller.player === null, "empty player list");
            controller.players = [paused, playing];
            check(controller.player === playing, "auto prefers playing player");
            controller.selectedPlayer = paused.dbusName;
            check(controller.player === paused, "manual selection overrides auto");
            controller.players = [playing];
            check(controller.player === playing && controller.selectedPlayer === "", "removed player falls back to auto");
            check(menu.formatTime(3661) === "1:01:01" && menu.formatTime(42) === "0:42", "time formatting");
            menu.seekPosition(999);
            check(playing.position === 180, "seek clamps to track length");
            playing.canSeek = false;
            menu.seekPosition(15);
            check(playing.position === 180, "unsupported seeking is blocked");
            console.log("Failures:", failures);
            Qt.exit(failures ? 1 : 0);
        }
    }
}
