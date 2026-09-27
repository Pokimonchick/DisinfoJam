# Task State

## Status
Completed

## Current task
Refine the project handoff workflow, including when checkpoint commits are required.

## Context
Git Safety requires a checkpoint before project changes, not for questions or read-only work. `MVP_README.md` is the existing project map; source files and Git remain authoritative.

## Already done
- Read the current `AGENTS.md` and `MVP_README.md`.
- Updated the existing `Task Handoff` section with compact command, subagent, model-choice, and compaction rules.
- Reused this existing task-state file instead of creating a duplicate.
- Clarified the checkpoint rule in `AGENTS.md` for ordinary requests, `prepare`, and `resume`.

## Decisions
- Keep the checkpoint flow; no separate handoff commits.
- Give subagents short task-specific briefs without requiring `prepare` or this file.
- Recommend `/compact` only when reducing the old conversation would help.
- `prepare` changes `TASK_STATE.md` and needs a checkpoint; read-only `resume` does not.

## Relevant files
- `AGENTS.md`
- `TASK_STATE.md`
- `MVP_README.md` (read; unchanged)

## Do not touch
- `MVP_README.md`, game code, scenes, resources, and unrelated documentation for this task.

## Remaining
None for this task.

## Validation
- Documentation diff inspected; `git diff --check` passed. Godot was not run.

## Known issues / uncertainties
None identified.

## Git state
- Branch: `elfat`.
- Relevant checkpoint: `d1ff57c` (`checkpoint: before checkpoint policy change`).
- Changed for this task: `AGENTS.md`, `TASK_STATE.md`.
- Working tree: these documentation edits are uncommitted after the checkpoint.
