import unittest
from pathlib import Path
from unittest.mock import patch

import keyboard

REGISTRY_XML = """<xkbConfigRegistry><layoutList>
<layout><configItem><name>us</name><shortDescription>en</shortDescription><description>English (US)</description><languageList><iso639Id>eng</iso639Id></languageList></configItem></layout>
<layout><configItem><name>ru</name><shortDescription>ru</shortDescription><description>Russian</description><languageList><iso639Id>rus</iso639Id></languageList></configItem></layout>
<layout><configItem><name>de</name><description>German</description><languageList><iso639Id>deu</iso639Id></languageList></configItem></layout>
<layout><configItem><name>br</name><description>Portuguese (Brazil)</description><languageList><iso639Id>por</iso639Id></languageList></configItem></layout>
<layout><configItem><name>latam</name><description>Spanish (Latin American)</description><languageList><iso639Id>spa</iso639Id></languageList></configItem></layout>
<layout><configItem><name>jp</name><description>Japanese</description><languageList><iso639Id>jpn</iso639Id></languageList></configItem></layout>
<layout><configItem><name>cn</name><description>Chinese</description><languageList><iso639Id>zho</iso639Id></languageList></configItem></layout>
<layout><configItem><name>ara</name><description>Arabic</description><languageList><iso639Id>ara</iso639Id></languageList></configItem></layout>
<layout><configItem><name>in</name><description>Indian</description><languageList><iso639Id>hin</iso639Id></languageList></configItem>
<variantList><variant><configItem><name>ben</name><description>Bangla (India)</description><languageList><iso639Id>ben</iso639Id></languageList></configItem></variant></variantList></layout>
<layout><configItem><name>ca</name><description>French (Canada)</description><languageList><iso639Id>fra</iso639Id></languageList></configItem>
<variantList><variant><configItem><name>eng</name><description>English (Canada)</description><languageList><iso639Id>eng</iso639Id></languageList></configItem></variant>
<variant><configItem><name>legacy</name><description>French (Canada, legacy)</description></configItem></variant></variantList></layout>
<layout><configItem><name>rare</name><description>Kabyle</description><languageList><iso639Id>kab</iso639Id></languageList></configItem></layout>
</layoutList></xkbConfigRegistry>"""
LANGUAGE_CODES = {"eng": "EN", "rus": "RU", "deu": "DE", "por": "PT", "spa": "ES",
                  "jpn": "JA", "zho": "ZH", "ara": "AR", "hin": "HI", "ben": "BN", "fra": "FR"}


def fixture_registry():
    records = keyboard.registry_from_xml(keyboard.ElementTree.fromstring(REGISTRY_XML), LANGUAGE_CODES)
    descriptions = {item["description"].casefold(): item["label"] for item in records.values()}
    return records, descriptions


