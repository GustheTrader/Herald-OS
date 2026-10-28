# Zoom-out review: `docs/designs/kanban-board.md`

## 1. The "next free digit" shortcut collides with Terminal

**Severity:** Major

**Affected Scope:** Detailed Implementation Plan, "5. `apps/desktop/src/shell/apps.ts`" (lines 469–477). The same claim is the reason given for that shared edit.

**Simplicity Rationale:** The plan says the new page takes the next free digit, and that this cannot collide with Overview through Connections (`1`–`7`) or Settings (`,`). Digits `8` and `9` are already taken, by Terminal and System, in `FLOATING_APPS` in `apps/desktop/src/shell/apps.ts`. Both `apps/desktop/src/shell/App.tsx` and `apps/desktop/src/shell/surfaces/MainSurface.tsx` resolve a shortcut with `HERMES_APPS.find(a => a.shortcut === event.key)`, and `HERMES_APPS` lists pages before floating apps. A Board shortcut of `8` wins that search and Terminal's binding stops working. There is no free digit in `1`–`9`. The shortcut field is optional; a page with no shortcut still opens from the sidebar, `page.open`, and the command bar. Adding a digit here is an extra global binding the shell has no room for.

## 2. The five-second poll does not stop when the user leaves the Board

**Severity:** Major

**Affected Scope:** "Freshness: the events WebSocket" (lines 211–214), "Data and actions" (lines 244–246), Board page plan (lines 427–429), and "Performance" under Non-Functional Requirements (lines 360–362).

**Simplicity Rationale:** The plan clears the interval on unmount and "when the page is hidden", and the performance requirement says the poll stops when the page is hidden. `apps/desktop/DESIGN.md` says a page stays mounted when the user navigates away, and that visibility is not lifecycle. `MainWindow` keeps every visited page mounted and hides the inactive one with CSS (`visibility: hidden`); it does not unmount it, and the document itself stays visible. After the first visit, a `setInterval` cleared only on unmount keeps calling `reload` for the rest of the session. `GET /board` is the heavy read: `get_board` loads every non-archived task and runs `_compute_task_diagnostics` across the board. The shell already has the signal for "this page is showing": `$page` in `src/store/windows.ts`. `FilesPage` already subscribes to it. The interval belongs on `$page === 'board'`.

The same reload fights the "do not blank" rule. `useBackendData` sets `loading` true on every tick and keeps the previous `data`. `AutomationsPage` treats only `loading && data === null` as the spinner. A Board page that keys its empty state on `loading` will blank a good board every five seconds.

## 3. The detail pane treats a card preview as the full card

**Severity:** Major

**Affected Scope:** "The three endpoints this page reads" (lines 163–178), CUJ 2 (lines 86–93), the detail-pane bullets in the Board page plan (lines 437–439), and verification step 2 (lines 522–523).

**Simplicity Rationale:** CUJ 2 says selecting a card shows it in full, including its latest summary, and the architecture says one `GET /board` carries every field the detail pane needs. In `plugins/kanban/dashboard/plugin_api.py`, `_task_dict` on the board path stores `latest_summary` cut to `_CARD_SUMMARY_PREVIEW_CHARS` (200). The comment on that path says the full text comes from `GET /tasks/{id}`. `get_task` loads `kanban_db.latest_summary` with no cut, and also returns comments, events, attachments, links, and runs. Verification step 2 then requires the pane to match `GET /api/plugins/kanban/tasks/{id}`, which the data flow never calls. Those two instructions cannot both be true.

The smaller shape is the one the verification step already names: the five-second poll stays on `/board` for the columns, and selecting a card loads `/tasks/{id}` once for the pane. That is one request for the card the user is reading, through the same `rest.get` wrapper, and it is the read the runtime already split out so a board listing does not ship every summary.

## 4. The failure marker rebuilds a badge the board payload already has

**Severity:** Major

**Affected Scope:** Goals (line 40), the stuck-card open question (lines 66–69), and the failure-marker test in `board.test.ts` (lines 506–510).

**Simplicity Rationale:** The plan marks a card when `consecutive_failures` is above zero or `last_failure_error` is set, and adds a unit test for that predicate. `get_board` already attaches the badge the dashboard uses. `_attach_diagnostics` puts `diagnostics` on the task and a `warnings` summary `{count, kinds, latest_at, highest_severity}`, with the comment that the card badge gets the summary so the drawer does not need another round trip. A card can be in distress with `consecutive_failures` still at 0 (the respawn guard records `blocker_auth` and then stops incrementing the counter; a stale heartbeat is a diagnostic, not a spawn-failure count). `status` and `block_kind` are already on the same task object for the blocked case. The goal "a failing or blocked card is legible without hunting" is `warnings` plus `status` / `block_kind`. A new predicate and a test for it duplicate that summary and miss the cards the runtime already flagged.

## 5. "Open the board" adds a second open path and skips the speech prompt the other pages use

**Severity:** Nit

**Affected Scope:** "The commands" (lines 254–267) and the `navigation.ts` edit (lines 497–501). CUJ 4 is lines 102–106.

**Simplicity Rationale:** `resolveAppId` in `src/commands/navigation.ts` already matches a page by `id` and by `name`. A page whose id is `board` and whose name is `Board` resolves "board" with no alias. The alias that actually adds a name is `kanban`. `page.open` already has the phrases `open the {name} page`, `switch to {name}`, and `go to the {name} page`, and the matcher lets the slot swallow "the", so "open the board" hits `page.open` once the page exists. No other page registers a command whose only job is `showPage`. `board.focus` has no sibling either: list commands return `highlight`, and `ActionHud` already scrolls to `[data-os-target]`. `board.open` and `board.focus` are a second navigation path.

The path the plan does not touch is the one that makes spoken page names reliable. `STT_VOCABULARY` in `apps/desktop/src/lib/voice/stt-tuning.ts` is a fixed prompt listing Overview, Missions, Memory, Files, Automations, Connections, Settings, Terminal, and System. Board and kanban are absent. CUJ 4 depends on that prompt the same way the other pages do. The alias edit and a new `board.open` command do not update it.

## 6. Two client rules invent an order the runtime already fixed

**Severity:** Nit

**Affected Scope:** CUJ 3 (lines 96–100); the `columnLabel` helper (lines 418–419) and the column-order test (lines 509–510).

**Simplicity Rationale:** CUJ 3 says a moved card appears "in the same position in the list". `get_board` does not preserve a client index. Queue columns keep dispatch order (priority, then oldest). The `done` column is sorted again, newest `completed_at` first. A card that moves changes column and lands where that sort puts it. Remembering the old index in the renderer is a second ordering on top of the payload.

The column-order test and the capitalise fallback assume `/workflow` and `/board` can disagree. `get_workflow` returns `DEFAULT_WORKFLOW.to_dict()` and its docstring says every board uses that workflow today. `BOARD_COLUMNS` is `list(DEFAULT_WORKFLOW.keys())`, and unknown statuses are bucketed into `todo`. The two lists are the same keys. A helper and a test for a column the workflow does not list are there for a per-board workflow the same docstring defers to a later phase. Slice 1 can render `workflow.columns` and look up tasks by `key`. The fallback and the divergence test can wait until a board can actually have a different workflow.