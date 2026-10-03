# Task State

## Status
Completed

## Current task
Guided work/home tutorials, low-stamina warning, dialogue back navigation, meaningful inline stat help, household transaction feedback and a home-only finance notebook; audit and soften all authored headline penalties. All requested behavior is implemented and focused checks pass. This replaces the obsolete completed dust-task snapshot.

## Context
- Five untimed shifts; continuing shuffled article queue and shuffled headline options remain.
- Both classic/backdrop headline-choice presentations remain editable/selectable; restored 8-bit home design remains.
- Publication costs 4 stamina, or 2 at reputation >=75; coffee restores up to 20 and the first cup is free; loyalty >=75 restores up to 10 once at shift start.
- Integer stamina display and passive drain of 1/15 per second are included with this feature milestone; the rate is not shown in the game UI.

## Already done
- Boss explains the actual desk controls with a spotlight and dimmed surroundings, including a demonstration of the real headline notes and combo display. The final step points to “Сдать выпуск”.
- First evening uses the same spotlight system with Nikola's portrait and inner monologue. Both stages have back/skip buttons, pause gameplay and save their current step/completion.
- Boss portrait is an existing placeholder. The user confirmed that the final portrait does not exist yet; assign it later on Tutorial > Boss Portrait in the inspector.
- Warning at stamina <=10 appears once per shift, after publication feedback has closed. Dismiss/Esc continues work; the other button finishes the shift. Reading the warning pauses passive drain.
- Narrative dialogue has a Back button; rereading does not replay gameplay effects.
- All three stat questions sit beside their meters and explain purpose, influences, zero-stat endings and dynamic bonuses. Bonus captions remain below the meters.
- Rent, meal, snack and coffee expenses emit a brief red deduction below the home balance. Rent is queued until arrival; loading never repeats the animation or cash mutation.
- FinanceLedger records cash mutations and publication categories. The notebook lies next to the home coffee cup and opens only when clicked; Today/All days show expenses, income by category, best categories and detailed transactions. Esc closes it.
- Saves include optional finances/guidance/warning state. Legacy saves import known publications and mark missing expenses as incomplete; history and balance are not reconstructed speculatively.
- All 32 articles/96 headlines audited. Base penalties cap at -12 reputation/-10 loyalty; nonpolitical state effects removed. Archive accusation is now -12/-10 instead of -37/-30 because it fabricates a crime and accuses officials. Money, texts, types and combo rules preserved.
- Exact known original article effects migrate for future options only. Past results and manual/generated article edits are preserved.
- MVP_README.md and Docs/SAVES.md describe the new behavior and compatibility.

## Decisions
- Notebook exists only at home and never opens automatically, including during teaching; underlying interactions are blocked by modals.
- No fabricated final boss artwork; his exported portrait can be assigned when supplied.
- Preserve the user's manual visual tuning. Solar-ray work was explicitly ended and must not resume.
- Focused checks only; no repeated full 450+ check suite or export for this change.

## Relevant files
- Data/interface_lessons.gd; Scenes/interaction_tutorial.tscn; Scripts/interaction_tutorial.gd; Scenes/mvp_game.tscn; Scripts/mvp_game.gd.
- Scripts/newsroom_session.gd; Scripts/newsroom_save_data.gd; Scripts/finance_ledger.gd; Scripts/finance_notebook.gd; Scenes/finance_notebook.tscn; Scripts/money_delta.gd.
- Scenes/home_screen.tscn; Scripts/home_screen.gd; Scripts/pixel_room.gd; Scripts/stat_descriptions.gd; newsroom_hud/work_status_drawer/stat_benefit_hint scenes and scripts.
- Data/article_catalog.gd; Data/community_articles.gd; Data/legacy_article_balance.gd; Tests/article_balance_tests.gd; Tests/finance_ledger_tests.gd; Tests/interface_flow_tests.gd; Tests/save_tests.gd; Tests/mvp_tests.gd --effects.
- MVP_README.md; Docs/SAVES.md.

## Do not touch
- Preserve manual Data/mvp_balance.tres, coffee Swirl bounds, headline_card/headline_choice_overlay/newsroom_screen geometry and assets, Sunlight tuning, export_presets.cfg and untracked artist sources.
- Scripts/desk_sunlight.gd and Shaders/desk_sunlight.gdshader have preexisting user tuning. Unrelated script/shader UIDs remain uncommitted.
- Preserve both choice presentations, restored home design and existing sunlit dust b203303.
- Push only elfat to origin/elfat after three new Codex commits; inspect outgoing commits, never force-push or make extra threshold commits.

## Remaining
- No implementation remains in the agreed scope. Await feedback/new requests; final boss portrait is a future asset, explicitly accepted as unavailable now.

## Validation
- Checked final working implementation before the feature commit; source/staged diffs reviewed and diff hygiene passed.
- Native Godot 4.7.2 Compatibility: 49 interface-flow checks pass at normal window size and at 960x640, including every spotlight, save/resume, input blocking, warning, notebook and cash feedback.
- Native captures inspected: work choices/stats/coffee, home lessons/bed, warning and notebook fit the screen and have readable text.
- Save suite: 56 checks pass; article balance/migration: 106 checks pass; combo/endings integration: 46 checks pass via --effects. Finance ledger checks and both stat scene bindings also pass.
- Temporary QA is under C:/Users/User/AppData/Local/Temp/disinfo-ux-*.png, disinfo-interface-render.log, disinfo-interface-compact.log, disinfo-ux-save-tests.log, disinfo-effects-tests.log and article_balance_check.log.
- No actual campaign/settings save was written. QA processes and all three helpers finished; none continue writing.
- No full campaign playthrough, full project suite or export was run.

## Known issues / uncertainties
- Headless save runs report an existing native shader compiler diagnostic in unchanged note_shadow.gdshader (TEXTURE passed into a helper sampler). Native Compatibility render runs pass with no shader errors and correct shadows; this unrelated headless-only diagnostic was not changed.
- Balance is a contextual numerical pass; further playtesting may tune the campaign economy. Combo multipliers still amplify effects by design.

## Git state
- Workspace C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat.
- At snapshot preparation: HEAD 07ff898 (article balance); prior b203303 (dust); origin/elfat c0931ba. This snapshot accompanies the validated UI/finance feature commit.
- Dust plus balance are two Codex commits since the last push. The pending coherent UI/finance commit makes three and triggers the authorized push to origin/elfat.
- Stage only intended feature files. Manual/unrelated files listed under Do not touch stay dirty; the snapshot is not permission to revert them.
- Verify current Git rather than treating the recorded pre-commit hash or push count as live state.
