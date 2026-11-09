//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Widgets

ShellRoot {
    Widgets.NotificationStore { id: store }
    property int failures: 0
    function check(condition, label) {
        console.log(condition ? "PASS:" : "FAIL:", label);
        if (!condition) failures++;
    }
    Process { id: sender }
    Timer { interval: 300; running: true; onTriggered: sender.exec(["notify-send", "-t", "400", "Expiry test", "Archive after timeout"]) }
    Timer {
        interval: 1000; running: true
        onTriggered: {
            check(store.entries.length === 1 && store.entries[0].notification === null, "expired notification retained as archive");
            sender.exec(["notify-send", "-t", "0", "--action=test=Test action", "Action test", "Persistent entry"]);
        }
    }
    Timer {
        interval: 1600; running: true
        onTriggered: {
            check(store.entries.length === 2 && store.unreadCount === 2, "history and unread count");
            if (store.entries.length < 2) { Qt.exit(1); return; }
            check(store.entries[0].actions.length === 1, "application action available");
            if (store.entries[0].actions.length === 0) { Qt.exit(1); return; }
            store.entries[0].actions[0].invoke();
            if (store.entries[0].notification) store.entries[0].notification.dismiss();
            store.dnd = true;
            sender.exec(["notify-send", "DND test", "Quiet history"]);
        }
    }
    Timer {
        interval: 2200; running: true
        onTriggered: {
            check(store.entries.length === 3 && store.popups.length === 0, "DND stores without popups");
            store.markRead();
            check(store.unreadCount === 0, "mark read");
            store.clear();
            check(store.entries.length === 0, "clear history");
            console.log("Failures:", failures);
            Qt.exit(failures > 0 ? 1 : 0);
        }
    }
}
