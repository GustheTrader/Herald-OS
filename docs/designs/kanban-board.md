# Kanban board surface

* **Author:** Hermes (Elephant), for the Gnoesis factory
* **Status:** Draft — awaiting Goldfish review
* **Date:** 2026-10-28
* **Concepts brief:** [`concepts_brief.md`](concepts_brief.md)

---

## Overview

Herald OS gains a **Board** page that shows the Hermes kanban board: the queue of cards Hermes
and its worker profiles pick up, move, and finish. The page is read-only in its first slice. It
renders the board's own columns, refreshes while it is open, and shows a detail pane for the
selected card.

The board lives in the Hermes runtime, behind `GET /api/plugins/kanban/board`. Herald OS is a
second renderer for an API that already exists and is already tested upstream. Nothing in the
Hermes runtime is forked, patched, or wrapped to serve it.

## The Problem

A user of Herald OS cannot answer "what is my agent doing right now?" from inside the shell.
The Missions page shows work derived from the user's own conversations. The board shows work the
agent started on its own — work that keeps moving while the user is on a different page. The two
views do not overlap, and the board is not visible anywhere in the shell.

The `docs/internal/ROADMAP.md` entry for Alpha 0.2 reads: "Kanban board surface on
`/api/plugins/kanban`." This design is that entry.

## Goals

* A user opens one page and sees every card on the current board, grouped into the runtime's
  own columns.
* The column set, the column labels, the column icons, and the legal transitions between
  columns are read from the runtime. Herald OS hardcodes none of them.
* The board refreshes while the page is open, so a card Hermes moves is seen to move.
* Selecting a card shows what the agent is doing with it: body, assignee, priority, current run,
  latest summary, child-task progress, link and comment counts, and failure signals.
* A card that is failing or blocked is legible without hunting for it.
* The page is reachable by the command bar and by voice, like every other page in the shell.
* The renderer never handles a credential. REST goes through the Electron main process, as it
  does everywhere else in the shell.

## Non-Goals

* Moving, creating, editing, commenting on, or attaching files to cards. That is a later slice.
* A board picker. The runtime owns which board is current (`GET /api/plugins/kanban/boards`
  reports it); the page shows the current board and names it.
* Any concept of a "project" layered on the board. The board is a queue.
* Replacing or merging with the Missions page. They show different work.
* A copy of the runtime's dashboard, in the renderer or anywhere else.
* Drag and drop. It is the obvious next interaction, and it is also a mutation; it waits for the
  slice that allows mutations.

## Open Questions

* **Does a card link to a Hermes conversation?** Cards carry a `session_id`, which the runtime
  documents as the originating `HERMES_SESSION_ID` — null for cards created from the CLI or the
  dashboard. Whether that value is a stored session id the shell can resume is **not verified**.
  Slice 1 shows the session id as text and offers no link. Slice 2 verifies it and, if it holds,
  adds "open this conversation".
* **Should a card link to a workspace?** Cards carry `workspace_path` and `branch_name` for cards
  that ran against a project worktree. The shell has a Studio and a Files page that can open a
  path. Slice 1 shows the path as text. Slice 2 may offer to open it.
* **How loud should a stuck card be?** The runtime reports per-card `consecutive_failures` and
  `last_failure_error` on the board payload, and a separate fleet-wide `/diagnostics` list. Slice
  1 shows a marker on the card and the error text in the detail pane. It does not raise a
  notification, because the shell's rule is that no background event may steal focus.
* **Should the board be a page or a floating window?** The board is wide (eight columns) and the
  main window already holds a sidebar, a detail pane, and a menu bar. Slice 1 puts it in the main
  window as a top-level page with a horizontally scrolling column strip. If the width turns out
  to be unusable, a floating window is the fallback, and the page is designed so that move is a
  change of registration, not a rewrite.

## Critical User Journeys (CUJs)

### CUJ 1: See what the agent is working on

