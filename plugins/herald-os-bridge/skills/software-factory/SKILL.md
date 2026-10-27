---
name: software-factory
description: Run a software factory on Herald OS. Hermes designs with the Elephant-Goldfish Model, fresh Goldfish subagents review the spec, and the Grok Build CLI writes the approved slice.
metadata:
  hermes:
    tags: [herald-os, software-factory, egm, hermes, grok]
    related_skills: [herald-os, grok]
---

# Software factory

Herald OS is the desk. You (Hermes) are the elephant: you hold the project and write the spec.
Goldfish reviewers are fresh `delegate_task` subagents. The person approves every gate. Grok
(`grok`, xAI's Grok Build CLI) writes the code for one approved slice and the Studio shows it.

Use this when the person asks for a software factory, EGM, an elephant/goldfish design, or a
feature that needs a spec before code. A one-screen site or a clear small fix stays on
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

`EGM artifact directory: docs/designs` inside the project you are designing.

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
4. **Implement one slice.** Grok's job, after that agreement.
   - Work in the project directory. `studio.open` so they can watch. `studio.file` on each file
     Grok changes.
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
5. **Drift.** After code has landed, follow `skills/egm_drift_report/SKILL.md` when the repo
   has checked-in specs.

A read-only Grok pass (review a diff, explain a failure) omits `--always-approve`.

## Standing rules

- Specs and briefs are files you write. Product code is Grok's, and only for a slice whose spec
  the person has approved.
- Goldfish tasks carry the artifact and the persona, and nothing from this transcript.
- Say which gate you are on, in one sentence, and the path of the file you just wrote.
- Open the file in the Studio or Files when it is there to show.
