# Editorial UI direction

The story takes place in Bripolis around the 1990s. The home now uses the supplied
Tamagotchi room art, day/night backgrounds and Nicola's animated sprite layers.
Keep the analog mood: newspaper cutouts, stationery, printed dots, ink, worn
paper and restrained warm accents. Avoid introducing mid-century props or
modern touchscreen styling in new art.

## References and palette

Use Persona 5's angled title strips, strong focus states and layered composition
as references. Keep Coco News's own art, readable Russian typography and colors;
do not import Persona assets. Examples reviewed: the
[official game gallery](https://www.playstation.com/en-us/games/persona-5-royal/)
and the [configuration screen](https://volx.jp/persona-5-royal-keyboard-controller-setting).

| Role | Color |
| --- | --- |
| Paper and light text | `#f4e6bf` |
| Ink and dark title strips | `#273533` |
| Primary action and paper backing | `#a53e35` |
| Hover/focus accent | `#e8bd68` |
| Portrait background | Dark muted teal |

## Current implementation

- `Scripts/game_fonts.gd` defines Alegreya Sans Regular for body text, Alegreya
  Sans Bold for emphasis and Ysabeau Bold for headings. The editorial theme and
  new home panels share these fonts; keep Cyrillic text readable at scene sizes.
- `Data/editorial_ui_theme.tres` supplies native button, checkbox and slider
  states plus `EditorialBanner`, `EditorialPortrait` and `EditorialPrimary` variants.
- `Scripts/editorial_card.gd` draws the paper frame; native containers own layout
  and controls retain their normal mouse/keyboard behavior.
- The desk balance uses a compact brown card with a gold border, fitting below
  qualification. Positive cash is green, debt is red, and the amount shows its
  sign. Pencil meter strokes use doubled thickness without changing their length
  or gameplay values.
- Settings, pause and new-story confirmation reuse `Shaders/pause_blur.gdshader` with
  a `BackBufferCopy` before the backdrop. Keep the menu visible below the new-story
  overlay and keep focus inside each modal.
- The narrative screen uses the supplied room background and a cream bottom
  dialogue frame with a speaker name. Boss portraits and portrait placeholders
  have been removed. Long story pages split into short fragments; Back/Next/Skip
  retain their story roles and the current fragment is saved.
- Heroine/boss dialogue and guided explanations use `DialogueReveal`: letters
  appear with small character blips, punctuation pauses and a short entry delay.
  The first Next click completes the text; the second advances. Pause/settings
  freeze the reveal. Ending summaries appear immediately.
  The voices remain the previous synthesized short blips from
  `dialogue_heroine.wav` and `dialogue_boss.wav`, rather than full spoken lines.
- Article source/title text fade in on a new article or when the desk becomes
  visible. Restoring a publication result does not replay that fade. The result
  note fades and returns over `DeskFocus.closing_seconds`; acknowledgement runs
  only after it closes. The old source/title fade with the stamp's absorption
  progress before being replaced by the next article, which then fades in.
  Live results retain the source scrollbar position; a new article starts at the top.
- `Scenes/home_screen.tscn`, `Scripts/home_screen.gd`, `Scripts/tamagotchi_room.gd`
  and `Scripts/tamagotchi_panels.gd` provide the evening room, shop, backpack and
  heroine information. Clicking the fish opens the backpack; using fish food
  produces a brief visual response without introducing hunger or pet-stat meters.
  Purchases enter the backpack first and cannot create debt. Drinks cost 12 $
  and restore up to 15 stamina when used; noodles cost 24 $ and restore up to 30;
  fish food costs 5 $ and changes no player stats. Item data lives in
  `Data/home_items.gd`.
- The next-shift action changes the room to its night presentation for 3.2 seconds
  (`night_seconds` on Home). Room interactions and panels close during this
  transition; pause/settings freeze playback. Stamina recovery occurs once when
  the session starts the next shift.
- Tune node sizes, spacing, heading colors and fonts in the scenes. Common colors
  and control states live in the theme; blur values live in each scene's material.
