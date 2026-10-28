## Findings

### 1. Shortcut "next free digit" collides with Terminal and System

**Severity**: Blocker

**Affected Scope**: `docs/designs/kanban-board.md` lines 473-477. `apps/desktop/src/shell/apps.ts` lines 45-57. `apps/desktop/src/shell/App.tsx` lines 59-66. `apps/desktop/src/shell/surfaces/MainSurface.tsx` lines 70-77. `apps/desktop/src/shell/Sidebar.tsx` lines 86-106. `apps/desktop/src/shell/CommandBar.tsx` line 241. `docs/manual/hotkeys.md` lines 22-24.

**Discrepancy**: The plan says the new page takes the next free digit after page shortcuts `1` through `7` and `,`, and that the sidebar paints that shortcut from the `PAGES` entry so no other binding changes. Page shortcuts in `PAGES` are `1`–`7` and `,`. `FLOATING_APPS` already binds `8` to Terminal and `9` to System. Both `App.tsx` and `MainSurface.tsx` resolve `HERMES_APPS` (pages and floating apps together) with `a.shortcut === event.key`, so digit `8` opens Terminal and digit `9` opens System. There is no free digit in `1`–`9`. `docs/manual/hotkeys.md` records the same map (`Cmd+1`…`Cmd+7` for the current pages, `Cmd+8` for Terminal) and is not in the plan's file list. The sidebar does not render shortcuts at all: `Sidebar.tsx` shows the glyph and `def.name` only. The shortcut hint is the command bar, `CommandBar.tsx` line 241. An implementer who follows "the next free digit" ships a binding that steals Terminal.

### 2. The `PAGES` entry and the page title are not specified

**Severity**: Blocker

**Affected Scope**: `docs/designs/kanban-board.md` lines 430-431 and 471-477. `apps/desktop/src/shell/apps.ts` lines 14-25 and 44-52. `apps/desktop/src/components/ui/glass.tsx` lines 12-22. `apps/desktop/src/commands/navigation.ts` lines 59-71.

**Discrepancy**: `HermesAppDef` requires `name`, `tagline`, `category`, `kind`, and `icon`. `category` is `'productivity' | 'creative' | 'development' | 'system'`. The plan says to add one entry after `missions` with `kind: 'page'`, `icon: 'board'`, "a tagline", and a shortcut. It never gives `name`, the tagline string, or `category`. `resolveAppId` matches `p.name.toLowerCase()` before aliases, and the sidebar label is `def.name`. `PageHeader` requires a `title` string. The plan sets the subtitle to the current board's name and never says what the header title is. Those are product choices the implementer would have to make. Voice for the word "board" still resolves once `id` is `'board'`, because `resolveAppId` checks the id before aliases, so the planned alias `board: 'board'` does not choose the visible name.

### 3. The five commands cannot be written from the plan, and `kanban:` cannot be highlighted

**Severity**: Blocker

**Affected Scope**: `docs/designs/kanban-board.md` lines 434-436 and 449-467. `apps/desktop/src/store/os-commands.ts` lines 24-27 and 52-64. `apps/desktop/src/features/voice/ActionHud.tsx` lines 82-93. `apps/desktop/src/commands/memory.ts` lines 63-90. `apps/desktop/src/commands/automations.ts` lines 46-64. `apps/desktop/src/lib/use-async.ts` lines 16-54.

**Discrepancy**: `OsCommand` requires `title`, `description`, `tier`, `args`, and `run`. `defineCommands` rejects an id that fails `/^[a-z][a-z0-9]*(\.[a-z][a-zA-Z0-9]*)+$/`, and `validateArgs` rejects unknown argument names. The plan names `board.open`, `board.refresh`, `board.search`, `board.select`, and `board.focus`, says each has a tier, a description, spoken phrases, and a `run`, and then specifies only two bodies: `board.open` calls `showPage('board')`, and `board.select` and `board.search` call `focusBoard()`. It gives no titles, no tier per command, no phrase strings, no `args` (search needs a query, select needs an id), no not-found result, and no rule for which card is first when select is called without an id. `board.refresh` and `board.focus` have no body. The plan also says the board payload stays inside the page loader, so a command cannot refetch it. `useBackendData` returns `reload` only to the component that called the hook. Nothing in the plan is a bridge a command can bump to call that `reload`. `board.focus` has no DOM target: `GlassCard`'s default element is a `div`, which is not focusable until someone sets `tabIndex` or renders `as="button"`.

