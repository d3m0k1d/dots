import unittest
from unittest.mock import patch

import vpn

VPN_UUID = "00000000-0000-4000-8000-000000000001"
WG_UUID = "00000000-0000-4000-8000-000000000002"


class VpnTests(unittest.TestCase):
    def test_only_saved_vpn_types_are_listed(self):
        profiles = (f"{VPN_UUID}:Office\\: VPN:vpn:tun1\n"
                    f"{WG_UUID}:Lab:wireguard:\n"
                    "00000000-0000-4000-8000-000000000003:External:tun:tun0")
        active = f"{VPN_UUID}:activated:tun1"
        devices = "tun1:tun:connected\ntun0:tun:connected (externally)\nenp1s0:ethernet:connected"
        with patch.object(vpn, "nmcli", side_effect=[profiles, active, devices]), patch.object(vpn, "details", return_value={}) as details:
            result = vpn.snapshot()
        self.assertEqual([item["name"] for item in result["profiles"]], ["Office: VPN", "Lab"])
        self.assertTrue(result["profiles"][0]["connected"])
        self.assertFalse(result["profiles"][1]["connected"])
        self.assertEqual(result["otherTunnels"][0]["device"], "tun0")
        self.assertEqual(len(result["otherTunnels"]), 1)
        details.assert_called_once_with(VPN_UUID)

    def test_ipv6_and_indexed_dns_are_decoded(self):
        output = "IP4.ADDRESS[1]:192.0.2.5/24\nIP6.ADDRESS[1]:2001\\:db8\\:\\:1/64\nIP4.DNS[1]:1.1.1.1\nIP4.DNS[2]:9.9.9.9"
        with patch.object(vpn, "nmcli", return_value=output):
            result = vpn.details(VPN_UUID)
        self.assertEqual(result["IP6.ADDRESS"], ["2001:db8::1/64"])
        self.assertEqual(result["IP4.DNS"], ["1.1.1.1", "9.9.9.9"])

    def test_external_tunnel_cannot_be_disconnected(self):
        with patch.object(vpn, "nmcli", return_value="tun") as run:
            with self.assertRaisesRegex(ValueError, "read-only"):
                vpn.main("down", {"uuid": VPN_UUID})
        run.assert_called_once()

    def test_actions_use_uuid_without_shell(self):
        for action in ("up", "down"):
            with self.subTest(action=action), patch.object(vpn, "nmcli", side_effect=["wireguard", ""]) as run:
                vpn.main(action, {"uuid": WG_UUID})
                self.assertEqual(run.call_args.args, ("connection", action, "uuid", WG_UUID))

    def test_invalid_uuid_never_runs_a_command(self):
        with patch.object(vpn, "nmcli") as run:
            with self.assertRaises(ValueError):
                vpn.main("up", {"uuid": "not-a-uuid; reboot"})
        run.assert_not_called()

    def test_unknown_operation_is_rejected(self):
        with patch.object(vpn, "nmcli") as run:
            with self.assertRaises(ValueError):
                vpn.main("remove", {"uuid": VPN_UUID})
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
