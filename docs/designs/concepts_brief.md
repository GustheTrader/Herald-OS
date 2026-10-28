# Kanban board surface for Herald OS

* **Author:** Hermes (Elephant), for the Gnoesis factory
* **Date:** 2026-10-28
* **Status:** Concept brief, awaiting Goldfish review

## Overview

Herald OS shows the work the user asked for: their conversations, their files, their
missions. It does not show the work the *agent* is doing on its own initiative. Hermes runs a
kanban board for exactly that: a queue of cards that Hermes and its worker profiles pick up,
move, and finish. The board exists in the Hermes runtime, it has a full HTTP API, and the
Herald OS roadmap names a "kanban board surface" as planned work. The board is not visible
anywhere in Herald OS today.

This concept is a page in the Herald OS shell that shows that board, so the user can see what
the agent is working on without leaving the machine.

## The problem

A user of Herald OS cannot currently answer the question "what is my agent doing right now?"
from inside the shell. They can see a conversation they started. They cannot see the queue of
things Hermes queued, what is running, what is blocked, or what finished while they were away.
The kanban board in the Hermes runtime holds that answer, and the Herald OS shell ignores it.

Two things make this a real gap rather than a missing nicety:

1. **The board is the agent's own work queue.** It is populated by Hermes dispatching work to
   worker profiles, not by the user opening a session. It keeps moving while the user is
   looking at a different page.
2. **The user already has a work view, and it shows the wrong half.** The Missions page shows
   work derived from the user's conversations. The board shows work the agent started on its
   own. Neither page shows the other.

## The anchored hypothesis

Herald OS gains a **Board** page that renders the Hermes kanban board as columns of cards,
refreshes itself while it is open, and shows a detail pane for the selected card. It reads the
board; it does not write to it. The first slice is deliberately read-only.

The hypothesis rests on four facts verified against a running Hermes runtime on 2026-10-28:

* The runtime serves the board at `GET /api/plugins/kanban/board`. It returns the columns and
  their cards, plus the current board's tenants and assignees.
* The runtime serves the column set and the legal card-to-card transitions at
  `GET /api/plugins/kanban/workflow`. Herald OS does not need to hardcode eight column names
  or a transition table; it reads them.
* Cards carry the fields a detail pane needs: title, body, assignee, priority, run start time,
  latest summary, child-task progress, link and comment counts, and worker diagnostics.
* The board API lives under `/api/`, so the shell's existing REST bridge can reach it without a
  new capability and without the renderer ever seeing a token.

## Analysis

### What already exists, and can be reused

The shell already has every moving part a board page needs. The page registry
(`src/shell/apps.ts`), the sidebar, the master/detail split used by Automations and
Connections, the glass primitives, and the REST client (`src/lib/rest.ts`) are all in place.
The automations page is the closest sibling: it lists backend-owned records, polls a Hermes
REST route, and shows a detail pane.

The Hermes runtime side needs nothing. The board, the columns, the transition rules, the
diagnostics, and the audit trail of card moves are all already implemented and already tested
upstream. Herald OS is a second renderer for an API that exists.

### What the board is not

The board is not a project tracker with its own concept of a project, and it is not a second
view of Missions. It is a queue with a strict column vocabulary, read from the runtime, with
transitions the runtime enforces. Anything Herald OS invents on top of that is a new concept
with a new owner, and the runtime already owns the domain.

### The strongest objection to this concept

Hermes's own dashboard already ships a kanban tab. The plugin manifest points at a built
JavaScript bundle that renders a board inside the dashboard. The cheap alternative is to open
that dashboard in Herald's existing web window and link to the kanban tab.

That alternative deserves a real answer, not a dismissal:

* The dashboard is a separate application with its own look. Embedding it puts a second visual
  language inside a shell that is one visual language.
* The dashboard authenticates `/api/plugins/` with a ticket in the query string. Putting a
  credential in a URL is worse than the shell's current arrangement, where REST runs in the
  Electron main process and the renderer never handles a token.
* A web view is opaque to Herald OS. It cannot be driven by the command bar, cannot be reached
  by voice, cannot be a target for a notification, and cannot carry the `data-os-target`
  attribute that makes a list item addressable by an `OsCommand`.

A board is also wide. Eight columns do not fit comfortably in the sidebar-plus-page layout the
shell uses for every other page, which is a fact to settle during design, not to discover
afterwards.

### Where the concept is deliberately thin

The first slice reads. It does not move cards, create cards, edit cards, comment, or attach
files. The reason is not caution for its own sake: the shell's REST bridge cannot express
`PATCH` today, so a move would force a change to shared IPC code, a change to the preload
bridge, and a new user-facing mutation path — three shared changes to ship a drag gesture.
The board's value to the user is seeing the agent's work. Seeing it is a complete, useful
feature on its own. Moving cards is a second slice with its own approval path.

## Goals

* A user can open one page and see every card on the current kanban board, grouped into the
  runtime's own columns.
* The column set, the column labels, the column icons, and the legal transitions between
  columns all come from the runtime, not from constants in Herald OS.
* The board refreshes while the page is open, so a card that Hermes moves is seen to move.
* Selecting a card shows what the agent is doing with it: the body, the assignee, the current
  run, the latest summary, the child-task progress, and any worker diagnostics.
* The page is reachable by the command bar and by voice, like every other page in the shell.

## Non-Goals

* Moving, creating, editing, commenting on, or attaching files to cards. That is a later
  slice, and it needs a shared-IPC change.
* A second board picker that shadows the runtime's board switching. The runtime owns which
  board is current.
* Any concept of a "project" layered on the board. The board is a queue.
* Replacing or merging with the Missions page. They show different work.
* A copy of the runtime's dashboard, in the renderer or anywhere else.

## Open questions

* **Which surface holds eight columns?** A page in the main window narrows to the sidebar
  width. The board may need a floating window of its own, or a horizontally scrolling page
  body, or a narrower set of columns with the rest behind a control. This is the largest
  open design question and it should be settled before anything is built.
* **Does the Board become a top-level sidebar page, or a tab inside Missions?** Both are
  defensible. A top-level page is more discoverable and costs a slot in the sidebar and a
  shortcut. A tab inside Missions keeps one "work" entry point but couples two different
  data sources and two different refresh behaviours.
* **How fresh does the board need to be?** Polling every few seconds is simple and matches
  existing shell patterns. The runtime also offers a WebSocket event stream for the board,
  which would push changes instead of pulling them, but that needs a new tokenised URL
  capability in the main process and a new preload method.
* **What does a card link to?** Cards carry a `session_id` when a worker ran them, and a
  workspace path and branch. Should selecting a card offer to open that session in the Hermes
  page, or to open the workspace in the Studio?
* **Should a card that is stuck be loud?** The runtime reports worker diagnostics and
  consecutive failures per card. A board that renders those quietly is a board the user has
  to read carefully. A board that shouts is a board the user stops trusting.

## Key decisions carried forward

* The board is read-only in the first slice.
* Columns, labels, icons, and legal transitions are read from the runtime.
* The Hermes runtime is not forked, patched, or wrapped to serve the board. Herald OS consumes
  the API it already publishes.
* The renderer never handles a token. REST goes through the Electron main process, as it does
  everywhere else in the shell.
