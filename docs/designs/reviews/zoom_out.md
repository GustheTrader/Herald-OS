# Zoom-out review: docs/designs/kanban-board.md

## 1. The "next free digit" shortcut collides with Terminal and System

**Severity:** Major

**Affected scope:** Detailed Implementation Plan, item 5, `apps/desktop/src/shell/apps.ts` (lines 473–477). The same claim sits behind "no other binding changes."

**Simplicity rationale:** `PAGES` already uses `1`–`7` and `,`. `FLOATING_APPS` already uses `8` for Terminal and `9` for System (`apps/desktop/src/shell/apps.ts`). Both `App.tsx` and `surfaces/MainSurface.tsx` resolve the shortcut with `HERMES_APPS.find(a => a.shortcut === event.key)`, and `HERMES_APPS` lists pages before floating apps. A second `8` opens the board and Terminal's binding stops working. There is no free digit. `page.open` and `open.any` already open a page once its id or alias resolves (`commands/navigation.ts`, `commands/open.ts`). Give the page a key that is not in that list, or ship it with no digit shortcut. Voice and the command bar are the requirement in the goals; a ninth digit is not.

## 2. The five-second poll does not stop when the user leaves the page

**Severity:** Major

**Affected scope:** Freshness (lines 211–214); Data and actions (lines 245–246); `BoardPage.tsx` plan (lines 427–429); Performance (lines 360–362).

**Simplicity rationale:** `MainWindow` keeps every visited page mounted and hides it with `visibility: hidden`. `apps/desktop/DESIGN.md` says visibility is not lifecycle. An interval cleared on unmount therefore runs for the rest of the session after the first visit. `document.hidden` stays false while the user is on Missions or anywhere else in the shell. `FilesPage` already reads `$page` from `src/store/windows.ts` and returns when `page !== 'files'`. Gate the reload on `$page === 'board'`. Otherwise the "poll stops when the page is hidden" rule is unmet, and a hidden page fetches the whole board every five seconds.

## 3. The not-ready path and the failure path cancel each other out

**Severity:** Major

**Affected scope:** CUJ 5 (lines 108–114); Freshness (lines 213–214); Failure behaviour (lines 363–365); `BoardPage.tsx` plan (lines 427–429 and 446–447); Verification step 6 (lines 528–529).

**Simplicity rationale:** `useBackendData` returns immediately when `$connectionEpoch` is 0 and leaves `data`, `error`, and `loading` untouched (`src/lib/use-async.ts`). A page that only reads that hook, before the backend has connected, shows neither an error nor a retry. That is the blank "no work" screen CUJ 5 forbids. `$backend.phase` in `src/store/backend.ts` is already the ready signal.

Skipping the interval while the backend is not ready makes verification step 6 impossible. After a ready backend stops, the epoch does not reset, and a skipped poll never calls `rest()`. `BackendManager.rest` throws `Hermes backend is not ready` only when it is called (`manager.ts`). The last board stays on screen and no error is recorded. Poll while `$page === 'board'`, and let the thrown error fill the hook. The hook already keeps the previous `data` when a later load fails.

The separate "404 from the plugin route" state has the same shape. `rest` throws `Error("GET /path -> 404: …")` and does not return a status (`manager.ts`, around lines 130–140). A distinct "not available" branch means parsing that sentence. One error string from the hook, drawn next to the last good board, covers plugin-missing, backend-down, and a failed first load. A 404 parser is a second client for a private error string.

## 4. The design names two owners for selection and filter state

**Severity:** Major

**Affected scope:** Data and actions (lines 247–248), against item 4 `board-store.ts` (lines 461–467) and `commands/board.ts` (lines 455–459).

**Simplicity rationale:** The architecture section says the page owns selection locally the way Automations does, and that there is no new store file. Automations keeps the selected id and the search query in `useState`. A command defined outside the page cannot write that state. `apps/desktop/DESIGN.md` requires page-local selection and filter state to expose a `focus*()` atom. Memory does this with `focusMemory` in `features/memory/memory-store.ts`. Missions does it with `focusMissions` in `src/store/missions.ts`. The implementation plan then adds `features/board/board-store.ts` and `focusBoard()` so `board.select` and `board.search` can reach the page.

Follow one of those. The smaller match for this page is the feature-local focus atom, with the loader still the only owner of board data, and with no new file under `src/store/`. The sentence that forbids a store file deletes the path the commands need. Implementing both produces either dead commands or two copies of the selection.

## 5. "Move it to a floating window later" is not a registration change

**Severity:** Major

**Affected scope:** Open questions, "page or a floating window" (lines 70–74); Alternative C (lines 316–324).

