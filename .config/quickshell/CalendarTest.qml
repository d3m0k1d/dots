//@ pragma UseQApplication
import QtQuick
import Quickshell
import "." as Widgets

ShellRoot {
    property int failures: 0
    function check(value, label) {
        console.log(value ? "PASS:" : "FAIL:", label);
        if (!value) failures++;
    }
    Widgets.CalendarMenu { id: calendar }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            calendar.displayedMonth = new Date(2024, 0, 1, 12);
            check(calendar.sameDay(calendar.dateForCell(0), new Date(2024, 0, 1)), "Monday-first grid");
            calendar.displayedMonth = new Date(2024, 1, 1, 12);
            check(calendar.sameDay(calendar.dateForCell(0), new Date(2024, 0, 29)), "previous-month padding");
            check(calendar.sameDay(calendar.dateForCell(31), new Date(2024, 1, 29)), "leap day");
            check(calendar.sameDay(calendar.dateForCell(32), new Date(2024, 2, 1)), "next-month padding");
            calendar.displayedMonth = new Date(2024, 11, 1, 12);
            calendar.changeMonth(1);
            check(calendar.displayedMonth.getFullYear() === 2025 && calendar.displayedMonth.getMonth() === 0, "year rollover");
            calendar.changeMonth(-1);
            check(calendar.displayedMonth.getFullYear() === 2024 && calendar.displayedMonth.getMonth() === 11, "previous year");
            check(calendar.formatDate(new Date(2024, 1, 29)) === "Thursday, 29 February 2024", "English labels");
            calendar.today();
            check(calendar.sameDay(calendar.selectedDate, new Date()), "Today resets selection");
            console.log("Failures:", failures);
            Qt.exit(failures ? 1 : 0);
        }
    }
}
