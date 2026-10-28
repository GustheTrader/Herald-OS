## Findings

### 1. The poll is justified by a misreading of `GET /board`

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, "Freshness: the events WebSocket" (lines 211–214) and "Non-Functional Requirements" / Performance (lines 360–362).

**Finding & Recommendation:** The spec says the board read is "a single coalesced SQLite query (`_read_board = coalesced_read(get_board)`)" and that "the payload is bounded by the number of live cards." Both claims are false in the runtime this page would call.

`coalesced_read` (`hermes_cli/web_read_coalescing.py`) deduplicates one in-flight call per event loop when the arguments match. A single Herald poller gets no coalescing benefit. `get_board` in `plugins/kanban/dashboard/plugin_api.py` then runs `list_tasks` with no `LIMIT`, a full scan of `task_links`, comment and child-progress aggregates, `latest_summaries`, `current_run_started_ats`, plus `_compute_task_diagnostics`, whose own comment says it "slurps the board" (every non-archived task, its `task_events`, and its `task_runs`). Archived rows are excluded. Done rows are not. Each task dict is `asdict(task)`, so every poll ships the full `body` and `result` of every historical done card.

The five-second poll therefore grows without a stated ceiling, and the reason given for rejecting the `/events` WebSocket in slice 1 does not hold. Put a bound in the spec: done-column cap or `include` of terminal cards, card projection that omits `body`/`result` from the poll, and a refetch driven by `latest_event_id` (already on the payload) instead of an unconditional full read. State what happens when the board is large. Re-decide the WebSocket against that cost, since the current rejection is based on a read that does not exist.

### 2. "Stop when the page is hidden" has no signal in this shell

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, "Freshness" (lines 213–214), "Data and actions" (lines 244–246), Performance (lines 360–362), and CUJ 4 (line 106) against the search sentence (lines 237–238).

**Finding & Recommendation:** Visited pages stay mounted. `MainWindow` hides the inactive page with `visibility: hidden` and `DESIGN.md` says visibility is not lifecycle. After the first visit, the Board component never unmounts, and `document.visibilityState` stays `visible` while the user is on Missions in the same window. An interval cleared "on hide" or "on unmount" keeps polling for the rest of the session, including the heavy read in finding 1.

The interval also has to be `useBackendData`'s `reload()`. A second fetch in the timer bypasses the generation guard in `src/lib/use-async.ts`, so a slow poll overwrites a newer reconnect refresh.

CUJ 4 requires the same selection and filter when the user comes back. That only happens because of this keep-alive. The layout section says the search "does not persist," which reads as reset-on-leave and fails the CUJ.

Name the stop condition: run the interval only while `$page === 'board'` and the OS document is visible; clear it otherwise. State that selection and the title filter survive navigation for the life of the process because the page stays mounted, and that nothing is written to the runtime or to disk.

### 3. The detail pane cannot be built from the three reads the spec allows

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, "The three endpoints this page reads" (lines 175–178) and CUJ 2 (lines 87–93).

**Finding & Recommendation:** The spec says each task on `GET /board` carries what the detail pane needs, including `latest_summary`, and slice 1 never calls `GET /tasks/{id}`. On the board path, `latest_summary` is cut to `_CARD_SUMMARY_PREVIEW_CHARS` (200) and the handler comment says the full text comes from `GET /tasks/{id}`. There is no truncated flag. A worker handoff longer than 200 characters shows up in the detail pane as if it were the whole summary.

"How long it has been running" is also the wrong clock if it is taken from `started_at` or from `age.started_age_seconds`. `task_age` subtracts `tasks.started_at`, which the same handler documents as the first-ever start. After a retry the run clock is `current_run_started_at`, compared with the payload's `now`. `age` itself is `{created_age_seconds, started_age_seconds, time_to_complete_seconds}`, not a single duration.

On select, load `GET /tasks/{id}` for the detail pane (full summary, and the comments and links whose counts are all the board payload has). Drive the running duration from `current_run_started_at` and `now`. Keep the board payload for the card face.

