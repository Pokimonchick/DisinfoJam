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
  `Scripts/mvp_game.gd` selects a cue when entering work or home and fades music
  out for other screens. Pause, settings and publication results keep it playing.
- `Scripts/newsroom_screen.gd` exposes **Audio / Headline Appear Sound** and
  **Headline Appear Volume Db** on the newsroom root. An animated note plays
  `paper - Part_1.wav` at its own tween delay (0, 0.055, 0.11 seconds). Cancelling the tween
  cancels pending sounds; restoring or rearranging visible choices is silent.
- The manager root exposes **Sfx Voice Count**, **Crossfade Seconds**,
  **Music Gain Db** and **Sfx Gain Db**. These are authoring values: initial
  music/SFX bus gains are -12/-8 dB before player volume settings.

## Player settings

The shared settings panel has Music and SFX sliders from 0 to 100 percent.
Changes affect both active and future sounds; zero mutes the respective bus.
Values live in `GameSettings` and persist as `audio/music_volume` and
`audio/sfx_volume` in `user://settings.cfg`, separately from campaign saves.
Rapid changes are coalesced for 0.25 seconds; closing settings or quitting
flushes pending changes. New campaigns keep the player's audio preferences.

This integration was reviewed in source only; no runtime or audio audition
was performed under the user's current no-test instruction.
