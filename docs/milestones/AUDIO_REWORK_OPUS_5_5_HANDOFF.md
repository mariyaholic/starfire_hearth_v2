# Soundtrack revision handoff for Opus 5.5

7 October 2026. Prepared by Codex for the next soundtrack review.

**Owner status: further soundtrack revisions requested. The owner remains unconvinced after revision 2; the soundtrack is not artistically approved.** This is a written handoff, not an assignment to or communication with another model.

## Owner direction and feedback

The intended finish is richer, convincing orchestral “wall of sound” music, replacing the current eerie procedural sound, with clearer SFX tones. The owner requested free production tools with believable recorded instruments, including piano, and before/after comparisons covering every existing music and SFX file.

After the first orchestral pass, the owner said the arrangement sounded nice but identified notes releasing too early during transitions, leaving “weird dead air in between notes for all instruments.” They also said “the triangle is a bit obnoxious here” and requested a replacement for its effect.

After hearing the phrasing revision, the owner said:

> Not that convinced - kindly make a note to that for Opus 5.5, write what you did, what you used, and note that I'm asking for further revisions with the soundtracks.

Treat this as a request for further artistic revision, not approval following successful technical tests. The exact cue/instrument perceived as the triangle was not confirmed. Latest revision feedback targets the soundtracks; SFX approval has not been established either.

## What was done

### First orchestral rendition (R1)

- Inventoried the delivered manifest and produced all **84 before/after pairs: 28 music cues and 56 SFX/ambience files**, including every variant. Each version contains approximately 53 minutes 16 seconds of full-length audio.
- Wrote new arrangements/recompositions for existing cue roles, retaining filenames and durations. These are not note-for-note transcriptions or simple remasters. Music uses shared motifs, distinct cue/character parts, harmonic progressions, sections, velocity/timing variation, stereo placement and shared hall processing.
- Rendered **172 sampled instrumental parts** using recorded piano and orchestral instruments. Rook's plucked role uses harp; no recorded guitar library was installed.
- Designed the SFX individually using sampled transients and custom tone/noise/FM layers: interface feedback, material impacts, shields/scans, travel/destruction and room ambience. Vael textures are nonverbal; no character dialogue was invented.
- Built full-length listening indexes, browser A/B players, embedded single-file players, comparison reels, score/MIDI exports, credits and a review ZIP. Original game recordings were copied byte-for-byte for comparison. Listening levels are matched by attenuation.

### Phrasing and softer accents (R2)

- Re-rendered all **28 music cues**, producing **175 active sampled parts**. All 56 R1 SFX/ambience proposals were retained byte-identically.
- Extended sustained harmony through bar boundaries, added instrument-dependent overlap at note transitions, tied repeated pitches and placed brief wind breaths with ensemble support. Piano gained finger legato and sustain-pedal changes at harmonic boundaries; harp/mallet releases allow more natural decay.
- Fixed overlapping same-pitch MIDI note lifetimes with reference-counted note-offs. The offline sfizz renderer discards channel identity, so channel separation alone did not prevent premature release.
- Fixed per-pitch SFZ velocity coverage. R1 maps left **418 scored events** without matching sample regions: 127 horn, 276 flute and 15 bassoon. All 14 custom maps now cover their declared pitch/velocity ranges, and actual scored notes select sample regions.
- Added full-RAM offline sample loading and a separate wrapper for the unchanged upstream piano mapping. A pilot dry-track dropout prompted this mitigation; a streaming root cause was not conclusively established.
- Fingerprinted music cache inputs, including phrasing code and mappings, to prevent stale renders after changes.
- Replaced high glock-style leads in Attention, Speaker and Answer with lower clarinet and softer marimba. Changed repeating high harp-colour accents elsewhere to quieter marimba an octave lower. Retained distinct harp roles such as Rook and beacon. This was an interpretation of the triangle complaint, not a confirmed identification or an owner-approved replacement.

## What was actually used

| Tool or source | Actual use |
| --- | --- |
| **sfizz 1.2.3** | User-local CMake/Ninja build, JACK disabled; offline MIDI-to-SFZ sample rendering. Executable: `/workspace/.starfire-setup/audio-tools/bin/sfizz_render`. |
| **Salamander Grand Piano v3**, Alexander Holm | Full upstream velocity-layered recorded piano, CC BY 3.0. Source pin `3382bf9496bba2486f5ab0de55a264d1dfc38404`; attribution, license and modifications documented. |
| **VSCO 2 Community Edition**, Versilian Studios/Sam Gossner/contributors | CC0 recorded strings, brass, woodwinds, harp, mallets and percussion. Source pin `440300901dfe9275fd84e0b7763af1f8443ae62e`. Custom SFZ maps, prepared sustain loops and separate prepared sample copies; upstream recordings preserved. |
| **Python: NumPy, SciPy, SoundFile, Mido** | Programmatic composition/MIDI, sample preparation, SFX synthesis, mixing, hall processing and validation. Venv: `/workspace/.starfire-setup/audio-tools/venv/`. |
| **FFmpeg / FFprobe** | OGG/WAV/AAC/MP3 exports, duration/codec inspection, loudness and true-peak measurement. |
| **Playwright / Chromium** | Browser listening-player checks in desktop and phone-sized touch layouts. |

