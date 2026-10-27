# Software factory

Herald OS, Hermes, Google's Elephant-Goldfish Model, and the Grok Build CLI, in one loop.
You approve the spec. Grok writes one slice of it. You watch that slice in the Studio.

| Role | Who | Job |
| --- | --- | --- |
| Desk | Herald OS | Studio, Files, approvals, the conversation |
| Elephant | Hermes, this session | Holds the project. Writes the spec. Does not write product code |
| Goldfish | Hermes `delegate_task` subagents | Read the spec with no memory of the design conversation |
| You | The person at the desk | Approve each gate |
| Builder | `grok` (Grok Build CLI) | Implements one approved slice |

EGM is the [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model)
(Apache-2.0). The factory pins the tree at
[GustheTrader/elephant-goldfish-model](https://github.com/GustheTrader/elephant-goldfish-model)
commit `3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669`. The skill that runs the loop is
`software-factory` in the `herald-os-bridge` plugin.

## Set it up

From a Herald OS checkout, after `npm run bootstrap`:

```bash
scripts/setup-software-factory.sh
npm install -g @xai-official/grok
grok login
```

The script clones EGM into `~/.hermes/herald-os/egm` and writes
`~/.hermes/herald-os/software-factory.json`, including the skill files it found.
The pinned tree keeps those files under `skills/egm_brainstorm/` and the same pattern
for draft, review, resolve, and drift. Re-running the script checks out the same commit.
`EGM_REF` selects another commit.

`grok login` uses a SuperGrok or X Premium+ subscription and stores
`~/.grok/auth.json`. That file is separate from the xAI login Hermes uses for its own tools.
Pay-as-you-go via `XAI_API_KEY` works when you choose it; the skill asks before using it.

Optional, so Hermes also has the upstream Grok orchestration notes:

```bash
hermes skills install official/autonomous-ai-agents/grok
```

## Run a feature

In Herald OS, tell Hermes to run the software factory and name the feature. It follows five
gates and waits for you at the end of each one:

1. **Brainstorm** writes `docs/designs/concepts_brief.md`.
2. **Draft** writes `docs/designs/<feature>.md`.
3. **Review** sends fresh Goldfish subagents through comprehension, critique, and a readiness
   check. A review inside the design chat does not count.
4. **Implement** hands one vertical slice to `grok --no-auto-update --always-approve -p …`
   in the project directory, runs the tests, and opens the Studio.
5. **Drift** compares the landed code with the checked-in spec.

A one-screen site or a clear bug fix stays on Studio's `build.start` path. The factory is for
work that should be designed before it is coded.

## What lives where

| Piece | Path |
| --- | --- |
| Skill Hermes follows | `plugins/herald-os-bridge/skills/software-factory/SKILL.md` |
| Setup script | `scripts/setup-software-factory.sh` |
| EGM checkout | `$HERMES_HOME/herald-os/egm` |
| Specs for a project | `<project>/docs/designs/` |
| Grok auth | `~/.grok/auth.json` |
