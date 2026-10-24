# Complete audio rendition review

7 October 2026. **Every delivered music cue and SFX/ambience variant has a before/after pair: 84 files, comprising 28 music cues and 56 SFX/ambience files.** The original delivered audio and game manifest remain unchanged. No branch, commit, push or runtime audio replacement was made for this review.

## Listen

- [Complete per-cue listening index — all 168 full-length recordings](AUDIO_REWORK_COMPLETE_LISTENING_INDEX.md).
- [Interactive player](../../reports/audio_rework/index.html): search, category filters, full-length playback, A/B switching at the same position, matched listening levels, cue preferences and exported notes.
- [QuickListen single-file player](../../reports/audio_rework/StarfireHearth_Audio_AB_QuickListen.html): approximately 31.4 MiB; every entry, 20-second music excerpts and full effects. Download once; audio is embedded.
- [Complete single-file player](../../reports/audio_rework/StarfireHearth_Audio_AB_Complete.html): approximately 195.9 MiB; all original and new full-length recordings embedded.
- [Every music cue comparison reel](../../reports/audio_rework/All_Music_Before_After.mp3): approximately 19 minutes; before excerpt then after excerpt for each of the 28 cues. [Timecodes](../../reports/audio_rework/Music_Reel_Timecodes.json).
- [Every SFX comparison reel](../../reports/audio_rework/All_SFX_Before_After.mp3): approximately 2 minutes 35 seconds; all 56 effects/ambience files in full, original then new. [Timecodes](../../reports/audio_rework/SFX_Reel_Timecodes.json).
- [Complete review ZIP](../../reports/audio_rework/StarfireHearth_Audio_AB_Review.zip): approximately 279 MiB. Includes original files, new game-format renders, AAC listening copies, scores, editable MIDI parts, credits and technical evidence. Open `index.html` with its media folders or serve the folder for reliable preview seeking. The single-file editions are separate downloads.

Each version contains approximately **53 minutes 16 seconds** of complete audio. Coverage follows `data/asset_manifest.json`, including every three-variant effect, all character themes, all mood pieces, both brief victory/defeat stings, five longer ending cues and the room ambience. Future voice placeholders contain no recordings and are not treated as existing speech assets.

## What changed

The score is a set of **new arrangements/recompositions for the established cue roles**, retaining filenames and durations. It is not a note-for-note transcription or an EQ remaster. It uses recorded Salamander piano and VSCO 2 CE strings, brass, woodwinds, harp, mallets and percussion, rendered through sfizz. There are 172 non-silent recorded instrumental parts across the 28 music cues, with separate musical sections, shared motifs, velocity/timing variations, orchestral positioning and hall processing.

The main title expands piano into strings, harp and horn. Colony music stays warmer and smaller; beacon music moves toward discovery/trade; jump and attention cues retain space and unease; battle uses articulated strings, horns and recorded percussion. Sola features clarinet/bassoon, Varga cello, Brandt horn and snare, Hale a waltz, Speaker glassy mallets/harp and Rook a weathered plucked-harp role. The endings share the home motif with different instrumentation and resolutions. Recorded guitar was not used.

Every SFX has an explicit design rather than a blanket remaster: piano taps and clearer interval patterns for interface decisions, controlled swishes, shorter differentiated material impacts, glass-like shields/scans and stronger low-frequency transit/destruction accents. Variants remain distinct. Vael effects are nonverbal tonal textures; no invented character dialogue is included. The ambience is a quieter continuous ventilation/room bed.

The original files are copied byte-for-byte under `before/`; `after/` contains new OGG/WAV renditions. Native browser AAC/M4A copies allow convenient comparison. Listening-level matching uses attenuation only: integrated loudness for music and RMS for short effects. It can be switched off. Two sparse cues received gentle transient shaping so isolated piano peaks would not make their entire arrangements quieter.

## Validation and limits

[Audio verification](../../reports/audio_rework/verification.json) passes all nine checks: exact manifest coverage; preserved original hashes; unique non-silent finite new signals; intended duration, channels and 48 kHz sample rate; no clipped samples; all sampled stems present; all 168 AAC files correctly encoded; no missing-sample/opcode errors; and suitable loop boundaries. Encoded music measures **−18.28 to −17.95 LUFS**; encoded music/ambience true peaks stay at or below **−1.14 dBTP**. Loop boundary jumps were checked against ordinary sample derivatives; this does not certify subjective musical continuity.

[Browser verification](../../reports/audio_rework/browser_verification.json) passes **34 checks** with no JavaScript errors. Desktop and touch/phone-sized Chromium layouts preserve all filters, notes and controls, A/B position, opening/full-length behavior and paired short effects. All **168 AAC files decode natively** with the intended duration. Both embedded editions play and switch to the original with networking disconnected after loading. Cloud browser policy prevents direct `file://` navigation, so the self-contained editions were loaded through HTTP before disconnecting; physical iOS/Android devices were not tested.

These are objective audio/playback checks and a complete first rendition for listening review. Artistic quality and which renditions enter the game remain review decisions. No runtime or save behavior changed, and the game was not retested for an asset replacement that has not occurred.

## Sources and reproducibility

[Attribution](../../reports/audio_rework/ATTRIBUTION.txt) includes Alexander Holm's Salamander Grand Piano credit, the CC-BY-3.0 license link and modifications, plus VSCO 2 CE CC0 credits and pinned sources. Recorded instrument libraries remain outside the game and are not distributed in the listening ZIP. Intermediate sfizz stems are 16-bit PCM; final mix masters are 24-bit PCM.

The preparation, composition, verification, review builder, range-aware player server and browser check scripts are under `tools/art/audio_rework/`. Run from the repository root:

```sh
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/prepare_libraries.py
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/produce.py --workers 4
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/verify.py
/workspace/.starfire-setup/audio-tools/venv/bin/python tools/art/audio_rework/build_review.py
python3 tools/art/audio_rework/browser_review.py
python3 tools/art/audio_rework/serve_review.py --port 8785
```

Instrument banks/maps, source/sample hashes and the user-local sampler live under `/workspace/.starfire-setup/audio-libraries/` and `/workspace/.starfire-setup/audio-tools/`. Review renders are isolated under `reports/audio_rework/`. The review builder keeps large libraries, executable tooling and intermediate WAV stems out of the ZIP.
