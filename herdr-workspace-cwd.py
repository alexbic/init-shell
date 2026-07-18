#!/usr/bin/env python3
"""Keep each Herdr workspace label synchronized with its active pane directory."""

import json
import os
import socket
import time

SOCKET = os.environ.get(
    "HERDR_SOCKET", os.path.expanduser("~/.config/herdr/herdr.sock")
)
POLL_SECONDS = float(os.environ.get("HERDR_CWD_POLL_SECONDS", "2"))


def request(method, params):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(5)
    try:
        client.connect(SOCKET)
        message = {"id": "workspace-cwd", "method": method, "params": params}
        client.sendall((json.dumps(message) + "\n").encode())
        response = json.loads(client.makefile().readline())
        if "error" in response:
            raise RuntimeError(response["error"])
        return response.get("result", {})
    finally:
        client.close()


def compact_path(path):
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        return "~" + path[len(home) :]
    return path


def sync_labels():
    result = request("session.snapshot", {})
    snapshot = result.get("snapshot", result)
    workspaces = {item["workspace_id"]: item for item in snapshot.get("workspaces", [])}
    panes = snapshot.get("panes", [])

    if not workspaces:
        request("workspace.create", {"cwd": os.path.expanduser("~"), "focus": False})
        return

    for workspace_id, workspace in workspaces.items():
        candidates = [pane for pane in panes if pane.get("workspace_id") == workspace_id]
        if not candidates:
            continue
        pane = next((item for item in candidates if item.get("focused")), None)
        if pane is None:
            active_tab = workspace.get("active_tab_id")
            pane = next(
                (item for item in candidates if item.get("tab_id") == active_tab),
                candidates[0],
            )
        cwd = pane.get("foreground_cwd") or pane.get("cwd")
        if not cwd:
            continue
        label = compact_path(cwd)
        if workspace.get("label") != label:
            request("workspace.rename", {"workspace_id": workspace_id, "label": label})


def main():
    while True:
        try:
            sync_labels()
        except (OSError, ValueError, RuntimeError) as error:
            print(f"herdr-workspace-cwd: {error}", flush=True)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
