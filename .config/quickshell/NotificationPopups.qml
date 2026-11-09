import QtQuick
import Quickshell

PanelWindow {
    id: popup
    required property var store
    visible: store.popups.length > 0
    anchors.top: true
    anchors.right: true
    margins.top: 40
    margins.right: 8
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 420
    implicitHeight: Math.min(cards.implicitHeight + 16, (screen?.height ?? 1080) - 100)
    color: "transparent"
    Column {
        id: cards
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 8
        Repeater {
            model: popup.store.popups
            NotificationCard {
                required property var modelData
                width: cards.width
                compact: true
                entry: modelData
                store: popup.store
            }
        }
    }
}
