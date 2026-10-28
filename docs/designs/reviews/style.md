# Style review — `docs/designs/kanban-board.md` (lines 1–393)

### 1
**Severity:** Nit
**Affected Scope:** Overview, line 18
**Style Rationale:** "Already exists and is already tested" uses "already" twice. The sentence states two facts: the API exists, and upstream tests cover it. The second "already" is emphasis with no added meaning.

### 2
**Severity:** Nit
**Affected Scope:** Goals, line 40
**Style Rationale:** "Legible without hunting for it" is a metaphor, and nobody can test it. CUJ 1 and the stuck-card open question already state the observable behaviour: a marker on the card, and the error text in the detail pane. This goal adds no measurable requirement.

### 3
**Severity:** Nit
**Affected Scope:** Non-Goals, lines 53–54
**Style Rationale:** "The obvious next interaction" is a personal judgment about what a reader will want. "It waits" makes the feature an actor. The constraint is factual: drag-and-drop mutates a card, and slice 1 does not mutate cards.

### 4
**Severity:** Nit
**Affected Scope:** Open Questions, "How loud should a stuck card be?", line 66
**Style Rationale:** "How loud" does not name the decision in the paragraph. The text chooses between a marker plus error text and a notification that would steal focus. A volume metaphor leaves the question sounding open after the paragraph has closed it.

### 5
**Severity:** Major
**Affected Scope:** CUJ 3: Watch the board move, lines 99–100
**Style Rationale:** "Within a few seconds" has no bound, so the journey cannot be verified. The freshness section sets the poll at five seconds while the page is visible. "A few" can be read as tighter than that mechanism. The acceptance line needs the same interval the plan commits to, plus request time.

### 6
**Severity:** Nit
**Affected Scope:** Freshness: the events WebSocket, lines 211–216
**Style Rationale:** "The board payload is small" states a size and gives no number. "A short poll is simpler" is a quality judgment. The concrete reasons are already in the sentence: one coalesced SQLite query, no reconnect logic, and no socket given to the renderer. "Cannot leak a socket" is the wrong verb for that last point. "Leak" reads as an accidental resource or secret leak. "The WebSocket is the right answer for a later slice" (line 216) is the same kind of verdict. The factual requirement is the `kanbanEventsUrl()` addition described in the following clauses.

### 7
**Severity:** Major
**Affected Scope:** Layout, lines 224–230
**Style Rationale:** "The board is wide and the shell is not" and "nothing is squeezed" are informal and give no measure. The next bullets require columns to "keep their natural width" and also to be "a fixed-width column." Natural width and fixed width are different layout rules. The section states neither a single rule nor a width. Eight columns is named earlier (line 70) and is not repeated here as the constraint.

### 8
**Severity:** Nit
**Affected Scope:** The commands, lines 264–267
**Style Rationale:** "With no new code" is false in the same sentence. The sentence specifies an addition to `PAGE_ALIASES`. The precise claim is that `page.open` already resolves a page by alias, so the new words need no new command handler.

### 9
**Severity:** Major
**Affected Scope:** Shared files this changes, lines 272–280
**Style Rationale:** The prose says the slice touches four shared files. The table lists five: `apps/desktop/src/shell/apps.ts`, `apps/desktop/src/shell/MainWindow.tsx`, `apps/desktop/src/components/app-icon.tsx`, `apps/desktop/src/commands/index.ts`, and `apps/desktop/src/commands/navigation.ts`. The count misstates the shared-change surface this section exists to declare.

### 10
**Severity:** Nit
**Affected Scope:** Alternative A: Embed the Hermes dashboard's own kanban tab, line 294
**Style Rationale:** "Almost no new code" does not say how much code. "Almost" makes the pro unfalsifiable.

### 11
**Severity:** Major
**Affected Scope:** Alternative A, Reason for Rejection, lines 300–302 (term also used in Overview, line 17)
**Style Rationale:** "A screenshot, not a surface" is hyperbole. The cons already list the defects: a second visual language, a credential in the query string, and no command-bar, voice, notification, or `data-os-target` integration. The embedded tab is a live view. "Second renderer" is then used for the rejected embedding, while the Overview uses "second renderer" for the design this document adopts (Herald OS rendering the existing API). One term names both the proposal and the thing the rejection forbids, so the reason cannot be checked against the rule it cites.

### 12
**Severity:** Nit
**Affected Scope:** Alternative B, Reason for Rejection, lines 312–314
**Style Rationale:** "A page wearing a disguise" is a metaphor. The rejection is already concrete: one page would carry two data sources, two refresh behaviours, and two meanings of "work".

### 13
**Severity:** Major
**Affected Scope:** Alternative C: Write the board as a floating window, lines 319–321
**Style Rationale:** "A question the user asks constantly" asserts a frequency this document never measures. "Deserves a permanent address, not a launcher" is a rhetorical preference. The next sentences state the decision in checkable terms: the floating window is deferred, the content stays a self-contained component, and only a proven width problem would force the promotion.

### 14
**Severity:** Nit
**Affected Scope:** Alternative D: Make the first slice writable, lines 332–337
**Style Rationale:** "Can feel like a screenshot of a board" is a subjective impression, and it uses "screenshot" again as a put-down for a read-only view. "The value of the first slice is seeing the agent's work, and seeing it is a complete feature" repeats one claim in two clauses.

### 15
**Severity:** Nit
**Affected Scope:** Alternative D, lines 339–342
**Style Rationale:** "Note for the reviewer" addresses the review process. The bulk route is a specification fact: `POST /api/plugins/kanban/tasks/bulk` was verified to move a card and to refuse an illegal transition, it needs no new IPC method, and slice 1 does not use it. That belongs in a normal paragraph.

### 16
**Severity:** Nit
**Affected Scope:** Alternative E, Reason for Rejection, line 353
**Style Rationale:** "The right read path" is a verdict word. The cons already draw the distinction: the gateway `/kanban` command is a command an agent runs, and the plugin REST API is the supported read path inside the shell's `/api/` boundary.

### 17
**Severity:** Major
**Affected Scope:** Non-Functional Requirements, Rollout, lines 366–367
**Style Rationale:** "Nothing existing changes behaviour" is an absolute the rest of the document exceeds. The design adds a sidebar entry, `PAGE_ALIASES` entries for "board" and "kanban", and command registration. Those change navigation and voice name resolution. The rollout claim that matches the design is narrower: existing pages keep their current behaviour, and removing the new page removes its registration.
