# Goldfish Annotated Review Report

**Target:** `docs/designs/kanban-board.md` (lines 1–535)
**Status:** awaiting the person's decision
**Date:** 2026-10-28

## How this review ran

Seven fresh reviewers audited the spec against the EGM standards, in separate
Cloudroom threads with no access to the design conversation. Each read the spec
from the repository and the Hermes runtime source, and nothing else.

| Reviewer | Standard | Scope |
| --- | --- | --- |
| `zoom_out` | zoom-out-standard | full file |
| `comprehension` | re-implementation-standard | feature scope, then detailed scope |
| `design_critic` | feature-spec-standard | feature scope (lines 1–393) |
| `structural` | feature-spec-standard | feature scope (lines 1–393) |
| `style` | persona vectors | feature scope (lines 1–393) |
| `implementation_readiness` | implementation-readiness-standard | detailed scope (lines 394–535) |
| `codebase_details` | implementation-readiness-standard | detailed scope (lines 394–535) |

Every finding below was checked against the source by the Elephant before it was
classified. The reviewer reports are in `docs/designs/reviews/`.

## Verdict

**Not ready for implementation.** The feature design is sound: the approach,
the endpoint choices, the security posture, and the rejection of the alternatives
all hold up. The failures are concentrated in the implementation plan, and they
are of one kind — **the plan describes a feature and does not describe the
code**. It names symbols the shell does not have, contradicts itself about
where state lives, and asks for a shortcut that another app already owns.

Six of the seven blockers are the same defect seen from different angles: the
plan was written from the feature outward, never checked inward against the
files it names.

---

## Blockers

### [1] Card payload has names and no types

**Reviewers:** `implementation_readiness` #1, `codebase_details` #5, `comprehension` #1
**Affected scope:** plan step 1, `features/board/api.ts` (lines 403–419); step 2 detail pane (lines 437–439)

**Discrepancy:** `BoardTask` lists twenty-one field names plus an index
signature. The fields the pane renders are not scalars. On the live payload:

* `id`, `title`, `status` — string. `body`, `assignee`, `result`, `session_id`,
  `workspace_path`, `branch_name`, `last_failure_error` — string or null.
* `priority`, `consecutive_failures` — number. `priority` is an integer, not a label.
* `created_at`, `started_at`, `completed_at`, `current_run_started_at` — unix
  seconds or null. Passing one to `new Date` as milliseconds renders 1970.
* `age` — `{ created_age_seconds, started_age_seconds, time_to_complete_seconds }`,
  each a number of seconds or null. Not a single duration.
* `progress` — `{ done, total }` or null. `ProgressBar` takes a 0–100 value; the
  plan never says to hide the bar when `progress` is null, nor the formula.
* `link_counts` — `{ parents, children }`. `comment_count` — number.
* `block_kind` — `"dependency" | "needs_input" | "capability" | "transient"` or null.
* `latest_summary` — string or null, **truncated to 200 characters on `/board`**.
  The full text is only on `GET /tasks/{id}`.
* `diagnostics` (list) and `warnings` (`{ count, kinds, latest_at, highest_severity }`)
  are attached when present. The field list omits both.

`started_at` is the first start ever; `current_run_started_at` is the current
run, which moves after a retry. The plan asks for both timestamps and "age"
without saying which one is "how long it has been running".

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified against `kanban_db.Task` and `_task_dict`. The plan's
own sample JSON already shows `now` as `1793156717` — unix seconds — so the
document knows the unit and does not carry it into the types. `toMs` in
`apps/desktop/src/features/automations/cron-humanize.ts` already converts this
mix correctly; the plan should name it instead of growing a second parser.

**Proposed Edit:** give every field its type in the `BoardTask` interface,
including the three object-valued fields; state that timestamps are unix
seconds and that `toMs` is the converter; state that `progress` is null when
the card has no children and that the bar is hidden then; state that the
running duration is `now - current_run_started_at`; add `diagnostics` and
`warnings`.

---

### [2] The page shortcut the plan asks for is already taken

**Reviewers:** `implementation_readiness` #2, `codebase_details` #1, `zoom_out` #1, `comprehension` #14
**Affected scope:** plan step 5, `shell/apps.ts` (lines 469–477)

