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
