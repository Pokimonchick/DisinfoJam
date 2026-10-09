# Proofreading and desk pencil

Proofreading unlocks on shift 3 (`NewsroomBalance.proofreading_unlock_day`). The first lesson guarantees one typo when the source contains a suitable word; later articles receive 0-2 seeded typos. `ProofreadingState` keeps the original `source_text` and a separate `display_text`: corruption swaps adjacent letters in lowercase Cyrillic words of at least five characters. Capitalized names, abbreviations and numbers are excluded. Starting qualification is 70; reaching zero after unlock triggers dismissal.

## Scene integration and tuning

`newsroom_screen.gd` creates `Canvas/World/Proofreading`, `Pencil` and `Eraser` at runtime. Only `SourceText` is judged. Writing is clipped to the rotated rectangular article body (`StampArea`), outside the headline. Ink can pass beneath the coffee and page controls; their higher layers cover it. Page controls still receive clicks before drawing. Marks use z-index 4, below the seal and desk objects. The surface's `mouse_filter = IGNORE` preserves desk GUI interactions. Tools remain visible while choosing a headline, with their interaction disabled. Page navigation uses the same reveal/absorption material as source text.

- The screen root exposes **Pencil Rest Position** `(800, 940)`, **Eraser Rest Position** `(600, 940)` to the pencil's left and **Source Ink Material**. The screen and brush each duplicate this material; reveal, absorption, origin and clock updates reach both copies. Brush grain therefore leaves source glyphs unchanged.
- `ProofreadingSurface` exposes **Pencil Color** (dense red), **Line Width**, **Grain Strength** and **Grain Scale**. The shader leaves small dry pigment gaps using static paper coordinates, so the texture moves with the marks without flickering over time. Existing saved points render with the current brush; scoring and erasure use their unchanged geometry.
- `Scenes/desk_pencil.tscn` uses detailed native meshes with a beveled six-sided red barrel, smooth sharpened wood, red pigment core, ribbed aluminum ferrule and a rounded cream rear eraser. The ferrule and rear eraser are two-thirds of their original length; the wooden barrel compensates, preserving total length and drawing point. **Rest Tilt Degrees** `(0, -18, 0)` brings the rear end toward the player without moving the desk anchor; **Lift Tilt Degrees** `(0, 55, 35)` controls the working pose. Returning the tool restores the resting angle. The rear eraser is visual; proofreading uses the separate tool on the left.
- `Assets/Desk/pencil_lacquer.png` is the photographic lacquer albedo, generated using the built-in imagegen tool; its exact prompt is preserved in the adjacent `.prompt.txt`. Godot's 3D importer enables mipmaps and VRAM compression; commit the asset's import settings alongside the PNG. `Shaders/worn_pencil.gdshader` combines it with sparse chips, softened facet edges and shallow tooth dents. `Shaders/pencil_wood.gdshader` rounds the sharpening from the hexagonal barrel into the core, adds lengthwise wood fibers and six scallops along the paint boundary. `Shaders/pencil_ferrule.gdshader` supplies rings and tooth dents with matching smooth normals and aluminum reflections. Lighting still matches the desk stamp; pencil and separate eraser use z-index 9 beneath the desk shadows. The square viewport leaves room for pickup rotation and the contact point stays under the pointer.
- `Scenes/desk_eraser.tscn` uses the supplied model, converted with Blender to `Assets/Models/eraser.glb`. The original `C:/Users/User/Downloads/eraser.blend` was not modified. Its 144px image is 80% of the original size. **Model Contact** targets the free nose, rather than the grip center; **Erase Radius** defaults to 18 desk pixels. Z-index 9 places it below the desk shadows. Both tools reuse the same pickup, projection and input code with **Tool Mode** selecting pencil or eraser.
- The screen unlocks both tools on shift 3, allows only one held tool, blocks them during stamp use/modals, and freezes them through the existing interface lock on pause. Resting viewports update once; held and returning tools render continuously.

```gdscript
proofreading_surface.bind(%SourceText, session.proofreading, source_pager.character_offset)
pencil.set_surface(proofreading_surface)
pencil.input_exclusions.assign([eraser, source_pager])
eraser.set_surface(proofreading_surface)
eraser.input_exclusions.assign([pencil, source_pager])
```

Bind when displaying/restoring an article, rather than on every HUD refresh. The two-argument `bind()` assigns `display_text`; with a page offset it keeps the pager's visible slice and maps geometry back to full-source characters. Binding cancels an unfinished stroke and rebuilds geometry. `clear()` detaches the view while retaining the state object. `changed` requests session save/update through the screen. Pagination is described in [ARTICLE_PAGES.md](ARTICLE_PAGES.md).

## Input and scoring

Click a tool to pick it up; moving the pointer carries its contact point without holding a button. Hold LMB to draw/erase and release to finish. RMB returns the tool. The eraser replaces the Undo button: its circular nose sweeps one capsule per mouse movement, splits intersected polylines and preserves untouched parts. Drawing and erasure edit geometry only; one save/update signal is emitted at the end of an erasing gesture. Page controls remain usable while holding either tool. Turning a page finishes the active gesture and briefly blocks writing/erasing. Pause/modals return the tools; completed marks remain.

