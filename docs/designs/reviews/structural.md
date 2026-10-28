**Severity:** Major

**Affected scope:** Technical Plan (Architecture), subsections "Data and actions" (lines 244–251) and "The commands" (lines 264–266), next to "Shared files this changes" (lines 276–280).

**Discrepancy:** File citations in one architecture section use two roots, and the short ones do not resolve. `src/lib/use-async.ts`, `src/features/board/`, `src/features/automations/`, `src/store/`, `src/commands/board.ts`, and `src/commands/navigation.ts` are not at the repository root and not beside this spec in `docs/designs/`. The same tree is written as `apps/desktop/src/...` in the shared-files table a few lines later (`src/commands/navigation.ts` on line 266, `apps/desktop/src/commands/navigation.ts` on line 280). `docs/ARCHITECTURE.md` states the rule for documents under `docs/`: the Renderer section (line 88) says `src/` paths are relative to `apps/desktop`. This spec never says that, so a reader cannot tell which tree the short paths belong to.

**Severity:** Major

**Affected scope:** Alternatives Considered, subsection "Alternative A: Embed the Hermes dashboard's own kanban tab" (lines 290–291).

**Discrepancy:** `dashboard/manifest.json` is not a path that opens. It is not in this repository, not under `apps/desktop`, and not at the Hermes runtime root. The manifest that declares the kanban tab is `plugins/kanban/dashboard/manifest.json` in the Hermes install. Additional Resources (line 376) already cites `plugins/kanban/dashboard/plugin_api.py` for that same directory, so the short path also disagrees with the spec's own resource list.

**Severity:** Nit

**Affected scope:** Non-Functional Requirements, subsection "Additional Resources" (lines 376–378).

**Discrepancy:** The resource list puts Herald-OS repo-root paths (`docs/...`, `apps/desktop/DESIGN.md`) in the same bullets as `plugins/kanban/dashboard/plugin_api.py`, `hermes_cli/kanban_db.py`, and `hermes_cli/web_server_dashboard.py`. Those three files are not in this repository. They sit under the Hermes install. The root this repo documents for that tree is `$HERMES_HOME/hermes-agent` (`docs/ARCHITECTURE.md`, "Three authorities"; `upstream/README.md`). The bullets name the runtime in prose and then omit that root, so the paths look like repository paths and do not resolve in the worktree.

**Severity:** Nit

**Affected scope:** Non-Functional Requirements, subsection "Additional Resources" (line 374).

**Discrepancy:** The citation `docs/ARCHITECTURE.md` — "the three-owner split the page follows" does not name a heading in that file. The section is `## Three authorities` (line 9). Nothing in the file says "three-owner" or "owner split". The citation is also a bare repo-root code span, not a link relative to this spec. Herald's own docs link documents with a path relative to the citing file (`docs/README.md`, `docs/internal/README.md`, and the links inside `docs/ARCHITECTURE.md`). From `docs/designs/kanban-board.md` that target is `../ARCHITECTURE.md`.
