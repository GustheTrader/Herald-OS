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
        "delegate_task",
        "grok --no-auto-update --always-approve",
        "skills/egm_brainstorm/SKILL.md",
        "skills/egm_draft/SKILL.md",
        "skills/egm_review/SKILL.md",
        "implementation_readiness",
        "GustheTrader/elephant-goldfish-model",
        PIN,
        "docs/designs",
    ):
        assert needle in text, needle


def test_setup_script_pins_the_same_commit():
    script = SETUP.read_text(encoding="utf-8")
    pins = set(re.findall(r"\b[0-9a-f]{40}\b", script))
    assert pins == {PIN}
    assert "https://github.com/GustheTrader/elephant-goldfish-model.git" in script
    assert "software-factory.json" in script
