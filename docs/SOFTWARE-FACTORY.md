# Gnoesis SI factory

Herald OS, Hermes, Google's Elephant-Goldfish Model, and the Grok Build CLI, with Cloudroom
as the internal app and the local cloud. You approve the spec. A slice then runs on the desk
in Grok, or in the local cloud where the Cloudroom app shows it.

| Role | Who | Job |
| --- | --- | --- |
| Desk | Herald OS | Studio, Files, approvals, the conversation |
| Elephant | Hermes, this session | Holds the project. Writes the spec. Does not write product code |
| Goldfish | Hermes `delegate_task` subagents | Read the spec with no memory of the design conversation |
| You | The person at the desk | Approve each gate |
| Desk builder | `grok` (Grok Build CLI) | Implements one approved slice on this machine |
| Internal app | [Cloudroom GUI](https://github.com/GustheTrader/cloudroom-gui) | Watch a thread and move it between the desk and the local cloud |
| Local cloud | [Cloudroom core](https://github.com/GustheTrader/cloudroom-core) | Self-hosted Rust runtime. Runs Codex, Claude Code, and Pi |

EGM is the [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model)
(Apache-2.0). The factory pins GustheTrader's tree at
[elephant-goldfish-model](https://github.com/GustheTrader/elephant-goldfish-model)
commit `3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669`. Cloudroom core is pinned at
`d44dd8b9a6d272a5f601b980c00fade202d00d4c` and Cloudroom GUI at
`b5efb8d902fd580262a6b0eeaa130f92d8340f4b`. The skill that runs the loop is
`software-factory` in the `herald-os-bridge` plugin.

## Set it up

From a Herald OS checkout, after `npm run bootstrap`:

```bash
scripts/setup-software-factory.sh
npm install -g @xai-official/grok
grok login
```

The script clones three trees under `~/.hermes/herald-os/` and writes
`software-factory.json`:

| Tree | Path | Role |
| --- | --- | --- |
| EGM | `egm/` | Design method. Skills live under `skills/egm_brainstorm/` and the same pattern for draft, review, resolve, and drift |
| Cloudroom core | `cloudroom-core/` | Local cloud. Install the service from `docs/setup.md` in that checkout |
| Cloudroom GUI | `cloudroom-gui/` | Internal app. Build notes are `gui/README.md` |

Re-running the script checks out the same commits. `EGM_REF`, `CLOUDROOM_CORE_REF`, and
`CLOUDROOM_GUI_REF` select other commits.

The core listens on `127.0.0.1:9840` and keeps `CLOUDROOM_TOKEN` in `/etc/cloudroom/core.env`.
Connect the app with Settings → Cloudroom account → Connect your own Core. Another machine
reaches the core through Tailscale, as `docs/setup.md` describes. The setup script only
reports whether something is already listening. It does not install the service or print the
token.

`grok login` uses a SuperGrok or X Premium+ subscription and stores
`~/.grok/auth.json`. That file is separate from the xAI login Hermes uses for its own tools.
Pay-as-you-go via `XAI_API_KEY` works when you choose it; the skill asks before using it.

Optional, so Hermes also has the upstream Grok orchestration notes:

```bash
hermes skills install official/autonomous-ai-agents/grok
```

## Run a feature

In Herald OS, tell Hermes to run the Gnoesis factory and name the feature. It follows five
gates and waits for you at the end of each one:

1. **Brainstorm** writes `docs/designs/concepts_brief.md`.
2. **Draft** writes `docs/designs/<feature>.md`.
3. **Review** sends fresh Goldfish subagents through comprehension, critique, and a readiness
   check. A review inside the design chat does not count.
4. **Implement** asks whether the slice runs on the desk (`grok` in the Studio) or in the
   local cloud (a core session on Codex, Claude Code, or Pi, shown in the Cloudroom app).
5. **Drift** compares the landed code with the checked-in spec.

A one-screen site or a clear bug fix stays on Studio's `build.start` path. The factory is for
work that should be designed before it is coded.

## What lives where

| Piece | Path |
| --- | --- |
| Skill Hermes follows | `plugins/herald-os-bridge/skills/software-factory/SKILL.md` |
| Setup script | `scripts/setup-software-factory.sh` |
| EGM checkout | `$HERMES_HOME/herald-os/egm` |
| Local cloud checkout | `$HERMES_HOME/herald-os/cloudroom-core` |
| Internal app checkout | `$HERMES_HOME/herald-os/cloudroom-gui` |
| Factory record | `$HERMES_HOME/herald-os/software-factory.json` |
| Specs for a project | `<project>/docs/designs/` |
| Grok auth | `~/.grok/auth.json` |
| Core token | `/etc/cloudroom/core.env` (`CLOUDROOM_TOKEN`) |