class KeyboardTests(unittest.TestCase):
    def setUp(self):
        patcher = patch.object(keyboard, "layout_registry", return_value=fixture_registry())
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_main_keyboard_not_first_hid_device(self):
        state = keyboard.keyboard_state({"keyboards": [
            {"name": "mouse-hid", "layout": "us,ru", "active_layout_index": 0, "capsLock": True},
            {"name": "real-keyboard", "main": True, "layout": "us, ru", "active_layout_index": 1,
             "active_keymap": "Russian", "capsLock": False},
        ]})
        self.assertEqual(state["keyboard"], "real-keyboard")
        self.assertEqual(state["label"], "RU")
        self.assertFalse(state["caps"])

    def test_english_and_caps_lock(self):
        state = keyboard.keyboard_state({"keyboards": [
            {"name": "keyboard", "main": True, "layout": "us,ru", "active_layout_index": 0, "capsLock": True},
        ]})
        self.assertEqual(state["label"], "EN")
        self.assertTrue(state["caps"])

    def test_additional_layout(self):
        state = keyboard.keyboard_state({"keyboards": [
            {"name": "keyboard", "layout": "us,ru,de", "active_layout_index": 2},
        ]})
        self.assertEqual(state["label"], "DE")
        self.assertIsNone(state["caps"])

    def test_missing_keyboard(self):
        self.assertEqual(keyboard.keyboard_state({"keyboards": []}), {"available": False})

    def test_old_hyprland_layout_title_fallback(self):
        state = keyboard.keyboard_state({"keyboards": [
            {"name": "keyboard", "main": True, "layout": "us,ru", "active_keymap": "Russian"},
        ]})
        self.assertEqual(state["label"], "RU")

    def test_next_targets_only_selected_keyboard(self):
        with patch.object(keyboard, "request", return_value="ok\n") as request:
            keyboard.switch_layout(Path("/fake/socket"), {"available": True, "keyboard": "real-keyboard"})
        request.assert_called_once_with(Path("/fake/socket"), "switchxkblayout real-keyboard next")

    def test_invalid_device_names_never_send_ipc(self):
        for name in ("bad name", "bad\nname", "bad;name", "bad\x00name", ""):
            with self.subTest(name=name), patch.object(keyboard, "request") as request:
                with self.assertRaises(ValueError):
                    keyboard.switch_layout("socket", {"available": True, "keyboard": name})
                request.assert_not_called()

    def test_switch_failure_is_reported(self):
        with patch.object(keyboard, "request", return_value="device not found"):
            with self.assertRaises(ValueError):
                keyboard.switch_layout("socket", {"available": True, "keyboard": "keyboard"})

    def test_state_request_is_read_only(self):
        with patch.object(keyboard.socket, "socket") as socket:
            client = socket.return_value.__enter__.return_value
            client.recv.side_effect = [b'{"keyboards":[]}', b""]
            self.assertEqual(keyboard.request("/fake/socket", "j/devices"), '{"keyboards":[]}')
        client.sendall.assert_called_once_with(b"j/devices")

    def test_paths_use_current_session(self):
        with patch.dict(keyboard.os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "instance", "XDG_RUNTIME_DIR": "/run/user/123"}, clear=True):
            self.assertEqual(keyboard.socket_paths(), (Path("/run/user/123/hypr/instance/.socket.sock"), Path("/run/user/123/hypr/instance/.socket2.sock")))

    def test_language_codes_not_country_codes(self):
        for layout, expected in {"br": "PT", "latam": "ES", "jp": "JA", "cn": "ZH", "ara": "AR", "ca": "FR"}.items():
            with self.subTest(layout=layout):
                state = keyboard.keyboard_state({"keyboards": [{"name": "keyboard", "layout": layout, "active_layout_index": 0}]})
                self.assertEqual(state["label"], expected)

    def test_variant_language_overrides_base_layout(self):
        state = keyboard.keyboard_state({"keyboards": [{"name": "keyboard", "layout": "us,in", "variant": ",ben", "active_layout_index": 1}]})
        self.assertEqual(state["label"], "BN")

    def test_inline_variant(self):
        state = keyboard.keyboard_state({"keyboards": [{"name": "keyboard", "layout": "ca(eng)", "active_layout_index": 0}]})
        self.assertEqual(state["label"], "EN")

    def test_variant_inherits_base_language(self):
        self.assertEqual(keyboard.layout_label("ca", "legacy", ""), "FR")

    def test_languages_without_two_letter_code(self):
        self.assertEqual(keyboard.layout_label("rare", "", ""), "KAB")

    def test_missing_metadata_uses_layout_code(self):
        with patch.object(keyboard, "layout_registry", return_value=({}, {})):
            self.assertEqual(keyboard.layout_label("custom-layout", "", ""), "CUSTOM-LAYOUT")
            self.assertEqual(keyboard.layout_label("", "", ""), "KB")

    def test_title_fallback_is_language_independent(self):
        state = keyboard.keyboard_state({"keyboards": [{"name": "keyboard", "main": True, "active_keymap": "Arabic"}]})
        self.assertEqual(state["label"], "AR")


class LanguageDataTests(unittest.TestCase):
    def test_iso_two_letter_and_bibliographic_aliases(self):
        data = '{"639-3": [{"alpha_2":"de","alpha_3":"deu","bibliographic":"ger"},{"alpha_3":"kab"}]}'
        with patch.object(Path, "read_text", return_value=data):
            codes = keyboard.language_codes()
        self.assertEqual(codes["deu"], "DE")
        self.assertEqual(codes["ger"], "DE")
        self.assertEqual(codes["kab"], "KAB")

    def test_missing_iso_files_do_not_crash(self):
        with patch.object(Path, "read_text", side_effect=FileNotFoundError):
            self.assertEqual(keyboard.language_codes(), {})


if __name__ == "__main__":
    unittest.main()
