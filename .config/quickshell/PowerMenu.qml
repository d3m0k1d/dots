import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PanelMenu {
    id: menu
    preferredWidth: 320
    contentHeight: body.implicitHeight
    property string pending: ""
    property string message: ""
    property var executor: null
    readonly property bool busy: worker.running
    readonly property var actions: [
        {key: "lock", label: "Lock screen", icon: "󰌾"},
        {key: "suspend", label: "Lock & suspend", icon: "󰤄"},
        {key: "logout", label: "Log out", icon: "󰍃"},
        {key: "reboot", label: "Restart", icon: "󰜉"},
        {key: "poweroff", label: "Power off", icon: "󰐥"}
    ]
    readonly property string pendingLabel: actions.find(action => action.key === pending)?.label ?? ""

    function toggle() { visible = !visible; }
    function requestAction(action) {
        if (busy || !actions.some(item => item.key === action)) return;
        message = "";
        if (action === "lock") startAction(action);
        else pending = action;
    }
    function confirm() {
        if (pending && actions.some(item => item.key === pending)) startAction(pending);
    }
    function startAction(action) {
        if (busy) return;
        pending = "";
        message = "";
        visible = false;
        // Tests inject a recorder; rendering the menu never executes an action.
        if (executor) { executor(action); return; }
        worker.result = "";
        worker.command = ["python3", Quickshell.shellPath("power.py"), action, Hyprland.usingLua ? "lua" : "legacy"];
        worker.running = true;
    }
    onVisibleChanged: { if (!visible) pending = ""; }
    Process {
        id: worker
        property string result: ""
        stdout: SplitParser { onRead: data => worker.result = data }
        onExited: (exitCode, exitStatus) => {
            try {
                const response = JSON.parse(result);
                if (response.ok) return;
                menu.message = response.error;
            } catch (error) {
                menu.message = "Action failed (exit " + exitCode + ").";
            }
            menu.visible = true;
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        radius: 15
        focus: true
        Keys.onEscapePressed: {
            if (menu.pending) menu.pending = "";
            else menu.visible = false;
        }
        Flickable {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: MenuScrollBar { id: scrollbar }
            Column {
                id: body
                width: scrollArea.width - (scrollbar.visible ? 16 : 0)
                spacing: 10
                Row {
                    width: parent.width
                    MenuLabel { text: "  Session & power"; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    MenuButton { text: "×"; width: 36; onClicked: menu.visible = false }
                }
                MenuLabel { width: parent.width; text: menu.message; visible: text.length > 0 }
                Column {
                    width: parent.width
                    spacing: 8
                    visible: menu.pending.length === 0
                    Repeater {
                        model: menu.actions
                        MenuButton {
                            required property var modelData
                            width: parent.width
                            enabled: !menu.busy
                            text: modelData.icon + "  " + modelData.label
                            onClicked: menu.requestAction(modelData.key)
                        }
                    }
                }
                Column {
                    width: parent.width
                    spacing: 10
                    visible: menu.pending.length > 0
                    MenuLabel { width: parent.width; text: menu.pendingLabel + "?" }
                    MenuLabel {
                        width: parent.width
                        color: "#aaaaaa"
                        text: menu.pending === "suspend"
                            ? "The screen must be confirmed locked by hypridle before suspend. If locking fails, suspend is cancelled. Active connections may be interrupted."
                            : "Save your work first. Applications and remote sessions may be closed."
                    }
                    MenuButton { width: parent.width; text: "Confirm: " + menu.pendingLabel; enabled: !menu.busy; onClicked: menu.confirm() }
                    MenuButton { width: parent.width; text: "Cancel"; onClicked: menu.pending = "" }
                }
            }
        }
    }
}
