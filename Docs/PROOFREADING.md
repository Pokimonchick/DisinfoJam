# Proofreading and desk pencil

Proofreading unlocks on shift 3 (`NewsroomBalance.proofreading_unlock_day`). The first lesson guarantees one typo when the source contains a suitable word; later articles receive 0-2 seeded typos. `ProofreadingState` keeps the original `source_text` and a separate `display_text`: corruption swaps adjacent letters in lowercase Cyrillic words of at least five characters. Capitalized names, abbreviations and numbers are excluded. Starting qualification is 70; reaching zero after unlock triggers dismissal.

## Scene integration and tuning

`newsroom_screen.gd` creates `Canvas/World/Proofreading`, `Pencil` and `UndoStroke` at runtime. The surface covers the 1920x1080 desk; only `SourceText` is judged. Its `mouse_filter = IGNORE` preserves desk GUI interactions.

- In `Scenes/newsroom_screen.tscn`, select the root and adjust **Pencil Rest Position** (`pencil_rest_position`, default `(800, 940)`) and **Source Ink Material** (`source_ink_material`). The material controls source/mark reveal and absorption and is duplicated per screen.
- `Scenes/desk_pencil.tscn` is editable directly: `Render/ModelRoot` contains the muted red hexagonal barrel, exposed wood and graphite meshes; `Render/Camera`, `Render/Sun` and `Shadow` control presentation. The 550x130 control uses its own 3D SubViewport and works with Compatibility.
- The root screen gates `pencil.enabled` using the session unlock flag, blocks `interaction_enabled` during stamp use/modals, and freezes tools through the existing interface lock on pause. Tool signals `picked_up`, `returned` and `interaction_changed` support mutual exclusion and parallax control.

```gdscript
proofreading_surface.bind(%SourceText, session.proofreading)
pencil.set_surface(proofreading_surface)
pencil.input_exclusions.assign([undo_stroke, %SourceText.get_v_scroll_bar()])
undo_stroke.pressed.connect(proofreading_surface.undo_last)
```

Bind when displaying/restoring an article, rather than on every HUD refresh. `bind()` assigns `display_text`, cancels an unfinished stroke and rebuilds geometry. `clear()` detaches the view while retaining the state object. `changed` requests session save/update through the screen.

## Input and scoring

Click the pencil to pick it up; moving the pointer carries its tip without holding a button. Hold LMB to draw, release to finish a stroke, and use RMB to finish the mark and return the pencil. **Отменить штрих** removes the last entire stroke. `input_exclusions: Array[Control]` passes native LMB clicks, drag motion and release to Undo and the source scrollbar while the pencil is held. Mouse-wheel scrolling also passes through. Scrolling finishes an active stroke; blocking/canceling the tool discards an unfinished stroke and preserves completed ones.

Each typo's target has 2.1 times its width and height (4.41 times its area). Crossing a correct word's central band accumulates a wrong mark after at least 35% of its width, with a 12px minimum; incidental touches and blank-space scribbles do not count. A stroke crossing a correct word only rewards a nearby typo if it also intersects that typo's actual bounds. Corrections and wrong-word penalties are deduplicated. Undo recalculates the result from remaining strokes.

`settlement()` returns `{corrected, missed, wrong, money, qualification}` and the session applies it once at actual stamp contact:

| Publication outcome | Money | Qualification |
| --- | ---: | ---: |
| Corrected typo | +2 | +1 |
| Missed typo | -1 | -3 |
| Incorrectly marked word | -1 | -1 |

Combo does not scale proofreading amounts. The result note shows **Вычитка** and qualification changes. The financial notebook records **Исправления при вычитке** separately from publication income, with **Пропущенные опечатки** and **Неверные пометки** under expenses. Rent continues to use the existing `NewsroomBalance.rent` and shift-end transaction.

## Native text geometry

Godot 4.7.2 RichTextLabel has no `get_character_bounds`. Geometry uses its `get_line_range`, `get_line_offset`, `get_line_height` and `get_line_width`, then shapes each line with the same font/size using `TextLine` and `TextServer.shaped_text_get_selection`. The cache rebuilds on bind, resize or theme changes; it does not scan characters each frame. The final virtual paragraph separator is clamped to the actual text length. This supports the existing plain, left-aligned source text without BBCode. References: [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html), [TextServer](https://docs.godotengine.org/en/stable/classes/class_textserver.html).

## State and saves

`to_data()` produces a version-1 primitive dictionary containing `article_id`, `source_text`, `display_text`, `seed`, `targets` and `strokes`. `restore()` requires `validate_data()` and restores existing typos rather than generating new ones. Session/save integration preserves an unfinished article's generated text and marks at home and into the next shift. Live publication feedback retains source scroll and marks; the next article receives its own state.

- Target: `{id: start, start, length, original, typo}`. Offsets count characters, not bytes.
- Stroke: `{segments, corrected: [target_id], wrong: [word_start]}`.
- Segment: `{anchor: "desk" | "text", points: [[x, y], ...]}`. Desk coordinates are normalized by surface size. Text segments also store `character` (line start); x is normalized by label width and y is the offset from that line's top in line-height units.

Text segments follow the actual scrollbar and clip to the visible source. Blank desk segments remain fixed. Mixed strokes share boundary points, save as one stroke and undo atomically. No nodes, resources or Vector2 values are serialized. Limits: 300 strokes per article and 6000 points per stroke.

## Focused checks

- `Tests/proofreading_tests.gd`: deterministic corruption, deduplication, settlement, undo, JSON validation/restore, native word geometry, scrolling, mixed-stroke continuity, pickup and GUI exclusions.
- `Tests/pencil_desk_integration_tests.gd`: actual third-shift scene, rendered pencil, drawing/Undo/RMB, stamp exclusion, pause/modal lock, home continuation and publication settlement without resetting live source scroll.

Run a selected suite with `godot --headless --path . --script res://Tests/proofreading_tests.gd`. For native inspection, omit `--headless` and add `--rendering-method gl_compatibility -- --capture`. Captures go to TEMP (`disinfo-proofreading.png` or `disinfo-pencil-desk-*.png`). Tests use isolated save slots and do not access the player's campaign file.
