# Gnoesis SI factory

Herald OS, Hermes, Google's Elephant-Goldfish Model, and the Grok Build CLI, with Cloudroom
as the internal app and the local cloud, and Gnoesisorca as the lab for recursive
self-improvement. You approve the spec. A product slice then runs on the desk in Grok, in the
local cloud, or in Cloudroom's Modal space. A change to the factory itself is tried in the lab.

| Role | Who | Job |
| --- | --- | --- |
| Desk | Herald OS | Studio, Files, approvals, the conversation |
| Elephant | Hermes, this session | Holds the project. Writes the spec. Does not write product code |
| Goldfish | Hermes `delegate_task` subagents | Read the spec with no memory of the design conversation |
| You | The person at the desk | Approve each gate |
| Desk builder | `grok` (Grok Build CLI) | Implements one approved slice on this machine |
| Internal app | [Cloudroom GUI](https://github.com/GustheTrader/cloudroom-gui) | Watch a thread and move it between the desk and the local cloud |
| Local cloud | [Cloudroom core](https://github.com/GustheTrader/cloudroom-core) | Self-hosted Rust runtime. Runs Codex, Claude Code, and Pi |
| Cloud space | Modal app `bb-sandboxes` | Where Cloudroom's cloud machines run. Token stays in `~/.modal.toml` and in the app's Modal sandbox plugin |
| RSI lab | [Gnoesisorca](https://github.com/GustheTrader/Gnoesisorca) | Fleet desk for recursive self-improvement. Fork of [stablyai/orca](https://github.com/stablyai/orca). Each attempt gets its own worktree |

EGM is the [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model)
(Apache-2.0). The factory pins GustheTrader's tree at
[elephant-goldfish-model](https://github.com/GustheTrader/elephant-goldfish-model)
commit `3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669`. Cloudroom core is pinned at
`d44dd8b9a6d272a5f601b980c00fade202d00d4c` and Cloudroom GUI at
`b5efb8d902fd580262a6b0eeaa130f92d8340f4b`. Gnoesisorca is pinned at
`6970cad0d3bfbcc29d8ad266c3edb23338f3daae`. The skill that runs the loop is
`software-factory` in the `herald-os-bridge` plugin.

## Set it up

From a Herald OS checkout, after `npm run bootstrap`:

```bash
scripts/setup-software-factory.sh
npm install -g @xai-official/grok
grok login
```

The script clones four trees under `~/.hermes/herald-os/` and writes
`software-factory.json`:

| Tree | Path | Role |
| --- | --- | --- |
| EGM | `egm/` | Design method. Skills live under `skills/egm_brainstorm/` and the same pattern for draft, review, resolve, and drift |
| Cloudroom core | `cloudroom-core/` | Local cloud. Install the service from `docs/setup.md` in that checkout |
| Cloudroom GUI | `cloudroom-gui/` | Internal app. Build notes are `gui/README.md` |
| Gnoesisorca | `gnoesisorca/` | RSI lab. Local app notes are `.github/CONTRIBUTING.md` (`pnpm install`, then `pnpm dev`; the tree asks for Node 24) |

Re-running the script checks out the same commits. `EGM_REF`, `CLOUDROOM_CORE_REF`,
`CLOUDROOM_GUI_REF`, and `GNOESISORCA_REF` select other commits. The script records the lab
and does not install Orca or start a fleet. A fleet spends your own agent subscriptions, so
Hermes starts one only after you ask, and merges a winner only after you pick it.

The core listens on `127.0.0.1:9840` and keeps `CLOUDROOM_TOKEN` in `/etc/cloudroom/core.env`.
Connect the app with Settings → Cloudroom account → Connect your own Core. Another machine
reaches the core through Tailscale, as `docs/setup.md` describes. The setup script only
reports whether something is already listening. It does not install the service or print the
token.

Cloudroom's cloud machines run in the Modal app `bb-sandboxes`. `modal token set` writes the
account token to `~/.modal.toml`. Enter the same token id and secret in the app under
Settings → Plugins → Modal sandbox. The setup script records the app name and never the token.

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
4. **Implement** asks where the slice runs: the desk (`grok` in the Studio), the local core,
   Cloudroom's Modal cloud (`bb-sandboxes`, shown in the Cloudroom app), or the Gnoesisorca
   RSI lab when the slice changes the factory itself.
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
| RSI lab checkout | `$HERMES_HOME/herald-os/gnoesisorca` |
| Factory record | `$HERMES_HOME/herald-os/software-factory.json` |
| Specs for a project | `<project>/docs/designs/` |
| Grok auth | `~/.grok/auth.json` |
| Core token | `/etc/cloudroom/core.env` (`CLOUDROOM_TOKEN`) |
| Modal cloud space | Modal app `bb-sandboxes` (profile in `~/.modal.toml`) |
