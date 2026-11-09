import copy
import unittest
from unittest.mock import patch

import network_profiles as backend


def profile():
    result = {key: "" for key in backend.FIELDS}
    result.update({
        "connection.id": "Test profile",
        "connection.uuid": "00000000-0000-4000-8000-000000000001",
        "connection.type": "802-3-ethernet",
        "connection.autoconnect": "yes",
    })
    for family in ("ipv4", "ipv6"):
        result.update({f"{family}.method": "auto", f"{family}.ignore-auto-dns": "no",
                       f"{family}.never-default": "no", f"{family}.route-metric": "-1"})
    return result


class ProfileTests(unittest.TestCase):
    def test_terse_escaping(self):
        self.assertEqual(backend.split_fields(r"name\:office:path\\name:2001\:db8\:\:1"),
                         ["name:office", "path\\name", "2001:db8::1"])

    def test_dhcp_and_dual_stack_static(self):
        values = profile()
        backend.validate(values)
        values.update({"ipv4.method": "manual", "ipv4.addresses": "192.0.2.10/24,192.0.2.11/24",
                       "ipv4.gateway": "192.0.2.1", "ipv4.dns": "1.1.1.1, 9.9.9.9",
                       "ipv6.method": "manual", "ipv6.addresses": "2001:db8::10/64",
                       "ipv6.gateway": "2001:db8::1", "ipv6.dns": "2606:4700:4700::1111"})
        backend.validate(values)

    def test_invalid_settings(self):
        for changes in ({"ipv4.method": "manual"}, {"ipv4.addresses": "192.0.2.1"},
                        {"ipv4.gateway": "::1"}, {"ipv6.dns": "1.1.1.1"},
                        {"ipv4.route-metric": "-2"}, {"connection.id": ""}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                backend.validate({**profile(), **changes})

    def test_save_changes_only_without_reconnect(self):
        original = profile()
        # Preserve route attributes and specialized DNS values when unrelated fields change.
        original["ipv4.routes"] = "{ ip = 198.51.100.0/24, nh = 192.0.2.1, mt = 10 }"
        original["ipv4.dns"] = "1.1.1.1#cloudflare-dns.com"
        changed = {**original, "connection.id": "Renamed"}
        with patch.object(backend, "load", side_effect=[original, changed]), patch.object(backend, "nmcli") as run:
            result = backend.save({"original": original, "changes": {"connection.id": "Renamed"}})
        run.assert_called_once_with("connection", "modify", "uuid", original["connection.uuid"], "connection.id", "Renamed")
        self.assertEqual(result["profile"], changed)

    def test_conflict_does_not_write(self):
        original = profile()
        current = {**original, "ipv4.dns": "9.9.9.9"}
        with patch.object(backend, "load", return_value=current), patch.object(backend, "nmcli") as run:
            with self.assertRaisesRegex(ValueError, "changed elsewhere"):
                backend.save({"original": original, "changes": {"connection.id": "Renamed"}})
        run.assert_not_called()

    def test_invalid_changes_do_not_write(self):
        for changes in ({"connection.uuid": "bad"}, {"ipv4.method": "manual"}):
            with patch.object(backend, "load", return_value=profile()), patch.object(backend, "nmcli") as run:
                with self.assertRaises(ValueError):
                    backend.save({"original": profile(), "changes": changes})
            run.assert_not_called()

    def test_save_does_not_mutate_input(self):
        original = profile()
        snapshot = copy.deepcopy(original)
        with patch.object(backend, "load", return_value=original), patch.object(backend, "nmcli"):
            backend.save({"original": original, "changes": {"ipv4.dns": "1.1.1.1 9.9.9.9"}})
        self.assertEqual(original, snapshot)

    def test_new_profile_has_no_autoconnect_or_activation(self):
        with patch.object(backend, "nmcli") as run, patch.object(backend, "load", return_value=profile()):
            backend.main("create", {"name": "Lab", "interface": "enp1s0"})
        args = run.call_args.args
        self.assertEqual(args[:4], ("connection", "add", "type", "ethernet"))
        self.assertEqual(args[-2:], ("connection.autoconnect", "no"))
        run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