* **Given**: A Hermes runtime with a board that has cards in it. The user is in Herald OS.
* **When**: The user opens the Board page.
* **Then**: The page shows the runtime's columns, in the runtime's order, each holding its cards.
  A card shows its title, its assignee, and its priority. Cards with failures are marked. The
  column headers carry the runtime's own labels and icons.

### CUJ 2: Read one card in full

* **Given**: The Board page is open with cards on it.
* **When**: The user selects a card.
* **Then**: The detail pane shows the card's body, status, assignee, priority, when it was
  created, when it started, how long it has been running, its latest summary, its child-task
  progress, its link and comment counts, and any failure error. Selecting a card does not navigate
  away and does not interrupt anything else.

### CUJ 3: Watch the board move

* **Given**: The Board page is open.
* **When**: Hermes moves a card from one column to another.
* **Then**: Within a few seconds the card appears in its new column, in the same position in the
  list, without the user reloading or doing anything.

### CUJ 4: Reach the board without the mouse

* **Given**: The user is anywhere in Herald OS.
* **When**: The user says "open the board", or types it in the command bar.
* **Then**: The Board page opens, focused, with the same selection and filter state it had.

### CUJ 5: The board is empty or missing

* **Given**: The runtime has no board, or the kanban plugin is not mounted, or the backend is
  not ready yet.
* **When**: The user opens the Board page.
* **Then**: The page explains what is wrong in one sentence and offers a retry. It does not show
  an empty grid that looks like "no work".

## Technical Plan (Architecture)

### Data flow

```text
  Renderer (BoardPage)
        |
        |  window.heraldOS.backend.rest({ method: 'GET', path: '/api/plugins/kanban/board' })
        v
  Electron main (BackendManager.rest)
        |   holds the session token; adds X-Hermes-Session-Token
        |   refuses any path not under /api/
        v
  Hermes runtime (127.0.0.1, random port)
        |
        |  GET /api/plugins/kanban/board
        |  GET /api/plugins/kanban/workflow
        |  GET /api/plugins/kanban/boards
        v
  kanban plugin (plugin_api.py) -> kanban_db -> SQLite
```

The renderer never talks to Node directly, never sees the token, and never opens a socket to the
runtime. The existing `rest` bridge in `apps/desktop/electron/backend/manager.ts` already carries
the token and already refuses paths outside `/api/`, and `/api/plugins/kanban/board` is inside
that boundary. **No new IPC, no new preload method, and no new credential path are needed.**

### Why the plugin API is reachable with the existing bridge

Verified against a running Hermes on 2026-10-28:

| Request | Result |
| --- | --- |
| `GET /api/plugins/kanban/board` with the session token | `200`, full board payload |
| The same request with a wrong token | `401` |
| The same request with no token | `401` |
| The same path outside `/api/` | `404` |

The kanban plugin is a **bundled** plugin, so the runtime's own trust gate mounts it without a
user opt-in (`_plugin_api_mount_skip_reason` treats bundled plugins as trusted unless explicitly
disabled). A user who has explicitly disabled the kanban plugin gets a clear "not available"
state, not an error.

### The three endpoints this page reads

All under `/api/plugins/kanban/`.

**`GET /board`** returns the whole board in one call:

```jsonc
{
  "columns": [ { "name": "triage", "tasks": [ /* ... */ ] }, /* ... eight columns ... */ ],
  "tenants": [],
  "assignees": [],
  "latest_event_id": 5,
  "now": 1793156717
}
```

Each task carries the fields a card and a detail pane need: `id`, `title`, `body`, `assignee`,
`status`, `priority`, `created_at`, `started_at`, `completed_at`, `age`, `latest_summary`,
`current_run_started_at`, `progress`, `link_counts`, `comment_count`, `consecutive_failures`,
`last_failure_error`, `block_kind`, `session_id`, `workspace_path`, `branch_name`, and `result`.

**`GET /workflow`** returns the column vocabulary and the legal transitions:

