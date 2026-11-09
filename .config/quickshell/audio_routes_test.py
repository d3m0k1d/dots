import copy
import json
import unittest
from unittest.mock import patch

import audio_routes as routes


def snapshot():
    return {"devices": {
        "output": [{"index": 1, "name": "speakers", "serial": "10", "description": "Speakers"},
                   {"index": 2, "name": "headphones", "serial": "20", "description": "Headphones"}],
        "input": [{"index": 3, "name": "mic", "serial": "30", "description": "Microphone"}],
    }, "streams": {
        "51": {"index": 844, "serial": "844", "direction": "output", "target": 1},
        "52": {"index": 845, "serial": "845", "direction": "input", "target": 9},
    }}


class AudioRouteTests(unittest.TestCase):
    def test_playback_move_does_not_change_defaults(self):
        payload = {"nodeId": "51", "streamSerial": "844", "targetName": "headphones", "targetSerial": "20"}
        with patch.object(routes, "snapshot", return_value=snapshot()), patch.object(routes, "pactl") as pactl:
            routes.move(payload)
        pactl.assert_called_once_with("move-sink-input", "844", "headphones")

    def test_recording_move_chooses_input(self):
        payload = {"nodeId": "52", "streamSerial": "845", "targetName": "mic", "targetSerial": "30"}
        with patch.object(routes, "snapshot", return_value=snapshot()), patch.object(routes, "pactl") as pactl:
            routes.move(payload)
        pactl.assert_called_once_with("move-source-output", "845", "mic")

    def test_reused_stream_id_is_rejected(self):
        payload = {"nodeId": "51", "streamSerial": "old", "targetName": "headphones", "targetSerial": "20"}
        with patch.object(routes, "snapshot", return_value=snapshot()), patch.object(routes, "pactl") as pactl:
            with self.assertRaisesRegex(ValueError, "stream changed"):
                routes.move(payload)
        pactl.assert_not_called()

    def test_hot_unplug_or_reused_target_is_rejected(self):
        payload = {"nodeId": "51", "streamSerial": "844", "targetName": "headphones", "targetSerial": "old"}
        with patch.object(routes, "snapshot", return_value=snapshot()), patch.object(routes, "pactl") as pactl:
            with self.assertRaisesRegex(ValueError, "device changed"):
                routes.move(payload)
        pactl.assert_not_called()

    def test_existing_target_is_noop(self):
        payload = {"nodeId": "51", "streamSerial": "844", "targetName": "speakers", "targetSerial": "10"}
        with patch.object(routes, "snapshot", return_value=snapshot()), patch.object(routes, "pactl") as pactl:
            routes.move(payload)
        pactl.assert_not_called()

    def test_direction_cannot_be_overridden(self):
        payload = {"nodeId": "52", "streamSerial": "845", "targetName": "headphones", "targetSerial": "20", "direction": "output"}
        with patch.object(routes, "snapshot", return_value=snapshot()), patch.object(routes, "pactl") as pactl:
            with self.assertRaises(ValueError):
                routes.move(payload)
        pactl.assert_not_called()

    def test_snapshot_only_reads_metadata(self):
        output = [{"index": 67, "name": "device", "description": "Device", "properties": {"object.serial": "67"}}]
        streams = [{"index": 844, "sink": 67, "properties": {"object.id": "51", "object.serial": "844"}},
                   {"index": 999, "sink": 67, "properties": {}}]
        with patch.object(routes, "pactl", side_effect=[json.dumps(output), json.dumps(streams), "[]", "[]"]) as pactl:
            result = routes.snapshot()
        self.assertEqual(result["streams"]["51"]["targetName"], "Device")
        self.assertEqual(len(result["streams"]), 1)
        for call in pactl.call_args_list:
            self.assertEqual(call.args[:3], ("-f", "json", "list"))

    def test_move_does_not_mutate_snapshot(self):
        original = snapshot()
        before = copy.deepcopy(original)
        with patch.object(routes, "snapshot", return_value=original), patch.object(routes, "pactl"):
            routes.move({"nodeId": "51", "streamSerial": "844", "targetName": "headphones", "targetSerial": "20"})
        self.assertEqual(original, before)


if __name__ == "__main__":
    unittest.main()
