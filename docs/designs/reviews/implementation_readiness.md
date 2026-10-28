# Implementation readiness findings

Target: `docs/designs/kanban-board.md`, Detailed Implementation Plan, lines 394–535.

## 1. Blocker — Card payload has names and no types, so the detail pane cannot be written

**Affected scope:** Step 1, `apps/desktop/src/features/board/api.ts` (plan lines 403–419). Step 2 detail pane (plan lines 437–439).

**Finding:** `BoardTask` is a list of field names plus an unspecified index signature. The fields the pane has to render are not scalars, and the plan never says how to format them.

The live kanban plugin (`plugin_api.get_board` / `kanban_db.Task` / `task_age`) returns:

- `id`, `title`, `status`: string.
- `body`, `assignee`, `result`, `session_id`, `workspace_path`, `branch_name`, `last_failure_error`: string or null.
- `priority`, `consecutive_failures`: number. `priority` is an integer, not a label.
- `created_at`, `started_at`, `completed_at`, `current_run_started_at`: unix seconds or null. Passing one to `new Date` as if it were milliseconds renders 1970.
- `age`: `{ created_age_seconds, started_age_seconds, time_to_complete_seconds }`, each a number or null. These are durations in seconds, not timestamps.
- `progress`: `{ done: number, total: number }` or null. Null means the card has no children. `ProgressBar` in `apps/desktop/src/components/ui/glass.tsx` takes a 0–100 `value`. The plan never says to hide the bar when `progress` is null, or to pass `done / total * 100`.
- `link_counts`: `{ parents: number, children: number }`. `comment_count`: number.
- `block_kind`: `"dependency" | "needs_input" | "capability" | "transient"` or null.
- `latest_summary`: string or null, and on `GET /board` it is cut to 200 characters (`_CARD_SUMMARY_PREVIEW_CHARS`). The full text is only on `GET /tasks/{id}`.

`started_at` is the first time the task ever started. `current_run_started_at` is the start of the current run, which is what moves after a retry. The plan tells the pane to show both "timestamps" and "age" and does not say which value is "how long it has been running".

`tenants: string[]` and `assignees: string[]` on `Board` match the current payload. The task fields above do not match anything an implementer can infer from the names.

The card face is the same gap. Step 2 says to render a `GlassCard` with `interactive`, `selected`, and `data-os-target`. It does not say the face shows title, assignee, priority, and a failure marker (that list is only in CUJ 1), or which primitive and tone mark a failure (`Pill` / `StatusDot`, `danger` vs `warn`).

## 2. Blocker — The page shortcut the plan asks for is already taken, and the `PAGES` entry is not a complete value

**Affected scope:** Step 5, `apps/desktop/src/shell/apps.ts` (plan lines 469–477). Also `apps/desktop/src/shell/App.tsx` lines 59–64 and `apps/desktop/src/shell/surfaces/MainSurface.tsx` lines 70–76.

**Finding:** `HermesAppDef` requires `name`, `tagline`, and `category` (`apps.ts` lines 14–25). Step 5 specifies `kind`, `icon`, "a tagline", and "a shortcut", and does not give the name, the tagline string, or the category (`'productivity' | 'creative' | 'development' | 'system'`). `PAGE_LABEL` in step 6 is `'Board'`. The sidebar label comes from `PAGES[].name` (`Sidebar.tsx` lines 86–107), not from `PAGE_LABEL`, so the name has to be specified as `Board` or the sidebar and the error-boundary label diverge.

The shortcut instruction is wrong against this tree. Page shortcuts `1`–`7` and `,` are the pages. Digit `8` is Terminal and digit `9` is System (`apps.ts` lines 56–57). Both key handlers search `HERMES_APPS`, which is `[...PAGES, ...FLOATING_APPS]` (`apps.ts` line 73) and return the first match. The "next free digit" is not free. Putting `'8'` on the board page makes Cmd/Ctrl+8 open Board and stops opening Terminal. There is no remaining digit the plan names (`0` is unused, and the plan does not say to use it).

The same paragraph says the sidebar renders the shortcut from that entry. It does not. `Sidebar.tsx` renders the icon and the name only. The shortcut hint is the command bar (`CommandBar.tsx` around line 241).

`PageId` and `AppIconId` are exhaustive. `MainWindow.tsx` lines 9 and 20 (`Record<PageId, …>`) and `app-icon.tsx` line 7 (`Record<AppIconId, …>`) fail `npm run typecheck` if `apps.ts` lands without steps 6 and 7. The plan never says those three edits ship together.

## 3. Blocker — Verification item 2 cannot pass with the client the plan specifies

**Affected scope:** Step 1 `boardApi` (plan lines 415–417). Verification item 2 (plan lines 522–523).

