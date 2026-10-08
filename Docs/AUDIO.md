# Audio

`AudioManager` is a single autoload of `Scenes/audio_manager.tscn`. Do not
instantiate additional managers in gameplay scenes. Music and SFX use separate
buses from `Data/audio_bus_layout.tres`, configured by
`audio/buses/default_bus_layout`; Master remains the final output. The manager
creates missing Music/SFX buses before routing players, so settings also work
when an editor session has not yet loaded the configured layout.

## Add a sound to a scene

1. Instance `Scenes/audio_cue.tscn` as a child, or inherit it for a reusable cue.
2. Assign an MP3, OGG or WAV to **Stream** in the Inspector.
3. Choose **Category**: SFX for effects, MUSIC for background tracks.
4. Adjust **Volume Db**, SFX **Pitch Scale**, and music **Loop Music** as needed.
5. Call the node's `play()` from the relevant interaction or connect a signal
   such as `Button.pressed` to it. **Autoplay** plays once when the node is ready,
   regardless of visibility; leave it off for hidden screens and interactions.

Scene cues contain only configuration. Players are shared by the manager:
two music players for crossfades and a fixed SFX pool, initially eight voices.
Effects can overlap. When all voices are occupied, a pool voice is reused.
No player is created per click or note, and audio resources are reused.

The same API is available directly:

```gdscript
AudioManager.play_music(track, -2.0, true)
AudioManager.play_sfx(effect, 0.0, 1.0)
AudioManager.stop_music() # fade out
AudioManager.stop_sfx()  # stop all effects
```

MP3 and OGG music loops use duplicated streams so imported resources are not
modified. Existing WAV loop points are preserved; streams without native looping
restart on completion. Re-requesting the same track does not reset playback.

## Current integration

- `Scenes/mvp_game.tscn` has `Audio/WorkMusic` and `Audio/HomeMusic` cue instances.
  Their streams and per-track gains can be changed in the Inspector.
  `Scripts/mvp_game.gd` uses WorkMusic for the desk, menu, new-story confirmation
  and dialogue screens. Pause, settings and publication results keep the current
  track playing without restarting it. Home uses HomeMusic; endings fade music
  out. Replace the cue streams later when individual scenes have their own tracks.
- `Scripts/newsroom_screen.gd` exposes **Audio / Headline Appear Sound** and
  **Headline Appear Volume Db** on the newsroom root. An animated note plays
  `paper - Part_1.wav` at its own tween delay (0, 0.055, 0.11 seconds). Cancelling the tween
  cancels pending sounds; restoring or rearranging visible choices is silent.
- The manager root exposes **Sfx Voice Count**, **Crossfade Seconds**,
  **Music Gain Db** and **Sfx Gain Db**. These are authoring values: initial
  music/SFX bus gains are 0/-8 dB before player volume settings. At 100% music
  volume, a cue with 0 dB gain plays at the source track's original level.

## Player settings

The shared settings panel has Music and SFX sliders from 0 to 100 percent.
Changes affect both active and future sounds; zero mutes the respective bus.
Values live in `GameSettings` and persist as `audio/music_volume` and
`audio/sfx_volume` in `user://settings.cfg`, separately from campaign saves.
Rapid changes are coalesced for 0.25 seconds; closing settings or quitting
flushes pending changes. New campaigns keep the player's audio preferences.

## Dialogue blips

`Scripts/dialogue_reveal.gd` on `NarrativeBody` and the tutorial's `Explanation`
uses the same SFX pool and player volume setting. `Heroine Voice` and `Boss Voice`
are replaceable streams in the Inspector, with `Voice Volume Db` and
`Pitch Variation` controls. The initial WAVs are original synthesized placeholders:
soft/high for Nicola, lower/drier for the boss. They are not borrowed game samples.

Letters and digits trigger a blip; spaces and punctuation remain silent. A slow
frame plays at most one blip instead of a catch-up burst. Pausing stops the text
and subsequent blips; hiding/skipping cancels the current reveal. No audio players
are allocated per character. The tiny mono PCM16 assets have smooth attack/release
envelopes and can be replaced with recorded character sounds later.