**Discrepancy:** The plan says the slice "takes the next free digit slot in the
page registry". `PAGES` uses `1`–`7` and `,`. `FLOATING_APPS` already binds `8`
to Terminal and `9` to System. `App.tsx` and `surfaces/MainSurface.tsx` both
resolve with `HERMES_APPS.find(a => a.shortcut === event.key)`, and
`HERMES_APPS` lists pages before floating apps — so a Board shortcut of `8`
takes Cmd/Ctrl+8 from Terminal and Terminal stops opening. There is no free
digit in `1`–`9`. `docs/manual/hotkeys.md` records the same map and is not in
the plan's file list.

The same paragraph says the sidebar renders the shortcut from the `PAGES` entry.
It does not: `Sidebar.tsx` shows the glyph and `def.name` only. The shortcut
hint lives in the command bar (`CommandBar.tsx`).

The plan also omits required fields of the `PAGES` entry: `HermesAppDef`
requires `name`, `tagline`, and `category` (`'productivity' | 'creative' |
'development' | 'system'`). The plan gives `kind`, `icon`, "a tagline", and a
shortcut. The sidebar label comes from `PAGES[].name`, not from `PAGE_LABEL`,
so an unspecified name makes the sidebar and the error-boundary label diverge.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `shell/apps.ts` lines 45–57, `Sidebar.tsx`, and
`docs/manual/hotkeys.md`. The plan's "no other binding changes" is the exact
claim this breaks. Voice and the command bar already satisfy the reachability
goal; a digit is not required by any goal.

**Proposed Edit:** ship the page with no digit shortcut, or pick a key outside
`1`–`9`. Give the `PAGES` entry its `name`, `tagline` string, and `category`.
Remove the sidebar-shortcut sentence. Add `docs/manual/hotkeys.md` to the file
list if a shortcut is chosen.

---

### [3] The detail pane cannot be built from the three reads the spec allows

**Reviewers:** `implementation_readiness` #3, `design_critic` #3, `comprehension` #15
**Affected scope:** "The three endpoints this page reads" (lines 163–198); CUJ 2 (lines 87–93); verification item 2 (lines 522–523)

**Discrepancy:** The spec says each task on `GET /board` carries what the
detail pane needs, and slice 1 never calls `GET /tasks/{id}`. On the board path
`latest_summary` is cut to 200 characters and the handler comment says the full
text comes from `/tasks/{id}`. There is no truncated flag, so a long worker
handoff shows up in the pane as if it were the whole summary.

Verification item 2 then says the pane's fields match
`GET /api/plugins/kanban/tasks/{id}` for the same card. That route returns
`{ task, comments, events, attachments, links, link_tasks, child_results, runs }`
with the full summary on `task`. An implementer who follows the file list fails
the check; an implementer who adds the task fetch to pass it is inventing a
request, a type, and a loading rule the plan does not contain.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `plugin_api.py`: `get_board` truncates at
`_CARD_SUMMARY_PREVIEW_CHARS = 200`; `get_task` returns the full text. The
spec is internally inconsistent — the feature scope and the verification plan
describe two different data sources.

**Proposed Edit:** choose one. The recommended route is to add
`GET /tasks/{id}` as a fourth read, fetched when a card is selected, and define
the detail pane from that response. Then item 2 becomes a true check. State the
extra request and that it only happens on selection.

---

### [4] The commands cannot be written from the plan, and `kanban` cannot be highlighted

**Reviewers:** `implementation_readiness` #6, `codebase_details` #3, `design_critic` #6, `comprehension` #7
**Affected scope:** plan step 3, `commands/board.ts` (lines 449–459); step 4, `board-store.ts` (lines 461–467); the commands table (lines 254–267)

**Discrepancy:** `OsCommand` requires `title`, `description`, `tier`, `args`,
and `run`. The plan gives a tier, a description, spoken phrases, and a `run`,
and specifies only two bodies: `board.open` calls `showPage('board')`, and
`board.select` and `board.search` call `focusBoard()`. Missing: titles, the
`args` list (search needs a query, select needs an id), phrase strings, the
summary lines, and the not-found result. `board.refresh` and `board.focus` have
no body at all.

