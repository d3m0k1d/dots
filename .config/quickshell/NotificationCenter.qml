import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelMenu {
    id: center
    required property var store
    contentHeight: body.implicitHeight
    function toggle() { visible = !visible; }
    onVisibleChanged: {
        if (visible) {
            if (store.activeCenter && store.activeCenter !== center) store.activeCenter.visible = false;
            store.activeCenter = center;
            store.markRead();
            scrollArea.contentY = 0;
        } else if (store.activeCenter === center) store.activeCenter = null;
    }
    component Label: MenuLabel {}
    component Button: MenuButton { textAlignment: Text.AlignHCenter }
    Rectangle {
        anchors.fill: parent
        color: "black"
        radius: 15
        focus: true
        Keys.onEscapePressed: center.visible = false
        Flickable {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
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
                    Label { text: "Notifications · " + center.store.entries.length; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    Button { width: 36; text: "×"; onClicked: center.visible = false }
                }
                Button {
                    width: parent.width
                    text: (center.store.dnd ? "[✓] " : "[ ] ") + "Do Not Disturb"
                    onClicked: center.store.dnd = !center.store.dnd
                }
                Button { width: parent.width; text: "Clear all"; enabled: center.store.entries.length > 0; onClicked: center.store.clear() }
                Label { text: "No notifications"; color: "#aaaaaa"; visible: center.store.entries.length === 0 }
                Repeater {
                    model: center.store.entries
                    NotificationCard {
                        required property var modelData
                        width: body.width
                        entry: modelData
                        store: center.store
                    }
                }
            }
        }
    }
}