```jsonc
{
  "columns": [
    { "key": "triage", "label": "Triage", "icon": "◇", "drag_target": true },
    { "key": "scheduled", "label": "Scheduled", "icon": "⏱", "drag_target": false }
    // ... eight columns ...
  ],
  "manual": { "triage": ["ready", "todo"], "ready": ["blocked", "done", "review", "..."] }
}
```

`drag_target` marks the columns a card may be dropped into. `manual` is the transition table the
runtime enforces. Slice 1 reads `columns` for labels and icons and ignores `manual`; slice 2 needs
`manual` to offer only legal moves.

**`GET /boards`** returns every board on disk plus `current`, which is the slug the runtime
treats as active. The page shows the current board's name in the header. It does not offer a
picker — switching boards is the runtime's job (`POST /boards/{slug}/switch`).

### Freshness: the events WebSocket

`GET /api/plugins/kanban/events` is a WebSocket that tails the runtime's `task_events` table and
pushes `{"events": [...], "cursor": N}`. It authenticates with the same session token, in the
query string, because a browser cannot set an `Authorization` header on an upgrade.

Verified on 2026-10-28: the handshake returns `101 Switching Protocols` with the session token,
and a card created through the REST API produced a text frame with a `created` event within one
second, carrying a `cursor` to resume from.

**Slice 1 does not use the WebSocket.** The board payload is small and the runtime's read is a
single coalesced SQLite query (`_read_board = coalesced_read(get_board)`). A short poll is
simpler, has no reconnect logic, and cannot leak a socket. Slice 1 polls `/board` every five
seconds while the page is visible and stops when the page is hidden.

The WebSocket is the right answer for a later slice, and it needs one addition to the Electron
main process: a `kanbanEventsUrl()` beside the existing `audioWsUrl()` in `manager.ts`, which
already establishes the pattern of a tokenised loopback URL handed to the renderer. The ADR-007
amendment that allowed `audioWsUrl` applies unchanged: the renderer already receives the gateway
`wsUrl` carrying the same loopback token.

### Layout

The board is wide and the shell is not. The design keeps the board's own geometry intact and
lets it scroll:

* The page is a top-level entry in the sidebar, next to Missions, with the page body scrolling
  horizontally across the columns. The columns keep their natural width; nothing is squeezed.