`board.refresh` has no path to the loader. The board payload stays inside the
page's `useBackendData`, and `reload` exists only inside the component. A
command handler runs outside React and cannot reach it.

`data-os-target="kanban:<task id>"` does not point the highlighter at the card
by itself. `OsHighlighter` queries `[data-os-target="${target.kind}:${target.id}"]`
from `result.highlight`, and `CommandHighlight['kind']` is
`'page' | 'memory' | 'automation' | 'mission' | 'file' | 'window' | 'connection' | 'setting'`.
There is no `'kanban'`. Returning it fails `npm run typecheck` until
`apps/desktop/src/store/os-commands.ts` changes — a file the plan says is not
touched.

`board.focus` has no DOM target: `GlassCard` renders a `div` unless
`as="button"`, and a `div` is not focusable.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `store/os-commands.ts` lines 24–27 and 52–64,
and `features/voice/ActionHud.tsx` lines 82–93. This is the same class of
defect as [1]: the plan lists command names where the contract lives in types.

**Proposed Edit:** give each command its `title`, `args`, `tier`, and `run`
body. Add `kanban` to `CommandHighlight['kind']` and list
`apps/desktop/src/store/os-commands.ts` in the shared-file table. Give
`board.refresh` a path to the loader — a tick in the focus atom the page's
effect observes, or the reload counter the store already needs. Say whether
cards render `as="button"`.

---

### [5] The plan both forbids a store file and tells the implementer to add one

**Reviewers:** `implementation_readiness` #8, `codebase_details` #7, `comprehension` #6, `zoom_out` #4, `design_critic` #6
**Affected scope:** plan step 4 (lines 461–467) against architecture lines 247–248

**Discrepancy:** The architecture section says the page owns its state locally
like the automations page, and "No new store file, no change to `src/store/`".
Step 4 creates `features/board/board-store.ts`. Both sentences cannot be
followed.

The choice matters, because a command handler runs outside React.
`useState` in `BoardPage` is invisible to `board.select` and `board.search`.
Automations has no store file because no command selects from it. Memory has
`memory-store.ts` because commands call `focusMemory`. The shell's seam for
this is a `focus*()` atom the page subscribes to — `DESIGN.md` requires it for
page-local selection and filter.

The plan also says "a nanostore atom pair" while describing three pieces of
state, and `memory-store.ts` exports one atom shaped
`{ query?, entryId?, ts }` with a stamped `ts` so a repeated command still
changes it.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified: `features/automations/` has no store module;
`features/memory/memory-store.ts` has one; `DESIGN.md` requires the `focus*()`
atom for command-driven page state. The feature-local atom is the right call —
it keeps board data in the page's loader (one owner for backend truth) and
puts only the command seam in a file under `src/features/board/`.

**Proposed Edit:** strike "No new store file" and replace it with the accurate
statement: no new file under `src/store/`. Keep `features/board/board-store.ts`.
Name the atom's shape and the fields each command sets.

---

### [6] Error, empty, and not-ready states are one sentence, and they disagree with the verification

**Reviewers:** `implementation_readiness` #4, `codebase_details` #4, `design_critic` #5, `comprehension` #2, `zoom_out` #3
**Affected scope:** plan step 2 (lines 427–429, 446–447); CUJ 5 (lines 108–114); verification item 6 (lines 528–529)

**Discrepancy:** Four situations have to be told apart, and the plan gives one
rule for all of them:

1. Backend not ready — `useBackendData` returns without setting `data`,
   `error`, or `loading` while `$connectionEpoch` is 0.
2. Plugin route 404 — "not available", not "no cards".
3. 200 with zero cards — a healthy empty board.
4. A later fetch failed while a board is on screen — keep that board, show the
   error next to refresh.

Step 2 says every empty and error state is an `EmptyGlass` with a retry.
Verification item 6 and the Failure-behaviour section say the last good board
stays visible. Those produce different UIs, and `AutomationsPage.tsx` lines
249–275 — the page step 2 says to copy — hides the list whenever `error` is set,
so copying it blanks the board.