`data-os-target={`kanban:${task.id}`}` does not point the voice HUD at the card by itself. `OsHighlighter` queries `[data-os-target="${target.kind}:${target.id}"]` from `result.highlight`. `CommandHighlight['kind']` is `'page' | 'memory' | 'automation' | 'mission' | 'file' | 'window' | 'connection' | 'setting'`. There is no `'kanban'`. Memory and automations commands return `highlight: { kind: 'memory' | 'automation', id }` to match their attributes. Returning `kind: 'kanban'` fails typecheck until `apps/desktop/src/store/os-commands.ts` changes, and that file is not in the plan.

### 4. Polling, 404, and the error state disagree with the hook the plan says to use

**Severity**: Blocker

**Affected Scope**: `docs/designs/kanban-board.md` lines 425-429, 446-447, and 526-529. `apps/desktop/src/lib/use-async.ts` lines 16-54. `apps/desktop/src/store/gateway.ts` lines 16-17 and 31-34. `apps/desktop/src/store/backend.ts` line 7. `apps/desktop/shared/ipc.ts` lines 8 and 19-20. `apps/desktop/electron/backend/manager.ts` lines 99-140. `apps/desktop/src/shell/MainWindow.tsx` lines 8-9 and 33-48. `apps/desktop/src/features/automations/AutomationsPage.tsx` lines 223-260.

**Discrepancy**: The plan tells the page to poll `board` every five seconds, skip the poll while the backend is not ready, clear the timer on unmount and when the page is hidden, render `EmptyGlass` for errors, and treat a 404 as "not available", distinct from "no cards". The verification plan then says stopping the backend shows an error with a retry while the last good board stays visible.

`useBackendData` skips the loader only when `enabled` is false or `$connectionEpoch === 0`. Epoch starts at 0 and only increments on `gateway.ready`. It is not cleared when the backend stops. After the first successful connect, epoch stays above 0 while `$backend.phase` is `'stopped'`, `'failed'`, `'restarting'`, or anything else in `BackendPhase`. Readiness for REST is `$backend.phase === 'ready'`. `manager.rest` throws `new Error('Hermes backend is not ready')` when `phase !== 'ready'`, and throws `new Error(`${method} ${path} -> ${status}: ${detail}`)` on any HTTP error. The renderer never receives a status code. `useBackendData` stores `err.message` and leaves the previous `data` in place. A 404 is detectable only by parsing that string, and the plan never says to parse it. The same string is the only way to tell a missing plugin from "backend is not ready" or a 500.

`MainWindow` keeps visited pages mounted and hides them with `visibility: 'hidden'`. Unmount does not run when the user leaves the Board. The plan never names `$page` from `apps/desktop/src/store/windows.ts` as the visibility signal. Skipping the interval whenever the backend is not ready also means stopping the backend never calls `reload`, so the error state in verification step 6 never appears. Copying the Automations page makes the opposite mistake: `AutomationsPage` sets `showRight` false and replaces the list with `EmptyGlass` whenever `jobs.error` is set, which hides the last good payload that `useBackendData` kept. The plan's render bullet matches that replacement. Verification step 6 matches keeping the payload. The implementer has to pick one. The plan also starts three loaders (`board`, `workflow`, `boards`) and never says which error is the 404, or what to draw when `board` succeeds and `workflow` fails.

### 5. Card fields have no types, and the timestamp converter already exists

**Severity**: Blocker

**Affected Scope**: `docs/designs/kanban-board.md` lines 403-412, 437-439, and 522-523. `apps/desktop/src/components/ui/glass.tsx` lines 180-190 and 237-244. `apps/desktop/src/features/memory/MemoryRow.tsx` line 6. `apps/desktop/src/features/automations/cron-humanize.ts` lines 24-36.