**Simplicity rationale:** The width escape hatch is described as a change of registration, with the board component reused as-is. Pages and windows are different kinds in this shell. `showPage` only sets `$page` on the main window (`src/store/windows.ts`). `openApp` on a window id creates a window, and in panels mode it opens a separate Electron window through `shell.open`. The window body is a `switch` in `shell/Desktop.tsx` (`FloatingContent`) and a second `switch` in `shell/surfaces/FloatingSurface.tsx`. The sidebar renders `PAGES` only. A later promotion means a new `FloatingAppId`, a `defaultSize`, both switches, and every `showPage('board')` becoming `openApp`. The column component can move. The shell wiring is a real slice. The page layout has to stand on its own; the design cannot treat the window as a cheap fallback if eight columns do not fit.

## 6. Load-bearing runtime claims are not in this source tree

**Severity:** Major

**Affected scope:** "Why the plugin API is reachable" (lines 143–157); the three endpoints (lines 159–199); Freshness (lines 201–214); Additional resources (lines 376–378).

**Simplicity rationale:** The shell half of the data flow is real. `BackendManager.rest` adds `X-Hermes-Session-Token` and refuses any path that does not start with `/api/` (`electron/backend/manager.ts`). `RestRequest` allows `GET`, `POST`, `PUT`, and `DELETE` only (`shared/ipc.ts`). `audioWsUrl` is the tokenised loopback helper the future-socket note points at, and the ADR-007 amendment in `docs/DECISIONS.md` matches that description.

The runtime half is not in the tree. `upstream/` holds a lockfile and a README; the Hermes snapshot is gitignored and not checked out. The design still cites `plugins/kanban/dashboard/plugin_api.py`, `hermes_cli/kanban_db.py`, `hermes_cli/web_server_dashboard.py`, `_plugin_api_mount_skip_reason`, and `_read_board = coalesced_read(get_board)` as the reason a five-second poll is cheap and a disabled plugin is the rare case. A probe dated 2026-10-28 is not a contract this repo can check. The table row "the same path outside `/api/` → 404" describes a Hermes response. The bridge the page actually calls throws `refusing REST path outside /api` and never fetches. Keep the page on `rest.get` of the three routes. Do not rest the poll rate or the empty-state story on private symbols this tree does not contain. The gateway wire is already pinned in `packages/hermes-client`. This plugin payload is not, so the interfaces in `api.ts` are the only pin, and they should name the fields the page renders.

## 7. "Open tasks" already opens Automations

**Severity:** Nit

**Affected scope:** `commands/navigation.ts` plan (lines 497–501). The live alias is `tasks: 'automations'` in `src/commands/navigation.ts`.

**Simplicity rationale:** The queue of cards is what a user will call tasks. That word already resolves to the cron page, and `open.any` delegates to `page.open`, which uses `resolveAppId`. Adding `board` and `kanban` leaves "open tasks" on Automations. Settle that alias in this design. The resolver already exists; this does not need a new command.

## 8. `board.focus` duplicates the highlighter the shell already runs

**Severity:** Nit

**Affected scope:** The commands table (line 262); `commands/board.ts` plan (lines 452–455).

**Simplicity rationale:** `OsHighlighter` scrolls to and pulses `[data-os-target="kind:id"]` from a command result's `highlight` (`features/voice/ActionHud.tsx`). Automations, connections, and missions return `highlight` and do not register a command whose only job is keyboard focus. `board.select`, `data-os-target="kanban:<task id>"`, and a `highlight` on the command result already point at the card. `board.focus` is a fifth read command with no sibling in the catalogue.

## 9. `columnLabel` invents a third column name

**Severity:** Nit

**Affected scope:** `api.ts` plan (lines 418–419); `board.test.ts` plan (lines 506–507).

**Simplicity rationale:** `GET /board` columns carry `name`. `GET /workflow` columns carry `label` and `icon`. A helper that capitalises a key the workflow did not list is a label vocabulary the shell owns, which the goals say the shell will not own. At render time, use the workflow `label`, and the board column's `name` when the workflow has no row. That lookup does not need a function or a test whose only job is the capitalisation rule.

## 10. Slice 1 specifies a socket API it does not open

**Severity:** Nit

**Affected scope:** Freshness (lines 216–220). The same idea is already listed under Future Improvements (lines 384–385).

**Simplicity rationale:** Slice 1 polls `/board`. The architecture section still names `kanbanEventsUrl()` on `BackendManager`, a token in the query string, and an ADR-007 reading for a WebSocket this slice does not connect. That is a speculative main-process interface. The future-improvements line is the right altitude. The function sketch is how the IPC change gets built early because the design already named it.