Recognition begins only at stamp contact. `ProofreadingEvaluation` measures every marked sheet in a hidden label, indexes word bounds in 64px cells and evaluates the remaining segments in frame-sized portions. **Proofreading Budget Ms** on the screen defaults to 2ms; it is a soft budget checked between operations. The visible reading page stays unchanged. While the job runs, writing, paging and publication actions are locked and stamina does not drain; pause also pauses recognition. Leaving the desk cancels the job, preserving an unpublished draft. No partial awards or classifications enter the save.

Each typo's target has 2.1 times its width and height (4.41 times its area). Crossing a correct word's central band accumulates a wrong mark after at least 35% of its width, with a 12px minimum; incidental touches and blank-space scribbles do not count. A stroke crossing a correct word only rewards a nearby typo if it also intersects that typo's actual bounds. Corrections and wrong-word penalties are deduplicated across strokes and pages.

`settlement()` returns `{corrected, missed, wrong, money, qualification}` and the session applies it once after the stamp's recognition job completes:

| Publication outcome | Money | Qualification |
| --- | ---: | ---: |
| Corrected typo | +2 | +1 |
| Missed typo | -1 | -3 |
| Incorrectly marked word | -1 | -1 |

Combo does not scale proofreading amounts. The result note shows **Вычитка** and qualification changes. The financial notebook records **Исправления при вычитке** separately from publication income, with **Пропущенные опечатки** and **Неверные пометки** under expenses. Rent continues to use the existing `NewsroomBalance.rent` and shift-end transaction.

All proofreading deductions of one article share a cap: 20 money and 20 qualification by default. Correction rewards are applied separately. `NewsroomBalance.proofreading_money_penalty_limit` and `proofreading_qualification_penalty_limit` expose independent settings in `Data/mvp_balance.tres`. The ledger allocates the capped money expense to missed typos first, then incorrect marks, and records the actual debit. Publication/headline penalties are separate. Old published results remain unchanged; the cap applies to future publications.

RMB uses `DeskPencil.return_to_rest()` or the stamp's existing return path to animate placement, tilt and camera together. `return_seconds` controls duration (pencil/eraser 0.34s, stamp 0.32s). Tools cannot be picked up during return; desk parallax stays frozen until placement finishes. Immediate `cancel_interaction()` remains available for scene changes, pause, focus loss and modals.

## Native text geometry

Godot 4.7.2 RichTextLabel has no `get_character_bounds`. Geometry uses its `get_line_range`, `get_line_offset`, `get_line_height` and `get_line_width`, then shapes each line with the same font/size using `TextLine` and `TextServer.shaped_text_get_selection`. The cache rebuilds on bind, resize or theme changes; it does not scan characters each frame. The final virtual paragraph separator is clamped to the actual text length. This supports the existing plain, left-aligned source text without BBCode. References: [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html), [TextServer](https://docs.godotengine.org/en/stable/classes/class_textserver.html).

## State and saves

`to_data()` produces a version-1 primitive dictionary containing `article_id`, `source_text`, `display_text`, `seed`, `targets` and `strokes`. `restore()` requires `validate_data()` and restores existing typos rather than generating new ones. Session/save integration preserves an unfinished article's generated text and marks at home and into the next shift. Live publication feedback retains the reading page and marks; the next article receives its own state.

- Target: `{id: start, start, length, original, typo}`. Offsets count characters, not bytes.
- Stroke: `{segments, corrected: [], wrong: [], page_character}`. New marks store geometry without classifications. Legacy cached classifications remain accepted for compatibility but publication computes a fresh result. The optional page anchor is a full-source character offset and survives JSON restore. Legacy strokes without it remain accepted.
- Segment: `{anchor: "desk" | "text", points: [[x, y], ...]}`. Desk coordinates are normalized by surface size. Text segments also store `character` (line start); x is normalized by label width and y is the offset from that line's top in line-height units.

New strokes use fixed normalized coordinates and one page anchor for the entire mark, including blank-paper portions. Turning a page hides the entire mark; returning restores it without shifting fragments relative to the text. Older mixed-anchor strokes are grouped onto their originating sheet and clipped to the paper when drawn. No nodes, resources or Vector2 values are serialized. Limits remain 300 strokes per article and 6000 points per stroke.

## Focused checks

- `Tests/proofreading_tests.gd`: deterministic corruption, deduplication, settlement, state undo, JSON validation/restore, native word geometry, paper/obstacle clipping, swept erasure, recognition across pages, dense-sheet timing, pickup and GUI exclusions.
- `Tests/pencil_desk_integration_tests.gd`: actual desk scene, rendered tools and resting angle, pencil/eraser/RMB pose restoration, brush material isolation and synchronized ink transitions, blank-paper scoring, whole-page marks and GUI navigation, mutual exclusion, pause/modal lock, home continuation, cancelled assessment through menu/Continue and publication settlement without resetting the reading page.

Run a selected suite with `godot --headless --path . --script res://Tests/proofreading_tests.gd`. For native inspection, omit `--headless` and add `--rendering-method gl_compatibility -- --capture`. Captures go to TEMP (`disinfo-proofreading.png` or `disinfo-pencil-desk-*.png`). Tests use isolated save slots and do not access the player's campaign file.
