# Task State

## Status
Completed

## Current task
Replace the temporary home/tamagotchi view with a full-screen, mid-century pixel-art room based on the approved concept, keeping the campaign's existing evening interactions and saves. Preserve the current headline-choice implementation while keeping the alternate overlay recoverable.

## Context
- The initial procedural room looked too flat and its palette diverged from the approved concept. The revised view uses richer 16-bit-style pixel art; the engine's color depth was not changed.
- Current user reference: C:/Users/User/AppData/Local/Temp/codex-clipboard-5d70c64b-c478-420d-a2e5-4a2de8302c7b.png. Nikola's portrait reference remains in Assets/Characters/Mask group (22).png.
- The user's AGENTS.md and unrelated desk/assets changes were already dirty and remain outside this milestone.

## Already done
- Added separate room, Nikola, and food/coffee PNGs under Assets/Home/; the scene keeps click areas and stat displays independent of the art.
- Replaced the narrow procedural room with a 1920x1080 fitted scene, compact top indicators, pixel-art props, bed highlight, tooltips, small feedback messages, and sleep transition.
- Preserved the existing evening rules: food, coffee, sleep, balance, and progression into the next shift. Home has its own pause button, with process disabled while paused.
- Returned the main branch elfat to the classic headline-choice presentation at 08f0fb0. The alternate overlay and user's opacity tuning are preserved on codex/headline-choice-overlay at 025ae25; the classic anchor is codex/headline-choice-classic at 0f9b790.
- Updated the project map to describe replaceable home art.

## Decisions
- This is a presentation change; NewsroomSession, gameplay balance, save format, and the initial tutorial remain untouched.
- Keep the alternate headline layout in Git history/its branch. Its commit can later be applied to the current branch without discarding home-room changes.

## Relevant files
- Assets/Home/evening_room.png, Assets/Home/nikola_idle.png, Assets/Home/evening_food.png and their Godot-generated .import companions.
- Scenes/home_screen.tscn, Scripts/home_screen.gd, Scripts/pixel_room.gd.
- Scenes/mvp_game.tscn, Scripts/mvp_game.gd, Tests/mvp_tests.gd, MVP_README.md.

## Do not touch
- Do not change the initial tutorial without a new request.
- Preserve unrelated dirty files and untracked artist assets. Do not stage them with the home milestone.
- Do not discard either headline-choice branch while the user is comparing presentations.

## Remaining
None for this completed task. Future artist-authored sprites or a chosen headline layout can be integrated as separate work.

## Validation
- Godot 4.7.2 loaded the new scene and passed focused home logic smoke check (HOME_SMOKE_PASSED).
- A focused full-game integration check passed (HOME_INTEGRATION_PASSED): shift to home, actual pause and coffee clicks, bed click, next shift.
- Rendered and inspected C:/Users/User/AppData/Local/Temp/disinfo-home-preview.png at 1920x1080. The full ~450-check suite was not rerun; no broader gameplay rules changed.
- Final diff inspection and git diff --check were used before committing the milestone.

## Known issues / uncertainties
- The room art is a generated concept implementation, not the artist's final sprite set. Existing tutorial text about the fridge opening visually was intentionally left unchanged; the new fridge uses hover/cursor feedback rather than a door-opening animation.
- An already-open Godot editor may need to refresh imported textures.

## Git state
- Workspace: C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat.
- Previous HEAD before the home milestone: 08f0fb0.
- Home feature and this snapshot belong to one focused milestone commit. No push was requested.
