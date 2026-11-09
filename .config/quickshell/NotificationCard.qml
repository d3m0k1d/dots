import QtQuick
import Quickshell

Rectangle {
    id: card
    required property var entry
    required property var store
    property bool compact: false
    property bool expanded: false
    implicitHeight: content.implicitHeight + 24
    color: "#101010"
    radius: 10

    component Label: MenuLabel {}
    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        Row {
            width: parent.width
            Label {
                width: parent.width - 90
                color: card.entry.critical ? "#ffffff" : "#aaaaaa"
                text: (card.entry.critical ? "! " : "") + card.entry.appName
                font.pixelSize: 12
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            Label { width: 64; text: Qt.formatDateTime(card.entry.receivedAt, "HH:mm"); color: "#aaaaaa"; font.pixelSize: 12 }
            Label {
                text: "×"
                width: 26
                horizontalAlignment: Text.AlignRight
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.store.remove(card.entry) }
            }
        }
        Label { width: parent.width; text: card.entry.summary; font.bold: true; maximumLineCount: card.expanded ? 100 : 3; elide: Text.ElideRight }
        Label {
            id: bodyText
            width: parent.width
            visible: text.length > 0
            text: card.entry.body
            maximumLineCount: card.expanded ? 100 : card.compact ? 3 : 6
            elide: Text.ElideRight
        }
        Label {
            visible: !card.compact && (bodyText.truncated || card.expanded)
            text: card.expanded ? "Show less" : "Show more"
            color: "#aaaaaa"
            font.pixelSize: 12
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.expanded = !card.expanded }
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: card.entry.actions
                Rectangle {
                    id: actionButton
                    required property var modelData
                    width: Math.min(actionLabel.implicitWidth + 20, content.width)
                    height: 30
                    radius: 6
                    color: actionMouse.containsMouse ? "#404040" : "#252525"
                    Label { id: actionLabel; anchors.centerIn: parent; width: Math.min(implicitWidth, actionButton.width - 20); text: actionButton.modelData.text || "Open"; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.pixelSize: 12 }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Invoking an action may immediately close and destroy this card.
                            const entry = card.entry;
                            actionButton.modelData.invoke();
                            if (entry.notification && !entry.notification.resident) entry.notification.dismiss();
                        }
                    }
                }
            }
        }
    }
}
