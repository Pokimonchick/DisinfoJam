# Task State

## Status
Completed

## Current task
Integrate supplied tamagotchi/home art, shop and backpack, short night transition,
paper dialogue presentation, global fonts/cursor/icon and a gentle stamp hint.
Refresh authored articles and add the user's two ginger-cat/coal-dust sources.
Apply the user's UI corrections: supplied home controls, black prologue, original
work tutorial styling, shorter lessons and one two-state Finish Shift button.

## Context
- Godot 4.7.2 Compatibility; Russian five-shift game in anthropomorphic Bripolis.
- User explicitly requested full tamagotchi tests and visual inspection on October 17.
  After the rendered pass, requested urgent completion without additional checks.
- Names follow Никола Коко, господин де Мур and Рататуй; avoid ordinary Russian
  names/patronymics and a forced real-country naming scheme.

## Already done
- Home composes supplied room video, heroine/shadow poses, bed and foreground shelf.
  Supplied animations are baked into small Theora loops; raw full-screen sequences
  are not loaded as animation textures at runtime.
- Six-product shop, details, purchase refusal, stacked backpack and heroine stats.
  Fish food produces a brief aquarium response without a separate needs system.
- A 3.2-second looping night precedes the next shift. Pause/settings freeze it;
  saves retain remaining time, and sleep recovery occurs once at HOME -> WORK.
- Latest decision: restored the actual original cutscene and ending layout from
  c885dde: large editorial card, heroine portrait left, title banner and full text
  right, original action buttons. Boss portrait panel is hidden. No desk behind
  cutscenes. Interactive tutorial keeps its own desk presentation.
- Next/instruction buttons removed; click/Space/Enter continue. Back/Skip have
  equal fixed footer sizes; lessons are concise (11 work / 4 home / 4 pencil).
- New home art: English SLEEP/SHOP, weekdays and DAYS LEFT; cash top left.
  Bubble opens Info/Bag; cash opens ledger. Removed the permanent room notice.
- Full room fits the viewport. Window glint plays once per pointer entry using Overlay
  blend; removed from the looping video. Day contrast/saturation adjusted. Heroine
  matches the room mockup (scale .95), shadow follows feet. Cursor reduced by 1.5.
- Alegreya Sans/Ysabeau throughout and supplied icon (also export presets).
- Finish Shift is one native button: cream normally, yellow on hover, enlarged 1.5x.
- Fixed wrapped-label sizing, rebuilt shop/detail/warning with supplied assets.
  Room buttons hide behind panels; Info/Bag moved to right-side tabs.
- Article data and headline catalog use colons instead of em dashes.
- Fixed JSON-decoded dialogue part_size validation so current saves load.
- Stamp image gently pulses when a headline is selected and stamping is available;
  it stops during carry, return, pause and blocked interactions.
- Rewrote 24 base and 18 additional Codex stories, retaining IDs/types/effects.
  Two new user sources bring the catalog to 52 articles / 156 headlines.
- Added subtle recurring details and a ginger chain; its sources remain fixed,
  so the coal-dust connection is left for the reader to discover.
- Save migration updates only untouched future authored prose, preserving the
  current draft, published results, manual changes and proofreading strokes.
- Supplied sound hooks are integrated; original synthetic dialogue blips retained.
  Earlier requested missed-typo qualification cost is -2; article penalty caps remain.

## Decisions
- Drinks: 12 $ / up to +15 stamina. Noodles: 24 $ / up to +30. Fish food: 5 $.
- Buying adds stock only, including on credit. Consume from the backpack at home; full stamina keeps
  the item. Purchases are allowed on credit again; the existing -100 debt defeat remains.
- Inventory is an authoritative snapshot, replacing the saved dictionary instead
  of recursively merging removed stacks. Counts are known IDs, integers 1..99.
- Old saves default to an empty bag. Story character offsets preserve position
  across short-fragment reflow; legacy fragment indices use their old 300 size.
  Format remains 1;
  content.authored_prose_revision = 2 controls prose/catalog migration.
- Proofreading and its story scene unlock at the beginning of shift 2.

- Starting campaign stamina increased from 30 to 60 in Data/mvp_balance.tres.
- Work stamina drain and publication costs reduced by 1.5, including reputation
  reduction. UI rounds displayed stamina costs and bonuses to whole numbers.
- Ending HUD minimum widths reduced to fit four scales, money and shift; clipped
  header labels cannot force the whole ending layout beyond the viewport.

## Relevant files
- Scenes/home_screen.tscn; Scripts/home_screen.gd, tamagotchi_room.gd,
  tamagotchi_panels.gd; Data/home_items.gd; Docs/TAMAGOTCHI_ASSETS.md.
- Scenes/mvp_game.tscn, interaction_tutorial.tscn; Scripts/mvp_game.gd,
  story_dialogue.gd, interaction_tutorial.gd, game_fonts.gd; Data/interface_lessons.gd.
- Scripts/newsroom_session.gd, newsroom_save_data.gd, finance_ledger.gd; Docs/SAVES.md.
- Data/article_catalog.gd, bripolis_articles.gd, district_letters.gd, story_chains.gd;
  Docs/OriginalArticles/, BRIPOLIS_CONTENT.md, BALANCE_TABLE.md.
- Scripts/desk_stamp.gd, cursor_tooltip.gd; Shaders/stamp_hint.gdshader;
  Scripts/finish_shift_button.gd; Assets/UI/finish_shift_*.png;
  Data/editorial_ui_theme.tres, project.godot, export_presets.cfg.

## Do not touch
- User edits in Scenes/newsroom_screen.tscn, Shaders/pencil_ferrule.gdshader,
  Shaders/worn_pencil.gdshader, export path Build/10 and outputs/.
- Campaign save and unrelated desk lighting/coffee/material tuning.
- Generated caches/import data: only Godot updates them.

## Remaining
No implementation remains in this correction batch. User requested urgent completion
without further test runs. Original cutscene/endings layout restored in source.

## Validation
- State/inventory/controller saves: 235 checks passed.
- Rendered home UI interaction/layout pass: 330 checks passed; root inspected actual
  captures of room, six items, shop, funds warning, Info/Bag, fish, pause and night.
- Story presentation: 67 headless / 69 rendered checks passed at the stage where
  intro was still black; existing pencil story flow: 47 passed.
- Stamp hint: 12 headless / 16 rendered checks passed; visible slow yellow pulse
  confirmed while the 3D viewport stayed cached.
- Final source/diff reviewed. Latest requested intro reversal, button enlargement,
  heroine sizing, punctuation and small panel polish were not rerun after user
  requested urgent completion without extra checks.

- Latest credit, stamina, ending HUD and stronger stamp glow edits: source/diff
  review only, without new test runs under the user's urgency request.

## Known issues / uncertainties
- Final cutscene/endings restoration and small visual changes were inspected in
  source/diff only; do not claim the old temporary story-presentation tests cover them.
- Existing campaigns retain their saved article text; punctuation edit updates the
  authored catalog, without resetting saved proofreading marks or past results.
- Existing unrelated dirty desk/audio test changes remain separate.

## Git state
- Workspace C:/Users/User/Desktop/gdg/DisinfoJam; branch elfat.
- Correction base: 1c0759c. Last successful pushed commit: 6046307.
- Stage the cohesive room/editorial/audio changes only. Preserve unrelated user
  scene/material/export-path work, old test edits, generated source UIDs and outputs/.
- Push elfat -> origin/elfat only after three new Codex commits since last push;
  inspect outgoing commits and never force-push. Consult current Git for final hash.
