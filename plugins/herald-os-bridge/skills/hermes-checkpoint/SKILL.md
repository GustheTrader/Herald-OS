---
name: hermes-checkpoint
description: Submit, track, and recover checkpointed Pi work through the factory_durable tool when Hermes needs crash-resumable execution.
metadata:
  hermes:
    tags: [hermes, checkpoint, durable, pi, recovery, factory]
    related_skills: [software-factory]
---

# Hermes checkpoint

Use this for work that needs to survive an interrupted Pi backend. You coordinate and review; `factory_durable` delegates execution to Pi. Your own Hermes reasoning and chat are not checkpointed by this tool.

1. Define the authorized task, its project, expected output, and any limits on changes. Call `factory_durable` with `action: sessions` and select the existing session for the project. Do not submit to a different project's working directory. If no suitable session exists, report that provisioning is needed.
2. Before submitting, record a unique stable task ID, session ID, and exact prompt in a durable project handoff appropriate to the task. Include the task boundaries and output location in the prompt. Do not put credentials in the handoff or prompt.
3. Submit with `action: submit`, `session`, `request_id` set to the stable task ID, and `prompt`. Record the returned `submissionId` in the handoff. A new task or changed prompt requires a new ID.
4. Check with `action: status`, `session`, and `submission_id`. Report progress or the completed result; review changes and run checks appropriate to the task.
5. If the submission response is lost or Hermes restarts, retry with the same session, request ID, and exact prompt. Never create a replacement ID to recover a lost response. If an action was interrupted, inspect its effects before deciding whether to retry; external effects may have partially completed.

The Zo process service is `gnoesis-pi-durable`; its API listens only on localhost. If unavailable, report the error and preserve the handoff for recovery. Manage the service through Zo Services. Do not expose its token or run the old background start/stop scripts while it is supervised. The service provides crash recovery, not a guarantee of exactly-once external effects or a hardened sandbox.

For project sessions and operational details, read `/home/workspace/Projects/Durable Gnoesis Agents Swarm/notes/hermes-lane.md`. Follow the project's Rust-first policy for durability-boundary changes.