**Finding:** Item 2 says the detail pane's fields match `GET /api/plugins/kanban/tasks/{id}` for the same card. `boardApi` only calls `/board`, `/workflow`, and `/boards`. Nothing in the plan fetches `/tasks/{id}`.

Those two responses are different documents. `/board` puts a 200-character preview in `latest_summary` and `{ done, total } | null` in `progress`. `/tasks/{id}` returns `{ task, comments, events, attachments, links, link_tasks, child_results, runs }`, with the full summary on `task` and per-child rows in `child_results`. An implementer who follows the file list fails the check. An implementer who adds the task fetch to make the check pass is inventing a request, a type, and a loading rule the plan does not contain.

The plan has to choose one and rewrite the other: either the pane is defined as the `/board` fields (and item 2 compares those fields, including the preview), or `boardApi` gains a `task(id)` call and the pane is defined from that response.

## 4. Blocker — Loading, empty, 404, and "backend not ready" are one sentence, and it disagrees with the verification

**Affected scope:** Step 2 (plan lines 427–429 and 446–447). Verification items 6 and the CUJ 5 behavior the plan claims to satisfy (plan lines 528–529). `apps/desktop/src/lib/use-async.ts` lines 16–54. `apps/desktop/electron/backend/manager.ts` lines 102–140.

**Finding:** Step 2 says every empty state and every error state is an `EmptyGlass` plus a retry button, and a 404 is a "not available" message distinct from "no cards". Verification item 6 says stopping the backend shows an error with a retry and the last good board stays on screen. The non-functional section (lines 363–365) says the same thing: do not blank the page. Both instructions are in the document. They produce different UIs. `AutomationsPage.tsx` (lines 249–275) hides the list whenever `error` is set, so copying that page, which step 2 points at, blanks the board.

`useBackendData` does not clear `data` when a later fetch fails (it only sets `error`). It also does not fetch while `$connectionEpoch` is 0: the effect returns immediately, and `data`, `error`, and `loading` stay `null / null / false`. A page that treats "no data and no error" as an empty board shows the empty grid CUJ 5 forbids, during the whole time the backend is still starting. The plan says to skip the interval while the backend is not ready. It does not say what to render in that state, and it does not name `$backend.phase` in `src/store/backend.ts`.

There is no status code on the failure. `BackendManager.rest` throws `Error` with the message `` `${method} ${path} -> ${status}: ${detail}` ``, or `Hermes backend is not ready` when `phase !== 'ready'` (manager.ts lines 102–104), before any HTTP call. A 404 is a substring of that message. The plan says "a 404" and does not say to match `-> 404`.

The four situations the page has to tell apart, and currently cannot from the text:

- Backend not ready (`Hermes backend is not ready`, or epoch still 0): one sentence plus retry, not an empty column strip.
- Plugin route 404: "not available", not "no cards".
- 200 with zero tasks: the empty board, which must not look like the two states above.
- A later fetch failed and a board is already on screen: keep that board, put the error next to the refresh button, do not swap in `EmptyGlass`.

The plan gives none of the sentences, and step 2's `EmptyGlass` rule covers the last case that verification says must keep the board.

## 5. Major — The five-second poll never stops when the user leaves the page

**Affected scope:** Step 2 (plan lines 427–429). `apps/desktop/src/shell/MainWindow.tsx` lines 8 and 33–54. `apps/desktop/DESIGN.md` line 29.

**Finding:** The plan clears the interval on unmount and "when the page is hidden". Visited pages stay mounted. `MainWindow` hides an inactive page with `visibility: hidden` on a wrapper and does not unmount it, and `DESIGN.md` states that visibility is not lifecycle. The page component receives no prop. `document.visibilityState` also stays `visible` when the user switches to Missions, so a `visibilitychange` listener does not fire.

Unmount cleanup runs when the window goes away, not when the user leaves Board. After the first visit the interval keeps calling `reload` on a hidden page. The signal for "this page is the visible one" is `$page === 'board'` from `src/store/windows.ts`. The plan does not name it. The backend-not-ready skip has the same hole: the plan does not name `$backend.phase !== 'ready'` (or the epoch check `useBackendData` already performs).

## 6. Major — The five commands are names, and `board.refresh` has no way to reach the loader

**Affected scope:** Step 3, `apps/desktop/src/commands/board.ts` (plan lines 449–459). Step 4, `board-store.ts` (plan lines 461–467). `apps/desktop/src/store/os-commands.ts` lines 14–27 and 52–64. `apps/desktop/src/features/voice/ActionHud.tsx` lines 82–93. `apps/desktop/src/components/ui/glass.tsx` lines 27–39.

**Finding:** An `OsCommand` needs `title`, `description`, `tier`, `args` (`name`, `type`, `required`), `phrases`, and a `run` that returns `ok` / `fail` with a `summary`. Voice matches only whole phrases (`src/lib/voice/intents.ts`). Step 3 says each command has a tier, a description, spoken phrases, and a run, and then specifies only `board.open` → `showPage('board')`. It does not give titles, argument lists, phrase strings, or the `summary` / `spoken` lines.

