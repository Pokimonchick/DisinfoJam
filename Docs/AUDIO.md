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
One additional persistent SFX player loops the currently used desk tool; dialogue
and clicks cannot steal it. No player is created per click, glyph or mouse motion.

The same API is available directly:

```gdscript
AudioManager.play_music(track, -2.0, true)
AudioManager.play_sfx(effect, 0.0, 1.0)
AudioManager.play_cue(AudioManager.Cue.UI_CLICK)
AudioManager.start_sfx_loop(self, friction, 14.0)
AudioManager.stop_sfx_loop(self) # only this owner's loop
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
  `Бумага перелистывание.wav` at its own tween delay (0, 0.055, 0.11 seconds). Cancelling the tween
  cancels pending sounds; restoring or rearranging visible choices is silent.
- The manager root exposes **Sfx Voice Count**, **Crossfade Seconds**,
  **Music Gain Db** and **Sfx Gain Db**. These are authoring values: initial
  music/SFX bus gains are 0/-8 dB before player volume settings. At 100% music
  volume, a cue with 0 dB gain plays at the source track's original level.

### Recorded MVP effects

Ten supplied WAV effects in `Assets/Sounds` are connected. The supplied voices
remain available as alternatives; the user preferred the previous synthesized
character blips. Common short
effects and their relative gains live in `AudioManager.CUE_STREAMS` and
`CUE_GAINS_DB`; individual stamp, tool friction and voice gains remain exposed
in their scripts' Inspector groups. Original source files are preserved.

| File | Trigger |
| --- | --- |
| `UI щелчок.wav` | Menu, pause, settings, tutorial, headline choice and home buttons; volume-slider drag completion |
| `Бумага перелистывание.wav` | Headline notes, accepted source page turns, opening result notes and financial notebook, changing notebook tabs |
| `Бумага падение.wav` | Closing headline/result notes and the financial notebook |
| `Предмет взять.wav` | Accepted stamp, pencil or eraser pickup |
| `Предмет положить.wav` | Completion of animated tool return, including right-click return |
| `Карандаш.wav` | Loop while LMB moves the pencil over valid article paper |
| `Ластик.wav` | Loop while LMB moves the eraser over valid article paper |
| `Штамп.wav` | Successful imprint at impact, before proofreading assessment |
| `Глоток кофе.wav` | Successful coffee consumption, never rejected consumption |
| `Предупреждение.wav` | Low-stamina warning or rejected stamp/coffee action; at most once per 0.75 seconds |
| `dialogue_heroine.wav` | Heroine letters during dialogue/tutorial reveal; retained at user request |
| `dialogue_boss.wav` | Boss letters during dialogue/tutorial reveal; retained at user request |

`bind_ui_buttons()` connects once per button. The cup and source page arrows
are excluded from generic clicks because they have physical action sounds.
Newly opened notebook buttons are bound explicitly.

Friction stops on release, off-paper motion, a stationary pointer (after 0.1 s),
page/modal locks, tool return, focus loss, pause, hiding or removal. Only one
prepared loop stream per supplied friction asset is cached; imported resources
are never modified. A hidden or disabled owner cannot leave a loop playing.
Muting SFX also stops the loop; music retains its independent routing.

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
`Pitch Variation` controls. Defaults retain the original synthesized
`dialogue_heroine.wav` and `dialogue_boss.wav` at the user's request.
`Голос Николы.wav` and `Голос Босса.wav` remain unused alternatives.

Letters and digits trigger a blip; spaces and punctuation remain silent. A slow
frame plays at most one blip instead of a catch-up burst. Pausing stops the text
and subsequent blips; hiding/skipping cancels the current reveal. No audio players
are allocated per character. The original short blips use soft/high tones for
Nicola and lower/drier tones for the boss; no full spoken dialogue is played.
