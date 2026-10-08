# Desk publication stamp

The stamp replaces the publication button. Click its handle with the left mouse
button, move the cursor over the article body, then click again to print.
Releasing the first click keeps the stamp attached to the cursor.
The full seal must fit within that area and avoid the headline and visible cup.
A faint preview and darker field corners appear at valid positions.
Consequences apply once at the end of the downward stroke, using the existing
`NewsroomSession.publish_headline()` rules. The result note waits until the stamp
returns to rest, waits for the configured `Result Delay Seconds`, and approaches over 0.7 seconds
with smooth acceleration and deceleration. Passive stamina loss stays paused
through this wait and the result. Pausing also pauses the pending result delay.
Closing the note fades the whole paper while it returns to its origin; publication
acknowledgement and the next article wait until that motion finishes.
When the result closes and the next article appears, the old red ink gradually
diffuses and absorbs into the paper. The previous source/title stay in place and
fade using that exact absorption progress; then the next source fades in.
Headline selection is blocked until the old source disappears. Pause freezes
both the text and ink. Opening a live result keeps the source's reading position.
A new imprint cancels any remaining absorption; new runs and loading clear it
immediately, while a restored publication result shows fresh ink.

Clicking elsewhere returns the stamp without publishing. Right click cancels a
held stamp. Pause, interface locks, loss of window focus, and leaving the desk
cancel an unfinished stroke. Picking up the stamp stops desk parallax.
Choosing a headline and reading a result prevent further stamping.

## Scene and Inspector controls

- `Scenes/newsroom_screen.tscn`, `Canvas/World/Stamp`: resting position. It sits to
  the right of the article, above the coffee, outside the source text.
- `Canvas/World/StampArea`: article body. Move or resize it in the 2D editor.
  Its bounds include the left paper margin below the headline, rather than just
  the central text column. A seal must still fit fully inside the paper body.
  `Imprint Size` (224 x 224 by default, including the PNG's transparent margins)
  approximates the round base's visible diameter. `Imprint Angle Degrees` sets the seal
  footprint. `Excluded Controls` reject overlap with the cup and headline even
  if the print area is moved. The full rotated footprint is checked.
  `Absorption Seconds` (0.8 by default) controls the old seal's disappearance
  when advancing to the next article; zero makes it immediate.
- `Assets/Desk/stamp_approved.png`: the supplied red mouse seal. `stamp_ink.gdshader`
  removes its neutral paper background during drawing and multiplies only the
  red ink over the existing article; the original PNG is preserved.
  Preview and imprint have separate local materials. The imprint's shader
  parameters `Absorption Spread Pixels` and `Absorption Grain` adjust subtle
  edge diffusion and paper pores without adding a background.
- `Scenes/desk_stamp.tscn`: transparent 640 x 640 3D render, camera and warm light.
  `Model Scene` accepts a replacement `PackedScene` with its underside at local
  `y = 0`; the initial model is `Scenes/desk_stamp_model.tscn`.
- `Light Direction Degrees`, `Light Energy`: match the object's light to the desk.
  Existing sunlight and dust settings are independent and unchanged.
- `Camera Height`, `Field Of View`, `Perspective Strength`, `Perspective Center`:
  near-overhead perspective similar to the coffee cup. Moving the stamp adjusts
  its view slightly while keeping the base contact fixed under the mouse offset.
- `Grab Rect`: elliptical clickable handle/body region in local 2D coordinates.
- `Lift Height`, `Lift Tilt Degrees`, `Strike Seconds`, `Return Seconds`: motion.
- `Scenes/newsroom_screen.tscn` root, `Result Delay Seconds`: wait after returning.
- `Canvas/DeskFocus`, `Opening Seconds` / `Closing Seconds`: result note entrance
  and fade-out duration (0.7 / 0.45 seconds initially).
- Newsroom root, `Source Reveal Seconds`: new article text fade (0.45 seconds).
  Source text stays readable while the first spotlight lesson freezes the desk.
- `Shadow Strength`, `Shadow Offset`: soft silhouette shadow, shared with the
  existing note-shadow shader. It expands when the stamp is lifted.
- `Impact Sound`, `Impact Volume Db`: optional authored audio, routed through the
  shared SFX manager and volume settings. An empty sound uses a short synthesized
  wooden thud; no new audio file is required.

The 3D scene renders during movement and once at rest. Editor preview remains
live for model and light adjustment. Movement is tracked in desk coordinates,
so cursor contact accounts for UI scaling, rotation and parallax.

The stamp is presentation, not a new gameplay resource. Drag positions and
animations are not saved. Continuing a published result shows a centred seal;
the existing result, selected headline, money and stats remain authoritative.

## Focused checks

`Tests/desk_stamp_tests.gd` checks real mouse-event two-click pickup/printing, transformed paper
bounds, preview, modal and pause cancellation, publication at contact and
duplicate protection, result timing, pause/resume during the wait and ink
absorption, and cancellation of old ink animations by new stamps and restores.
Run with `-- --capture` under the native Compatibility
renderer to inspect the 3D render and save desk/drag/result/ink images into `%TEMP%`.