The behavior that is still a design choice:

- `board.refresh` must refetch. The plan keeps the board inside the page's `useBackendData` and keeps the store free of board data. `reload` exists only inside the component. A command cannot call it. The store's "focus counter" is described as the thing select and search bump. The plan never says refresh bumps a generation the page's effect observes, which is the only path that fits the ownership rule the plan just set.
- `board.select` takes an id, or selects "the first card" when the id is omitted. First in workflow order, then payload order, is not stated. What `run` returns when the id is not on the board is not stated. The command cannot know the first id until the page has data, and the plan does not say the page resolves "first" after load.
- `board.search` filters by title. It does not say whether the command also calls `showPage('board')`, what it returns when nothing matches, or the argument name (`query`).
- `board.focus` "moves keyboard focus to the selected card". `GlassCard` renders a `div` unless `as="button"` (`glass.tsx` line 27). A `div` is not focusable. The plan does not say `as="button"` or `tabIndex={0}`, or what to do when nothing is selected.
- Cards set `data-os-target={`kanban:${task.id}`}`. `OsHighlighter` only scrolls to an element when the command result includes `highlight: { kind, id }` and `kind` is not `page`, `window`, or `setting`. `CommandHighlight['kind']` is `'page' | 'memory' | 'automation' | 'mission' | 'file' | 'window' | 'connection' | 'setting'`. `'kanban'` is not in that union, and `os-commands.ts` is not in the file list. Returning `{ kind: 'kanban', id }` does not typecheck. Omitting `highlight` means the attribute the plan adds never points the voice highlighter at the card. `board.select` has to return `highlight: { kind: 'kanban', id }` and the union has to grow, in the same change.

`open.any` already routes "open the board" through `resolveAppId` once the page name or the `kanban` alias exists (`open.ts` lines 32–33, phrases `open {name}`). That covers CUJ 4's utterance. It does not define `board.refresh`, `board.search`, `board.select`, or `board.focus`.

## 7. Major — Column order, the label fallback, and the tested helpers describe three different joins

**Affected scope:** Step 1 `columnLabel` (plan lines 418–419). Step 2 column strip (plan lines 432–433). Step 10 tests (plan lines 506–510).

**Finding:** Board columns are `{ name, tasks }`. Workflow columns are `{ key, label, icon, drag_target }`. The plan never says the join key is `workflow.columns[].key === board.columns[].name`.

Step 2 iterates `workflow.columns` only. `columnLabel` exists so a column the workflow does not list still renders, with a capitalised key. Those two rules disagree: a board column absent from the workflow is dropped if the strip only walks `workflow.columns`, and `columnLabel` is then dead. The test says order follows `workflow.columns`, not the board payload, and does not say where a workflow-only gap (an extra board column) goes.

The capitalisation rule is also unspecified for a key like `in_progress` (`In_progress` versus `In progress`). Today's keys are single words (`triage`, `todo`, `scheduled`, `ready`, `running`, `blocked`, `review`, `done`), so the first letter is enough only while that stays true. The helper is documented as the way a new runtime column still renders, which is the case where the key may not be one word.

The test file also requires a title filter (case-insensitive, empty query returns every card) and a failure marker (`consecutive_failures > 0` or `last_failure_error` present). Only `columnLabel` is named, and only `columnLabel` is placed in `api.ts`. The filter and the marker have no function name and no module. "last_failure_error is present" does not say whether `""` counts. After a title filter, the plan does not say whether a column with zero matching cards stays on the strip.

`GET /workflow` also returns `archived: "archived"` beside `columns` and `manual` (`Workflow.to_dict`). The plan's `Workflow` interface omits it. That is harmless if the page never reads it. It is another sign the interface was not taken from the response.

## 8. Major — The plan both forbids a store file and tells the implementer to add one

**Affected scope:** Step 4 (plan lines 461–467). Architecture section, lines 247–248.

**Finding:** Lines 247–248 say the page owns its state under `src/features/board/`, and then: "No new store file, no change to `src/store/`." Step 4 creates `apps/desktop/src/features/board/board-store.ts` with a nanostore atom pair and `focusBoard`. Automations, the page step 2 says to follow, keeps selection and the search string in `useState` and has no store file. Memory, the pattern step 4 cites, has `memory-store.ts` because commands call `focusMemory`.

Both sentences cannot be followed. Without the store, `board.search` and `board.select` have nowhere to write that survives the page (and commands cannot import the page). With the store, the architecture sentence is ignored. The plan has to strike one of them. The file, if it stays, needs the `BoardFocus` shape: which fields (`taskId`, `query`, the counter) each command sets, and whether the search box is controlled by the atom or copied into local state the way `MemoryPage` copies `$memoryFocus`.
