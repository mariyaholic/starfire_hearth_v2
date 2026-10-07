# M1.2 Stage E — optional character voice capacity

**Status: implemented and revalidated; no recorded performances are included.** This
stage adds an optional presentation voice path. Dialogue text, event choices and simulation
serialization remain independent of it.

## Implementation

- `app/voice_registry.gd` creates stable presentation cues. Event IDs use
  `event/<story-chain>/<step>` and optional asset IDs use `voice_<story-chain>_<step>`; they are
  derived from story identity rather than mutable prose. Cue metadata retains speaker, localized
  text key, story chain/step, locale, asset ID and delivery status without entering `GameState`.
- `app/voice_service.gd` is an autoload that registers immutable cue metadata, requests an
  optional clip, and reports missing/muted/unavailable/playing/finished states. Repeated requests
  for the same ID are ignored, a new ID replaces the old line, and stop is wired to event-overlay
  dismissal and `Game.session_started` (new game/load). It never calls `SoundSynth` for speech.
- `app/audio.gd` adds a dedicated `Voice` bus and player. Voice volume is independently persisted
  in `Settings` and follows the global mute; headless runs retain lifecycle state without starting
  an audio device. `ui/screens/flow/settings_screen.gd` exposes the volume control.
- `ui/screens/game/event_overlay.gd` requests one presentation cue when the overlay is created,
  records an accessibility/tooling status on the overlay, and stops it before restoring music on
  close. Ordinary UI refreshes do not request the cue again. Body text and choices are unchanged.
- `app/asset_ids.gd` accepts only manifest records of kind `voice` for speech streams and rejects
  missing, non-delivered or malformed resources silently. `tools/import_assets.py` now validates
  optional `voice_*` recordings (44.1/48 kHz, 200–15,000 ms, up to two channels, peak limit and
  loudness warning) and converts them to non-looping Ogg; no generated fallback is registered.
- Added additive `ui.voice.*` localization keys for status/fallback text. Missing localized text
  still returns its key through the existing string fallback, so dialogue remains visible.

## Revalidation evidence

Focused voice tests pass **3 tests / 24 checks / zero failures**:

```text
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd -- --filter test_voice
3 passed, 0 failed, 24 checks
```

The existing audio tests pass **5 tests / 187 checks / zero failures**, including the dedicated
Voice bus, volume and mute path:

```text
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd -- --filter test_audio
5 passed, 0 failed, 187 checks
```

`python3 -m py_compile tools/import_assets.py` passes. The 4 October follow-up repeated
both focused voice/audio runs with the counts above and no failures. The complete
regression suite includes these tests; latest totals and browser evidence are in the
[D–G revalidation report](M1_2_D_G_REVALIDATION_REPORT.md).

This validates the optional capacity and fallback lifecycle. Audible recorded dialogue,
browser speech playback after a user gesture and physical-device audio remain future
checks once actual recordings are delivered.
