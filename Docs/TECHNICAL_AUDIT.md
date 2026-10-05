# Technical audit — 2026-10-05

Scope: runtime scripts, scene wiring, content, save/load paths, audio, UI effects,
shaders, asset references, export configuration and the existing test/tooling setup.
This is a source audit with focused runtime checks, not a claim of zero technical
debt or a benchmark of every asset and supported device.

## Changes

| Area | Concrete issue | Resolution |
| --- | --- | --- |
| Pencil meters | Assigning an unchanged ink color redrew all three meters during every stamina tick. | Redraw only when the color changes; value/resize redraws remain. |
| Home room | Hundreds of drawing commands were rebuilt every visible frame although artwork changes in discrete steam/bob states. | Redraw on those state transitions, hover and the existing inventory/resize updates. |
| Tutorial | The dimming/highlight canvas was redrawn even with fixed geometry. | Redraw when the highlight, viewport size or dim opacity changes; continue tracking moving targets. |
| HUD and drawer | Repeated identical color/style overrides notified the theme machinery during every state update. | Apply overrides only when colors differ. |
| Dust | Unchanged light parameters were copied to the material every frame, including while the desk was hidden. | Cache forwarded values, update visible effects only and stop zero-count particle layers. Live light parameters are still read each visible frame. |
| Fatigue | Hidden overlay received material updates. | Keep effect timing/state but skip hidden material writes. |
| Note shadows | Passing built-in `TEXTURE` as a function sampler triggered a native shader compiler error. | Sample in `fragment()` and pass alpha to the bounds helper. Preserve blur weights, offsets and all authored parameters. |
| Save writing | Writer could replace a valid save with a file larger than the reader's 32 MiB limit. | Validate UTF-8 byte size before touching any save files and write the same encoded buffer. |
| Save validation | Legacy finance history, optional result stamina cost and presentation fields could reach conversions without sufficient type/range checks. | Reject malformed inputs before state mutation/file replacement; keep older optional defaults and integral JSON floats compatible. |
| Content migration | Updating recognized legacy effects also overwrote manually edited explanations. | Preserve nonempty explanations; fill only missing text. |
| Pencil tracing | Unused tracing nodes/script remained instantiated after the effect was disabled. | Remove the mechanism at the user's request, including references and script UID. |

## Architecture retained

- `NewsroomSession` owns gameplay; balance/resources and article catalog own data.
  Queue shuffling is linear, current-article access is constant-time, and scene
  transitions/purchases do not need a new framework.
- `SaveRepository` keeps validated atomic writes, backup recovery, explicit
  migrations and unknown extension fields. Legacy timer fields remain for save
  compatibility; they do not restore the removed timer mechanic.
- `AudioManager` keeps two music players, a bounded SFX pool, interrupted-fade
  handling and separate buses. Settings writes are already debounced.
- Existing note/result/hover tweens cancel earlier animation and guard delayed
  completion. Notebook summaries run when opened, not every frame.
- Scene geometry, article effects, inspector settings, prices, stamina rules,
  existing artwork and the two note presentation modes retain their current
  behavior. User edits outside the audit are not part of the audit commit.

## Validation

- `Tests/save_tests.gd`: **110 checks, 0 failures**. Regression cases cover size
  rejection without altering primary/backup/temp files, invalid restore without
  state mutation, presentation validation and migration of manual explanations.
- `Tests/interface_flow_tests.gd -- --compact`: **49 checks, 0 failures**,
  including tutorial placement, modal interaction and home/notebook transitions.
- Native OpenGL Compatibility smoke on Intel UHD, 1280 × 720: both note modes,
  pause blur and home captured and reviewed. Dust parameter propagation,
  animation, zero count and hidden-desk suspension also passed. No script/shader
  errors in that rendered run.
- Godot imported the new paper WAV through its native importer after the first
  integration run found the absent import. No cache files were edited manually.
- Changed source and final diff reviewed. Full gameplay/balance simulation,
  release export, FPS/VRAM benchmarking and other-device checks were not run.

## Observed engine limitation

Godot 4.7.2 can retain an `AudioStreamMP3` and `AudioStreamPlaybackMP3` pair when
a native player is started and stopped immediately in the same frame. A minimal
native-player reproduction, without the manager, confirmed this with both Dummy
and WASAPI; a 0.1 s interval did not reproduce it. The save harness reports two
such pairs at shutdown despite passing all checks. Separate manager transition
probes and the rendered smoke completed without the warning. Do not add an
unproven manager workaround or hide this warning by weakening tests.

## Future changes

- Extend the existing data/save/audio interfaces before introducing replacement
  systems. Validate new persisted fields before applying them.
- Keep rendering driven by actual visual changes, without suppressing fractional
  gameplay state signals or breaking inspector updates.
- Profile on a target device before changing shader quality, texture sizes,
  source-art packaging or export filters. Existing original art and inactive
  prototype components were not deleted merely because they are unused today.
