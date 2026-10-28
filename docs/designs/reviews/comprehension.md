# Comprehension review: docs/designs/kanban-board.md

Standard: re-implementation. A reader who has only this document has to guess types, state transitions, error handling, and several user-visible behaviors. Named shell symbols were checked against the Herald-OS tree. Named kanban runtime symbols were checked against the current Hermes runtime sources this repo does not contain (`upstream/hermes-agent` is gitignored and absent).

## Feature specification (lines 1–393)

### 1. Card and detail payload is a list of names

**Severity:** Blocker

**Affected scope:** Goals (lines 38–39); CUJ 1 (lines 82–84); CUJ 2 (lines 90–93); "The three endpoints this page reads" (lines 163–198)

**Gap:** `GET /board` names the task fields a card and a detail pane need, and the sample JSON gives types only for the board envelope (`tenants`, `assignees`, `latest_event_id`, `now`). Every task field is an untyped name. A reader cannot render the page without inventing the contract. On the live payload those shapes are:

- `id` is a string. `priority` is an int; queue order is higher priority first. `assignee`, `body`, `result`, `session_id`, `workspace_path`, and `branch_name` are strings or null. `result` is a string, separate from `latest_summary`.
- `created_at`, `started_at`, `completed_at`, `current_run_started_at`, and `now` are unix seconds, or null when unset. `started_at` is the first start ever. After a retry the run clock is `current_run_started_at`.
- `age` is an object, `{ created_age_seconds, started_age_seconds, time_to_complete_seconds }`, each a number of seconds or null. It is not a single duration.
- `progress` is `{ done, total }` or null when the card has no children. `link_counts` is `{ parents, children }`.
- `latest_summary` on `/board` is truncated to 200 characters. The full text is only on `GET /tasks/{id}`.
- `block_kind` is `dependency`, `needs_input`, `capability`, `transient`, or null. A circuit-breaker block can sit in `blocked` with `block_kind` null.
- The payload also attaches `diagnostics` (a list) and `warnings` (`{ count, kinds, latest_at, highest_severity }`) when the runtime has any. The field list omits both.
- `status` is the column key (`triage`, `todo`, `scheduled`, `ready`, `running`, `blocked`, `review`, `done`).

CUJ 2 asks for "how long it has been running" and does not say which clock, or what to show when `current_run_started_at` is null. The goal list, the field list at lines 175–178, and CUJ 2 name different sets: the field list includes `result`, `block_kind`, `session_id`, `workspace_path`, and `branch_name`; CUJ 2 leaves those out and adds a running duration that is not a field. Timestamp formatting, a null assignee, a null summary, and whether `body` is plain text or markdown are all unspecified. `ProgressBar` in this repo treats its value as a percentage from 0 to 100; the document never says how `{ done, total }` becomes that number, or that the bar is omitted when `progress` is null.

### 2. Empty, missing, and failed boards are one sentence

**Severity:** Blocker

**Affected scope:** CUJ 5 (lines 108–114); the reachability table (lines 147–157); Failure behaviour (lines 363–365)

**Gap:** CUJ 5 binds three causes to one outcome: "the runtime has no board", the kanban plugin is not mounted, and the backend is not ready. Each must "explain what is wrong in one sentence" and offer a retry, and must not look like an empty grid. The sentences, the retry action, and the way the page tells the causes apart are not given.

A current board always exists. `list_boards` always includes `default`, and `GET /board` initialises the database. A healthy queue with zero cards is an empty board, which is a different screen from "plugin missing". The document has no rule for that healthy empty board.

The page never sees an HTTP status. `BackendManager.rest` throws `Error` with the text `GET <path> -> <status>: <detail>`, and throws `Hermes backend is not ready` before any request when the backend phase is not `ready`. `useBackendData` stores that message and, on a later failure, leaves the previous `data` in place. While the gateway epoch is still 0 the hook returns without setting `data`, `error`, or `loading`, so a naive "no tasks" check paints "backend not ready" as "no work".

