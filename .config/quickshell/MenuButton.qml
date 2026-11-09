import QtQuick

Rectangle {
    id: button
    property string text: ""
    property string detail: ""
    property int textAlignment: Text.AlignLeft
    signal clicked()
    implicitHeight: detail ? 56 : 36
    color: pointer.containsMouse ? "#202020" : "#101010"
    radius: 8
    opacity: enabled ? 1 : 0.45
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        MenuLabel { text: button.text; width: parent.width; wrapMode: Text.NoWrap; elide: Text.ElideRight; horizontalAlignment: button.textAlignment }
        MenuLabel { text: button.detail; width: parent.width; visible: text.length > 0; wrapMode: Text.NoWrap; elide: Text.ElideRight; color: "#aaaaaa"; font.pixelSize: 12 }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
