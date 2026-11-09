//@ pragma UseQApplication
import QtQuick
import Quickshell
import "." as Widgets

ShellRoot {
    property int failures: 0
    function check(value, label) {
        console.log(value ? "PASS:" : "FAIL:", label);
        if (!value) failures++;
    }
    PanelWindow {
        id: bar
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 40
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        Item { id: trigger; x: 0; y: 5; width: 20; height: 30 }
    }
    Widgets.PanelMenu {
        id: menu
        screen: bar.screen
        barWindow: bar
        anchorItem: trigger
        contentHeight: 10000
    }
    Timer {
        interval: 150
        running: true
        onTriggered: {
            const shell = Qt.createComponent(Qt.resolvedUrl("shell.qml"));
            check(shell.status === Component.Ready, "full shell compiles: " + shell.errorString());
            menu.updatePlacement();
            check(menu.margins.left === 8, "left edge clamped");
            check(menu.margins.top === bar.height, "directly below bar");
            check(menu.height <= 480, "height capped");
            trigger.x = 500;
            Qt.callLater(() => {
                check(menu.margins.left === Math.round(510 - menu.width / 2), "follows icon movement");
                trigger.x = bar.width - 20;
                Qt.callLater(() => {
                    check(menu.margins.left + menu.width <= bar.width - 8, "right edge clamped");
                    menu.preferredWidth = bar.width * 2;
                    Qt.callLater(() => {
                        check(menu.width <= bar.width - 16, "oversized menu fits screen");
                        console.log("Failures:", failures);
                        Qt.exit(failures ? 1 : 0);
                    });
                });
            });
        }
    }
}
