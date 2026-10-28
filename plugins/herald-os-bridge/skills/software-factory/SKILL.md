---
name: software-factory
description: Run the Gnoesis SI factory on Herald OS. Hermes designs with the Elephant-Goldfish Model, fresh Goldfish subagents review the spec, Grok writes an approved slice on the desk, Cloudroom is the internal app and the local cloud, and Gnoesisorca is the RSI lab.
metadata:
  hermes:
    tags: [herald-os, gnoesis, software-factory, egm, hermes, grok, cloudroom, gnoesisorca, rsi]
    related_skills: [herald-os, grok]
---

# Gnoesis SI factory

Herald OS is the desk. You (Hermes) are the elephant: you hold the project and write the spec.
Goldfish reviewers are fresh `delegate_task` subagents. The person approves every gate. Grok
(`grok`, xAI's Grok Build CLI) writes an approved slice on the desk and the Studio shows it.
Cloudroom GUI is the internal app. Cloudroom core is the local cloud. Gnoesisorca is the
RSI lab, where the factory tries recursive self-improvement.

Use this when the person asks for Gnoesis, a software factory, EGM, an elephant/goldfish design,
RSI, Gnoesisorca, or a feature that needs a spec before code. A one-screen site or a clear small fix stays on
`build.start` and the Studio path in the `herald-os` skill.

## Where EGM lives

The Elephant-Goldfish Model checkout is `$HERMES_HOME/herald-os/egm` (usually
`~/.hermes/herald-os/egm`), from
[GustheTrader/elephant-goldfish-model](https://github.com/GustheTrader/elephant-goldfish-model)
at commit `3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669`. That tree tracks Google's
[elephant-goldfish-model](https://github.com/google/elephant-goldfish-model) (Apache-2.0).

If `skills/egm_brainstorm/SKILL.md` is missing there, run the Herald OS repo's
`scripts/setup-software-factory.sh` and stop until it finishes. Read EGM's skill files from that
checkout. Do not paraphrase them from memory. The pinned tree names the skill directories with
underscores (`egm_brainstorm`, `egm_draft`, `egm_review`, `egm_resolve`, `egm_drift_report`) and
names the skills inside them with hyphens (`egm-brainstorm`, and so on). A newer checkout that
uses hyphen directories is fine: read whichever of the two files exists.
`$HERMES_HOME/herald-os/software-factory.json` records the checkout after setup.

The supported desks are macOS and Linux with a graphical session. Windows PowerShell alone is
not the full factory desk; use WSL2 or a Mac/Linux machine and read
`docs/SOFTWARE-FACTORY.md` (macOS and Linux, Windows and PowerShell).

`EGM artifact directory: docs/designs` inside the project you are designing.

## Cloudroom

Both checkouts are recorded in `$HERMES_HOME/herald-os/software-factory.json` after setup.

| Piece | Role | Checkout | Pin |
| --- | --- | --- | --- |
| [cloudroom-gui](https://github.com/GustheTrader/cloudroom-gui) | Internal app | `$HERMES_HOME/herald-os/cloudroom-gui` | `b5efb8d902fd580262a6b0eeaa130f92d8340f4b` |
| [cloudroom-core](https://github.com/GustheTrader/cloudroom-core) | Local cloud | `$HERMES_HOME/herald-os/cloudroom-core` | `d44dd8b9a6d272a5f601b980c00fade202d00d4c` |

The internal app is where the person watches a thread and moves it between the desk and the
local cloud. Build notes are `gui/README.md` in the GUI checkout. If the app is already
installed, open it with `os_ui` `native.launch`. It connects to their own core under
Settings → Cloudroom account → Connect your own Core.

The local cloud is one Rust service on their Linux machine. It listens on `127.0.0.1:9840`
unless they changed `CLOUDROOM_LISTEN`. Before you call it, read `docs/setup.md` and
`docs/api.md` in the core checkout. The harnesses it runs are Codex, Claude Code, and Pi.
Grok is the desk builder. It is not a core harness.

Cloudroom's cloud space is Modal. The app name is `bb-sandboxes`, which is the Modal sandbox
plugin's default. Sandboxes in that app are the cloud machines the internal app shows.
The Modal profile is already verified for this account. Credentials are `tokenId` and
`tokenSecret` in Cloudroom's Settings → Plugins → Modal sandbox, the same pair `modal token
set` writes to `~/.modal.toml`. Leave both out of chat, specs, Grok prompts, and git.
`modal profile current` and `modal app list` confirm the space. `room-cli modal account
inspect --json` checks the plugin token without allocating a machine. A new machine is
`room-cli machine create --provider modal-sandbox --json`, and only after the person asks,
because it spends Modal credit.

`CLOUDROOM_TOKEN` is in `/etc/cloudroom/core.env`. The core's `api()` helper in `docs/setup.md`
reads it into curl's config. Leave the token out of chat, specs, Grok prompts, and git.
Reach a core on another machine with Tailscale (`tailscale serve`), as that doc describes.
`tailscale funnel` publishes the API to the internet. Do not use it.

A core that is not answering means the service is not installed yet. Point the person at
`docs/setup.md` in the core checkout and wait. Do not invent a token or start the service
with root unless they ask you to follow that doc.

## RSI lab

Recursive self-improvement of this factory runs in Gnoesisorca. That tree is a fork of
[stablyai/orca](https://github.com/stablyai/orca) (MIT), pinned from
[GustheTrader/Gnoesisorca](https://github.com/GustheTrader/Gnoesisorca) at
`6970cad0d3bfbcc29d8ad266c3edb23338f3daae` (main on 2026-10-21). The checkout is
`$HERMES_HOME/herald-os/gnoesisorca`. Setup records it in `software-factory.json` with role
`rsi-lab`.

Orca runs a fleet of CLI agents — Codex, Claude Code, Grok, Hermes, Pi, and any other agent
that has a terminal — each in its own git worktree. The lab is the place for an experiment
that changes the factory itself: this skill, the setup script, how EGM is applied, or a spec
about the factory. The person watches the fleet in the Orca app or with the `orca` CLI.

If `.github/CONTRIBUTING.md` is missing in the checkout, run `scripts/setup-software-factory.sh`
and stop. Read that file and the checkout README before starting the lab. The pinned tree's
local app is `pnpm install` then `pnpm dev`, and it asks for Node 24. `orca worktree create`
isolates one attempt. A fleet spends the person's own agent subscriptions. Start one only
after they ask. Merge a winner only after they pick it. The setup script pins the tree. It
does not install Orca or start a fleet.

## You are the Hermes harness

EGM skills say "spawn a subagent". On Hermes that is `delegate_task`.

- One Goldfish is one task. Its context is the persona file, the artifact path, and the prompt
  the EGM skill gives you. Leave this conversation out of the task.
- Persona files are `$HERMES_HOME/herald-os/egm/agents/<name>.md`: `zoom_out`, `comprehension`,
  `design_critic`, `codebase_details`, `structural`, `style`, `implementation_readiness`,
  `synthesizer`, `bootstrap_orchestrator`. A skill that names `egm-zoom-out` means
  `agents/zoom_out.md`. Tell the subagent to read that file first.
- Dispatch reviewers in one `delegate_task` batch (`tasks=[...]`) so they do not see each other.
  If a synthesizer subagent cannot spawn its own reviewers, you dispatch them and you write the
  synthesis from their reports.
- A review needs `delegate_task`. If that tool is missing, stop and tell the person. A review
  inside this chat is not a Goldfish review.
- Human gates are one plain question, then you wait. The person answers in Herald OS.

## Gates

Stop at the end of each gate until the person says to continue.

1. **Brainstorm.** Follow `skills/egm_brainstorm/SKILL.md`. Write
   `docs/designs/concepts_brief.md`. Tell them the path and the two or three sharpest objections.
2. **Draft.** Follow `skills/egm_draft/SKILL.md`. It reads the concepts brief. Write
   `docs/designs/<feature>.md`.
3. **Review.** Follow `skills/egm_review/SKILL.md`: comprehension, antagonistic critics, then
   implementation readiness. Apply `skills/egm_resolve/SKILL.md` only for findings the person
   accepts. The spec is ready when a readiness Goldfish says go and the person agrees.
4. **Implement one slice.** After that agreement, ask once where it runs, and keep that answer.
   An experiment that changes the factory itself runs in the RSI lab. A product slice runs on
   the desk, in the local cloud, or in the Modal cloud.
   - **Desk.** Grok, in the project directory. `studio.open` so they can watch. `studio.file`
     on each file Grok changes.
     - `grok` must be on `PATH`. Auth is `~/.grok/auth.json` from `grok login` (SuperGrok or X
       Premium+). Hermes's own xAI login is a different token. If either is missing, say so and
       give the install line `npm install -g @xai-official/grok`. An `XAI_API_KEY` in the
       environment is the fallback they can choose. Wait for them.
     - Prompt Grok with the spec path and one vertical slice from its implementation plan. Pass
       the slice's files, behavior, and tests. Headless, in that directory:

       `grok --no-auto-update --always-approve -p '<slice>'`

       Long runs use the terminal tool with `background=true`. Continue the same Grok session
       with `grok --no-auto-update -c -p '...'`.
     - Run the project's tests. On failure, one `-c` turn to fix them, then stop and show the
       diff. The next slice waits for the person.
   - **Local cloud.** `GET /v1/ready` on the core must report ready. Create a session with
     `POST /v1/sessions`: a new `request_id`, the harness they have signed in (`codex`,
     `claude-code`, or `pi`), and `"workspace"` when this project should have its own cloud
     folder. Send the approved slice as one prompt to
     `/v1/sessions/<id>/prompts`. Watch `/stream` or `/events` until that request completes.
     Tell them the session id and open the internal app. Close the session
     (`POST /v1/sessions/<id>/close`) after they have seen the result. The next slice waits.
   - **Modal cloud.** When they want the slice in Cloudroom's cloud, use the Modal app
     `bb-sandboxes`. Open the internal app, confirm the Modal sandbox plugin has its token,
     and create the machine only after they agree. The machine is the cloud space for that
     slice. Do not put the Modal token in the prompt.
   - **RSI lab.** When the slice changes the factory itself, use the Gnoesisorca checkout.
     One Orca worktree per attempt. Wait until they pick the winner before anything merges.
5. **Drift.** After code has landed, follow `skills/egm_drift_report/SKILL.md` when the repo
   has checked-in specs.

A read-only Grok pass (review a diff, explain a failure) omits `--always-approve`.

## Standing rules

- Specs and briefs are files you write. Product code is Grok's, and only for a slice whose spec
  the person has approved.
- An experiment that rewrites the factory runs in the RSI lab, one worktree per attempt.
- Goldfish tasks carry the artifact and the persona, and nothing from this transcript.
- Say which gate you are on, in one sentence, and the path of the file you just wrote.
- Open the file in the Studio or Files when it is there to show.
