# Task State

## Status
Active

## Current task
Implement approved Bripolis chains, fifty finite articles, organic ink transitions,
and third-shift proofreading pencil with qualification and tutorials.
Latest correction: no mandatory publication minimum; finish any shift freely.

## Context
- Godot4.7.2 Compatibility, five-shift Russian campaign, 1990s anthropomorphic city.
- Cats govern Bripolis; user-authored stories are the prose reference.
- Preserve both headline layouts, existing balance, 8-bit home and solar/dust tuning.

## Already done
- Eighteen new articles plus original32; exact archive of eight user sources.
- Three chain definitions and exact-choice source variants; one of each headline type.
- Finite queue, early chains and next-shift promotion after carried draft, with separators.
- Session/save integration: choices, typo copy, marks, qualification, single settlement.
- Legacy queue migration extends saved materials, preserves manual source bodies.
- 3D red pencil, freehand surface, scroll-bound strokes, atomic Undo; runtime desk wiring.
- Fourth HUD stat, compact colored balance and aligned title/value rows.
- Organic source/stamp shaders and two-press result opening/closing behavior.
- Pencil episode after shift2, natural lessons, shift3 mini tutorial incl.oldsave migration.
- Separate proofreading income/penalties in the home financial notebook.

## Decisions
- Exactly three current editorial types; additional types remain deferred.
- At least one separating article; only follow-up source text varies by exact choice.
- Correction+2$/+1 qualification; miss-1$/-3; wrongword-1$/-1; no combo on these.
- Qualification starts70, unlocks shift3; zero dismisses the employee.
- Blank marks harmless; unfinished materials/marks survive home and reload.
- Undo button is temporary eraser; separate3D eraser remains deferred.
- Keep user's result delay0.5 and current solar/coffee settings.

## Relevant files
- Data/article_catalog.gd, community_articles.gd, bripolis_articles.gd, story_chains.gd.
- Docs/OriginalArticles/community_articles_original.gd, BRIPOLIS_CONTENT.md, PROOFREADING.md.
- Scripts/article_sequence.gd, newsroom_session.gd, newsroom_save_data.gd.
- Scripts/desk_pencil.gd, proofreading_state.gd, proofreading_surface.gd.
- Scripts/newsroom_screen.gd, desk_focus.gd, stamp_area.gd; Scenes/desk_pencil.tscn.
- Shaders/source_ink.gdshader, stamp_ink.gdshader; Data/source_ink.tres.
- Scripts/mvp_game.gd, Data/chapter_one.gd, interface_lessons.gd; bothHUDscenes/scripts.
- Tests/story_sequence_tests.gd, proofreading_tests.gd, pencil_desk_integration_tests.gd,
  pencil_story_flow_tests.gd, ink_focus_hud_tests.gd.

## Do not touch
- User edits in Scenes/newsroom_screen.tscn, export_presets.cfg and outputs/.
- Solar/dust/coffee tuning, player save slot and authored global balance.
- Generated .godot/import cache; only Godot may update it.

## Remaining
- Review integrated source/stamp fades and update affected existing assertions.
- Run affected save/finance/stamp checks; repair concrete failures.
- Update existing project/save/stamp docs; inspect final diff and intended staging.
- Commit meaningful validated units; push only thirdnewCodexcommit fromelfat.

## Validation
- Native editor import0, new class_names registered, stderrclean.
- Root story sequence320 checks0fail:128seed queues, variants, migration, settlement, exhaustion.
- Proofreading subsystem81 checks, headless/native; pencil screenshot reviewed.
- Storyguidance34 checks, ink/HUD22 nativechecks; stderrclean.
- Pencil desk25 headless/26 nativechecks, threecaptures reviewed.
- Existing save/finance/stamp affected checks pending; nofullsuite/export.

## Known issues / uncertainties
- Helpers finishEnglishnewdocs only; root owns remaining integration/review/commits.
- Source geometry assumes plain left-aligned text without BBCode.
- Already-published legacy order cannot be retroactively changed.

## Git state
- Workspace C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat; base91c6d14 origin/elfat.
- No new Codexcommits since lastpush yet; feature work uncommitted.
- Keep user scene/export edits and outputs/ out of feature commits.
