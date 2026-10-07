# Task State

## Status
Completed

## Current task
Redesign the main menu using the supplied menu_background.PNG and coco_news.PNG,
following the sketch's left-side layout while retaining the four existing actions.
Make the previous publication seal disappear into the paper when the next article appears.

## Context
- Existing five-shift Godot game on local elfat; source and Git outrank old snapshots.
- Two-click 3D stamping, both headline-choice layouts and the restored 8-bit home stay in place.
- The user is tuning the editor during work; preserve live values and unrelated scene edits.

## Already done
- Full-screen authored menu background, emblem at upper left, heroine visible at right.
- Two large paper arrows for Continue/New Story and two smaller ones for Settings/Quit.
- Native Button input, disabled Continue, saved-run summary and original actions retained.
- Reference canvas fits uniformly to the window; background keeps its aspect ratio and covers it.
- Paper hover animation and keyboard focus marker; menu header/help clutter removed.
- Old stamp ink diffuses and fades through the existing red-ink Multiply shader over 0.8s.
- Absorption pauses with the desk. Preview material is independent; new ink cancels old callbacks.
- Restores, new runs and leaving WORK clear transient ink immediately.
- Focused interaction tests and project documentation updated.

## Decisions
- Exactly four menu buttons; the sketch does not introduce separate Work/Home routes.
- Menu positions are editable under Scenes/mvp_game.tscn -> Menu/Canvas in 1920x1080 coordinates.
- Absorption Seconds on StampArea controls fade duration; zero disables the animation.
- Imprint shader exposes Absorption Spread Pixels and Absorption Grain.
- Result Delay Seconds currently reads 0.5 in newsroom_screen.gd: this live user value was preserved.
- No new save data, gameplay effects or release export.

## Relevant files
- Scenes/mvp_game.tscn; Scripts/main_menu.gd; Scripts/menu_paper_button.gd; Scripts/mvp_game.gd.
- Assets/Assets for new version of game/menu_background.PNG and coco_news.PNG plus Godot import metadata.
- Scenes/stamp_area.tscn; Scripts/stamp_area.gd; Shaders/stamp_ink.gdshader; Scripts/newsroom_screen.gd.
- Tests/interface_flow_tests.gd; Tests/desk_stamp_tests.gd; Docs/DESK_STAMP.md; MVP_README.md.

## Do not touch
- User/editor changes in Scenes/newsroom_screen.tscn, including solar animation time and node metadata.
- Solar/dust tuning, coffee animation, authored balance, player saves and 8-bit home.
- Both headline-choice layouts and the existing publication rules.
- Cache/import contents: only Godot generates them.

## Remaining
None for the agreed menu and ink-absorption scope.

## Validation
- Native Godot 4.7.2 Compatibility: interface flow 61 checks passed at 1920x1080 and 960x640.
- Native stamp/ink flow: 54 checks passed; headless focused ink run: 52 passed.
- Covers menu clicks, modal blocking, disabled/enabled Continue, save resume, actual stamping,
  delayed result entrance, next-article absorption, pause/resume and interruption by fresh/restored ink.
- Menu and partly/fully absorbed ink screenshots visually reviewed; changed code and diff reviewed.
- Logs: %TEMP%/disinfo-menu-interface.log, disinfo-menu-compact.log, disinfo-ink-native.log.
- Captures: %TEMP%/disinfo-ux-menu.png, disinfo-ux-menu-saved.png, disinfo-ux-menu-compact.png,
  disinfo-stamp-ink-absorbing.png and disinfo-stamp-next-article.png.
- Checked the completed working-tree feature stage before its commit; no full MVP suite or export.

## Known issues / uncertainties
- Background crops at non-16:9 aspect ratios; buttons remain fitted and the heroine stays visible.
- No helper/test process continues writing; existing user Godot editor remains open.

## Git state
- Workspace C:/Users/User/Desktop/gdg/DisinfoJam; local branch elfat.
- Last successful push/base: 0fe67cb at origin/elfat.
- This snapshot is from the validated feature stage before the menu/ink commit.
- The following feature commit is the first Codex commit since that push; push only after three.
- Keep the unrelated working-tree edit to Scenes/newsroom_screen.tscn out of that commit.
