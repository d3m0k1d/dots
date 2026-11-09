//@ pragma UseQApplication
//@ pragma Env QT_STYLE_OVERRIDE=Fusion
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env GTK_THEME=Adwaita:dark
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

ShellRoot {
    id: root
    property var status: ({})
    NotificationStore { id: notifications }
    MediaController { id: media }
    KeyboardController { id: keyboard }
    readonly property var outputAudio: Pipewire.defaultAudioSink?.ready ? Pipewire.defaultAudioSink.audio : null
    readonly property var inputAudio: Pipewire.defaultAudioSource?.ready ? Pipewire.defaultAudioSource.audio : null

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(node => node !== null)
    }

    function switchWorkspace(workspace) {
        if (Hyprland.usingLua) {
            Quickshell.execDetached([
                "hyprctl", "eval",
                "hl.dispatch(hl.dsp.focus({ workspace = " + workspace + " }))"
            ]);
        } else {
            Hyprland.dispatch("workspace " + workspace);
        }
    }

    Process {
        command: ["python3", Quickshell.shellPath("status.py")]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try { root.status = JSON.parse(data); }
                catch (error) { console.warn("Invalid status:", error); }
            }
        }
    }
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.left: true
            anchors.right: true
            exclusiveZone: 40
            implicitHeight: 40
            color: "transparent"
            readonly property var menus: [networkMenu, soundMenu, bluetoothMenu, notificationCenter, mediaMenu, powerMenu, calendarMenu]

            NetworkMenu {
                id: networkMenu
                screen: panel.screen
                barWindow: panel
                anchorItem: networkTrigger
                menuGroup: panel.menus
            }
            SoundMenu {
                id: soundMenu
                screen: panel.screen
                barWindow: panel
                anchorItem: soundMenu.trigger === "input" ? inputTrigger : outputTrigger
                menuGroup: panel.menus
                fullMixerAvailable: root.status.fullMixer ?? false
            }
            BluetoothMenu {
                id: bluetoothMenu
                screen: panel.screen
                barWindow: panel
                anchorItem: bluetoothTrigger
                menuGroup: panel.menus
                managerAvailable: root.status.bluetoothManager ?? false
            }
            NotificationCenter {
                id: notificationCenter
                screen: panel.screen
                barWindow: panel
                anchorItem: notificationsTrigger
                menuGroup: panel.menus
                store: notifications
            }
            MediaMenu {
                id: mediaMenu
                screen: panel.screen
                barWindow: panel
                anchorItem: mediaTrigger
                menuGroup: panel.menus
                controller: media
            }
            PowerMenu {
                id: powerMenu
                screen: panel.screen
                barWindow: panel
                anchorItem: tuxTrigger
                menuGroup: panel.menus
            }
            CalendarMenu {
                id: calendarMenu
                screen: panel.screen
                barWindow: panel
                anchorItem: clockTrigger
                menuGroup: panel.menus
            }
            NotificationPopups {
                screen: panel.screen
                store: notifications
                visible: panel.screen === Quickshell.screens[0] && notifications.popups.length > 0
                    && !networkMenu.visible && !soundMenu.visible && !bluetoothMenu.visible && !mediaMenu.visible && !powerMenu.visible && !calendarMenu.visible
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 5
                anchors.bottomMargin: 5
                radius: 15
                color: "#000000"

                Flickable {
                    id: leftZone
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    width: Math.max(0, (parent.width - workspaceStrip.width) / 2 - 24)
                    height: parent.height
                    contentWidth: Math.max(width, leftGroup.implicitWidth)
                    contentHeight: height
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: leftGroup
                    height: leftZone.height
                    spacing: 10

                    StatusItem {
                        id: tuxTrigger
                        text: ""
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        anchors.verticalCenter: parent.verticalCenter
                        tooltipEnabled: false
                        interactive: true
                        onActivated: button => {
                            if (button !== Qt.LeftButton) return;
                            networkMenu.visible = false;
                            soundMenu.visible = false;
                            bluetoothMenu.visible = false;
                            notificationCenter.visible = false;
                            mediaMenu.visible = false;
                            powerMenu.toggle();
                        }
                    }

                    StatusItem {
                        id: clockTrigger
                        text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                        width: 85
                        horizontalAlignment: Text.AlignHCenter
                        tooltipEnabled: false
                        interactive: true
                        onActivated: button => { if (button === Qt.LeftButton) calendarMenu.toggle(); }
                    }

                    StatusItem {
                        text: root.status.disk !== undefined ? " " + root.status.disk + "%" : ""
                        hint: root.status.diskHint ?? ""
                        action: "kitty -e btop"
                    }
                    StatusItem {
                        text: root.status.memory !== undefined ? " " + root.status.memory + "%" : ""
                        hint: "RAM usage"
                        action: "kitty -e btop"
                    }
                    StatusItem {
                        text: root.status.cpu !== undefined ? " " + root.status.cpu + "%" : ""
                        hint: "CPU usage"
                        action: "kitty -e btop"
                    }
                    StatusItem {
                        text: root.status.temperature !== undefined ? " " + root.status.temperature + "°C" : ""
                        hint: "CPU temperature"
                    }
                    StatusItem {
                        text: root.status.power !== undefined ? root.status.power + " W" : ""
                        hint: "Battery power draw"
                    }
                    StatusItem {
                        id: mediaTrigger
                        width: Math.min(implicitWidth, panel.width < 1400 ? 100 : 220)
                        elide: Text.ElideRight
                        text: media.player ? "󰎆 " + (media.player.trackTitle || media.player.identity || "Media") : "󰎆"
                        tooltipEnabled: false
                        interactive: true
                        onActivated: button => {
                            if (button === Qt.RightButton) {
                                if (media.player?.canTogglePlaying) media.player.togglePlaying();
                            } else {
                                networkMenu.visible = false;
                                soundMenu.visible = false;
                                bluetoothMenu.visible = false;
                                notificationCenter.visible = false;
                                powerMenu.visible = false;
                                mediaMenu.toggle();
                            }
                        }
                    }

                }
                }

                    Row {
                        id: workspaceStrip
                        readonly property var monitor: Hyprland.monitors.values.find(item => item.name === panel.screen.name) ?? null
                        readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
                        readonly property int firstWorkspace: activeWorkspace >= 6 ? 6 : 1
                        spacing: 5
                        anchors.centerIn: parent

                        Repeater {
                            model: workspaceStrip.firstWorkspace === 1 ? 6 : 5

                            Rectangle {
                                id: workspaceButton
                                required property int index
                                readonly property int workspaceId: workspaceStrip.firstWorkspace + index
                                readonly property bool active: workspaceStrip.activeWorkspace === workspaceId
                                width: 26
                                height: 28
                                radius: 6
                                color: active ? "#ffffff" : "#202020"

                                Text {
                                    anchors.centerIn: parent
                                    text: workspaceButton.workspaceId
                                    color: parent.active ? "#000000" : "#ffffff"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.switchWorkspace(workspaceButton.workspaceId)
                                    onWheel: event => {
                                        const direction = event.angleDelta.y > 0 ? -1 : 1;
                                        root.switchWorkspace(Math.max(1, Math.min(10, workspaceStrip.activeWorkspace + direction)));
                                    }
                                }
                            }
                        }
                    }

                    Flickable {
                        id: rightZone
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        width: Math.max(0, (parent.width - workspaceStrip.width) / 2 - 24)
                        height: parent.height
                        contentWidth: Math.max(width, rightGroup.implicitWidth)
                        contentHeight: height
                        contentX: Math.max(0, contentWidth - width)
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: rightGroup
                        x: Math.max(0, rightZone.width - implicitWidth)
                        height: rightZone.height
                        spacing: 12

                        Repeater {
                            model: SystemTray.items
                            Item {
                                id: trayIcon
                                required property var modelData
                                width: 18
                                height: 30
                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    source: trayIcon.modelData.icon
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: event => {
                                        if (event.button === Qt.MiddleButton) trayIcon.modelData.secondaryActivate();
                                        else if (event.button === Qt.RightButton || trayIcon.modelData.onlyMenu) {
                                            const point = trayIcon.mapToItem(panel.contentItem, 0, trayIcon.height);
                                            trayIcon.modelData.display(panel, point.x, point.y);
                                        } else trayIcon.modelData.activate();
                                    }
                                    onWheel: event => trayIcon.modelData.scroll(event.angleDelta.y, false)
                                }
                            }
                        }
                        StatusItem {
                            id: notificationsTrigger
                            text: notifications.dnd ? "󰂛" : "󰂚" + (notifications.unreadCount ? " " + notifications.unreadCount : "")
                            hint: "Notifications · click: history · right-click: Do Not Disturb"
                            interactive: true
                            onActivated: button => {
                                if (button === Qt.RightButton) notifications.dnd = !notifications.dnd;
                                else {
                                    networkMenu.visible = false;
                                    soundMenu.visible = false;
                                    bluetoothMenu.visible = false;
                                    mediaMenu.visible = false;
                                    powerMenu.visible = false;
                                    notificationCenter.toggle();
                                }
                            }
                        }
                        Row {
                            visible: keyboard.state.available ?? false
                            spacing: 6
                            StatusItem {
                                text: keyboard.state.label ?? ""
                                hint: (keyboard.state.layout ?? "Keyboard layout") + "\n" + (keyboard.state.keyboard ?? "")
                                    + "\nClick: next layout" + (keyboard.state.error ? "\n" + keyboard.state.error : "")
                                interactive: true
                                onActivated: button => { if (button === Qt.LeftButton) keyboard.nextLayout(); }
                            }
                            StatusItem {
                                text: keyboard.state.caps === true ? "⇪ CAPS" : ""
                                tooltipEnabled: false
                            }
                        }
                        StatusItem {
                            text: "󰅍"
                            hint: "Clipboard history"
                            action: "cliphist list | wofi --dmenu | cliphist decode | wl-copy"
                        }
                        StatusItem {
                            text: root.status.brightness !== undefined ? "󰃠 " + root.status.brightness + "%" : ""
                            hint: "Brightness · scroll: ±5%"
                            scrollUp: "brightnessctl set +5%"
                            scrollDown: "brightnessctl set 5%-"
                        }
                        StatusItem {
                            id: bluetoothTrigger
                            text: Bluetooth.defaultAdapter?.enabled ? "" : "󰂲"
                            hint: "Bluetooth · click: devices · right-click: power"
                            interactive: true
                            onActivated: button => {
                                if (button === Qt.LeftButton) {
                                    networkMenu.visible = false;
                                    soundMenu.visible = false;
                                    notificationCenter.visible = false;
                                    mediaMenu.visible = false;
                                    powerMenu.visible = false;
                                    bluetoothMenu.toggle();
                                } else if (button === Qt.RightButton && Bluetooth.defaultAdapter) {
                                    bluetoothMenu.stopScan();
                                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                                }
                            }
                        }
                        StatusItem {
                            id: inputTrigger
                            text: root.inputAudio ? (root.inputAudio.muted ? "" : "") : ""
                            hint: "Microphone · click: input settings · right-click: toggle mute"
                            interactive: true
                            onActivated: button => {
                                if (button === Qt.LeftButton) {
                                    networkMenu.visible = false;
                                    bluetoothMenu.visible = false;
                                    notificationCenter.visible = false;
                                    mediaMenu.visible = false;
                                    powerMenu.visible = false;
                                    soundMenu.toggle("input");
                                } else if (button === Qt.RightButton && root.inputAudio) {
                                    root.inputAudio.muted = !root.inputAudio.muted;
                                }
                            }
                        }
                        StatusItem {
                            id: outputTrigger
                            text: root.outputAudio ? (root.outputAudio.muted ? "󰝟 " : "󰕾 ") + Math.round(root.outputAudio.volume * 100) + "%" : ""
                            hint: "Volume · click: sound settings · right-click: toggle mute · scroll: ±5%"
                            tooltipEnabled: false
                            interactive: true
                            onActivated: button => {
                                if (button === Qt.LeftButton) {
                                    networkMenu.visible = false;
                                    bluetoothMenu.visible = false;
                                    notificationCenter.visible = false;
                                    mediaMenu.visible = false;
                                    powerMenu.visible = false;
                                    soundMenu.toggle("output");
                                } else if (button === Qt.RightButton && root.outputAudio) {
                                    root.outputAudio.muted = !root.outputAudio.muted;
                                }
                            }
                            onScrolled: direction => {
                                if (root.outputAudio) {
                                    const volume = Math.round(root.outputAudio.volume * 100) + direction * 5;
                                    root.outputAudio.volume = Math.max(0, direction > 0 ? Math.min(100, volume) : volume) / 100;
                                }
                            }
                        }
                        StatusItem {
                            id: networkTrigger
                            text: root.status.network === undefined ? "" : (root.status.network === "wifi" ? "" : root.status.network === "ethernet" ? "󰈀" : "󰖪")
                            hint: (root.status.networkHint ?? "Disconnected") + (root.status.speed !== undefined ? "\n↓ " + root.status.speed + " KiB/s" : "")
                            interactive: true
                            onActivated: button => {
                                if (button === Qt.LeftButton) {
                                    soundMenu.visible = false;
                                    bluetoothMenu.visible = false;
                                    notificationCenter.visible = false;
                                    mediaMenu.visible = false;
                                    powerMenu.visible = false;
                                    networkMenu.toggle();
                                }
                            }
                        }
                         StatusItem {
                             text: root.status.battery !== undefined ? (root.status.charging ? "󰂄 " : "󰁹 ") + root.status.battery + "%" : ""
                            hint: root.status.charging ? "Power connected" : "On battery"
                        }
                    }
                    }
            }
        }
    }
}
