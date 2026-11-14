import json
import subprocess


def test_durable_available_outside_herald(plugin, monkeypatch, tmp_path):
    from importlib import import_module
    durable = import_module(plugin.__name__ + ".bridge.durable")
    launcher = tmp_path / "pi-durable/bin/hermes-tool.sh"
    launcher.parent.mkdir(parents=True)
    launcher.touch()
    binary = tmp_path / "crates/hermes-durable/target/release/hermes-durable"
    binary.parent.mkdir(parents=True)
    binary.touch()
    monkeypatch.setattr(durable, "LAUNCHER", launcher)
    monkeypatch.delenv("HERALD_OS", raising=False)
    assert durable.available()


def test_lost_response_preserves_retry_identity(plugin, monkeypatch):
    from importlib import import_module
    durable = import_module(plugin.__name__ + ".bridge.durable")
    def timeout(*args, **kwargs):
        raise subprocess.TimeoutExpired(args[0], 25)
    monkeypatch.setattr(durable.subprocess, "run", timeout)
    result = json.loads(durable.handle({"action": "submit", "request_id": "stable-task"}))
    assert "preserve request_id" in result["error"]
