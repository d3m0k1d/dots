import QtQuick
import Quickshell

Text {
    id: root
    property string hint: ""
    property string action: ""
    property string secondaryAction: ""
    property string scrollUp: ""
    property string scrollDown: ""
    property bool interactive: false
    property bool tooltipEnabled: true
    property bool tooltipReady: false
    signal activated(int button)
    signal scrolled(int direction)
    color: "white"
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferFullHinting
    antialiasing: true
    height: 30
    verticalAlignment: Text.AlignVCenter
    visible: text.length > 0
    textFormat: Text.PlainText

    function run(command) {
        if (command) Quickshell.execDetached(["sh", "-c", command]);
    }

    Timer {
        interval: 500
        running: root.tooltipEnabled && mouse.containsMouse && root.hint.length > 0
        onTriggered: root.tooltipReady = true
    }

    PopupWindow {
        id: tooltip
        anchor.item: root
        anchor.rect.x: Math.round(root.width / 2)
        anchor.rect.y: root.height + 8
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
        visible: root.tooltipEnabled && root.tooltipReady && mouse.containsMouse && root.hint.length > 0
        implicitWidth: Math.min(tooltipText.implicitWidth + 20, 520)
        implicitHeight: tooltipText.implicitHeight + 20
        color: "transparent"
        // Empty input region: the tooltip cannot consume clicks or wheel events.
        mask: Region {}
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            radius: 15
        }
        Text {
            id: tooltipText
            anchors.fill: parent
            anchors.margins: 10
            text: root.hint
            textFormat: Text.PlainText
            color: root.color
            font: root.font
            renderType: root.renderType
            antialiasing: root.antialiasing
            wrapMode: Text.Wrap
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: root.tooltipReady = false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.action || root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => {
            root.run(event.button === Qt.RightButton ? root.secondaryAction : root.action);
            root.activated(event.button);
        }
        onWheel: event => {
            if (event.angleDelta.y === 0) return;
            root.run(event.angleDelta.y > 0 ? root.scrollUp : root.scrollDown);
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
