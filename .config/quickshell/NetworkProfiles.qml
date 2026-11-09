import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: editor
    property bool active: false
    property var profiles: []
    property var original: null
    property var draft: ({})
    property string message: ""
    property string operation: ""
    property bool confirmActivation: false
    property string ipFamily: "ipv4"
    readonly property bool busy: worker.running
    readonly property bool dirty: original !== null && Object.keys(draft).some(key => original[key] !== undefined && draft[key] !== original[key])
    signal back()
    spacing: 10

    function request(action, payload) {
        if (busy) return;
        message = "";
        operation = action;
        worker.result = "";
        worker.command = ["python3", Quickshell.shellPath("network_profiles.py"), action, JSON.stringify(payload)];
        worker.running = true;
    }
    function setField(key, value) {
        draft = Object.assign({}, draft, { [key]: value });
        confirmActivation = false;
    }
    function save() {
        const changes = {};
        for (const key of Object.keys(draft)) {
            if (original[key] !== undefined && draft[key] !== original[key]) changes[key] = draft[key];
        }
        request("save", {original: original, changes: changes});
    }
    onActiveChanged: {
        if (active && !busy) {
            original = null;
            draft = ({});
            confirmActivation = false;
            request("list", {});
        }
    }
    Process {
        id: worker
        property string result: ""
        stdout: SplitParser { onRead: data => worker.result = data }
        onExited: (exitCode, exitStatus) => {
            try {
                const response = JSON.parse(result);
                if (!response.ok) { editor.message = response.error; return; }
                if (response.profiles) editor.profiles = response.profiles;
                if (response.profile) {
                    editor.original = response.profile;
                    editor.draft = Object.assign({}, response.profile);
                    editor.ipFamily = "ipv4";
                }
                editor.message = response.message ?? "";
                editor.confirmActivation = false;
                if (editor.operation === "clone") {
                    editor.original = null;
                    editor.request("list", {});
                }
            } catch (error) {
                editor.message = "Network request failed (exit " + exitCode + ").";
            }
        }
    }

    component Label: MenuLabel {}
    component Button: Rectangle {
        id: button
        property string text: ""
        signal clicked()
        implicitHeight: Math.max(36, label.implicitHeight + 16)
        radius: 8
        color: pointer.containsMouse ? "#202020" : "#101010"
        opacity: enabled ? 1 : 0.45
        Label { id: label; text: button.text; anchors.centerIn: parent; width: parent.width - 16 }
        MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }
    component Field: Column {
        id: field
        property string label: ""
        property string key: ""
        spacing: 5
        Label { text: field.label; width: parent.width; color: "#aaaaaa"; font.pixelSize: 12 }
        Rectangle {
            width: parent.width
            height: 36
            color: "#101010"
            border.color: input.activeFocus ? "#ffffff" : "#303030"
            radius: 8
            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 8
                text: editor.draft[field.key] ?? ""
                onTextEdited: editor.setField(field.key, text)
                color: "white"
                selectedTextColor: "white"
                selectionColor: "#555555"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                renderType: Text.NativeRendering
                clip: true
                selectByMouse: true
                enabled: !editor.busy
            }
        }
    }
    component Toggle: Button {
        property string label: ""
        property string key: ""
        text: (editor.draft[key] === "yes" ? "[✓] " : "[ ] ") + label
        enabled: !editor.busy
        onClicked: editor.setField(key, editor.draft[key] === "yes" ? "no" : "yes")
    }
    component IpSettings: Column {
        id: ip
        property string family: "ipv4"
        readonly property var methods: family === "ipv4"
            ? ["auto", "manual", "disabled", "link-local", "shared"]
            : ["auto", "dhcp", "manual", "disabled", "ignore", "link-local", "shared"]
        spacing: 8
        Label { text: ip.family === "ipv4" ? "IPv4" : "IPv6" }
        Button {
            width: parent.width
            enabled: !editor.busy
            text: "Method: " + (editor.draft[ip.family + ".method"] ?? "") + "  ›"
            onClicked: {
                const current = ip.methods.indexOf(editor.draft[ip.family + ".method"]);
                editor.setField(ip.family + ".method", ip.methods[(current + 1) % ip.methods.length]);
            }
        }
        Label { width: parent.width; color: "#aaaaaa"; font.pixelSize: 12; text: (ip.family === "ipv4" ? "auto = DHCP · manual = static" : "auto = SLAAC/DHCPv6 · manual = static") + "\nSwitching method does not erase stored addresses." }
        Field { width: parent.width; key: ip.family + ".addresses"; label: "Addresses/prefix (comma-separated)" }
        Field { width: parent.width; key: ip.family + ".gateway"; label: "Gateway (empty = none)" }
        Field { width: parent.width; key: ip.family + ".dns"; label: "DNS servers (comma-separated)" }
        Field { width: parent.width; key: ip.family + ".dns-search"; label: "DNS search/routing domains (comma-separated)" }
        Toggle { width: parent.width; key: ip.family + ".ignore-auto-dns"; label: "Ignore automatic DNS" }
        Toggle { width: parent.width; key: ip.family + ".never-default"; label: "Never use as default route" }
        Field { width: parent.width; key: ip.family + ".route-metric"; label: "Route metric (-1 = automatic)" }
        Field { width: parent.width; key: ip.family + ".routes"; label: "Routes (nmcli: prefix next-hop metric, …)" }
    }

    Button {
        width: parent.width
        text: editor.original ? "‹ Profiles (discard unsaved edits)" : "‹ Network"
        enabled: !editor.busy
        onClicked: {
            if (editor.original) {
                editor.original = null;
                editor.confirmActivation = false;
                editor.request("list", {});
            } else editor.back();
        }
    }
    Label { text: editor.busy ? "Working…" : editor.message; visible: text.length > 0; width: parent.width }

    Column {
        width: parent.width
        spacing: 8
        visible: editor.original === null
        Label { text: "Connection profiles" }
        Label { text: "Select a profile to edit or duplicate it."; width: parent.width; color: "#aaaaaa" }
        Repeater {
            model: editor.profiles
            Button {
                required property var modelData
                width: parent.width
                text: modelData.name + "\n" + modelData.type + (modelData.device ? " · " + modelData.device : "")
                enabled: !editor.busy
                onClicked: editor.request("load", {uuid: modelData.uuid})
            }
        }
        Label { text: "New Ethernet profile" }
        Field { width: parent.width; key: "create.name"; label: "Profile name" }
        Field { width: parent.width; key: "create.interface"; label: "Interface (empty = any Ethernet interface)" }
        Button {
            width: parent.width
            text: "Create (autoconnect off)"
            enabled: !editor.busy && (editor.draft["create.name"] ?? "").trim().length > 0
            onClicked: editor.request("create", {name: editor.draft["create.name"], interface: editor.draft["create.interface"] ?? ""})
        }
    }
    Column {
        width: parent.width
        spacing: 10
        visible: editor.original !== null
        Label { text: "Edit profile" }
        Label { text: editor.original?.["connection.uuid"] ?? ""; width: parent.width; font.pixelSize: 12; color: "#aaaaaa" }
        Field { width: parent.width; key: "connection.id"; label: "Profile name" }
        Field { width: parent.width; key: "connection.interface-name"; label: "Interface (empty = any compatible interface)" }
        Toggle { width: parent.width; key: "connection.autoconnect"; label: "Autoconnect" }
        Field {
            width: parent.width
            key: (editor.original?.["connection.type"] ?? "") + ".mtu"
            visible: editor.original?.[key] !== undefined
            label: "MTU (auto / 0 = automatic)"
        }
        Row {
            width: parent.width
            spacing: 8
            Button { width: (parent.width - 8) / 2; text: editor.ipFamily === "ipv4" ? "✓ IPv4" : "IPv4"; onClicked: editor.ipFamily = "ipv4" }
            Button { width: (parent.width - 8) / 2; text: editor.ipFamily === "ipv6" ? "✓ IPv6" : "IPv6"; onClicked: editor.ipFamily = "ipv6" }
        }
        IpSettings { width: parent.width; family: "ipv4"; visible: editor.ipFamily === "ipv4" }
        IpSettings { width: parent.width; family: "ipv6"; visible: editor.ipFamily === "ipv6" }
        Button { width: parent.width; text: "Save profile (no reconnect)"; enabled: editor.dirty && !editor.busy; onClicked: editor.save() }
        Button {
            width: parent.width
            text: "Reload profile (discard edits)"
            enabled: !editor.busy
            onClicked: editor.request("load", {uuid: editor.original["connection.uuid"]})
        }
        Button {
            width: parent.width
            text: "Activate / reconnect…"
            enabled: !editor.busy && !editor.dirty
            onClicked: editor.confirmActivation = !editor.confirmActivation
        }
        Column {
            width: parent.width
            spacing: 8
            visible: editor.confirmActivation
            Label { text: "This can interrupt this interface, SSH and VPN sessions. Activate this profile now?"; width: parent.width }
            Button { text: "Confirm activation"; width: parent.width; enabled: !editor.busy; onClicked: editor.request("activate", {uuid: editor.original["connection.uuid"]}) }
        }
        Field { id: cloneName; width: parent.width; key: "clone.name"; label: "New profile name (for duplication)" }
        Label { width: parent.width; color: "#aaaaaa"; font.pixelSize: 12; text: "Duplication copies saved credentials and the autoconnect policy." }
        Button {
            width: parent.width
            text: "Duplicate saved profile"
            enabled: !editor.busy && !editor.dirty && (editor.draft["clone.name"] ?? "").trim().length > 0
            onClicked: editor.request("clone", {uuid: editor.original["connection.uuid"], name: editor.draft["clone.name"]})
        }
    }
}