There is also no status code to branch on. `BackendManager.rest` throws
`Error("GET <path> -> <status>: <detail>")`, or `Hermes backend is not ready`
before any request when the phase is not `ready`. A 404 is a substring of that
message, and the plan never says to parse it.

And the plan's "skip the interval while the backend is not ready" makes
verification item 6 impossible: after a ready backend stops, the epoch does not
reset, the skipped poll never calls `rest()`, and no error is ever recorded.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `lib/use-async.ts` lines 16–54,
`electron/backend/manager.ts` lines 99–140, and `AutomationsPage.tsx`. The
spec contains both instructions today, and a reader who follows the plan
fails its own verification.

**Proposed Edit:** enumerate the four states and give each its rendering. Name
`$backend.phase` from `src/store/backend.ts` as the ready signal and
`$connectionEpoch` as the hook's own gate. Say that the poll runs while
`$page === 'board'` and lets the thrown error reach the hook, rather than
skipping on readiness. State how a 404 is detected from the error string, or
fold plugin-missing into the one error path.

---

## Majors

### [7] The poll never stops when the user leaves the page

**Reviewers:** `implementation_readiness` #5, `codebase_details` #4, `design_critic` #2, `comprehension` #16, `zoom_out` #2
**Affected scope:** "Freshness" (lines 211–214); "Data and actions" (lines 244–246); plan step 2 (lines 427–429)

**Discrepancy:** The plan clears the interval on unmount and "when the page is
hidden". `MainWindow` keeps every visited page mounted and hides the inactive
one with `visibility: hidden`; `DESIGN.md` says visibility is not lifecycle.
Unmount does not run when the user opens Missions, and `document.visibilityState`
stays `visible` inside the same window. The signal is `$page` from
`src/store/windows.ts`. `FilesPage` already reads it and returns when
`page !== 'files'`.

The interval also has to call `useBackendData`'s `reload()`. A second fetch in
the timer bypasses the generation guard in `use-async.ts`, so a slow poll can
overwrite a newer reconnect refresh.

CUJ 4 requires the same selection and filter when the user returns, which
happens only because the page stays mounted. The layout section says the
search "does not persist", which reads as reset-on-leave and fails CUJ 4.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `shell/MainWindow.tsx` lines 29–54 and
`store/windows.ts` line 34. This is a performance defect, not a style one: the
hidden page fetches the whole board every five seconds for the rest of the
session.

**Proposed Edit:** name `$page === 'board'` as the gate, and state that
selection and the title filter survive navigation for the life of the process
because the page stays mounted. Remove "does not persist" or scope it to the
process lifetime.

---

### [8] The poll is justified by a misreading of `GET /board`

**Reviewers:** `design_critic` #1, `zoom_out` #6
**Affected scope:** "Freshness" (lines 211–214); Performance (lines 360–362)

**Discrepancy:** The spec calls the board read "a single coalesced SQLite
query" and says the payload is "bounded by the number of live cards".
`coalesced_read` deduplicates concurrent in-flight calls with identical
arguments; a single Herald poller gets no benefit from it. `get_board` then
runs `list_tasks` with no `LIMIT`, a full scan of `task_links`, the comment and
child-progress aggregates, `latest_summaries`, `current_run_started_ats`, and
`_compute_task_diagnostics`, whose own comment says it "slurps the board".
Archived rows are excluded; done rows are not. Each task dict is
`asdict(task)`, so every poll ships the full `body` and `result` of every
historical done card.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `plugin_api.py` `get_board` and
`hermes_cli/web_read_coalescing.py`. The rejection of the WebSocket rests on a
read that does not exist in this shape. This does not force slice 2 into
slice 1 — a five-second poll is still a defensible first slice — but the
document must not justify it with a false cost model, and must say what happens
on a board with many done cards.

**Proposed Edit:** correct the description of the board read. State that the
payload grows with the number of non-archived cards, that done cards are
included, and what the page does on a large board. Keep the WebSocket deferral
but ground it in the real cost.

---

### [9] CUJ 3's "same position in the list" is not the runtime's order

**Reviewers:** `design_critic` #7, `comprehension` #3
**Affected scope:** CUJ 3 (lines 95–100)

