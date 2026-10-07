# Audio revision 3: rewritten score, three-cue pilot

7 October 2026. Follows the [revision 2 handoff](AUDIO_REWORK_OPUS_5_5_HANDOFF.md), where the
Owner was not convinced and asked for further soundtrack revisions. As that handoff
recommends, this is a **small pilot for listening before anything else is rendered**: three
cues (title, sorrow, Sola). It is not an approved soundtrack, and nothing in the game changed.

## What was actually wrong

Revisions 1 and 2 shared one score generator. Revision 2 fixed note lengths, so the gaps
between notes went away, but the score underneath was never changed. Measuring the score
itself (no audio needed) shows three faults:

| Measure (all 28 cues) | Revision 2 | Revision 3 |
| --- | --- | --- |
| Beat-length melody notes a semitone against the harmony | about 14% (one in seven) | 0.5%, in one harp cue (Rook) |
| Distinct phrases in the three-minute title cue | 2 | 13 |
| Off-beat marimba notes in the title cue | 192 | 0 |

- **The melody ignored the harmony.** Each cue cycled a fixed eight-note motif against a
  separate eight-chord loop, so the tune regularly sat a semitone or a minor ninth against the
  strings. This is most likely much of what sounded "unconvincing".
- **The tune hardly developed.** The motif repeated every four bars for the whole cue.
- **Constant mallet ticks.** Most lyrical cues had a marimba note on every off-beat, through the
  hall reverb. This is the likeliest source of the "triangle" complaint. Revision 2 made it
  quieter and lower but kept it.
- All harmony moved in parallel blocks and re-attacked every bar, with no phrase-level dynamics.

## What revision 3 does

The new composer is `tools/art/audio_rework/compose.py`; `produce.py --revision 3` uses it.
Revision 2 still renders exactly as before with `--revision 2`.

- **Harmony first.** Eight-bar phrases: the first half ends on a half cadence, the second
  half on a full cadence. Sections run intro, A, A, B, A, with a turnaround that leads back
  to the start for looping cues.
- **Melody over the harmony.** Each cue's original motif contour is kept as scale steps.
  Every strong-beat or beat-length note lands on a chord tone, and the motif's direction
  is kept. Short notes off the chord move by step. Cadences land on the root.
- **Development.** The motif is restated a step higher. The B section has its own
  longer-note theme, given to a different instrument. Returning A sections add a violin
  octave doubling, a counter-melody (cello, or horn in the heroic cues) and woodwind answers
  at phrase ends.
- **Voice-led strings.** Each string voice moves to the nearest note of the next chord and
  holds common tones, instead of moving in parallel blocks.
- **Dynamics.** Sections grow (quiet first statement, fuller returns) and each four-bar phrase
  has a gentle swell. Velocities stay in the soft and middle sample layers, and gain curves
  carry the crescendo. The loudest layer switches at velocity 85 and is about 15 dB louder,
  which caused sudden jumps.
- **Balance by role.** Each part is rendered separately and levelled by role (tune, harmony,
  counter-melody, colour) before the mix, so the melody always leads.
- **No mallet ticking.** A soft harp figure colours the B sections instead. Marimba remains
  only in the playful cue. Timpani mark section arrivals only.

## Owner feedback on the first pilot render

- **"Weird random cut at the start" of the title.** Real, not the player. Like revision 2,
  the mixer pasted each looping cue's ring-out and reverb over its opening, so a first play
  began on the dying final chord with no fade-in. Revision 3 no longer does this: notes in
  a looping cue's last bar end inside the file, and the last 0.35 s fade out.
- **Sola's theme "wonky" and "too similar to title".** Both were in D major over the same
  progression and form. Sola is now in F major with its own chords (I IV ii V, vi ii V I),
  a dotted, inquisitive rhythm, a bassoon counter-line and flute answers. Quick notes are
  now lightly detached instead of overlapped: without recorded legato, overlapping quick
  notes smeared into double attacks. Weak-beat notes may now pass by step instead of being
  forced onto chord tones, which had flattened the motif into repeated Fs and Cs.

## Listen

Generated audio is not committed (`reports/` is ignored). Reproduce with the commands below,
or use the files shared with this pilot:

- `reports/audio_rework_r3/R2_vs_R3_Pilot.mp3`: for each cue, revision 2, a one-second gap,
  then revision 3 of the same passage, matched in loudness. Timecodes are in
  `R2_vs_R3_Pilot_Timecodes.json`.
- `reports/audio_rework_r3/<cue>_R3.mp3`: the full-length revision 3 cues.

## Limits

- **Not artistically verified.** The numbers above confirm the faults are gone. They do not
  show that the result sounds convincing. Only the Owner's listening can decide that.
- **Same sample bank.** VSCO 2 CE and Salamander have no recorded legato transitions. If the
  Owner still hears the instruments themselves as fake, the next step is better samples or
  a DAW workflow, not more score work.
- **Same hall reverb.** The synthetic hall from revisions 1 and 2 is unchanged.
- **Three cues only.** The composer covers all 28 cues; the other 25 are not rendered or reviewed.
- SFX are unchanged from revision 1.

## Reproduce

The libraries are fetched as described in the handoff. In this session the GitHub API was
unavailable, so the two pinned repositories were cloned at their pinned commits (VSCO 2 CE as a
sparse checkout), and `prepare_libraries.py` was run over those files.

```sh
python3 tools/art/audio_rework/prepare_libraries.py
python3 tools/art/audio_rework/produce.py --revision 3 --out reports/audio_rework_r3 --only mus_title mood_sorrow theme_sola
python3 tools/art/audio_rework/produce.py --revision 2 --out reports/audio_rework_phrasing --only mus_title mood_sorrow theme_sola
python3 tools/art/audio_rework/build_r3_comparison.py
```