The failure section says a failed fetch keeps the last good board and shows the error next to the refresh button, and that a missing plugin is a distinct "not available" state. It does not say which of `/board`, `/workflow`, and `/boards` failing produces which state, or what happens when a 404 arrives after a good payload is already on screen.

The reachability table says the same path outside `/api/` returns 404. The bridge never sends that request. It throws `refusing REST path outside /api: ...`.

### 3. Column membership, order, and width are not a rule

**Severity:** Major

**Affected scope:** CUJ 1 (lines 82–84); CUJ 3 (lines 95–100); Layout (lines 222–230)

**Gap:** The page must group cards into the runtime's columns, in the runtime's order. `/board` columns have `name`. `/workflow` columns have `key`. Tasks have `status`. The document never says those three strings are the same key, or what to do with a task whose status matches no column (the runtime buckets unknowns into `todo`).

CUJ 3 says a moved card appears "in the same position in the list". Position is not defined. The runtime keeps queue-column order as priority descending, then `created_at` ascending, and re-sorts `done` by `completed_at` descending. A client that preserves array order and a client that sorts by title both satisfy the prose, and neither can keep a stable index across a move.

Layout says the columns keep their natural width, and also that each column is fixed-width. No width is given. Whether a column with zero cards stays on the strip is not stated. The board payload includes every workflow column even when its task list is empty, which is the behaviour an eight-column strip needs, and the document does not say to keep those empty columns.

### 4. "Failing" and "blocked" have no marker rule

**Severity:** Major

**Affected scope:** Goals (line 40); Open question "How loud should a stuck card be?" (lines 66–69); CUJ 1 (line 83)

**Gap:** A failing or blocked card must be legible without hunting, and cards with failures are marked. The marker's condition and its appearance are not specified. `consecutive_failures` above zero, a non-null `last_failure_error`, `status` of `blocked`, a non-null `block_kind`, and a `warnings` badge are different sets. A human block often has `consecutive_failures` of 0 and `block_kind` set. A circuit-breaker block can have failures counted and `block_kind` null. The open question says slice 1 shows a marker on the card and the error text in the detail pane, and does not say which field is the marker or which field is the error text (`last_failure_error` versus `warnings`).

### 5. Selection and search lifetime contradict each other

**Severity:** Major

**Affected scope:** CUJ 2 (lines 86–93); CUJ 4 (lines 102–106); Layout search paragraph (lines 234–238)

**Gap:** CUJ 4 restores the same selection and filter when the page is opened again. The search paragraph says the filter does not persist. Nothing says whether "persist" means across leaving the page, across restarting the shell, or across a poll. Nothing says whether opening the page selects a card. With no selection, the detail pane's contents are unspecified. Nothing says what happens when a refresh or a filter removes the selected card: keep a stale pane, clear the selection, or select another card. The feature scope also does not say how a title match works (substring or whole title, case folding).

### 6. The five-second refresh has no visibility signal, and the state owner is contradicted

**Severity:** Major

**Affected scope:** Freshness (lines 211–214); Data and actions (lines 244–248)

**Gap:** The poll runs while the page is visible and stops when the page is hidden or the backend is not ready. In this shell, visited pages stay mounted and are hidden with CSS (`MainWindow.tsx`; `apps/desktop/DESIGN.md` says visibility is not lifecycle). Unmount does not run when the user opens Missions. The document does not name `$page` in `src/store/windows.ts`, or `$backend.phase` / the gateway epoch, so a reader can poll on `document.visibilityState` and keep fetching while another page is showing.

The same section says the page owns state under `src/features/board/` the way automations does, and that there is no new store file. Automations has no store module. Voice commands in this shell reach a page through a `focus*()` atom (DESIGN.md). The section forbids the file that pattern uses, and does not say where the selected id and the search string live instead.

### 7. The commands are names without contracts, and voice cannot point at a card

**Severity:** Major

**Affected scope:** Data and actions (lines 249–252); The commands (lines 254–267)

