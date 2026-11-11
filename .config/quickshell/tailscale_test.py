import unittest
from unittest.mock import patch

import tailscale


class TailscaleTests(unittest.TestCase):
    def test_snapshot_normalizes_peers(self):
        data = '{"BackendState":"Running","Self":{"HostName":"box","DNSName":"box.tail.ts.net.","TailscaleIPs":["100.64.0.1"]},"CurrentTailnet":{"Name":"tailnet"},"Peer":{"1":{"HostName":"node","DNSName":"node.tail.ts.net.","TailscaleIPs":["100.64.0.2"],"Online":true,"OS":"linux"}}}'
        with patch.object(tailscale, "run", return_value=data), patch.object(tailscale.shutil, "which", return_value="/usr/bin/tailscale"):
            result = tailscale.snapshot()
        self.assertEqual(result["state"], "Running")
        self.assertEqual(result["dnsName"], "box.tail.ts.net")
        self.assertEqual(result["peers"][0]["ips"], ["100.64.0.2"])

    def test_headscale_requires_http_url(self):
        with self.assertRaisesRegex(ValueError, "http"):
            tailscale.action("up", {"server": "headscale.local"})

    def test_headscale_passes_login_server(self):
        with patch.object(tailscale, "privileged", return_value="") as command:
            tailscale.action("up", {"server": "https://hs.example", "authKey": "tskey-auth-test"})
        command.assert_called_once_with("up", "--accept-dns=true", "--login-server", "https://hs.example", "--auth-key", "tskey-auth-test")

    def test_snapshot_handles_logged_out_nullable_fields(self):
        data = '{"BackendState":"NeedsLogin","Self":{"HostName":"box"},"CurrentTailnet":null,"Peer":null}'
        with patch.object(tailscale, "run", side_effect=[data, '{"CorpDNS":false,"RouteAll":true,"AdvertiseRoutes":["192.168.1.0/24"]}']), patch.object(tailscale.shutil, "which", return_value="/usr/bin/tailscale"):
            result = tailscale.snapshot()
        self.assertFalse(result["acceptDns"])
        self.assertTrue(result["acceptRoutes"])
        self.assertEqual(result["advertiseRoutes"], ["192.168.1.0/24"])

    def test_set_preferences_uses_explicit_flags(self):
        with patch.object(tailscale, "privileged", return_value="") as command:
            tailscale.action("set", {"acceptDns": False, "acceptRoutes": True, "advertiseRoutes": "192.168.1.0/24"})
        command.assert_called_once_with("set", "--accept-dns=false", "--accept-routes=true", "--advertise-routes", "192.168.1.0/24")

    def test_control_requires_noninteractive_sudo(self):
        with patch.object(tailscale, "run", side_effect=[RuntimeError("access denied"), ""]) as run:
            tailscale.privileged("down")
        self.assertEqual(run.call_args.args[:4], ("sudo", "-n", "--", "tailscale"))


if __name__ == "__main__":
    unittest.main()
