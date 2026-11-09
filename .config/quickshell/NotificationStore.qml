import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: store
    property bool dnd: false
    property var activeCenter: null
    property var entries: []
    readonly property int unreadCount: entries.filter(entry => entry.unread).length
    readonly property var popups: dnd || activeCenter ? [] : entries.filter(entry => entry.popupVisible).slice(0, 3)

    function markRead() {
        for (const entry of entries) entry.unread = false;
    }
    function remove(entry) {
        if (!entries.includes(entry)) return;
        entry.removing = true;
        if (entry.notification) entry.notification.dismiss();
        entries = entries.filter(item => item !== entry);
        entry.destroy();
    }
    function clear() {
        for (const entry of entries.slice()) remove(entry);
    }
    onDndChanged: {
        if (dnd) for (const entry of entries) entry.popupVisible = false;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        bodyMarkupSupported: false
        onNotification: notification => {
            notification.tracked = true;
            const existing = store.entries.find(entry => entry.notification === notification);
            if (existing) { existing.update(); return; }
            const entry = entryFactory.createObject(store, {notification: notification});
            store.entries = [entry, ...store.entries];
            entry.update();
            // Bound memory usage; no notification contents are written to disk.
            while (store.entries.length > 100) store.remove(store.entries[store.entries.length - 1]);
        }
    }
    Component {
        id: entryFactory
        Scope {
            id: entry
            property var notification: null
            property string appName: ""
            property string summary: ""
            property string body: ""
            property date receivedAt: new Date()
            property bool unread: false
            property bool popupVisible: false
            property bool removing: false
            property bool isTransient: false
            property bool critical: false
            readonly property var actions: notification ? notification.actions : []

            function update() {
                if (!notification) return;
                appName = notification.appName || "Notification";
                summary = notification.summary;
                body = notification.body;
                isTransient = notification.transient;
                critical = notification.urgency === NotificationUrgency.Critical;
                receivedAt = new Date();
                unread = !store.activeCenter && !notification.lastGeneration;
                popupVisible = !store.dnd && !store.activeCenter && !notification.lastGeneration;
                expiry.stop();
                if (notification.expireTimeout !== 0) {
                    expiry.interval = notification.expireTimeout > 0 ? Math.max(1, notification.expireTimeout) : 6000;
                    expiry.restart();
                }
            }
            Timer {
                id: expiry
                onTriggered: {
                    entry.popupVisible = false;
                    if (entry.notification && (entry.isTransient || entry.notification.expireTimeout > 0)) entry.notification.expire();
                }
            }
            Connections {
                target: entry.notification
                function onSummaryChanged() { entry.update(); }
                function onBodyChanged() { entry.update(); }
                function onActionsChanged() { entry.update(); }
                function onClosed(reason) {
                    entry.popupVisible = false;
                    entry.notification = null;
                    expiry.stop();
                    if (entry.isTransient && !entry.removing) store.remove(entry);
                }
            }
        }
    }
}