**Gap:** Each command is a tier and a one-line purpose. An `OsCommand` also needs a `title`, an `args` list, `phrases`, and a `run` result (`src/store/os-commands.ts`). None of those are given. `board.search` does not say the argument name or whether an empty query clears the filter. `board.select` says "the first card" without saying first visible card, first column, or payload order, or what happens when the id is unknown. `board.focus` does not say the target element or the no-selection case. `board.refresh` does not say how a command outside the page reaches the loader.

Cards use `data-os-target="kanban:<task id>"` so voice can point at them. Pointing works only when the command result's `highlight.kind` matches that prefix (`OsHighlighter`). `CommandHighlight.kind` is `page | memory | automation | mission | file | window | connection | setting`. `kanban` is not in that union. Returning it is a type error unless `src/store/os-commands.ts` changes. This section says `src/store/` is unchanged. The document never mentions `highlight`.

### 8. "Worker profiles" and the runtime sources are undefined here

**Severity:** Major

**Affected scope:** Overview (lines 12–13); trust-gate paragraph (lines 154–156); Additional Resources (lines 371–378)

**Gap:** The board is "the queue of cards Hermes and its worker profiles pick up". A worker profile is never defined or linked. In the runtime it is the named profile in `assignee`, which the dispatcher spawns. A reader cannot tell an assignee from a person, a session, or a tenant.

The resources point at `plugins/kanban/dashboard/plugin_api.py`, `hermes_cli/kanban_db.py`, and `hermes_cli/web_server_dashboard.py`. Those paths are not in this repository, and the document gives no repository URL, commit, or version. `_plugin_api_mount_skip_reason`, `coalesced_read`, and `task_events` are named the same way. The inlined JSON is not enough to replace those files, which is why the task schema in finding 1 is still open.

### 9. The shared-file count does not match the table

**Severity:** Nit

**Affected scope:** Shared files this changes (lines 272–280)

**Gap:** The prose says the slice touches four shared files. The table has five: `apps.ts`, `MainWindow.tsx`, `app-icon.tsx`, `commands/index.ts`, and `commands/navigation.ts`.

## Detailed implementation plan (lines 394–535)

### 10. `BoardTask` is still an untyped name list

**Severity:** Blocker

**Affected scope:** `apps/desktop/src/features/board/api.ts` (lines 403–419)

**Gap:** The plan types the board envelope, workflow columns, and a narrow boards row (`slug`, `name`, `is_current`). `name` does exist on board metadata. `BoardTask` repeats the same name list as the feature spec and adds an index signature. It still does not say which fields are string, number, null, or object. `age`, `progress`, and `link_counts` stay opaque, so the detail pane and `ProgressBar` still have no formula. `diagnostics` and `warnings` are absent, so a strict interface drops the runtime's own badge. `Workflow` omits the `archived` string that `GET /workflow` returns beside `columns` and `manual`. `columnLabel`'s "capitalised key" does not say the transform (`scheduled` to `Scheduled` is a guess) or where a column that is missing from the workflow is inserted.

### 11. The plan's error UI blanks the board the feature section keeps

**Severity:** Blocker

**Affected scope:** `BoardPage.tsx` (lines 425–429 and 446–447); Verification items 6 (lines 528–529)

**Gap:** The plan sends every empty and error state through `EmptyGlass`. The feature section says a failed fetch keeps the last good board and puts the error next to the refresh button. Following the plan clears that board. "A 404 from the plugin route" is the only detector given. `rest.get` does not return a status; `useBackendData.error` is the thrown message string, and a later error does not clear `data`. The plan does not say which loader's 404 wins when `/board`, `/workflow`, and `/boards` disagree, what the "not available" sentence is, what the zero-card sentence is, or what to draw when `data` is null and `error` is null because the backend is not ready. Verification item 6 requires the last good board to stay visible, which `EmptyGlass`-on-error does not do.

### 12. The tests name behaviour the plan never specifies as functions

**Severity:** Major

**Affected scope:** `api.ts` (lines 418–419); `board.test.ts` (lines 503–510); column strip (lines 432–433)

