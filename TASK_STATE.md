# Task State

## Status
Completed

## Current task
Contextual rebalance of all 32 articles / 96 headlines, including stronger false-sensation penalties, loyalty costs for truthful criticism, money and combo consequences. Complete five shifts covering the whole queue and provide a reusable authoring table. The prior UI/tutorial/finance milestone is already complete in 3a3240f.

## Context
- Five untimed shifts; unfinished shuffled articles continue next day and headline positions remain shuffled.
- One recovery cycle means one work shift before home. Exact recovery in any shuffled queue is not required; reasonable play must be viable with some difficulty.
- Publication costs 4 stamina or 2 at reputation >=75. First coffee is free; coffee restores up to 20; sleep up to 10; loyalty >=75 grants up to 10 once at shift start.
- Actual local resource starts at 30 stamina; the class default remains 80. Manual Data/mvp_balance.tres was preserved. Reports explicitly state their starting values.

## Already done
- False sensational claims now lose 6–20 reputation and 3–11 loyalty before combo, with contextual explanations; loss of loyalty is weaker, roughly half rather than a fixed formula.
- Truthful critical coverage improves reader trust but lowers loyalty. Support for authorities and some facts positive for the state restore loyalty; neutral private facts normally leave it unchanged.
- Honest emotional/sensational headlines and accurate official responses retain positive reputation. Editorial type defines combo, not truthfulness.
- Publication income coefficient changed 0.45 -> 0.35 in Scripts/newsroom_balance.gd. Base cash, source/headline text, IDs, types, prices, stamina rules and combo rules are preserved.
- Loyalty help was shortened to fit and describes the new tradeoff.
- Known original and previously softened authored effects migrate for future choices only. Past results, money and ledger remain unchanged; manual/generated edits are preserved. Unknown future article IDs/variants are skipped safely.
- Docs/BALANCE.md explains contextual profiles, same-shift recovery, combos and economy. Docs/BALANCE_TABLE.md contains all 96 choices including base cash, payouts/effects at x1 and x2, and reasons.
- Docs/BALANCE_RUNS.md gives 12 shuffled queues, five strategies, 30/60 active seconds per material, income coefficient comparison and seed 42 daily results / all 32 publications.
- Tests/balance_playthrough.gd regenerates the reports with --report; --ui additionally uses real selection/publication/result/purchase/bed handlers and an isolated save slot.
- Native mixed campaign seed 42 completed 7/7/6/6/6 articles. End cash 44, stamina 34, reputation 100, loyalty 61. All 32 articles published once.

## Decisions
- Loyalty is general government attitude to the newspaper; factual criticism is not automatically welcomed by authorities. Do not restore loyalty on all facts.
- Moderate damage can be recovered within a shift using appropriate topics; compensation is not promised for every queue, especially critical facts and long negative combos.
- Both choice presentations, restored 8-bit home, prior spotlight teaching, warning, dialogue back and home-only notebook remain.
- Final boss portrait is still an accepted future asset. No solar-ray or dust edits.
- Use focused checks; no full 450+ suite or export. Helpers completed; none continue writing.

## Relevant files
- Data/article_catalog.gd; Data/community_articles.gd; Data/legacy_article_balance.gd.
- Scripts/newsroom_balance.gd; Scripts/stat_descriptions.gd; Scripts/newsroom_session.gd.
- Docs/BALANCE.md; Docs/BALANCE_TABLE.md; Docs/BALANCE_RUNS.md; Data/ARTICLE_BALANCE_NOTES.md; MVP_README.md; Docs/SAVES.md.
- Tests/balance_playthrough.gd; Tests/article_balance_tests.gd; Tests/interface_flow_tests.gd; Tests/mvp_tests.gd --effects.

## Do not touch
- Preserve manual Data/mvp_balance.tres, Scenes/desk_coffee.tscn Swirl bounds, headline_card/headline_choice_overlay/newsroom_screen geometry/assets, Scripts/desk_sunlight.gd, Shaders/desk_sunlight.gdshader, export_presets.cfg and untracked artist sources / unrelated UIDs.
- Do not rewrite actual campaign/settings saves during checks.
- Push only elfat -> origin/elfat after three new Codex commits. No force push, no artificial threshold commits.

## Remaining
- No implementation remains in this scope. Await player feedback or newly authored articles; then use the balance guide and regenerate the reports.

## Validation
- Final numerical data: 12 seeds x five strategies x two reading tempos x three income coefficients, using actual session rules. Truthful and cautious mixed strategies complete all 32 articles in 12/12 queues at both tempos with coefficient 0.35.
- Mixed winning cash: 44..97 at 30 seconds, 1..50 at 60 seconds; temporary debt is allowed. Pure false sensations, maximizing loyalty without trust, and fixed two false sensations daily fail.
- Native Godot 4.7.2 Compatibility five-day campaign: 54 checks pass, with real screens and isolated saves. Day totals match simulation; home and finale captures inspected.
- Final headless report regeneration: 10 checks pass. Article effects/migrations: 153 pass after final migration guards. Combo/endings integration: 46 pass. Native interface/save/teaching/finance integration: 49 pass.
- Report-generator coefficient coverage and loyalty wording received minor final edits after the native run; headless final regeneration and source review cover them. No gameplay behavior was changed after the native campaign.
- Source diffs reviewed; diff hygiene passes. No full suite or export. No actual player save was written; all QA processes finished.
- QA files: C:/Users/User/AppData/Local/Temp/disinfo-balance-*.log, disinfo-balance-day-1..5.png, disinfo-article-final.log, disinfo-effects-final.log, disinfo-interface-balance-final.log.

## Known issues / uncertainties
- Policies use known effects and economical purchases. They demonstrate viable paths, not guaranteed survival for arbitrary choices, extra active reading time or spending. Human playtesting is still needed to judge comfort/difficulty.
- Only the actual starting-30 resource was used for these reported runs; changes to the resource require regeneration.
- Existing unchanged note_shadow.gdshader can emit a headless-only compiler diagnostic when render scenes load; native Compatibility checks have no shader errors. This task did not alter shadows.

## Git state
- Workspace C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat.
- Before this coherent balance commit: HEAD and origin/elfat are 3a3240f. No outgoing commits; this milestone makes one of three since the successful push.
- Intended files are the balance data/scripts, three new Docs/BALANCE* files, report/test changes, documentation and this replacement of the dangerously stale prior snapshot.
- Unrelated manual files listed above remain dirty and excluded. Recorded pre-commit hashes/counts are not live Git state; verify before later commits/pushes.
