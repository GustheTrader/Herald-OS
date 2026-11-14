from __future__ import annotations

import json
import subprocess
from pathlib import Path

LAUNCHER = Path("/home/workspace/Projects/Durable Gnoesis Agents Swarm/pi-durable/bin/hermes-tool.sh")
SCHEMA = {
    "name": "factory_durable",
    "description": "Delegate authorized work to checkpointed Pi, list sessions, or check a submission. Use an existing session id. For submit choose a stable request_id and preserve it with the exact prompt across retries. Interrupted side effects require inspection, never blind replay. Hermes conversation itself is not checkpointed by this tool.",
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["sessions", "submit", "status"]},
            "session": {"type": "string"},
            "request_id": {"type": "string"},
            "prompt": {"type": "string"},
            "submission_id": {"type": "integer"},
        },
        "required": ["action"],
    },
}


def available():
    return LAUNCHER.is_file() and (LAUNCHER.parents[2] / "crates/hermes-durable/target/release/hermes-durable").is_file()


def handle(args, **kwargs):
    try:
        result = subprocess.run(["bash", str(LAUNCHER)], input=json.dumps(args), capture_output=True, text=True, timeout=25)
        return result.stdout.strip() or json.dumps({"error": "durable client failed; preserve request_id when retrying"})
    except (OSError, subprocess.TimeoutExpired):
        return json.dumps({"error": "durable client unavailable; preserve request_id and prompt when retrying"})
