# Task State

## Status
Completed

## Current task
Keep both headline-choice presentations editable in the same project and select either one from the game's existing settings menu. Preserve the same note cards, article order, publication rules and campaign save format.

## Context
- The base presentation is in Scenes/newsroom_screen.tscn. The alternate backdrop, instruction banner and close button are independently editable in Scenes/headline_choice_overlay.tscn.
- The alternate scene preserves the user's opacity setting (0.8392157) from the earlier Git branch. The same three cards and selection behavior are shared by both presentations, as previously requested.
- Unrelated AGENTS.md, desk/asset, export, and project changes were already dirty and remain outside this milestone.

## Already done
- Added the alternate scene and its two art assets back to the main checkout without switching branches or replacing the classic layout.
- Added a persistent checkbox to the existing settings panel; it is available from both the main menu and pause. Changes apply to open choices immediately.
- The alternate view closes with its own X or a click outside the notes. The classic view remains unchanged.
- Updated the project map. The older branch codex/headline-choice-overlay remains as a historical fallback.

## Decisions
- Store the selected presentation in user://settings.cfg, alongside the tooltip preference; do not put this visual preference in campaign saves.
- Shared note positions and note art remain in the newsroom scene; only the alternate background elements are separate. Gameplay, saves, and the initial tutorial remain untouched.

## Relevant files
- Scenes/headline_choice_overlay.tscn, Assets/note_select/Group 17.png, Assets/note_select/image 48.png (and existing Godot-generated .import companions).
- Scripts/newsroom_screen.gd, Scenes/settings_panel.tscn, Scripts/settings_panel.gd, Scripts/game_settings.gd, MVP_README.md.

## Do not touch
- Do not change the initial tutorial without a new request.
- Preserve unrelated dirty files and untracked artist assets. Do not stage them with the home milestone.
- Do not discard either headline-choice branch while the user is comparing presentations.

## Remaining
None for this completed task. Future independent note positions, if requested, would require a separate layout change.

## Validation
- Godot 4.7.2 imported the two alternate art assets and loaded both presentations.
- Focused choice smoke check passed: classic/alternate visibility, X, outside click, note selection without publication, and settings panel state.
- Settings persistence check passed; the pre-existing user settings file was restored byte-for-byte afterwards.
- Rendered and inspected classic, alternate and settings-panel screenshots in the local Temp directory. The full ~450-check suite was not rerun.
- Final diff inspection and git diff --check were used before committing the milestone.

## Known issues / uncertainties
- Both presentations intentionally share the three note cards and their positions. The alternate scene controls its own backdrop, banner, opacity and close button.
- An already-open Godot editor may need to refresh imported textures or reopen the new overlay scene.

## Git state
- Workspace: C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat.
- Previous HEAD before the choice-switch milestone: bc7c9bc. The alternate historical branch remains at 025ae25.
- The choice switch and this corrected snapshot belong to one focused milestone commit. No push was requested.
