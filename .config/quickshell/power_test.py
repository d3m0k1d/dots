import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import power


class PowerTests(unittest.TestCase):
    def test_unknown_action_does_not_run(self):
        with patch.object(power, "run") as run:
            with self.assertRaises(ValueError):
                power.execute("anything", "lua")
            run.assert_not_called()

    def test_invalid_mode_does_not_run(self):
        with patch.object(power, "run") as run:
            with self.assertRaises(ValueError):
                power.execute("reboot", "invalid")
            run.assert_not_called()

    def test_power_actions_do_not_force_or_use_sudo(self):
        for action in ("suspend", "reboot", "poweroff"):
            with self.subTest(action=action), patch.object(power, "prepare_suspend"), patch.object(power, "run") as run:
                power.execute(action, "lua")
                run.assert_called_once_with("systemctl", "--no-ask-password", action)

    def test_logout_modes(self):
        with patch.object(power, "run") as run:
            power.execute("logout", "lua")
            run.assert_called_once_with("hyprctl", "eval", "hl.dispatch(hl.dsp.exit())")
        with patch.object(power, "run") as run:
            power.execute("logout", "legacy")
            run.assert_called_once_with("hyprctl", "dispatch", "exit")

    def test_lock_is_separate_from_suspend(self):
        with patch.object(power, "lock_session") as lock, patch.object(power, "run") as run:
            power.execute("lock", "lua")
            lock.assert_called_once_with()
            run.assert_not_called()

    def test_missing_locker_does_not_launch(self):
        with patch.object(power.shutil, "which", return_value=None), patch.object(power.subprocess, "Popen") as spawn:
            with self.assertRaisesRegex(RuntimeError, "Install hyprlock"):
                power.lock_session()
            spawn.assert_not_called()

    def test_suspend_is_cancelled_if_lock_cannot_be_verified(self):
        with patch.object(power, "prepare_suspend", side_effect=RuntimeError("not locked")), patch.object(power, "run") as run:
            with self.assertRaises(RuntimeError):
                power.execute("suspend", "lua")
            run.assert_not_called()

    def test_waits_for_real_guard_lock_state(self):
        with patch.dict(power.os.environ, {"XDG_SESSION_ID": "3"}), patch.object(power, "sleep_guard_owner", return_value=":1.99"), \
                patch.object(power, "guard_locked", side_effect=[False, False, True]), patch.object(power.time, "sleep"), patch.object(power, "run") as run:
            power.prepare_suspend()
        run.assert_called_once_with("loginctl", "lock-session", "3")

    def test_lock_timeout_never_suspends(self):
        with patch.dict(power.os.environ, {"XDG_SESSION_ID": "3"}), patch.object(power, "sleep_guard_owner", return_value=":1.99"), \
                patch.object(power, "guard_locked", return_value=False), patch.object(power, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "did not confirm"):
                power.prepare_suspend(timeout=0)
        run.assert_called_once_with("loginctl", "lock-session", "3")

    def test_guard_must_match_current_compositor_and_uid(self):
        with patch.dict(power.os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "current"}), \
                patch.object(power, "bus_call", side_effect=[":1.99", 123]), \
                patch.object(Path, "stat", return_value=SimpleNamespace(st_uid=power.os.getuid())), \
                patch.object(Path, "read_text", return_value="hypridle\n"), \
                patch.object(Path, "read_bytes", return_value=b"HYPRLAND_INSTANCE_SIGNATURE=current\0"):
            self.assertEqual(power.sleep_guard_owner(), ":1.99")
        with patch.dict(power.os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "current"}), \
                patch.object(power, "bus_call", side_effect=[":1.99", 123]), \
                patch.object(Path, "stat", return_value=SimpleNamespace(st_uid=power.os.getuid())), \
                patch.object(Path, "read_text", return_value="hypridle\n"), \
                patch.object(Path, "read_bytes", return_value=b"HYPRLAND_INSTANCE_SIGNATURE=another-session\0"):
            with self.assertRaisesRegex(RuntimeError, "Suspend cancelled"):
                power.sleep_guard_owner()


if __name__ == "__main__":
    unittest.main()