### 4. Failure markers miss the stuck states the board payload already computes

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, Goals (lines 39–40), the stuck-card open question (lines 66–69), CUJ 1 (lines 83–84), and the task field list (lines 175–178).

**Finding & Recommendation:** The spec marks a card from `consecutive_failures` and `last_failure_error`, and defers fleet diagnostics to a later `GET /diagnostics`. `get_board` already attaches per-task `diagnostics` and a `warnings` summary (`{count, kinds, latest_at, highest_severity}`) via `_attach_diagnostics`. `hermes_cli/kanban_diagnostics.py` raises `stale_running`, `stuck_in_blocked`, `stranded_in_ready`, `repeated_crashes`, and `block_unblock_cycling` on cards whose `consecutive_failures` is still 0 and whose `last_failure_error` is null. A dead running worker (no heartbeat, no pid) is the case the goal calls "failing or blocked" and the open question calls "stuck," and the spec's marker does not show it.

`block_kind` is also the wrong extra signal: the column comment says it is kept across unblock, so a card back in `ready` still carries the old kind.

Mark the card from `warnings.highest_severity` (and show `diagnostics` in the detail pane). Those fields are on the board payload slice 1 already fetches. Leave `GET /diagnostics` for the fleet strip in the future-improvements list.

### 5. CUJ 5 merges three outcomes the runtime keeps apart, and a healthy empty board is one of them

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, CUJ 5 (lines 108–114) and "Failure behaviour" (lines 363–365). The trust-gate paragraph (lines 154–157) is the disabled-plugin case.

**Finding & Recommendation:** "No board", "plugin not mounted", and "backend not ready" are specified as one sentence and a retry, and the page must not show an empty grid that looks like "no work." The runtime does not have that single state.

- `board_exists` returns true for the `default` board even when no file exists. `GET /board` calls `init_db`, which creates `kanban.db` and runs migrations. The first paint of a read-only page writes a database into the Hermes home. A fresh install then returns 200 and eight empty columns. That is "no work," and the goals require those columns to be shown.
- A kanban plugin that is explicitly disabled is refused by `_plugin_api_request_refused` with HTTP 404 and `{"detail": "Plugin not found"}`. The shell bridge turns that into a thrown `Error`. `useBackendData` records it on the same `error` channel as a 500. "Plugin not found" is the string that means "not available." Any other failure is the "keep the last good board and show the error beside refresh" path. A 404 after a successful load must replace the stale board, or the page keeps painting a plugin that is gone.
- While `$connectionEpoch` is 0, `useBackendData` returns without setting `data` or `error`. Backend-not-ready is `$backend.phase`, not a failed fetch. With neither branch, CUJ 5 renders a blank page and offers no retry.

Split the empty-state spec into those three signals, and say that 200 with empty columns is a healthy board. Say that the first `GET /board` materializes the default database, since "read-only" does not describe that write.

### 6. The commands cannot do what the command table says, and the highlight type forbids `kanban`

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, "Data and actions" (lines 247–252), "The commands" (lines 255–267), and "Shared files this changes" (lines 269–284).

**Finding & Recommendation:** `board.search`, `board.select`, and `board.focus` have to change filter, selection, and DOM focus from `src/commands/board.ts`. The spec puts that state in the page component and forbids a new store and any change under `src/store/`. Command handlers run outside React. `useState` in `BoardPage` is invisible to them. The shell's existing seam is a `focus*()` atom the page subscribes to (`$missionFocus` on Missions, `focusMemory` in `features/memory/memory-store.ts`). `DESIGN.md` requires that atom for page-local selection and filter. Automations does not select from a command either: `automation.show` only returns a `highlight`, and the detail pane stays on whatever the click selected.

`data-os-target="kanban:<task id>"` needs `highlight.kind === 'kanban'`. `CommandHighlight['kind']` in `src/store/os-commands.ts` is `'page' | 'memory' | 'automation' | 'mission' | 'file' | 'window' | 'connection' | 'setting'`. Returning `kanban` does not typecheck. `OsHighlighter` will query that attribute once the object exists, so the union has to grow. That is a change to `src/store/os-commands.ts`, which the shared-file list says is untouched.

