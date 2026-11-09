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

    def test_control_requires_noninteractive_sudo(self):
        with patch.object(tailscale, "run", return_value="") as run:
            tailscale.privileged("down")
        self.assertEqual(run.call_args.args[:4], ("sudo", "-n", "--", "tailscale"))


if __name__ == "__main__":
    unittest.main()
