import importlib.util
import pathlib
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "herdr-workspace-cwd.py"
SPEC = importlib.util.spec_from_file_location("herdr_workspace_cwd", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CompactPathTests(unittest.TestCase):
    def test_home_is_compacted(self):
        with mock.patch.object(MODULE.os.path, "expanduser", return_value="/home/wiz"):
            self.assertEqual(MODULE.compact_path("/home/wiz"), "~")
            self.assertEqual(MODULE.compact_path("/home/wiz/src"), "~/src")
            self.assertEqual(MODULE.compact_path("/srv/app"), "/srv/app")


class SyncLabelsTests(unittest.TestCase):
    def test_creates_initial_workspace(self):
        responses = [{"snapshot": {"workspaces": [], "panes": []}}, {}]
        with mock.patch.object(MODULE, "request", side_effect=responses) as request:
            MODULE.sync_labels()
        request.assert_has_calls(
            [
                mock.call("session.snapshot", {}),
                mock.call(
                    "workspace.create",
                    {"cwd": str(pathlib.Path.home()), "focus": False},
                ),
            ]
        )

    def test_renames_workspace_to_focused_pane_directory(self):
        snapshot = {
            "snapshot": {
                "workspaces": [{"workspace_id": "w1", "label": "old"}],
                "panes": [
                    {
                        "workspace_id": "w1",
                        "focused": True,
                        "foreground_cwd": "/srv/app",
                    }
                ],
            }
        }
        with mock.patch.object(MODULE, "request", side_effect=[snapshot, {}]) as request:
            MODULE.sync_labels()
        request.assert_called_with(
            "workspace.rename", {"workspace_id": "w1", "label": "/srv/app"}
        )

    def test_does_not_rename_when_label_is_current(self):
        snapshot = {
            "snapshot": {
                "workspaces": [{"workspace_id": "w1", "label": "/srv/app"}],
                "panes": [{"workspace_id": "w1", "cwd": "/srv/app"}],
            }
        }
        with mock.patch.object(MODULE, "request", return_value=snapshot) as request:
            MODULE.sync_labels()
        request.assert_called_once_with("session.snapshot", {})


if __name__ == "__main__":
    unittest.main()
