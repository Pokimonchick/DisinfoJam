# Task State

## Status
Completed

## Current task
Remove the shift timer, correct publication stamina spending, reset the stats drawer for new games, and replace coffee/loyalty time bonuses with approved stamina recovery.

## Context
- Campaign still has five shifts, a continuing shuffled article queue, shuffled headline choices, and a publication limit of 10.
- User approved coffee +20 stamina and loyalty >=75 granting +10 at shift start. First coffee is free on the first shift.
- Classic and backdrop headline-choice presentations remain editable and selectable. The old 8-bit home scene remains.

## Already done
- Removed the active countdown and its desk/HUD controls; finish manually or acknowledge the final publication of a full issue.
- Publication costs 4 stamina, or 2 with reader support at reputation >=75. Passive drain remains 0.10/sec and pauses during results, pause, and narrative screens.
- New game expands the drawer; Continue restores its saved state. Stamina displays one decimal.
- Coffee restores up to 20 stamina, caps at 100, and cannot be wasted at full stamina or consumed during pending results. Unused coffee carries over; later cups are purchased at home.
- Loyalty >=75 restores up to 10 stamina only on starting a shift; loading or changing loyalty during work does not regrant it.
- Updated hints, tutorial, pause text, editor previews and project/save documentation. Publication-result rows retain the requested distinct colors.
- Earlier close-button/art/shadow correction was committed and pushed as cc266c1. It is complete and is not the current task.

## Decisions
- Preserve legacy time fields and approval_time_applied as inactive save/resource data; save the new approval_stamina_applied flag separately. Save format remains version 1.
- Preserve existing saved coffee inventory and applied results; no retroactive stamina compensation on loading older saves.
- Keep the user's current production starting stamina, scene positions, artist sources, and export settings.

## Relevant files
- Scripts/newsroom_session.gd, newsroom_balance.gd, newsroom_save_data.gd — rules, balance and save compatibility.
- Scripts/mvp_game.gd — new-run presentation reset, tutorial and pause.
- Scripts/newsroom_screen.gd, work_status_drawer.gd, newsroom_hud.gd, home_screen.gd — UI and hints.
- Scenes/newsroom_screen.tscn, newsroom_hud.tscn, work_status_drawer.tscn — timer removal and editor previews.
- Data/reader_support.tres, state_approval.tres; MVP_README.md; Docs/SAVES.md.
- Tests/mvp_tests.gd, Tests/save_tests.gd — targeted regressions.

## Do not touch
- Preserve manual scene edits, Data/mvp_balance.tres overrides, export_presets.cfg and untracked artist originals in Assets/Assets for new version of game/new/.
- Do not remove either headline-choice presentation or redesign the restored home scene.
- Push only elfat to origin/elfat after three new Codex commits; inspect outgoing commits first. Ask before pushing any other branch.

## Remaining
- No implementation remains for the agreed scope.

## Validation
- Current source: headless MVP --untimed passed 155 checks (catalog audit skipped); save suite passed 56 checks using temporary slots.
- Existing headless shader sampler diagnostic appeared; native OpenGL UI smoke completed without shader errors. Inspected desk/home screenshots for timer removal and stamina text.
- Diff reviewed; no full catalogue suite, export build or prolonged balance playthrough was needed.
- No live helper or background check remains. Tests and smoke did not overwrite the player's campaign save.

## Known issues / uncertainties
- Balance was not tuned through an entire manual playthrough; passive drain remains as explicitly requested.

## Git state
- Workspace: C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat; prior milestone HEAD cc266c1, also last successful push to origin/elfat.
- This snapshot accompanies the validated untimed-shift milestone. Its commit is discoverable from the current Git log.
- Unrelated working-tree changes remain in Data/mvp_balance.tres, Scenes/headline_card.tscn, Scenes/headline_choice_overlay.tscn, manual layout hunks of Scenes/newsroom_screen.tscn, export_presets.cfg and untracked new/ art.
