# AGENTS.md

## Project

Godot 4.x game project.

Follow the existing project structure, naming, architecture, and code style. Prefer small, focused changes over rewrites.

For gameplay or architecture work, read `MVP_README.md` as a short project map; for save-system work, also read `Docs/SAVES.md`. Verify relevant behavior in code before editing.

## Git Safety

Before every new user request, create a checkpoint commit **before editing anything**.

If there are changes:

```bash
git add -A
git commit -m "checkpoint: before <short task description>"
```

If the tree is clean:

```bash
git commit --allow-empty -m "checkpoint: before <short task description>"
```

Do not amend, squash, delete, or push checkpoint commits unless explicitly asked.

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

Keep one Git-tracked root `TASK_STATE.md` as a compact, portable snapshot of the current large task, not a request log, chat history, reasoning trace, permanent project document, or required subagent IPC. Use `Status` (`Active`, `Blocked`, `Completed`), `Current task`, `Context`, `Already done`, `Decisions`, `Relevant files`, `Do not touch`, `Remaining`, `Validation`, `Known issues / uncertainties`, and `Git state` (branch, relevant checkpoint, changed files, working tree). Keep `Remaining` actionable; never paste a full diff. Update the file only for `prepare`, an explicit save-state request, a substantial manual root handoff, or a dangerously stale snapshot. Reuse it for later large tasks; routine code changes and subagent calls do not require updates.

For `prepare`, first obey Git Safety, then replace stale state with a concise handoff. Do not start new implementation or run `/compact` automatically. Suggest `/compact` only when a large conversation makes it useful. Do not create a separate handoff commit: the next request's checkpoint records the updated file.

For `resume`, first obey Git Safety, then read `AGENTS.md` and `TASK_STATE.md`, plus `MVP_README.md` for gameplay/architecture or `Docs/SAVES.md` for saves. Verify branch, working tree, and relevant source files; code and Git override stale state. A checkpoint can leave `git diff` empty, so consult a short `git log` and `git show --stat` only when needed. Start with `Relevant files` and `Remaining`; broaden research only if necessary. `resume` is mainly for `/compact`, a root-model/chat change, or another context break, not required after `prepare` in the same intact conversation.

### Subagents and models

Keep short, sequential, context-heavy work with root. Use a subagent when a bounded task benefits from less context, independent or parallel research, repetitive implementation, or separate review. No user `prepare` is needed. Give each subagent a short just-in-time brief: objective, needed context and decisions, files/search area, constraints, expected result, and checks. Ask it to return findings, changed files, checks, concerns, and deviations. Reading `TASK_STATE.md` is optional for a subagent; avoid extra coordination layers.

If model selection is available, prefer Luna for bounded mechanical work, repository searches, simple plan execution, and checks; Sol for normal engineering, multi-file logic, debugging, and review; Astra for exceptionally hard bounded architecture, root-cause analysis, critical review, or a failing plan. Match the delegated task, not the root model. If mechanical work exposes ambiguity, a scope change, or significant gameplay/architecture risk, pause that part and return the issue for stronger analysis.

Switch the root model manually only when a substantial next phase warrants it; prefer a suitable subagent for one bounded task. A manual handoff may use `prepare`, optional `/compact` when the old conversation is large, then `resume`. `TASK_STATE.md` preserves portable task state; `/compact` reduces conversation context. Neither is a mandatory ritual, and unnecessary coordination should not displace useful work.

### Completion and Git

Do not update `TASK_STATE.md` merely because work finished. At the next `prepare` or explicit request, set `Completed`, retain useful results, and clear stale `Remaining`. Git Safety remains the controlling commit rule; do not add handoff commits or ignore `TASK_STATE.md`.
