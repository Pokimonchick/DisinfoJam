# Editorial UI direction

The story now takes place around the 1990s. The room concepts are art direction
for the future pixel-art interior, not a request to replace the current room.
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

- `Data/editorial_ui_theme.tres` supplies native button, checkbox and slider
  states plus `EditorialBanner`, `EditorialPortrait` and `EditorialPrimary` variants.
- `Scripts/editorial_card.gd` draws the paper frame; native containers own layout
  and controls retain their normal mouse/keyboard behavior.
- Settings, pause and new-story confirmation reuse `Shaders/pause_blur.gdshader` with
  a `BackBufferCopy` before the backdrop. Keep the menu visible below the new-story
  overlay and keep focus inside each modal.
- The narrative screen uses the existing Nicola portrait only for heroine pages.
  Boss, document and ending illustrations retain their own replaceable visuals.
  Story text remains scrollable, with its existing Back/Next/Skip behavior.
- Heroine/boss dialogue and guided explanations use `DialogueReveal`: letters
  appear with small character blips, punctuation pauses and a short entry delay.
  The first Next click completes the text; the second advances. Pause/settings
  freeze the reveal. Documents and ending summaries appear immediately.
- Article source/title text fade in on a new article or when the desk becomes
  visible. Restoring a publication result does not replay that fade. The result
  note fades and returns over `DeskFocus.closing_seconds`; acknowledgement runs
  only after it closes, then the next article fades in.
- Tune node sizes, spacing, heading colors and fonts in the scenes. Common colors
  and control states live in the theme; blur values live in each scene's material.
