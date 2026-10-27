"""The software-factory skill and its setup script agree on the EGM pin and the Hermes/Grok roles."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SKILL = ROOT / "plugins/herald-os-bridge/skills/software-factory/SKILL.md"
SETUP = ROOT / "scripts/setup-software-factory.sh"
PIN = "3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669"


def test_skill_names_the_factory_roles():
    text = SKILL.read_text(encoding="utf-8")
    assert "name: software-factory" in text
    for needle in (
        "Gnoesis",
        "delegate_task",
        "grok --no-auto-update --always-approve",
        "skills/egm_brainstorm/SKILL.md",
        "skills/egm_draft/SKILL.md",
        "skills/egm_review/SKILL.md",
        "implementation_readiness",
        "GustheTrader/elephant-goldfish-model",
        "GustheTrader/cloudroom-core",
        "GustheTrader/cloudroom-gui",
        "d44dd8b9a6d272a5f601b980c00fade202d00d4c",
        "b5efb8d902fd580262a6b0eeaa130f92d8340f4b",
        PIN,
        "docs/designs",
        "bb-sandboxes",
        "127.0.0.1:9840",
        "CLOUDROOM_TOKEN",
        "GustheTrader/Gnoesisorca",
        "6970cad0d3bfbcc29d8ad266c3edb23338f3daae",
        "rsi-lab",
        "stablyai/orca",
        "recursive self-improvement",
        "orca worktree create",
    ):
        assert needle in text, needle


def test_setup_script_pins_the_same_commits():
    script = SETUP.read_text(encoding="utf-8")
    pins = set(re.findall(r"\b[0-9a-f]{40}\b", script))
    assert pins == {
        PIN,
        "d44dd8b9a6d272a5f601b980c00fade202d00d4c",
        "b5efb8d902fd580262a6b0eeaa130f92d8340f4b",
        "6970cad0d3bfbcc29d8ad266c3edb23338f3daae",
    }
    assert "https://github.com/GustheTrader/elephant-goldfish-model.git" in script
    assert "https://github.com/GustheTrader/cloudroom-core.git" in script
    assert "https://github.com/GustheTrader/cloudroom-gui.git" in script
    assert "https://github.com/GustheTrader/Gnoesisorca.git" in script
    assert "https://github.com/stablyai/orca" in script
    assert '"name": "gnoesis"' in script
    assert '"role": "local-cloud"' in script
    assert '"role": "cloud-space"' in script
    assert '"role": "rsi-lab"' in script
    assert '"appName": "bb-sandboxes"' in script
