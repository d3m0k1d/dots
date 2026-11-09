import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: menu
    property Item anchorItem: null
    property var barWindow: null
    property var menuGroup: []
    property real contentHeight: 0
    property int preferredWidth: 420
    property int maximumHeight: 480
    property point triggerPosition: Qt.point((screen?.width ?? 1920) - 8, 40)
    visible: false
    anchors.top: true
    anchors.left: true
    margins.top: barWindow ? barWindow.height : 40
    margins.left: Math.round(Math.max(8, Math.min(triggerPosition.x - width / 2, (screen?.width ?? 1920) - width - 8)))
    implicitWidth: Math.max(1, Math.min(preferredWidth, (screen?.width ?? 1920) - 16))
    implicitHeight: Math.max(1, Math.min(contentHeight + 32, maximumHeight, (screen?.height ?? 1080) - margins.top - 8))
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    function updatePlacement() {
        if (anchorItem && barWindow)
            triggerPosition = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width / 2, anchorItem.height);
    }
    TransformWatcher {
        a: menu.anchorItem
        b: menu.barWindow?.contentItem ?? null
        onTransformChanged: menu.updatePlacement()
    }
    Connections {
        target: menu
        function onVisibleChanged() {
            if (!menu.visible) return;
            for (const other of menu.menuGroup) {
                if (other && other !== menu) other.visible = false;
            }
            menu.updatePlacement();
        }
        function onAnchorItemChanged() { menu.updatePlacement(); }
        function onBarWindowChanged() { menu.updatePlacement(); }
    }
    Connections {
        target: menu.anchorItem
        function onWidthChanged() { menu.updatePlacement(); }
    }
    HyprlandFocusGrab {
        active: menu.visible
        windows: [menu]
        onCleared: menu.visible = false
    }
}