**Discrepancy**: `BoardTask` is a list of names (`id`, `title`, `body`, `assignee`, `status`, `priority`, the three timestamps, `age`, `latest_summary`, `current_run_started_at`, `progress`, `link_counts`, `comment_count`, `consecutive_failures`, `last_failure_error`, `block_kind`, `session_id`, `workspace_path`, `branch_name`, `result`) plus an index signature. None of those fields has a TypeScript type. The page still has to render timestamps, age, child progress, and link and comment counts. `ProgressBar` takes `value: number` and clamps it to 0–100. `KeyValue` takes `{ label, value }[]`. The plan never maps `progress` or `link_counts` onto those props. The Hermes kanban plugin is not in this repository (`plugins/kanban/dashboard/plugin_api.py` and `hermes_cli/kanban_db.py` are cited as runtime files and are absent here), so the plan is the only schema, and it does not contain one.

`Board.now` is typed only as `number`. The sample payload earlier in the same document is `1793156717`, which is Unix seconds (about 2026-10-28). `formatShortDate` in `MemoryRow.tsx` passes the number straight to `new Date`, which treats it as milliseconds and renders January 1970. The converter that already handles this mix is `toMs` in `apps/desktop/src/features/automations/cron-humanize.ts`: numbers below `1e12` are multiplied by 1000, and ISO strings go through `Date.parse`. The plan tells the implementer to render the timestamps and does not name `toMs`, so the page grows a second clock parser. Verification step 2 compares the pane to `GET /api/plugins/kanban/tasks/{id}`. The planned client never calls that route and never types its body, so a mismatch between the board card and the task route has no specified winner.

### 6. Column order, the join key, and `columnLabel` are three different rules

**Severity**: Major

**Affected Scope**: `docs/designs/kanban-board.md` lines 403-419, 432-433, and 506-510. `apps/desktop/src/features/overview/shared.tsx` lines 27-29.

**Discrepancy**: `BoardColumn` identifies a column with `name`. `WorkflowColumn` identifies it with `key`. The plan never says the join is `column.name === workflowColumn.key` (or `task.status`, or anything else). The page bullet renders one column per `workflow.columns` entry. `columnLabel(workflow, key)` falls back to a capitalised key when the workflow does not list that key, "so a new runtime column still renders." The test then requires order to follow `workflow.columns` rather than the board payload. A fallback for keys the workflow does not list only runs if board columns absent from the workflow are still rendered, which the page bullet does not say. Where those extra columns go (dropped, appended, sorted by `name`) is an open choice. "Capitalised" is also open for `in_progress` and `ready-for-review`. The exported capitaliser already in the repo is `titleCase` in `apps/desktop/src/features/overview/shared.tsx`, and it only does `charAt(0).toUpperCase() + slice(1)`. A new capitaliser inside `columnLabel` duplicates that helper and still does not define the multi-word rule.

### 7. `board-store.ts` does not match the memory pattern it names

**Severity**: Major

**Affected Scope**: `docs/designs/kanban-board.md` lines 247-248 and 461-467. `apps/desktop/src/features/memory/memory-store.ts` lines 65-76. `apps/desktop/src/features/memory/MemoryPage.tsx` lines 46-62.

**Discrepancy**: The plan says to follow `memory-store.ts` with "a nanostore atom pair" holding the selected task id, the search query, and a focus counter. That is three pieces of state, not a pair, and the counter's type and name are not given. `memory-store.ts` exports one atom, `$memoryFocus`, shaped `{ query?: string; entryId?: string; ts: number }`, and `focusMemory` stamps `ts: Date.now()` so a repeated command still changes the atom. The Memory page keeps the query and the selected id in `useState` and copies them out of `$memoryFocus` in an effect. The plan instead makes the store the owner of selection and search. The same design document, at lines 247-248, says the page owns its state locally and that there is no new store file and no change under `src/store/`. Lines 461-467 then create `apps/desktop/src/features/board/board-store.ts`. An implementer has two architectures and no field list for `focusBoard(focus)`.

### 8. The tests name behavior and do not name the functions

**Severity**: Major

**Affected Scope**: `docs/designs/kanban-board.md` lines 503-518. `apps/desktop/src/features/automations/api.ts` line 112. `apps/desktop/vitest.config.ts` lines 11-13.

