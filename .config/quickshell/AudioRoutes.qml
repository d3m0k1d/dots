import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: routes
    property bool active: false
    property bool available: false
    property var snapshot: ({devices: {output: [], input: []}, streams: {}})
    property string message: ""
    property string operation: ""
    property bool refreshPending: false
    readonly property bool busy: worker.running

    function refresh() {
        if (busy) { refreshPending = true; return; }
        request("list", {});
    }
    function request(action, payload) {
        if (busy) return;
        operation = action;
        worker.result = "";
        worker.command = ["python3", Quickshell.shellPath("audio_routes.py"), action, JSON.stringify(payload)];
        worker.running = true;
    }
    function move(nodeId, target) {
        if (busy) return;
        const stream = snapshot.streams[String(nodeId)];
        if (!stream) { message = "This stream is not routable through PulseAudio."; return; }
        message = "";
        request("move", {nodeId: String(nodeId), streamSerial: stream.serial,
            targetName: target.name, targetSerial: target.serial});
    }
    onActiveChanged: { if (active) refresh(); }

    Process {
        id: worker
        property string result: ""
        stdout: SplitParser { onRead: data => worker.result = data }
        onExited: (exitCode, exitStatus) => {
            try {
                const response = JSON.parse(result);
                if (!response.ok) { routes.message = response.error; routes.available = false; return; }
                routes.snapshot = response.snapshot;
                routes.available = true;
                if (response.message) routes.message = response.message;
            } catch (error) {
                routes.available = false;
                routes.message = "Audio routing unavailable. Check pactl / pipewire-pulse.";
            } finally {
                if (routes.refreshPending) {
                    routes.refreshPending = false;
                    if (routes.active) debounce.restart();
                }
            }
        }
    }
    Process {
        command: ["pactl", "subscribe"]
        environment: ({LC_ALL: "C"})
        running: routes.active
        stdout: SplitParser {
            onRead: data => {
                if (/on (sink-input|source-output|sink|source|server|card)\b/.test(data)) debounce.restart();
            }
        }
    }
    Timer { id: debounce; interval: 150; onTriggered: { if (routes.active) routes.refresh(); } }
    Timer { interval: 5000; running: routes.active; repeat: true; onTriggered: routes.refresh() }
}