Libraries/maps and provenance live under `/workspace/.starfire-setup/audio-libraries/`. **No DAW was used.** Ardour, Audacity, Surge XT, Decent Sampler and BBC Symphony Orchestra Discover were researched but were not installed or used for these renditions. The initial [tool research](AUDIO_REWORK_TOOL_RESEARCH.md) predates the subsequent full library preparation.

The stock sfizz intermediate stems are **16-bit PCM**; final mix masters are **24-bit PCM**. Higher final bit depth does not recover intermediate precision. This sample bank has **no recorded interval-legato transitions**; overlaps and ties do not supply those performances.

## Where to listen and inspect

- [R2 five-cue phrasing comparison](../../reports/audio_rework_phrasing/Phrasing_Revision_Comparison.mp3), approximately three minutes: title, sorrow, Sola, Speaker and battle. Here **Before = R1 orchestral pass; After = R2**. This is the revision preview preceding the owner's latest feedback.
- [R2 full listening index](AUDIO_REWORK_PHRASING_LISTENING_INDEX.md), all 84 pairs. Here **Before = original game; After = R2**.
- [R2 all-music comparison reel](../../reports/audio_rework_phrasing/All_Music_Before_After.mp3), original game → R2 excerpts across all 28 cues.
- [R2 technical report and reproduction commands](AUDIO_REWORK_PHRASING_REPORT.md).
- [R1 report](AUDIO_REWORK_AB_REVIEW_REPORT.md) and [R1 full listening index](AUDIO_REWORK_COMPLETE_LISTENING_INDEX.md).
- [Production scripts](../../tools/art/audio_rework/produce.py), [library preparation](../../tools/art/audio_rework/prepare_libraries.py), [phrasing/MIDI implementation](../../tools/art/audio_rework/phrasing.py), [phrasing checks](../../tools/art/audio_rework/verify_phrasing.py) and [attribution](../../tools/art/audio_rework/ATTRIBUTION.txt).

Review outputs are separate: `reports/audio_rework/` for R1 and `reports/audio_rework_phrasing/` for R2. Both contain `scores/`, per-instrument MIDI/renders, `masters/`, original and proposed game-format audio, browser media and verification evidence. Large generated reports are ignored by Git; the handoff links require these workspace artifacts or the exported review package.

## Evidence and limits

R2 passes **334 dry-track phrasing checks**, covering 4,827 held transitions and 202 same-pitch ties: no detected premature note-offs, near-silent holes of at least 50 ms at intended held transitions, or dropouts of at least 100 ms inside long held notes after attack. Sample mapping and piano pedal checks pass. These are threshold-based checks on dry tracks, not a guarantee of convincing performance.

The nine audio/file/codec checks pass, with unchanged original hashes and all 175 active parts present. Encoded music measures −18.25 to −17.93 LUFS; music/ambience true peaks are at or below −1.19 dBTP. All 34 browser checks pass, including all 168 AAC files and embedded playback after networking is disabled. Physical iOS/Android devices were not tested.

**Technical continuity and playback success did not resolve the owner's artistic dissatisfaction.** Do not present passing checks as approval or as evidence that the orchestra now sounds realistic.

## Recommended next revision approach

The owner's explicit request is further soundtrack revisions. The following are recommendations for the next author, not newly approved production stages:

1. Listen critically to the R1/R2 preview and complete cues before changing the score again. Reassess the actual audible transitions and metallic accent; do not assume the previous replacement solved the complaint.
2. Audition musical phrasing, dynamic shaping, expression, ensemble balance, sample attacks/releases and cue individuality. Richness should come from convincing orchestration and performance, with room for melodic clarity and quiet passages. These are review areas, not established diagnoses of the remaining dissatisfaction.
3. If the free sample bank cannot achieve convincing transitions, investigate stronger free articulation sources or a DAW-based performance workflow, verifying availability and licenses before claiming they were used.
4. Present a small, polished pilot with clearly labelled comparisons for owner listening before rendering another complete batch. Retain the original game, R1 and R2 for reference.

Continue in the existing M1 checkout; the owner instructed **no new branch**. No delivered audio, manifest, runtime playback or save behavior was changed for these proposals. No proposed soundtrack has been installed in the game. The handoff, audio reports and authoring scripts are published on the existing `claude/starfire-hearth-build-cs2vb6` branch; generated listening audio and sample libraries are not included in that Git push. This handoff authorizes no further rendering by itself; the current task is to record the work and revision request.