**Discrepancy**: `board.test.ts` is required to cover four pure behaviors: `columnLabel` fallback, a title filter, a failure marker, and column order. Only `columnLabel` is placed, in the new `api.ts`. The filter, the failure marker, and the ordering function have no names, no modules, and no signatures. The filter test says "matches on title case-insensitively" and "returns everything for an empty query." It does not say substring versus equality, whether the query is trimmed, or what a missing title does. The marker "is set when `consecutive_failures` is above zero or `last_failure_error` is present," with no function name and no visual (which `Pill` tone, which `StatusDot`). `isFailedStatus` in `apps/desktop/src/features/automations/api.ts` is the failure helper next to the file the plan says to copy, and it implements `/error|fail/i` on a status string. It does not implement the consecutive-failure rule. Vitest for this package includes `src/**/*.test.ts` under `environment: 'node'`, so these tests can only import pure functions. The plan's hand pass covers the page, and it does not add cases for the 404 string, a partial loader failure, or the command argument contract.

### 9. Empty, loading, selection, and column geometry are still choices

**Severity**: Major

**Affected Scope**: `docs/designs/kanban-board.md` lines 430-447. `apps/desktop/src/lib/use-async.ts` lines 16-23. `apps/desktop/src/features/automations/AutomationsPage.tsx` lines 64-68 and 223-278. `apps/desktop/src/features/memory/MemoryRow.tsx` lines 8-10. `apps/desktop/src/features/automations/AutomationsPage.tsx` lines 347-354. `apps/desktop/DESIGN.md` lines 52-56.

**Discrepancy**: `useBackendData` starts as `{ data: null, error: null, loading: false }` and flips `loading` to true inside the effect. Automations treats "no rows yet" as `jobs.loading && jobs.data === null`, and a separate `EmptyGlass` when the query matches nothing (`No automations match …`). The plan has one empty state, "no cards", and one error state. It does not say what the first paint shows, what a search with zero title hits shows, or which card is selected before any click. The detail pane is always described as showing the card fields. With no selection rule, the pane has no row to read. The column strip has no width and no scroll direction in the implementation plan. `DESIGN.md` fixes the master/detail ratio at 3:2 and does not fix a column width. The plan tells the card to follow both `AutomationsPage.tsx` and `MemoryRow.tsx`. Those disagree: `MemoryRow` renders `GlassCard as="button"`, and the automation card is a `div` with an inner `<button>`. A `div` with `onClick` is not keyboard-operable. The plan's aria rule ("every interactive element carries an `aria-label` or visible text") also does not fit `SearchField`: its props are `value`, `onChange`, `placeholder`, `className`, `trailing`, `autoFocus`, and `onSubmit` (`glass.tsx` lines 122-140). It has no `aria-label` prop, and the plan does not list `glass.tsx` as a file to change.

### 10. The work is not phased, so the registry edit does not leave the tree buildable

**Severity**: Major

**Affected Scope**: `docs/designs/kanban-board.md` lines 396-511. `apps/desktop/src/shell/apps.ts` lines 5 and 27-43. `apps/desktop/src/shell/MainWindow.tsx` lines 9-29. `apps/desktop/src/components/app-icon.tsx` lines 7-87. Implementation Readiness Standard, "Phasing & Checkpoints".

**Discrepancy**: The standard requires incremental phases that each leave the codebase buildable and testable. The plan is a flat list of ten file edits. `PageId` and `AppIconId` are closed unions. `PAGE_VIEW` and `PAGE_LABEL` are `Record<PageId, …>`. `PATHS` is `Record<AppIconId, React.ReactNode>`. Adding `'board'` to either union fails `npm run typecheck` (`strict`, and those records are exhaustive) until `apps.ts`, `MainWindow.tsx`, and `app-icon.tsx` change in the same step. The plan numbers those as items 5, 6, and 7 and never says they land together, and it never defines a checkpoint where the new page is registered but inert, then wired, then covered by `board.test.ts`.

### 11. Command registration wording does not match the bootstrap loop

**Severity**: Nit

**Affected Scope**: `docs/designs/kanban-board.md` lines 491-495. `apps/desktop/src/commands/index.ts` lines 28-42.

**Discrepancy**: The plan says to add `boardCommands` to "the array passed to `defineCommands`", inside the same try/catch as the others. `registerOsCommands` iterates an array and calls `defineCommands(group)` once per group, with the try/catch inside the loop. One `defineCommands` call does not receive the whole registry. The group still has to be its own entry in that array, imported the way `automationCommands` and `memoryCommands` are. `page.open`'s description at `apps/desktop/src/commands/navigation.ts` line 116 enumerates every page by id and does not gain `board` in the plan, so the agent-facing description of `page.open` stays on the old list after the alias map is updated.
