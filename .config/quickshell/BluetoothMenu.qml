import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth

PanelMenu {
    id: menu
    contentHeight: body.implicitHeight

    property bool managerAvailable: false
    property var selectedAdapter: null
    property var scanAdapter: null
    property var pendingDevice: null
    property var forgetDevice: null
    property string message: ""
    readonly property var adapter: selectedAdapter && Bluetooth.adapters.values.includes(selectedAdapter) ? selectedAdapter : Bluetooth.defaultAdapter
    readonly property bool transitioning: adapter?.state === BluetoothAdapterState.Enabling || adapter?.state === BluetoothAdapterState.Disabling
    readonly property var devices: adapter ? adapter.devices.values.slice().sort((a, b) =>
        Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired)
        || (a.name || a.address).localeCompare(b.name || b.address)) : []

    function toggle() { visible = !visible; }
    function stopScan() {
        scanTimeout.stop();
        if (scanAdapter) scanAdapter.discovering = false;
        scanAdapter = null;
    }
    function toggleScan() {
        if (scanAdapter) { stopScan(); return; }
        if (!adapter?.enabled) return;
        message = "";
        scanAdapter = adapter;
        adapter.discovering = true;
        scanTimeout.restart();
    }
    function openManager() {
        if (!managerAvailable) return;
        visible = false;
        Quickshell.execDetached(["blueman-manager"]);
    }
    function connectDevice(device) {
        message = "";
        pendingDevice = device;
        device.connect();
        connectTimeout.restart();
    }
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                if (menu.visible && menu.adapter?.enabled && !menu.scanAdapter) menu.toggleScan();
            });
        } else {
            stopScan();
            forgetDevice = null;
            message = "";
        }
    }
    onAdapterChanged: {
        stopScan();
        scrollArea.contentY = 0;
        Qt.callLater(() => {
            if (menu.visible && menu.adapter?.enabled && !menu.scanAdapter) menu.toggleScan();
        });
    }
    Connections {
        target: menu.adapter
        function onEnabledChanged() {
            if (!menu.adapter?.enabled) menu.stopScan();
            else if (menu.visible && !menu.scanAdapter) menu.toggleScan();
        }
    }
    Timer { id: scanTimeout; interval: 60000; onTriggered: menu.stopScan() }
    Timer {
        id: connectTimeout
        interval: 20000
        onTriggered: {
            if (menu.pendingDevice && !menu.pendingDevice.connected)
                menu.message = "Could not connect. Check device power and pairing, or open Blueman for details.";
            menu.pendingDevice = null;
        }
    }
    Connections {
        target: menu.pendingDevice
        function onConnectedChanged() {
            if (menu.pendingDevice?.connected) {
                connectTimeout.stop();
                menu.pendingDevice = null;
                menu.message = "";
            }
        }
    }

    component Label: MenuLabel {}
    component Button: MenuButton {}

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
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Controls.ScrollBar.vertical: MenuScrollBar {
                id: scrollbar
            }
            Column {
                id: body
                width: scrollArea.width - (scrollbar.visible ? 16 : 0)
                spacing: 10
                Row {
                    width: parent.width
                    Label { text: "Bluetooth"; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    Button { width: 36; text: "×"; onClicked: menu.visible = false }
                }
                Label {
                    visible: !menu.adapter
                    width: parent.width
                    text: "Bluetooth service unavailable or no adapter detected.\nInstall bluez and bluez-utils, then start bluetooth.service."
                    color: "#aaaaaa"
                }
                Button {
                    visible: Bluetooth.adapters.values.length > 1
                    width: parent.width
                    text: "Adapter: " + (menu.adapter?.name ?? "") + "  ›"
                    onClicked: {
                        const adapters = Bluetooth.adapters.values;
                        menu.selectedAdapter = adapters[(adapters.indexOf(menu.adapter) + 1) % adapters.length];
                    }
                }
                Label {
                    visible: menu.adapter !== null
                    width: parent.width
                    text: (menu.adapter?.name ?? "") + " · " + (menu.adapter ? BluetoothAdapterState.toString(menu.adapter.state) : "")
                }
                Button {
                    visible: menu.adapter !== null
                    width: parent.width
                    enabled: !menu.transitioning && menu.adapter?.state !== BluetoothAdapterState.Blocked
                    text: menu.adapter?.enabled ? "  Turn Bluetooth off" : "󰂲  Turn Bluetooth on"
                    onClicked: {
                        menu.stopScan();
                        menu.adapter.enabled = !menu.adapter.enabled;
                    }
                }
                Label {
                    visible: menu.adapter?.state === BluetoothAdapterState.Blocked
                    text: "Adapter blocked. Check rfkill / hardware switch."
                    width: parent.width
                    color: "#aaaaaa"
                }
                Button {
                    visible: menu.adapter?.enabled ?? false
                    width: parent.width
                    text: menu.scanAdapter ? "Stop scanning" : "Scan for devices"
                    onClicked: menu.toggleScan()
                }
                Label {
                    visible: menu.scanAdapter !== null
                    width: parent.width
                    text: "Searching… Put your device in pairing mode. Scanning stops after 60 seconds or when this menu closes."
                    font.pixelSize: 12
                    color: "#aaaaaa"
                }
                Label {
                    visible: menu.message.length > 0
                    width: parent.width
                    text: menu.message
                }
                Repeater {
                    model: menu.adapter?.enabled ? menu.devices : []
                    Column {
                        id: deviceRow
                        required property var modelData
                        readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || menu.pendingDevice === modelData
                        width: body.width
                        spacing: 6
                        Label { width: parent.width; text: (deviceRow.modelData.connected ? "✓ " : "") + (deviceRow.modelData.name || deviceRow.modelData.address) }
                        Label {
                            width: parent.width
                            font.pixelSize: 12
                            color: "#aaaaaa"
                            text: deviceRow.modelData.address + " · " + BluetoothDeviceState.toString(deviceRow.modelData.state)
                                + (deviceRow.modelData.paired ? " · paired" : " · not paired")
                                + (deviceRow.modelData.batteryAvailable ? " · " + Math.round(deviceRow.modelData.battery * 100) + "% battery" : "")
                        }
                        Button {
                            width: parent.width
                            enabled: !deviceRow.busy && !deviceRow.modelData.blocked && (deviceRow.modelData.paired || menu.managerAvailable)
                            text: deviceRow.busy ? "Working…" : deviceRow.modelData.connected ? "Disconnect" : deviceRow.modelData.paired ? "Connect" : "Pair in Blueman…"
                            onClicked: {
                                if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                                else if (deviceRow.modelData.paired) menu.connectDevice(deviceRow.modelData);
                                else menu.openManager();
                            }
                        }
                        Row {
                            visible: deviceRow.modelData.paired
                            width: parent.width
                            spacing: 8
                            Button {
                                width: (parent.width - 8) / 2
                                enabled: !deviceRow.busy
                                text: deviceRow.modelData.trusted ? "[✓] Trusted" : "[ ] Trusted"
                                onClicked: deviceRow.modelData.trusted = !deviceRow.modelData.trusted
                            }
                            Button {
                                width: (parent.width - 8) / 2
                                enabled: !deviceRow.busy
                                text: "Forget…"
                                onClicked: menu.forgetDevice = menu.forgetDevice === deviceRow.modelData ? null : deviceRow.modelData
                            }
                        }
                        Button {
                            visible: menu.forgetDevice === deviceRow.modelData
                            width: parent.width
                            text: "Confirm: disconnect and forget"
                            onClicked: { deviceRow.modelData.forget(); menu.forgetDevice = null; }
                        }
                        Label { visible: deviceRow.modelData.blocked; text: "Blocked · unblock in Blueman"; color: "#aaaaaa" }
                        Rectangle { width: parent.width; height: 1; color: "#202020" }
                    }
                }
                Label {
                    visible: (menu.adapter?.enabled ?? false) && menu.devices.length === 0
                    width: parent.width
                    text: menu.scanAdapter ? "Looking for devices… Enable pairing mode on your device." : "No devices found. Try scanning again with your device in pairing mode."
                    color: "#aaaaaa"
                }
                Button {
                    width: parent.width
                    enabled: menu.managerAvailable
                    text: menu.managerAvailable ? "Pairing / advanced settings…" : "Install blueman for pairing dialogs"
                    onClicked: menu.openManager()
                }
            }
        }
    }
}
