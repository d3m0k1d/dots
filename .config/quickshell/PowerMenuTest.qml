//@ pragma UseQApplication
import QtQuick
import Quickshell
import "." as Widgets

ShellRoot {
    property int failures: 0
    property var recorded: []
    function check(value, label) {
        console.log(value ? "PASS:" : "FAIL:", label);
        if (!value) failures++;
    }
    Widgets.PowerMenu {
        id: menu
        executor: action => { recorded = [...recorded, action]; }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            check(recorded.length === 0, "rendering does not execute actions");
            for (const action of ["suspend", "logout", "reboot", "poweroff"]) {
                menu.requestAction(action);
                check(menu.pending === action && recorded.length === 0, action + " requires confirmation");
                menu.pending = "";
            }
            menu.requestAction("poweroff");
            menu.confirm();
            check(recorded.length === 1 && recorded[0] === "poweroff", "confirmation invokes injected recorder only");
            menu.confirm();
            check(recorded.length === 1, "confirmation is one-shot");
            menu.requestAction("invalid");
            check(recorded.length === 1 && menu.pending === "", "invalid action rejected");
            menu.visible = true;
            menu.requestAction("reboot");
            menu.visible = false;
            check(menu.pending === "" && recorded.length === 1, "closing cancels confirmation");
            menu.requestAction("lock");
            check(recorded.length === 2 && recorded[1] === "lock", "lock invokes recorder without shutdown confirmation");
            console.log("Failures:", failures);
            Qt.exit(failures ? 1 : 0);
        }
    }
}
