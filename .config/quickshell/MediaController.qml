import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Scope {
    property var players: Mpris.players.values
    property string selectedPlayer: ""
    readonly property var player: players.find(item => item.dbusName === selectedPlayer)
        ?? players.find(item => item.isPlaying) ?? players[0] ?? null
    onPlayersChanged: {
        if (selectedPlayer && !players.some(item => item.dbusName === selectedPlayer)) selectedPlayer = "";
    }
}