* Each column is a fixed-width column: a header (the runtime's label and icon, plus a count) and
  a stack of cards.
* The detail pane is a right-hand panel inside the page, in the same 3:2 master/detail shape
  every other list page uses. The board strip and the detail pane share the page body; the board
  strip scrolls horizontally within its share.
* The page header carries the board's name, a search field that filters cards by title, and a
  refresh button.

The search field filters on the client against the cards already in memory. It does not change
what the runtime returns, and it does not persist.

### Data and actions

Following `apps/desktop/DESIGN.md`:

* Data comes in through `useBackendData` (`src/lib/use-async.ts`), which refetches on every
  gateway reconnect and guards against stale responses. The page adds its own five-second
  interval for the live refresh, and clears it when the page is hidden.
* The page owns its state locally under `src/features/board/`, like the automations page owns
  `src/features/automations/`. No new store file, no change to `src/store/`.
* Cards carry `data-os-target="kanban:<task id>"`, so a card is addressable by an `OsCommand` and
  can be pointed at by voice.
* Every new user-visible action registers an `OsCommand` in `src/commands/board.ts`, with a tier
  and spoken-friendly phrases.

### The commands

| Command | Tier | What it does |
| --- | --- | --- |
| `board.open` | read | Open the Board page. |
| `board.refresh` | read | Refetch the board now. |
| `board.search` | read | Filter cards by title. |
| `board.select` | read | Select a card by id, or the first card when no id is given. |
| `board.focus` | read | Move the keyboard focus to the selected card. |

`board.open` is what the voice matcher and the command bar use, alongside the generic
`page.open` command, which already resolves any page by name and synonym. Adding "board" and
"kanban" to `PAGE_ALIASES` in `src/commands/navigation.ts` makes "open the kanban" work through
the existing path with no new code.

### Shared files this changes

Per `apps/desktop/DESIGN.md` ("call out shared changes in the pull request description rather
than slipping them in"), the slice touches four shared files and adds no new IPC:

| File | Change | Why |
| --- | --- | --- |
| `apps/desktop/src/shell/apps.ts` | Add `board` to `PageId`, `AppIconId`, and `PAGES`. | A page is registered here. |
| `apps/desktop/src/shell/MainWindow.tsx` | Add the `board` entry to `PAGE_VIEW` and `PAGE_LABEL`. | Pages load lazily from this map. |
| `apps/desktop/src/components/app-icon.tsx` | Add the `board` glyph to `PATHS`. | `PageHeader` takes an `AppIconId`. |
| `apps/desktop/src/commands/index.ts` | Register `boardCommands`. | Every new action group is registered here. |
| `apps/desktop/src/commands/navigation.ts` | Add `board` and `kanban` to `PAGE_ALIASES`. | Voice and the command bar resolve pages by synonym. |

`apps/desktop/electron/`, `apps/desktop/preload/`, and `apps/desktop/shared/ipc.ts` are
**not** touched. The existing `rest` bridge already carries the token and already covers the
path.

## Alternatives Considered

### Alternative A: Embed the Hermes dashboard's own kanban tab

The kanban plugin ships a built dashboard tab (`dashboard/manifest.json` declares
`"tab": { "path": "/kanban" }` with a compiled `dist/index.js`). Herald OS has a `web` floating
window that loads a URL.

* **Pros**: The board UI already exists and is maintained upstream. Almost no new code.
* **Cons**: It puts a second visual language inside a shell that is one visual language. The
  dashboard authenticates `/api/plugins/` with a ticket in the query string, so embedding it
  means a credential in a URL. A web view is opaque to the shell: it cannot be driven by the
  command bar, cannot be reached by voice, cannot be a notification target, and cannot carry
  `data-os-target`.
* **Reason for Rejection**: A board the user cannot reach by voice and that Herald OS cannot
  command is a screenshot, not a surface. The shell's own rule is that the renderer never
  reimplements the agent; the same reasoning applies to a second renderer of the board.

### Alternative B: Fold the board into the Missions page as a tab

Missions is "a derived view of a session". The board is the runtime's own queue. One page, two
data sources, two refresh behaviours, two different meanings of "work".

* **Pros**: No new sidebar entry, no new page, no new shortcut.
* **Cons**: It makes the Missions page mean two things. The sidebar is the shell's navigation and
  the roadmap treats the board as its own surface.
* **Reason for Rejection**: The two views answer different questions and are refreshed by
  different mechanisms. A tab that swaps the whole page body for a different data model is a
  page wearing a disguise.

### Alternative C: Write the board as a floating window

* **Pros**: A wide board gets a wide window. The Studio works this way.
* **Cons**: A floating window is a separate thing to open, focus, and close. The board is the
  answer to a question the user asks constantly ("what is the agent doing?"), and a question
  asked constantly deserves a permanent address, not a launcher.
* **Reason for Rejection**: Deferred, not rejected. The page's content is a self-contained
  component, so promoting it to a floating window later is a registration change. The width
  question is the only thing that would force this, and it is not yet proven to be a problem.

### Alternative D: Make the first slice writable

Moving a card means `PATCH /api/plugins/kanban/tasks/{id}`, and the shell's `RestRequest` has no
`PATCH` method — it allows `GET`, `POST`, `PUT`, `DELETE`. Adding it means changing the shared
IPC contract in `apps/desktop/shared/ipc.ts`, the preload bridge, and the main-process bridge,
and then shipping a drag gesture on top of it.

* **Pros**: A read-only board can feel like a screenshot of a board.
* **Cons**: Three shared changes to ship a drag. A mutation also needs the runtime's transition
  table to be respected, optimistic UI, and a rollback story.
* **Reason for Rejection**: The value of the first slice is seeing the agent's work, and seeing
  it is a complete feature. Mutations are a second slice with their own approval path.

> **Note for the reviewer:** the runtime also exposes `POST /api/plugins/kanban/tasks/bulk`,
> which applies the same transition rules as `PATCH` and needs no new IPC method. It was verified
> to move a card and to refuse an illegal transition. It is a viable route for slice 2 that
> avoids the shared-IPC change entirely. Slice 1 does not use it.

### Alternative E: Render the board from the gateway instead of the plugin API

The runtime has a `/kanban` command on the gateway, and the shell already talks to the gateway
over a WebSocket.

* **Pros**: No new HTTP calls; one transport for everything.
* **Cons**: The gateway's kanban command is a command an agent runs, not a query a UI runs. The
  plugin's REST API is the supported read path for a renderer, and the plugin API routes are
  already inside the shell's `/api/` boundary.
* **Reason for Rejection**: The REST plugin API is the right read path and is already reachable.

## Non-Functional Requirements

* **Security**: The renderer never holds a credential. The session token stays in the Electron
  main process, exactly as it is for every other backend call. The page issues no requests of
  its own; it goes through `window.heraldOS.backend.rest`.
* **Performance**: The board is one HTTP call every five seconds while visible, against a
  coalesced SQLite read. The payload is bounded by the number of live cards. The poll stops
  when the page is hidden and when the backend is not ready.
* **Failure behaviour**: A failed fetch leaves the last good board on screen and shows the error
  next to the refresh button. The page does not blank out. A missing or disabled kanban plugin
  shows a distinct "not available" state, not an empty board.
* **Rollout**: A new page is additive. Nothing existing changes behaviour. Removing the page
  removes the sidebar entry.

---

### Additional Resources

* `docs/internal/ROADMAP.md` — the Alpha 0.2 entry this design implements.
* `docs/ARCHITECTURE.md` — the three-owner split the page follows.
* `apps/desktop/DESIGN.md` — the page contract, the visual vocabulary, and the shared-file rule.
* The Hermes runtime's `plugins/kanban/dashboard/plugin_api.py` and `hermes_cli/kanban_db.py` —
  the API this page reads.
* `hermes_cli/web_server_dashboard.py` — how the plugin API is mounted and trusted.

### Future Improvements

* **Writable board.** Drag a card between columns, with the runtime's `manual` transition table
  deciding which moves are offered, and `drag_target` deciding which columns accept a drop.
* **Live events.** Replace the five-second poll with the runtime's `/events` WebSocket, adding a
  `kanbanEventsUrl()` to the Electron main process beside `audioWsUrl()`.
* **Deep links.** Open the card's Hermes conversation, or its workspace in the Studio, once the
  id semantics are verified.
* **Diagnostics.** A fleet-wide "stuck cards" strip, from `GET /api/plugins/kanban/diagnostics`.
* **Comments and attachments.** Reading a card's comment thread and its attachments, both of
  which the task endpoint already returns.

---

## Detailed Implementation Plan

### Target Files to Create/Modify

#### 1. `apps/desktop/src/features/board/api.ts` (Create)

* **Type / Scope**: TypeScript module, page-local API client.
* **Proposed Changes**: Typed wrappers over the kanban plugin's REST routes, following the shape
  of `apps/desktop/src/features/automations/api.ts`.
  - `interface BoardColumn { name: string; tasks: BoardTask[] }`
  - `interface BoardTask` — the card fields the page reads: `id`, `title`, `body`, `assignee`,
    `status`, `priority`, `created_at`, `started_at`, `completed_at`, `age`, `latest_summary`,
    `current_run_started_at`, `progress`, `link_counts`, `comment_count`,
    `consecutive_failures`, `last_failure_error`, `block_kind`, `session_id`, `workspace_path`,
    `branch_name`, `result`, plus an index signature for forward compatibility.
  - `interface Board { columns: BoardColumn[]; tenants: string[]; assignees: string[];
    latest_event_id: number; now: number }`
  - `interface WorkflowColumn { key: string; label: string; icon: string; drag_target: boolean }`
  - `interface Workflow { columns: WorkflowColumn[]; manual: Record<string, string[]> }`
  - `interface BoardsPayload { boards: { slug: string; name: string; is_current: boolean }[];
    current: string }`
  - `const boardApi = { board: () => rest.get<Board>('/api/plugins/kanban/board'),
    workflow: () => rest.get<Workflow>('/api/plugins/kanban/workflow'),
    boards: () => rest.get<BoardsPayload>('/api/plugins/kanban/boards') }`
  - A `columnLabel(workflow, key)` helper that falls back to a capitalised key when the runtime
    does not list a column, so a new runtime column still renders.

#### 2. `apps/desktop/src/features/board/BoardPage.tsx` (Create)

* **Type / Scope**: React page component, exported as `BoardPage`.
* **Proposed Changes**:
  - Loads `boardApi.board()`, `boardApi.workflow()`, and `boardApi.boards()` through
    `useBackendData`.
  - A five-second `setInterval` calls the board loader's `reload` while the page is the visible
    one; the interval is cleared on unmount and when the page is hidden. It is skipped while the
    backend is not ready.
  - Renders `PageHeader` with the `board` icon, the current board's name as the subtitle, a
    `SearchField` filtering cards by title client-side, and a refresh `GlassButton`.
  - Renders the column strip: for each column from the runtime's `workflow.columns` order, a
    column header with the runtime's `label`, `icon`, and card count, then the cards.
  - Renders a card as a `GlassCard` with `interactive`, `selected` when it is the selected card,
    and `data-os-target={`kanban:${task.id}`}` (following `features/automations/AutomationsPage.tsx`
    and `features/memory/MemoryRow.tsx`).
  - Renders the detail pane in a `GlassCard` on the right: body, status, assignee, priority,
    created/started/completed timestamps, age, latest summary, child progress, link and comment
    counts, session id, workspace path, branch, and the failure error when there is one.
  - Uses only the tokens and primitives in `apps/desktop/DESIGN.md`: `.glass-card`,
    `glass-card-selected`, `text-fg`, `text-fg-2`, `text-fg-3`, `border-line`, `bg-accent`,
    `bg-accent-soft`, `rounded-lg`, `rounded-xl`, `Pill`, `StatusDot`, `KeyValue`, `Section`,
    `EmptyGlass`, `ProgressBar`, `PageHeader`, `GlassCard`, `GlassButton`, `SearchField`.
    No literal colours, no dark borders, no card-in-card beyond one level.
  - Every interactive element carries an `aria-label` or visible text.
  - Empty and error states use `EmptyGlass` with a retry `GlassButton`; a 404 from the plugin
    route renders a "not available" message distinct from "no cards".

#### 3. `apps/desktop/src/commands/board.ts` (Create)

* **Type / Scope**: TypeScript module, an `OsCommand` group.
* **Proposed Changes**: Export `boardCommands: readonly OsCommand[]` with `board.open`,
  `board.refresh`, `board.search`, `board.select`, and `board.focus`, each with a `tier`, a
  `description`, spoken `phrases`, and a `run` that returns `ok(...)` or `fail(...)` from
  `src/store/os-commands.ts`. `board.open` calls `showPage('board')`. `board.select` and
  `board.search` reach the page through a `focusBoard()` function exported from the board
  feature, matching the `focusSettings()` pattern in
  `apps/desktop/src/features/settings/sections/shared.tsx` and `focusMemory()` in
  `apps/desktop/src/features/memory/memory-store.ts`.

#### 4. `apps/desktop/src/features/board/board-store.ts` (Create)

* **Type / Scope**: TypeScript module, page-local selection and filter state.
* **Proposed Changes**: A nanostore atom pair and a `focusBoard(focus)` function, following
  `features/memory/memory-store.ts`: the selected task id, the search query, and a `focus`
  counter the commands bump to make the page react. It holds no board data — the board stays in
  the page's loader, so there is one owner for backend truth.

#### 5. `apps/desktop/src/shell/apps.ts` (Modify)

* **Type / Scope**: The app registry.
* **Proposed Changes**: Add `'board'` to the `PageId` union and to `AppIconId`. Add one entry to
  `PAGES`, after `missions`, with `kind: 'page'`, `icon: 'board'`, a `tagline`, and a `shortcut`
  that does not collide with the existing `1`-`7` and `,` bindings. The existing page shortcuts
  are `1` Overview, `2` Hermes, `3` Missions, `4` Memory, `5` Files, `6` Automations,
  `7` Connections, `,` Settings. The slice takes the next free digit slot in the page registry
  and the sidebar renders the shortcut label from the same entry, so no other binding changes.

#### 6. `apps/desktop/src/shell/MainWindow.tsx` (Modify)

* **Type / Scope**: The page router.
* **Proposed Changes**: Add `board: lazy(() => import('../features/board/BoardPage.tsx').then(m => ({ default: m.BoardPage })))`
  to `PAGE_VIEW` and `board: 'Board'` to `PAGE_LABEL`.

#### 7. `apps/desktop/src/components/app-icon.tsx` (Modify)

* **Type / Scope**: The inline SVG icon set.
* **Proposed Changes**: Add a `board` entry to `PATHS`, drawn as three vertical columns of
  stacked cards in the same 24x24 stroke style as the other glyphs.

#### 8. `apps/desktop/src/commands/index.ts` (Modify)

* **Type / Scope**: The command registry bootstrap.
* **Proposed Changes**: Import `boardCommands` and add the group to the array passed to
  `defineCommands`, in the same defensive try/catch as the others.

#### 9. `apps/desktop/src/commands/navigation.ts` (Modify)

* **Type / Scope**: Page and app name resolution.
* **Proposed Changes**: Add `board: 'board'` and `kanban: 'board'` to `PAGE_ALIASES`, so
  "open the board" and "open the kanban" both resolve through the existing `page.open` command.

#### 10. `apps/desktop/src/features/board/board.test.ts` (Create)

* **Type / Scope**: Unit test, Vitest, matching the repo's existing `*.test.ts` files.
* **Proposed Changes**: Tests for the pure helpers: `columnLabel` falls back to a capitalised key
  for a column the runtime's workflow does not list; the card filter matches on title
  case-insensitively and returns everything for an empty query; the failure marker is set when
  `consecutive_failures` is above zero or `last_failure_error` is present; and the column order
  follows the runtime's `workflow.columns` order rather than the board payload's order.

### Verification Plan

* **Compilation/Build**: `npm run build`
* **Unit Tests**: `npm run test`
* **Static Analysis & Linting**: `npm run typecheck`
* **Test Coverage Requirement**: The pure helpers in `board.test.ts` are covered. The page
  component is exercised by hand against a live runtime.
* **E2E/Integration**: A manual pass against a running Hermes backend:
  1. `GET /api/plugins/kanban/board` returns cards; the Board page shows them in the runtime's
     columns, with the runtime's labels and icons.
  2. Selecting a card shows its detail pane; the pane's fields match
     `GET /api/plugins/kanban/tasks/{id}` for the same card.
  3. Creating a card through the runtime's API makes it appear on the page within five seconds
     without a reload.
  4. Moving a card through the runtime's API moves it on the page within five seconds.
  5. "Open the board" by voice and by command bar opens the page.
  6. Stopping the backend shows the error state with a retry, and the last good board stays
     visible.
  7. The renderer bundle contains no session token: the page's network calls all go through
     `window.heraldOS.backend.rest`, and the token appears only in the main process.

---

*Drafted with EGM*
