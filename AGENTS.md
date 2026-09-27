# AGENTS.md

## Project

Godot 4.x game project.

Follow the existing project structure, naming, architecture, and code style. Prefer small, focused changes over rewrites.

For gameplay or architecture work, read `MVP_README.md` as a short project map; for save-system work, also read `Docs/SAVES.md`. Verify relevant behavior in code before editing.

## Git Safety

Commit completed, substantial changes after relevant validation: for example, adding a save system, a major gameplay feature, or reaching a release milestone. Decide by the change's scope, importance and risk, not by the kind of file or edit. Small changes can remain uncommitted until a meaningful milestone or an explicit commit request. Do not commit every request or create an automatic checkpoint before editing.

Before committing, inspect Git status and the diff, then stage only files intended for that commit. Preserve unrelated work. If an operation could discard uncommitted work, safeguard it first. Do not amend, squash, delete, rewrite, or push commits unless explicitly asked.

## Scope

Before editing, inspect the relevant files and understand the current implementation.

- Make the smallest change that solves the task.
- Reuse existing patterns.
- Do not refactor unrelated code.
- Do not reorganize folders or rename unrelated files/nodes.
- Do not change gameplay outside the requested scope.
- Do not introduce large abstractions when a local fix is enough.

## Godot Safety

Do not manually edit generated/cache files such as `.godot/` or `.import/`.

Be careful with `project.godot`, `.tscn`, and `.tres`:
- keep edits minimal,
- preserve UIDs, resource references, and node paths,
- avoid rewriting or reordering unrelated serialized content.

Use Godot-native solutions and follow existing architecture.

## Validation

Do only validation proportional to the change.

Usually:
1. inspect the final diff,
2. check the touched files for obvious syntax/reference errors,
3. run one relevant quick check if useful.

Do not run broad, repetitive, or expensive checks for small local changes.

Never claim something was tested if it was not.

## Final Response

Keep the final report short:
- what changed,
- files changed,
- what was actually checked,
- any important remaining risk.

## Task Handoff

### State and commands

Keep one Git-tracked root `TASK_STATE.md` as a compact, portable snapshot of the current large task, not a request log, chat history, reasoning trace, permanent project document, or required subagent IPC. Use `Status` (`Active`, `Blocked`, `Completed`), `Current task` (goal, scope, acceptance), `Context`, `Already done`, `Decisions`, `Relevant files`, `Do not touch`, `Remaining`, `Validation` (result, checked revision or stage, unchecked items), `Known issues / uncertainties`, and `Git state` (workspace, branch, relevant commit, changed files, working tree). Keep `Remaining` actionable; never paste a full diff. Update the file only for `prepare`, an explicit save-state request, a substantial manual root handoff, or a dangerously stale snapshot. Material changes to requirements, decisions, results or blockers that would mislead recovery count as stale; batch their correction at a natural work boundary. Routine code changes and subagent calls do not require updates.

The coordinating root owns this snapshot and integrates results; helpers do not write it. Read it on recovery, task changes or before updating, not on every request. Match the user's goal and workspace; a `Completed` snapshot is not an instruction to resume old work. Do not overwrite another unfinished task or assume ownership from an old owner label; resolve ambiguity first. Reuse this file after the previous task is complete; separate task records are needed only if multiple unfinished tasks actually need preservation.

Before saving, reread the current file, preserve valid constraints and others' changes, and remove confirmed stale details. Keep it short (roughly 100 substantive lines or less when practical). Put lasting knowledge in existing project documentation. Never copy secrets from environment variables, credentials or logs into state or handoffs; use safe references only.

`prepare` and `resume` are explicit workflow requests, not built-in slash commands; quoted examples or unrelated uses of these words do not trigger them.

For `prepare`, replace stale state with a concise handoff. Verify actual results and account for known helpers/processes still writing; collect results or coordinate a pause when needed, and identify continuing work. Do not start new implementation or run `/compact` automatically. Suggest `/compact` only when a large conversation makes it useful; follow the platform's context handling without fixed thresholds. Local preparation does not require a commit; for a requested transfer, preserve state and necessary results using the agreed repository workflow.

Saving here preserves local continuation. Git-tracked, committed, transferred and accessible to a recipient are separate facts. For a requested handoff to another environment, use the existing repository workflow within authorization and account for uncommitted/untracked files and required artifacts; report unverified delivery explicitly. Do not require a remote transfer check for continuation here.

For `resume`, read `AGENTS.md` and the matching `TASK_STATE.md`, plus `MVP_README.md` for gameplay/architecture or `Docs/SAVES.md` for saves. Verify branch, working tree and relevant source files. Current confirmed requirements define the goal; code, Git and fresh checks establish actual implementation, not permission to discard an unmet requirement. A commit can leave `git diff` empty, so consult a short `git log` and `git show --stat` only when needed. Start with `Relevant files` and `Remaining`; broaden research only for a concrete gap. Recover missing state from evidence; clarify an unrecoverable goal or decision before dependent edits. Never reset to a recorded commit or erase others' work automatically. `resume` is mainly for `/compact`, a root-model/chat change, or another context break, not required after `prepare` in the same intact conversation.

### Subagents and models

Keep short, sequential, context-heavy work with root. Use a subagent when available and permitted, and when a bounded task benefits enough from independent research, repetitive implementation or separate review to justify coordination. No user `prepare` is needed. Give each subagent a short just-in-time brief: objective, needed context and decisions, search area and allowed files to edit, constraints, expected result, and checks. Avoid inheriting full history when a short brief suffices. Ask it to return findings, changed files, checks, concerns, and deviations; root checks and integrates the result in proportion to risk. Reading `TASK_STATE.md` is optional for a subagent; avoid extra coordination layers.

Coordinate one root per working tree; assign helpers non-overlapping write areas. Independent writing roots need separate worktrees/checkouts or explicit ownership and integration; otherwise serialize conflicting edits. Different branch names or state files alone do not isolate working files. Do not add locking infrastructure preemptively.

If model selection is available and permitted, prefer Luna for bounded mechanical work, repository searches, simple plan execution, and checks; Sol for normal engineering, multi-file logic, debugging, and review; Astra for exceptionally hard bounded architecture, root-cause analysis, critical review, or a failing plan. Match the delegated task, not the root model; use only models actually available in the environment. If mechanical work exposes ambiguity, a scope change, or significant gameplay/architecture risk, pause that part and return the issue for stronger analysis. Repeated failures call for revisiting the task, context or model. Without delegation or model selection, root performs the work.

Switch the root model manually only when a substantial next phase warrants it; prefer a suitable subagent for one bounded task. A manual handoff may use `prepare`, optional `/compact` when the old conversation is large, then `resume`. `TASK_STATE.md` preserves portable task state; `/compact` reduces conversation context. Neither is a mandatory ritual, and unnecessary coordination should not displace useful work.

### Completion and Git

Do not update `TASK_STATE.md` merely because work finished. At the next `prepare` or explicit request, set `Completed` only when the agreed scope and required checks are satisfied or exceptions explicitly accepted; retain useful results and clear stale `Remaining`. Otherwise use `Active`, or `Blocked` for a concrete obstacle. Retain the completed snapshot until reuse; completion does not authorize deleting artifacts or uncommitted work. Git Safety remains the controlling commit rule; do not make routine handoff commits or ignore `TASK_STATE.md`. Change this workflow only for an observed failure or new need; no periodic audit or product test suite is required for instruction-only changes.