Add `kanban` to `CommandHighlight` and list that file. Add a `focusBoard()` atom under `src/features/board/` (this is not `src/store/`) that holds the selected id, the title query, and a focus tick. Have the page subscribe the way `MissionsPage` subscribes to `$missionFocus`. `board.select` with no id selects the first card in current column order from the last fetched board held beside that atom.

### 7. CUJ 3's "same position in the list" is not the runtime's order

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, CUJ 3 (lines 95–100).

**Finding & Recommendation:** A correct renderer will fail this CUJ. Queue columns keep `list_tasks` order: `priority DESC, created_at ASC`. The done column is re-sorted `completed_at DESC`, then `id DESC`. A card that moves lands at that sort key in the destination column. It does not keep its old index. A card that becomes done goes to the top of Done.

Write the CUJ against that order, and key rows by task id so a five-second replacement does not remount the selected card or clear the detail pane. "Same position" as an index is an acceptance test the runtime will not pass.

### 8. Alternative D is rejected for an IPC change the same section says is unnecessary

**Severity:** Major

**Affected Scope:** `docs/designs/kanban-board.md`, Alternative D (lines 326–342).

**Finding & Recommendation:** The rejection says a move requires `PATCH`, and `RestRequest.method` has no `PATCH`, so slice 2 needs edits to `shared/ipc.ts`, the preload, and the main-process bridge. That method union is real (`'GET' | 'POST' | 'PUT' | 'DELETE'` in `apps/desktop/shared/ipc.ts`). The note under the alternative then says `POST /api/plugins/kanban/tasks/bulk` applies the same transition rules as `PATCH` and needs no new IPC method. The route exists (`plugin_api.py` shares `_apply_status` between `PATCH /tasks/{id}` and `POST /tasks/bulk`). The cons still say "Three shared changes to ship a drag" as the cost of making the board writable.

The product reason that survives is the one in the last sentence of the rejection: seeing the queue is a complete slice. The IPC premise does not survive. Rewrite Alternative D so the recorded reason is scope (mutations, the `manual` table, optimistic rollback), and record `POST /tasks/bulk` as the slice-2 transport so the next design does not reopen a shared IPC change to do a move.

### 9. The shared-file count does not match the table

**Severity:** Nit

**Affected Scope:** `docs/designs/kanban-board.md`, "Shared files this changes" (lines 271–280).

**Finding & Recommendation:** The prose says the slice touches four shared files. The table has five: `apps.ts`, `MainWindow.tsx`, `app-icon.tsx`, `commands/index.ts`, and `navigation.ts`. Count the rows. Finding 6 adds `os-commands.ts` as a sixth.

### 10. The Goals promise transitions slice 1 does not read, and Alternative A's cited rule does not decide it

**Severity:** Nit

**Affected Scope:** `docs/designs/kanban-board.md`, Goals (lines 35–36), the `/workflow` paragraph (lines 193–195), Overview (lines 17–18), and Alternative A "Reason for Rejection" (lines 301–302).

**Finding & Recommendation:** The Goals say column set, labels, icons, and legal transitions are read from the runtime and none are hardcoded. The plan says slice 1 reads `columns` and ignores `manual`. Slice 1 has no moves, so ignoring `manual` matches the non-goals. The Goals bullet overclaims the slice. Limit that bullet to set, labels, and icons, and put transitions on the writable-board future item, which already names `manual` and `drag_target`.

Alternative A's rejection ends by citing "the shell's own rule" that the renderer never reimplements the agent, and applies it to "a second renderer of the board." `docs/ARCHITECTURE.md` says "Agent behaviour is never re-implemented in React." The overview of this spec says Herald OS is a second renderer of the kanban API, which is the chosen design. The rule does not pick between embedding the dashboard and drawing the board. The cons already carry the decision: a second visual language, a credential in the webview URL, and a surface the command bar and `data-os-target` cannot see. Drop the rule sentence so the record does not argue against the design it adopts.
