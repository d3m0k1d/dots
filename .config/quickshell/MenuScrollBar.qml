import QtQuick
import QtQuick.Controls

ScrollBar {
    id: scrollbar
    policy: ScrollBar.AsNeeded
    width: 6
    minimumSize: 0.08
    contentItem: Rectangle { implicitWidth: 6; radius: 3; color: scrollbar.pressed ? "white" : scrollbar.hovered ? "#bbbbbb" : "#777777" }
    background: Rectangle { color: "#202020"; radius: 3 }
}
