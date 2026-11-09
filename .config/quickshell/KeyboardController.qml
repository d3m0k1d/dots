import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: keyboard
    property var state: ({available: false})
    function nextLayout() {
        if (state.available && monitor.running) monitor.write("next\n");
    }
    Process {
        id: monitor
        command: ["python3", Quickshell.shellPath("keyboard.py")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try { keyboard.state = JSON.parse(data); }
                catch (error) { console.warn("Invalid keyboard status"); }
            }
        }
        onExited: keyboard.state = ({available: false})
    }
}
