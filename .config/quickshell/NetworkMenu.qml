import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking

PanelMenu {
    id: menu
    contentHeight: body.implicitHeight

    property var selected: null
    property var attempt: null
    property bool passwordRequired: false
    property string message: ""
    property bool showProfiles: false
    property bool showVpn: false
    property bool showTailscale: false
    onShowProfilesChanged: scrollArea.contentY = 0
    onShowVpnChanged: scrollArea.contentY = 0
    onShowTailscaleChanged: scrollArea.contentY = 0
    readonly property bool busy: attempt?.stateChanging ?? false
    readonly property bool hasWifi: Networking.devices.values.some(device => device.type === DeviceType.Wifi)

    function toggle() { visible = !visible; }
    function supportsPassword(network) {
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae;
    }
    function connectNetwork(network) {
        if (busy) return;
        message = "";
        selected = network;
        password.clear();
        if (network.device.type === DeviceType.Wifi && !network.known && supportsPassword(network)) {
            passwordRequired = true;
            password.forceActiveFocus();
        } else {
            passwordRequired = false;
            attempt = network;
            network.connect();
        }
    }
    function submitPassword() {
        if (!selected || !password.text.length || busy) return;
        attempt = selected;
        passwordRequired = false;
        selected.connectWithPsk(password.text);
        password.clear();
    }
    onVisibleChanged: {
        if (!visible) {
            password.clear();
            passwordRequired = false;
            selected = null;
            message = "";
            showProfiles = false;
            showVpn = false;
            showTailscale = false;
        }
    }

    Connections {
        target: menu.attempt
        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets && menu.attempt
                    && menu.attempt.device.type === DeviceType.Wifi && menu.supportsPassword(menu.attempt)) {
                menu.selected = menu.attempt;
                menu.passwordRequired = true;
                menu.message = "Password required or incorrect. Try again.";
                password.forceActiveFocus();
            } else {
                menu.message = "Connection failed: " + ConnectionFailReason.toString(reason)
                    + ". Enterprise networks may require a saved profile.";
            }
        }
    }

    component Label: MenuLabel {}
    component Button: MenuButton {
        signal triggered()
        onClicked: triggered()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        radius: 15
        focus: true
        Keys.onEscapePressed: menu.visible = false

        Flickable {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick

            Controls.ScrollBar.vertical: MenuScrollBar {
                id: scrollbar
            }

            Column {
                id: body
                width: scrollArea.width - (scrollbar.visible ? 16 : 0)
                spacing: 10
                Row {
                    width: parent.width
                    Label { text: "Network"; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    Button { text: "×"; width: 36; onTriggered: menu.visible = false }
                }
                NetworkProfiles {
                    width: parent.width
                    active: menu.visible && menu.showProfiles
                    visible: menu.showProfiles
                    onBack: menu.showProfiles = false
                    onOriginalChanged: scrollArea.contentY = 0
                }
                NetworkVpn {
                    width: parent.width
                    active: menu.visible && menu.showVpn
                    visible: menu.showVpn
                    onBack: menu.showVpn = false
                    onExternalWindowRequested: menu.visible = false
                }
                TailscaleMenu {
                    width: parent.width
                    active: menu.visible && menu.showTailscale
                    visible: menu.showTailscale
                    onBack: menu.showTailscale = false
                }
                Column {
                    width: parent.width
                    spacing: 10
                     visible: !menu.showProfiles && !menu.showVpn && !menu.showTailscale
                 Button {
                    width: parent.width
                    text: "VPN / WireGuard"
                    detail: "Saved profiles · connection status · IP / DNS"
                    onTriggered: {
                        menu.showVpn = true;
                        menu.passwordRequired = false;
                        password.clear();
                 }
                 Button {
                     width: parent.width
                     text: "Tailscale / Headscale"
                     detail: "Mesh VPN · peers · connect to custom control server"
                     onTriggered: {
                         menu.showTailscale = true;
                         menu.passwordRequired = false;
                         password.clear();
                     }
                 }
                 }
                 Button {
                     width: parent.width
                     text: "Connection profiles / IP settings"
                     detail: "DHCP · static IP · DNS · routes · duplicate profiles"
                     onTriggered: {
                         menu.showProfiles = true;
                         menu.passwordRequired = false;
                         password.clear();
                     }
                 }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#aaaaaa"
                    text: Networking.backend === NetworkBackendType.None ? "NetworkManager is unavailable"
                        : Networking.connectivity === NetworkConnectivity.Full ? "Internet connected"
                        : Networking.connectivity === NetworkConnectivity.Portal ? "Sign-in required (captive portal)"
                        : Networking.connectivity === NetworkConnectivity.Limited ? "Local network · limited internet"
                        : "No confirmed internet access"
                }
                Button {
                    width: parent.width
                    visible: menu.hasWifi
                    enabled: Networking.wifiHardwareEnabled && !menu.busy
                    text: "  Wi-Fi " + (Networking.wifiEnabled ? "on" : "off")
                    detail: Networking.wifiHardwareEnabled ? "Click to toggle" : "Blocked by hardware switch"
                    onTriggered: Networking.wifiEnabled = !Networking.wifiEnabled
                }
                Label { visible: !menu.hasWifi; text: "No Wi-Fi adapter detected"; color: "#aaaaaa" }

                Repeater {
                    model: Networking.devices
                    Column {
                        id: deviceSection
                        required property var modelData
                        width: body.width
                        spacing: 6
                        visible: modelData.type === DeviceType.Wired || (modelData.type === DeviceType.Wifi && Networking.wifiEnabled)
                        Binding {
                            target: deviceSection.modelData.type === DeviceType.Wifi ? deviceSection.modelData : null
                            property: "scannerEnabled"
                            value: menu.visible && Networking.wifiEnabled
                            when: deviceSection.modelData.type === DeviceType.Wifi
                        }
                        Label {
                            text: (deviceSection.modelData.type === DeviceType.Wired ? "󰈀  Ethernet · " : "  Wi-Fi · ") + deviceSection.modelData.name
                        }
                        Label {
                            visible: deviceSection.modelData.address.length > 0
                            text: deviceSection.modelData.address
                            color: "#aaaaaa"
                        }
                        Label {
                            visible: deviceSection.modelData.type === DeviceType.Wired && !deviceSection.modelData.hasLink
                            text: "Cable disconnected"
                            color: "#aaaaaa"
                        }
                        Label {
                            visible: deviceSection.modelData.type === DeviceType.Wifi && deviceSection.modelData.networks.values.length === 0
                            text: "Scanning for networks…"
                            color: "#aaaaaa"
                        }
                        Repeater {
                            model: deviceSection.modelData.networks
                            Button {
                                required property var modelData
                                width: deviceSection.width
                                enabled: !menu.busy && !modelData.stateChanging
                                text: (modelData.connected ? "✓  " : "") + (modelData.name || "Unnamed network")
                                detail: modelData.stateChanging ? ConnectionState.toString(modelData.state)
                                    : (modelData.connected ? "Connected · click to disconnect" : modelData.known ? "Saved · click to connect" : "Click to connect")
                                        + (deviceSection.modelData.type === DeviceType.Wifi ? " · " + Math.round(modelData.signalStrength * 100) + "% · " + WifiSecurityType.toString(modelData.security) : "")
                                onTriggered: {
                                    if (modelData.connected) modelData.disconnect();
                                    else menu.connectNetwork(modelData);
                                }
                            }
                        }
                    }
                }
                Label {
                    visible: menu.busy
                    text: "Connecting…"
                }
                Label {
                    visible: menu.message.length > 0
                    text: menu.message
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Column {
                    width: parent.width
                    spacing: 8
                    visible: menu.passwordRequired && menu.selected !== null
                    Label { text: "Password · " + (menu.selected?.name ?? ""); width: parent.width; elide: Text.ElideRight }
                    Rectangle {
                        width: parent.width
                        height: 38
                        color: "#101010"
                        radius: 8
                        border.color: password.activeFocus ? "white" : "#404040"
                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.margins: 10
                            color: "white"
                            selectionColor: "#555555"
                            selectedTextColor: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            renderType: Text.NativeRendering
                            echoMode: TextInput.Password
                            clip: true
                            onAccepted: menu.submitPassword()
                            Keys.onEscapePressed: menu.visible = false
                        }
                    }
                    Row {
                        spacing: 8
                        Button { text: "Connect"; width: 110; enabled: password.text.length > 0 && !menu.busy; onTriggered: menu.submitPassword() }
                        Button { text: "Cancel"; width: 100; onTriggered: { menu.passwordRequired = false; password.clear(); } }
                    }
                }
                }
            }
        }
    }
}
