# Audio revision 2 — held phrasing and softer accents

**Latest owner feedback, 7 October 2026:** the owner remains unconvinced and requests further soundtrack revisions. This rendition is not artistically approved. See the [Opus 5.5 handoff](AUDIO_REWORK_OPUS_5_5_HANDOFF.md) for work performed, tools used and the requested follow-up.

7 October 2026. **All 28 music cues are re-rendered with connected phrasing and repaired sample maps.** The 56 existing SFX/ambience comparisons are retained. The original game audio and first orchestral review remain intact; this revision is a separate listening proposal under `reports/audio_rework_phrasing/`.

## Listen

- [First orchestral rendition → corrected rendition comparison](../../reports/audio_rework_phrasing/Phrasing_Revision_Comparison.mp3), approximately three minutes. Each cue plays the earlier orchestral excerpt, a short gap, then revision 2. Order: title at 0:00, sorrow at 0:37, Sola at 1:06, Speaker at 1:43, battle at 2:20. [Exact timecodes](../../reports/audio_rework_phrasing/Phrasing_Comparison_Timecodes.json).
- [Complete full-length listening index](AUDIO_REWORK_PHRASING_LISTENING_INDEX.md): all 84 pairs. Here **Before** is the original game recording and **After** is revision 2.
- [Quick-listen player](../../reports/audio_rework_phrasing/StarfireHearth_Audio_AB_QuickListen.html): every entry, music excerpts and full SFX, embedded in one file.
- [Full-length player](../../reports/audio_rework_phrasing/StarfireHearth_Audio_AB_Complete.html): all original and revised recordings embedded.
- [Complete review package](../../reports/audio_rework_phrasing/StarfireHearth_Audio_AB_Review.zip): game-format files, browser listening copies, scores/MIDI, credits, comparison reel and verification evidence.
- [All 28 music cues — original game → revision 2 excerpts](../../reports/audio_rework_phrasing/All_Music_Before_After.mp3).

## Cause and correction

The first score used fixed short melody gates, shortened bar-length sustain gates and no piano pedal. Sustained notes were released before the next note or harmony could carry the line. Short SFZ release envelopes also cut plucked/struck resonance early.

The instrument maps had a second defect: velocity layers were allocated using the instrument-wide set of layers even when a particular pitch had fewer recorded layers. Those pitches had unplayable volume ranges. The pre-fix map snapshot leaves **418 events in the first score without a matching sample region**: 127 horn, 276 flute and 15 bassoon events. This was a map defect; the recorded sample files were present. [Coverage comparison](../../reports/audio_rework_phrasing/sample_map_coverage_comparison.json).

The revised score holds harmony through bar boundaries, overlaps sustained transitions and ties repeated pitches within the same voice. Wind lines have brief phrase breaths carried by the ensemble. Piano has sustain-pedal changes at harmonic boundaries and finger legato in its melody; harp/mallet releases now allow their recorded natural decay. Separate voice identities keep violin harmony strands distinct. MIDI note-offs are reference-counted because sfizz's CLI discards channel identity; an older overlapping same-pitch note can no longer release a pitch that another voice still needs.

SFZ velocity ranges are now allocated per pitch, and all 14 custom instrument maps cover their entire declared note/volume range. Offline maps fully preload samples into RAM. The piano uses a separate RAM-loading wrapper around the unchanged upstream Salamander instrument. Music cache entries record a fingerprint of the score generator, phrasing implementation and instrument mappings, so instrument revisions cannot silently reuse an older render.

The prominent metallic music lead has been replaced with **lower-register clarinet and soft marimba** in Attention, Speaker and Answer. Repeating high colour accents elsewhere now use quieter, lower-register marimba instead of the bright upper-register plucked line. Harp remains where it has a distinct melody/accompaniment role, such as Rook and beacon music. The main motif and cue roles remain recognizable across the revision.

## Validation

[Dry-track phrasing verification](../../reports/audio_rework_phrasing/phrasing_verification.json) passes **334 checks** across all 28 cues, including **4,827 held transitions and 202 same-pitch ties**. There are no premature MIDI note-offs, no detected near-silent holes of at least 50 ms at held transitions, and no detected 100 ms dropouts inside long held notes after their initial attack. Every scored custom-instrument note selects a valid sample region. Piano parts contain pedal sustain and pedal lifts. These checks inspect dry rendered instrument tracks rather than a reverb-covered final mix.

[Audio verification](../../reports/audio_rework_phrasing/verification.json) passes all nine file/signal/codec checks. All 84 comparisons preserve the intended coverage, channels, duration and 48 kHz sample rate, and all original hashes still match the game assets. All **175 sampled instrumental parts** render non-silently. Encoded music measures **−18.25 to −17.93 LUFS**; music/ambience true peaks are at or below **−1.19 dBTP**. Browser AAC files retain their full durations; loop discontinuities remain within the technical boundary check.

[Browser verification](../../reports/audio_rework_phrasing/browser_verification.json) passes **34 checks** with no JavaScript errors in desktop and touch/phone-sized Chromium layouts. All 168 AAC recordings decode with their intended duration. Both embedded players work with networking disconnected after loading, including A/B switching. Physical iOS/Android devices were not tested. The builder labels this set as revision 2; the listening index distinguishes original-game comparisons from first-orchestral-pass comparisons.

These are technical continuity checks, not a claim of final artistic approval. This sample bank has no recorded interval-legato transitions; the correction uses held/overlapping sampled sustains, ties and natural releases. The listening reel is the basis for assessing the musical result.

## Reproduce

From the repository root:

```sh
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/prepare_libraries.py
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/produce.py --out reports/audio_rework_phrasing --workers 3
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/verify_phrasing.py
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/verify.py --out reports/audio_rework_phrasing
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/build_phrasing_comparison.py
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/build_review.py --out reports/audio_rework_phrasing
python3 tools/art/audio_rework/browser_review.py --out reports/audio_rework_phrasing
python3 tools/art/audio_rework/serve_review.py --out reports/audio_rework_phrasing --port 8786
```

Credits and modification details are included in `ATTRIBUTION.txt`. There are no game-code, save, runtime-audio or delivered-asset changes for this review, and no new branch was created.
