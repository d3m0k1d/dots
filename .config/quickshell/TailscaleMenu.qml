import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io

Column {
    id: view
    property bool active: false
    property var state: ({available: false, state: "unknown", peers: []})
    property string message: ""
    property string operation: ""
    property var pending: null
    property string headscaleServer: ""
    property string authKey: ""
    readonly property bool busy: worker.running
    signal back()

    function request(action, payload) {
        if (busy) return
        operation = action
        worker.result = ""
        worker.command = ["python3", Quickshell.shellPath("tailscale.py"), action, JSON.stringify(payload || {})]
        worker.running = true
    }
    function refresh() { request("status", {}) }
    function ask(action, label) { pending = {action: action, label: label} }
    function confirm() {
        if (!pending) return
        const action = pending.action
        pending = null
        request(action, action === "up" ? {server: headscaleServer, authKey: authKey} : {})
    }
    onActiveChanged: { pending = null; if (active) refresh() }

    Timer { interval: 5000; running: view.active; repeat: true; onTriggered: view.refresh() }
    Process {
        id: worker
        property string result: ""
        stdout: SplitParser { onRead: data => worker.result = data }
        onExited: (exitCode, exitStatus) => {
            try {
                const response = JSON.parse(result)
                if (!response.ok) { view.message = response.error; return }
                if (response.state !== undefined) view.state = response
                view.message = response.message || ""
                if (view.operation !== "status") Qt.callLater(view.refresh)
            } catch (error) { view.message = "Tailscale request failed" }
        }
    }

    MenuButton { width: parent.width; text: "‹ VPN / WireGuard"; onClicked: view.back() }
    MenuLabel { text: "Tailscale / Headscale"; font.bold: true }
    MenuLabel {
        width: parent.width
        text: view.state.available === false ? "Not installed" : "State: " + (view.state.state || "unknown")
        color: view.state.state === "Running" ? "#8ee28e" : "#ffcc66"
    }
    MenuLabel { width: parent.width; visible: !!view.state.hostname; text: (view.state.hostname || "") + (view.state.dnsName ? " · " + view.state.dnsName : ""); color: "#aaaaaa" }
    MenuLabel { width: parent.width; visible: !!view.state.tailnet; text: "Tailnet: " + view.state.tailnet; color: "#aaaaaa" }
    MenuLabel { width: parent.width; visible: view.message.length > 0; text: view.message; wrapMode: Text.Wrap; color: "#ff9999" }

    Column {
        width: parent.width
        spacing: 6
        visible: view.pending !== null
        MenuLabel { width: parent.width; text: "Confirm " + view.pending?.label + "?" }
        MenuLabel { width: parent.width; text: "This changes the VPN connection and may alter routes/DNS."; color: "#aaaaaa"; wrapMode: Text.Wrap }
        Row {
            spacing: 6
            MenuButton { text: "Confirm"; enabled: !view.busy; onClicked: view.confirm() }
            MenuButton { text: "Cancel"; onClicked: view.pending = null }
        }
    }

    Column {
        width: parent.width
        spacing: 6
        visible: view.pending === null
        MenuButton { width: parent.width; text: "Connect to Tailscale"; enabled: !view.busy; onClicked: view.ask("up", "connect") }
        MenuButton { width: parent.width; text: "Connect to Headscale"; enabled: !view.busy; onClicked: view.ask("up", "connect to Headscale") }
        MenuButton { width: parent.width; text: "Disconnect"; enabled: !view.busy && view.state.state === "Running"; onClicked: view.ask("down", "disconnect") }
        MenuButton { width: parent.width; text: "Log out"; enabled: !view.busy && view.state.state === "Running"; onClicked: view.ask("logout", "log out") }
    }

    Column {
        width: parent.width
        spacing: 6
        visible: view.pending?.action === "up"
        MenuLabel { text: "Headscale server (optional)" }
        Controls.TextField { width: parent.width; placeholderText: "https://headscale.example.com"; text: view.headscaleServer; onTextChanged: view.headscaleServer = text }
        MenuLabel { text: "Auth key (optional; stored only for this request)"; color: "#aaaaaa"; font.pixelSize: 12 }
        Controls.TextField { width: parent.width; echoMode: TextInput.Password; text: view.authKey; onTextChanged: view.authKey = text }
    }

    MenuLabel { text: "Peers"; font.bold: true }
    Repeater {
        model: view.state.peers || []
        MenuLabel {
            required property var modelData
            width: view.width
            text: (modelData.online ? "● " : "○ ") + modelData.name + (modelData.ips.length ? " · " + modelData.ips.join(", ") : "")
            color: modelData.online ? "#dddddd" : "#777777"
            font.pixelSize: 12
        }
    }
    MenuLabel { visible: (view.state.peers || []).length === 0; text: "No peers or status unavailable"; color: "#aaaaaa" }
    MenuButton { width: parent.width; text: "Refresh"; enabled: !view.busy; onClicked: view.refresh() }
}
