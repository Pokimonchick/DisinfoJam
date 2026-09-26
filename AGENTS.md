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

### TASK_STATE.md

Keep one tracked `TASK_STATE.md` in the project root as a compact snapshot of the current task. It is for switching models, continuing after `/compact` or in a new chat, and explicit user requests to save task state. It is not an action log or permanent project documentation. Do not update it after every ordinary request or code change.

Update it only when the user says `prepare`, explicitly asks to save or update task state, before handing work to another model, or when a major task change makes the existing snapshot dangerously misleading. Keep only current, concise facts; no chat transcript, large logs, code dumps, or internal chain-of-thought. Use these sections: `Status` (`Active`, `Blocked`, or `Completed`), `Current task`, `Context`, `Already done`, `Decisions`, `Relevant files`, `Do not touch`, `Remaining`, `Validation`, `Known issues / uncertainties`, and `Git state`. In `Git state`, record the branch, latest relevant checkpoint commit, files changed for this task, and whether uncommitted changes existed at handoff. Do not paste the full diff.

### `prepare`

Treat `prepare` as a new user request: first create the normal checkpoint commit under Git Safety. Do not create a separate handoff commit unless explicitly asked. Then read the current task state and update `TASK_STATE.md` with the current goal, completed work, decisions, relevant files, concrete remaining steps, validation, risks, and Git state. Remove stale information. If a faster model can continue mechanically, make `Remaining` precise enough for it to do so. Do not start new implementation after `prepare` unless the user also requests it.

### `resume`

Treat `resume` as a new user request: first create the normal checkpoint commit. Read `AGENTS.md` and `TASK_STATE.md`; for gameplay or architecture also read `MVP_README.md`, and for save-system work also read `Docs/SAVES.md`. Check the current branch and working tree. A checkpoint may have committed the previous step, so use a short `git log` and `git show --stat` for the relevant checkpoint when `git diff` is empty; inspect the full commit only if needed. Source files and Git are the source of truth. If the snapshot disagrees with them, follow the code and correct the snapshot at the next `prepare`. Continue from `Remaining`, starting with `Relevant files`; inspect more of the repository only when necessary.

### Model choice and escalation

Choose by type of work, not model name. Use a stronger reasoning model for unknown problems, root-cause analysis, complex debugging or review, architecture, ambiguous behavior, substantial planning, a failed plan, or decisions that materially affect gameplay or architecture. A faster model can implement an established plan, make small local or repetitive edits, rename or format, fix lint/style, update simple tests, run checks, and resolve obvious local errors from a clear `Remaining` list. If mechanical work reveals an architectural problem, ambiguity, conflict with game logic, scope change, out-of-scope gameplay risk, or a significant new decision, pause that part, record the issue briefly, and propose handing it to a stronger reasoning model.

### After `/compact` and completion

After `/compact`, continue from `AGENTS.md`, `TASK_STATE.md`, `MVP_README.md` when relevant, and the source files in `Relevant files`. Do not reconstruct the full chat history when the snapshot is sufficient. When a task finishes, do not rewrite `TASK_STATE.md` after every later message. At the next `prepare` or explicit request, set `Status` to `Completed`, record the result and useful validation, and remove stale remaining steps. For a new task, reuse the same file and replace the old state.

### Git integration

Git Safety remains the controlling rule. `prepare` creates its usual checkpoint before updating `TASK_STATE.md`; the next user request's checkpoint naturally records that update. Do not add a parallel commit flow or a separate handoff commit without an explicit request. Keep `TASK_STATE.md` tracked by Git and out of `.gitignore`.