**Discrepancy:** Queue columns keep `list_tasks` order: `priority DESC,
created_at ASC`. The done column is re-sorted `completed_at DESC`, then
`id DESC`. A card that moves lands at that sort key in the destination column;
it does not keep its old index, and a card that becomes done goes to the top
of Done. A correct renderer fails the CUJ as written.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `kanban_db.list_tasks` and the `get_board`
column sorts. An acceptance test that the runtime cannot pass is worse than no
acceptance test.

**Proposed Edit:** rewrite the CUJ against the runtime's order, and say that
rows are keyed by task id so a five-second replacement does not remount the
selected card.

---

### [10] The failure marker misses the stuck states the runtime already computes

**Reviewers:** `design_critic` #4, `comprehension` #4
**Affected scope:** Goals (lines 39–40); the stuck-card open question (lines 66–69); CUJ 1 (lines 83–84)

**Discrepancy:** The spec marks a card from `consecutive_failures` and
`last_failure_error`. `get_board` already attaches per-task `diagnostics` and a
`warnings` summary (`{ count, kinds, latest_at, highest_severity }`).
`kanban_diagnostics.py` raises `stale_running`, `stuck_in_blocked`,
`stranded_in_ready`, `repeated_crashes`, and `block_unblock_cycling` on cards
whose `consecutive_failures` is 0 and whose `last_failure_error` is null. A dead
running worker — the case the goal calls "failing or blocked" — does not show
the spec's marker. `block_kind` is not the fix either: it is kept across
unblock, so a card back in `ready` still carries the old kind.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `kanban_diagnostics.py` and
`_warnings_summary_from_diagnostics`. The signals are already on the payload
slice 1 fetches.

**Proposed Edit:** mark the card from `warnings.highest_severity`, and show
`diagnostics` in the detail pane. Keep `GET /diagnostics` for the fleet strip
in future improvements.

---

### [11] The plan's error UI blanks the board the feature section keeps

**Reviewers:** `implementation_readiness` #4, `codebase_details` #4, `comprehension` #11
**Affected scope:** plan step 2 (lines 446–447) against "Failure behaviour" (lines 363–365)

**Discrepancy:** The same contradiction as [6], seen from the render rule.
`useBackendData` keeps the previous `data` when a later fetch fails. The plan's
`EmptyGlass`-on-error rule throws that away.

**AI Suggestion:** PROPOSE FIX
**Justification:** Folded into [6]. Listed separately because it needs a
different edit in a different place.

**Proposed Edit:** change the render rule to keep the board visible on a
later-failure error and put the error next to the refresh button.

---

### [12] The shared-file count does not match the table

**Reviewers:** `style` #9, `design_critic` #9, `comprehension` #9, `codebase_details` #3
**Affected scope:** "Shared files this changes" (lines 271–280)

**Discrepancy:** The prose says the slice touches four shared files. The table
lists five. Finding [4] adds `os-commands.ts` as a sixth.

**AI Suggestion:** PROPOSE FIX
**Justification:** Trivial but the section exists to declare exactly this
surface, and `apps/desktop/DESIGN.md` requires shared changes to be called out.

**Proposed Edit:** count the rows, and say six if `os-commands.ts` is added.

---

### [13] Alternative D is rejected for an IPC change the same section says is unnecessary

**Reviewers:** `design_critic` #8
**Affected scope:** Alternative D (lines 326–342)

**Discrepancy:** The rejection says a move needs `PATCH`, which `RestRequest`
does not allow, so slice 2 needs three shared changes. The note under the
alternative then says `POST /api/plugins/kanban/tasks/bulk` applies the same
transition rules, needs no new IPC method, and was verified to move a card and
refuse an illegal transition. The route exists and shares `_apply_status` with
`PATCH`. The cons still say "Three shared changes to ship a drag".

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified: `RestRequest.method` is
`'GET' | 'POST' | 'PUT' | 'DELETE'`, and `POST /tasks/bulk` exists and uses
the same status-verb dispatch. The recorded reason for rejection is wrong.

**Proposed Edit:** rewrite the reason as scope — mutations, the `manual`
transition table, optimistic UI, rollback — and record `POST /tasks/bulk` as
the slice-2 transport so the next design does not reopen a shared IPC change.