**Gap:** The test file covers four pure helpers. The plan defines one, `columnLabel`. The card filter, the failure marker, and the column-order helper have no names, no modules, and no signatures. The filter is case-insensitive on title and returns every card for an empty query. Substring versus whole-title match is still open, and so is whether the search string is trimmed. The failure marker is `consecutive_failures` above zero or a present `last_failure_error`. That rule misses a blocked card with neither, which the feature goal requires to be legible. Column order "follows `workflow.columns` rather than the board payload". The plan never says to match `task.status` to `column.key` / `column.name`, or where cards from a board column that the workflow does not list go.

### 13. Commands, selection, and refresh are still incomplete

**Severity:** Major

**Affected scope:** `commands/board.ts` (lines 449–459); `board-store.ts` (lines 461–467); card rendering (lines 434–436)

**Gap:** The plan adds `tier`, `description`, `phrases`, and `ok` / `fail`, and still gives no `title`, no `args`, no phrase strings, and no spoken summaries. `OsCommand.title` and `args` are required. `board.select` and `board.search` call `focusBoard()`, whose argument shape is "a focus counter" in one sentence and `focusBoard(focus)` in another. The store holds the selected id, the search query, and that counter. It has no reload signal, and the board data stays inside the page loader, so `board.refresh` has no path to `reload`. The card is a `GlassCard` with `selected` set. The plan never says a click or a key writes the selected id. `board.select` still does not define "the first card".

Voice pointing still needs `highlight: { kind: 'kanban', id }` (see finding 7). The plan does not return a highlight and does not add `kanban` to `CommandHighlight`. `data-os-target` alone does not move the highlighter.

This store file also contradicts the feature section's "No new store file" and its automations analogy. Automations has no store. The plan follows `memory-store.ts`, which does. A reader cannot obey both sections.

### 14. The page registry shortcut collides, and required registry fields are missing

**Severity:** Major

**Affected scope:** `apps/desktop/src/shell/apps.ts` (lines 469–477)

**Gap:** `HermesAppDef` requires `name`, `tagline`, and `category` (`productivity | creative | development | system`). The plan specifies `kind`, `icon`, "a tagline", and a shortcut. It does not give `name`, the tagline string, or `category`. The shortcut is "the next free digit" after `1`–`7` and `,`. In `HERMES_APPS`, `8` is Terminal and `9` is System. Shortcuts are matched with `HERMES_APPS.find` in `App.tsx`, and `PAGES` come first, so a Board shortcut of `8` takes Cmd/Ctrl+8 from Terminal. The plan says no other binding changes. No free digit is named.

### 15. The detail pane and the verification check describe different responses

**Severity:** Major

**Affected scope:** `BoardPage.tsx` detail pane (lines 437–439); Verification item 2 (lines 522–523)

**Gap:** The pane is rendered from the three loaders. The plan never calls `GET /api/plugins/kanban/tasks/{id}`. Verification item 2 says the pane's fields match that endpoint for the same card. That endpoint returns `{ task, comments, events, attachments, links, link_tasks, child_results, runs }`, and its `latest_summary` is the full text. The board card's `latest_summary` is a 200-character preview. A pane built only from `/board` fails the check. The pane field list (timestamps, `age`, session id, workspace, branch, failure error) still does not say how `age` or the running duration is formatted, and it still omits `result` and `block_kind`. Whether `body` and `latest_summary` are markdown is unspecified.

### 16. "Visible" and "backend ready" are still unnamed signals

**Severity:** Major

**Affected scope:** `BoardPage.tsx` poll (lines 427–429)

**Gap:** The interval calls the board loader's `reload` while this page is the visible one, clears on unmount and when the page is hidden, and skips while the backend is not ready. Unmount does not happen on page change, because `MainWindow` keeps visited pages mounted and hides them. The plan does not name `$page`. It does not name `$backend` or `$connectionEpoch`. `useBackendData` already refuses to load at epoch 0, which is a different condition from `BackendPhase !== 'ready'` (the phase can be `restarting` or `failed` while an old epoch is non-zero). The plan does not say which of those gates the interval, or whether a hidden page may finish a request already in flight.
