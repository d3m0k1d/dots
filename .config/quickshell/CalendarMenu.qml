import QtQuick
import QtQuick.Controls as Controls
import Quickshell

PanelMenu {
    id: menu
    contentHeight: body.implicitHeight
    preferredWidth: 360
    property date displayedMonth: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1, 12)
    property date selectedDate: clock.date
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property real cellWidth: (body.width - 24) / 7
    SystemClock { id: clock; precision: SystemClock.Seconds }

    function toggle() { visible = !visible; }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function dateForCell(index) {
        const first = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1, 12);
        const offset = (first.getDay() + 6) % 7;
        return new Date(first.getFullYear(), first.getMonth(), 1 - offset + index, 12);
    }
    function changeMonth(step) { displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + step, 1, 12); }
    function today() {
        selectedDate = clock.date;
        displayedMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1, 12);
    }
    function formatDate(date) { return weekdays[date.getDay()] + ", " + date.getDate() + " " + months[date.getMonth()] + " " + date.getFullYear(); }

    Rectangle {
        anchors.fill: parent
        color: "black"
        radius: 15
        focus: true
        Keys.onEscapePressed: menu.visible = false
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
                    MenuLabel { text: "Calendar"; width: parent.width - 36; height: 36; verticalAlignment: Text.AlignVCenter }
                    MenuButton { width: 36; text: "×"; onClicked: menu.visible = false }
                }
                MenuLabel { text: Qt.formatDateTime(clock.date, "HH:mm:ss"); font.pixelSize: 24 }
                MenuLabel { width: parent.width; text: menu.formatDate(clock.date); color: "#aaaaaa"; font.pixelSize: 12 }
                Row {
                    width: parent.width
                    spacing: 6
                    MenuButton { text: "‹"; width: 32; onClicked: menu.changeMonth(-1) }
                    MenuLabel { text: menu.months[menu.displayedMonth.getMonth()] + " " + menu.displayedMonth.getFullYear(); width: parent.width - 76; height: 36; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    MenuButton { text: "›"; width: 32; onClicked: menu.changeMonth(1) }
                }
                Grid {
                    columns: 7
                    spacing: 4
                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        MenuLabel { required property string modelData; text: modelData; width: menu.cellWidth; horizontalAlignment: Text.AlignHCenter; color: "#aaaaaa"; font.pixelSize: 12 }
                    }
                }
                Grid {
                    columns: 7
                    spacing: 4
                    Repeater {
                        model: 42
                        Rectangle {
                            id: day
                            required property int index
                            readonly property date date: menu.dateForCell(index)
                            readonly property bool selected: menu.sameDay(date, menu.selectedDate)
                            readonly property bool isToday: menu.sameDay(date, clock.date)
                            width: menu.cellWidth
                            height: 30
                            radius: 6
                            color: selected ? "white" : pointer.containsMouse ? "#202020" : "transparent"
                            border.width: isToday && !selected ? 1 : 0
                            border.color: "white"
                            MenuLabel {
                                anchors.centerIn: parent
                                text: day.date.getDate()
                                color: day.selected ? "black" : day.date.getMonth() === menu.displayedMonth.getMonth() ? "white" : "#666666"
                            }
                            MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.selectedDate = day.date }
                        }
                    }
                }
                MenuLabel { width: parent.width; text: menu.formatDate(menu.selectedDate); color: "#aaaaaa"; font.pixelSize: 12 }
                MenuButton { width: parent.width; text: "Today"; textAlignment: Text.AlignHCenter; onClicked: menu.today() }
            }
        }
    }
}