---

### [14] Short paths in the spec do not resolve, and two file paths are wrong

**Reviewers:** `structural` #1–#4, `comprehension` #8, `zoom_out` #6
**Affected scope:** "Data and actions" (lines 244–251); "The commands" (lines 264–266); Alternative A (lines 290–291); "Additional Resources" (lines 371–378)

**Discrepancy:** Four separate problems:

1. The spec writes `src/lib/use-async.ts`, `src/features/board/`,
   `src/store/`, `src/commands/board.ts` — then writes
   `apps/desktop/src/commands/navigation.ts` for the same file a few lines
   later. `docs/ARCHITECTURE.md` line 88 says renderer paths are relative to
   `apps/desktop`. The spec never says that, so the short paths do not resolve.
2. `dashboard/manifest.json` (Alternative A) is not a path that opens. The
   manifest is `plugins/kanban/dashboard/manifest.json` in the Hermes install.
3. The resources list mixes repo-root paths with runtime paths
   (`plugins/kanban/dashboard/plugin_api.py`, `hermes_cli/kanban_db.py`,
   `hermes_cli/web_server_dashboard.py`) that are not in this repository. They
   live under the Hermes install, `$HERMES_HOME/hermes-agent`.
4. `docs/ARCHITECTURE.md` is cited for "the three-owner split". The heading is
   `## Three authorities`; the file never says "owner".

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified in `docs/ARCHITECTURE.md`, `upstream/README.md`,
and the Hermes install. A reader following the spec's own paths finds nothing.

**Proposed Edit:** state once that renderer paths are relative to
`apps/desktop`, or write every path in full. Fix the manifest path. Name the
Hermes install root for the runtime files and give the runtime version. Cite
`## Three authorities`. Use repo-relative Markdown links the way
`docs/README.md` does.

---

### [15] The work is not phased, so the registry edit does not leave the tree buildable

**Reviewers:** `codebase_details` #10
**Affected scope:** plan items 5–7 (lines 469–491)

**Discrepancy:** The plan is a flat list of ten file edits. `PageId` and
`AppIconId` are closed unions; `PAGE_VIEW` and `PAGE_LABEL` are
`Record<PageId, …>` and `PATHS` is `Record<AppIconId, …>`. Adding `'board'` to
either union fails `npm run typecheck` until `apps.ts`, `MainWindow.tsx`, and
`app-icon.tsx` change together. The plan numbers those as items 5, 6, and 7 and
never says they land together.

**AI Suggestion:** PROPOSE FIX
**Justification:** Verified: both records are exhaustive. The implementation
readiness standard requires phases that each leave the codebase buildable.

**Proposed Edit:** group the plan into phases — API and types, then the
registry trio as one atomic change, then the page, then commands, then tests —
and say which phase leaves the tree green.

---

### [16] The five-second refresh has no bound in CUJ 3

**Reviewers:** `style` #5
**Affected scope:** CUJ 3 (lines 99–100)

**Discrepancy:** "Within a few seconds" cannot be verified, and "a few" can be
read as tighter than the five-second poll the plan commits to.

**AI Suggestion:** PROPOSE FIX
**Justification:** A CUJ is an acceptance test. This one has no number.

**Proposed Edit:** state the bound as the poll interval plus request time.

---

### [17] Layout states two different width rules and no width

**Reviewers:** `style` #7
**Affected scope:** "Layout" (lines 224–230)

**Discrepancy:** The columns "keep their natural width" and are also "a
fixed-width column". Those are different rules, and neither names a width.

**AI Suggestion:** PROPOSE FIX
**Justification:** The plan has to give an implementer a number.

**Proposed Edit:** pick one rule and name the width.

---

### [18] Rollout claims an absolute the design exceeds

**Reviewers:** `style` #17
**Affected scope:** "Non-Functional Requirements", Rollout (lines 366–367)

**Discrepancy:** "Nothing existing changes behaviour" is contradicted by the
sidebar entry, the `PAGE_ALIASES` entries for "board" and "kanban", and the
command registration — all of which change navigation and voice name
resolution.

**AI Suggestion:** PROPOSE FIX
**Justification:** The accurate claim is narrower and still true.

