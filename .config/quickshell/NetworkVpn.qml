import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: view
    property bool active: false
    property var profiles: []
    property var otherTunnels: []
    property bool editorAvailable: false
    property bool healthy: false
    property string message: ""
    property string operation: ""
    property var pending: null
    readonly property bool busy: worker.running
    signal back()
    signal externalWindowRequested()
    spacing: 10

    function request(action, payload) {
        if (busy) return;
        if (action !== "list") message = "";
        operation = action;
        worker.result = "";
        worker.command = ["python3", Quickshell.shellPath("vpn.py"), action, JSON.stringify(payload)];
        worker.running = true;
    }
    function openEditor(uuid) {
        if (!editorAvailable) return;
        externalWindowRequested();
        Quickshell.execDetached(uuid ? ["nm-connection-editor", "--edit=" + uuid] : ["nm-connection-editor"]);
    }
    onActiveChanged: {
        pending = null;
        if (active) request("list", {});
    }
    Timer {
        interval: 5000
        running: view.active
        repeat: true
        onTriggered: view.request("list", {})
    }
    Process {
        id: worker
        property string result: ""
        stdout: SplitParser { onRead: data => worker.result = data }
        onExited: (exitCode, exitStatus) => {
            const completed = view.operation;
            try {
                const response = JSON.parse(result);
                if (!response.ok) {
                    if (completed === "list") view.healthy = false;
                    view.message = response.error + (completed === "up" ? "\nIf credentials are required, configure them using the profile editor / a NetworkManager secret agent." : "");
                    return;
                }
                if (response.profiles) {
                    view.profiles = response.profiles;
                    view.otherTunnels = response.otherTunnels;
                    view.editorAvailable = response.editorAvailable;
                    view.healthy = true;
                }
                if (response.message) view.message = response.message;
            } catch (error) {
                view.healthy = false;
                view.message = "VPN request failed (exit " + exitCode + "). Status may be stale.";
            } finally {
                if (completed !== "list" && view.active) Qt.callLater(() => view.request("list", {}));
            }
        }
    }

    MenuButton { width: parent.width; text: "‹ Network"; onClicked: view.back() }
    MenuLabel { text: "VPN / WireGuard" }
    MenuLabel { width: parent.width; color: "#aaaaaa"; font.pixelSize: 12; text: "Saved NetworkManager profiles. VPN plugins and credentials must already be configured." }
    MenuLabel {
        width: parent.width
        visible: view.busy || view.message.length > 0
        text: view.busy ? (view.operation === "up" ? "Connecting…" : view.operation === "down" ? "Disconnecting…" : "Refreshing…") : view.message
    }
    Column {
        width: parent.width
        visible: view.pending !== null
        spacing: 8
        MenuLabel { width: parent.width; text: (view.pending?.action === "up" ? "Connect " : "Disconnect ") + (view.pending?.name ?? "") + "?" }
        MenuLabel { width: parent.width; color: "#aaaaaa"; text: "Routes and DNS may change. SSH and other active connections can be interrupted." }
        MenuButton {
            width: parent.width
            text: "Confirm"
            enabled: !view.busy && view.healthy
            onClicked: {
                const action = view.pending;
                view.pending = null;
                view.request(action.action, {uuid: action.uuid});
            }
        }
        MenuButton { width: parent.width; text: "Cancel"; onClicked: view.pending = null }
    }
    Repeater {
        model: view.profiles
        Column {
            id: profile
            required property var modelData
            width: view.width
            spacing: 6
            MenuLabel { width: parent.width; text: (profile.modelData.connected ? "✓ " : "") + profile.modelData.name }
            MenuLabel { width: parent.width; color: "#aaaaaa"; font.pixelSize: 12; text: profile.modelData.type + " · " + profile.modelData.state + (profile.modelData.device ? " · " + profile.modelData.device : "") }
            Repeater {
                model: Object.keys(profile.modelData.details)
                MenuLabel {
                    required property string modelData
                    width: profile.width
                    font.pixelSize: 12
                    text: modelData + ": " + profile.modelData.details[modelData].join(", ")
                    color: "#aaaaaa"
                }
            }
            MenuButton {
                width: parent.width
                text: profile.modelData.connected ? "Disconnect…" : "Connect…"
                enabled: !view.busy && view.healthy && !["activating", "deactivating"].includes(profile.modelData.state)
                onClicked: view.pending = {uuid: profile.modelData.uuid, name: profile.modelData.name, action: profile.modelData.connected ? "down" : "up"}
            }
            MenuButton { width: parent.width; text: "Edit profile…"; enabled: view.editorAvailable && !view.busy; onClicked: view.openEditor(profile.modelData.uuid) }
            Rectangle { width: parent.width; height: 1; color: "#202020" }
        }
    }
    MenuLabel { visible: view.healthy && view.profiles.length === 0; width: parent.width; text: "No saved VPN/WireGuard profiles. Add or import one using the profile editor."; color: "#aaaaaa" }
    MenuButton { width: parent.width; text: "Refresh"; enabled: !view.busy; onClicked: view.request("list", {}) }
    MenuButton { width: parent.width; text: view.editorAvailable ? "Add / import / edit profiles…" : "Install nm-connection-editor for profile setup"; enabled: view.editorAvailable && !view.busy; onClicked: view.openEditor("") }
    Column {
        width: parent.width
        spacing: 6
        visible: view.otherTunnels.length > 0
        MenuLabel { width: parent.width; text: "Other tunnel interfaces" }
        MenuLabel { width: parent.width; color: "#aaaaaa"; font.pixelSize: 12; text: "Not controlled by this VPN list. Use the application that created the tunnel; no disconnect is performed here." }
        Repeater {
            model: view.otherTunnels
            MenuLabel { required property var modelData; width: parent.width; text: modelData.device + " · " + modelData.type + " · " + modelData.state; font.pixelSize: 12; color: "#aaaaaa" }
        }
    }
}