**Proposed Edit:** say existing pages keep their current behaviour, and that
removing the page removes its registration.

---

## Nits

Accepted for the same edit pass; no separate decision needed.

| # | Finding | Reviewers | Fix |
| --- | --- | --- | --- |
| N1 | "already exists and is already tested" — "already" twice | style 1 | drop the second |
| N2 | "Legible without hunting for it" is an untestable metaphor | style 2 | state the observable behaviour |
| N3 | "The obvious next interaction" / "It waits" | style 3 | state the constraint factually |
| N4 | "How loud should a stuck card be?" — the paragraph already decided it | style 4 | name the decision |
| N5 | "The board payload is small" / "A short poll is simpler" / "cannot leak a socket" | style 6 | state the concrete reasons |
| N6 | "With no new code" is false in the same sentence | style 8 | "no new command handler" |
| N7 | "Almost no new code" | style 10 | give the number |
| N8 | "A screenshot, not a surface"; "second renderer" names both the proposal and the design | style 11 | drop the metaphor; do not reuse the term |
| N9 | "A page wearing a disguise" | style 12 | the cons already carry it |
| N10 | "A question the user asks constantly"; "deserves a permanent address" | style 13 | keep the checkable facts |
| N11 | "Can feel like a screenshot of a board" | style 14 | drop the repetition |
| N12 | "Note for the reviewer" addresses the review process | style 15 | make it a normal paragraph |
| N13 | "The right read path" | style 16 | the cons already draw it |
| N14 | Alternative A's cited rule does not decide between the options | design_critic 10 | drop the rule sentence |
| N15 | The Goals promise transitions slice 1 does not read | design_critic 10 | limit the goal to set, labels, icons |
| N16 | "Open tasks" already opens Automations | zoom_out 7 | settle the alias in this design |
| N17 | `board.focus` duplicates the highlighter the shell already runs | zoom_out 8 | drop it, or justify it |
| N18 | `columnLabel` invents a third column name | zoom_out 9 | use workflow label, fall back to board name |
| N19 | Slice 1 names a socket API it does not open | zoom_out 10 | keep it in future improvements only |
| N20 | "Move it to a floating window later" is not a registration change | zoom_out 5 | say what promotion actually needs |
| N21 | Command registration wording does not match the bootstrap loop | codebase_details 11 | "add the group to the array" |
| N22 | `page.open`'s description enumerates pages and does not gain `board` | codebase_details 11 | add it |

---

## Traceability

| Consolidated | Findings folded in |
| --- | --- |
| [1] Card payload types | impl_readiness 1, codebase_details 5, comprehension 1 |
| [2] Shortcut collision + registry fields | impl_readiness 2, codebase_details 1, zoom_out 1, comprehension 14 |
| [3] Detail pane source | impl_readiness 3, design_critic 3, comprehension 15 |
| [4] Command contracts + `kanban` highlight | impl_readiness 6, codebase_details 3, design_critic 6, comprehension 7 |
| [5] Store ownership | impl_readiness 8, codebase_details 7, comprehension 6, zoom_out 4, design_critic 6 |
| [6] Four error states | impl_readiness 4, codebase_details 4, design_critic 5, comprehension 2, zoom_out 3 |
| [7] Poll stop condition | impl_readiness 5, codebase_details 4, design_critic 2, comprehension 16, zoom_out 2 |
| [8] Poll cost model | design_critic 1, zoom_out 6 |
| [9] CUJ 3 ordering | design_critic 7, comprehension 3 |
| [10] Failure marker | design_critic 4, comprehension 4 |
| [11] Error UI keeps the board | impl_readiness 4, codebase_details 4, comprehension 11 |
| [12] Shared-file count | style 9, design_critic 9, comprehension 9, codebase_details 3 |
| [13] Alternative D reason | design_critic 8 |
| [14] Path resolution | structural 1–4, comprehension 8, zoom_out 6 |
| [15] Phasing | codebase_details 10 |
| [16] CUJ 3 bound | style 5 |
| [17] Layout width | style 7 |
| [18] Rollout claim | style 17 |

Raw reports: `docs/designs/reviews/`.
