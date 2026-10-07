# Free audio production tools — research and cloud proof

7 October 2026. Owner direction: clearer SFX tones and a richer orchestral wall of
sound. This is tool research and an isolated sampler proof. Game audio assets,
manifest, playback code and saves were not changed. No branch was created.

## Recommended production setup

Use a sampler playing recorded instruments for the score. Compose distinct strings,
brass, woodwinds, piano and percussion parts; render stems and mix them with a coherent
hall space. Broad orchestration and expressive performance produce the density. Keep
melody, rhythmic attacks and quiet sections clear rather than making every passage
uniformly loud. Sci-fi synthesis can remain a restrained supporting layer.

| Tool/library | Purpose | Free route and practical fit |
| --- | --- | --- |
| [Ardour](https://ardour.org/) | Multitrack MIDI composition, editing, automation and mixing | Free source; Linux distribution packages are available without payment. Official ready-made downloads use a payment/demo model, so use the distribution/source route for zero cost. Linux/macOS/Windows. |
| [sfizz](https://sfz.tools/sfizz/) | Plays SFZ sampled instruments; offline MIDI rendering | BSD-2-Clause engine; Linux plugins and an offline renderer. A user-local offline renderer is built and tested here. |
| [VSCO 2 Community Edition](https://versilian-studios.com/vsco-community/) | Recorded orchestral instruments and articulations | CC0, direct download without signup; approximately 3 GB of samples. Use the SFZ version with sfizz. A useful starting library; full arrangement/ensemble realism needs an audition. |
| [Salamander Grand Piano](https://github.com/sfzinstruments/SalamanderGrandPiano) | Recorded acoustic piano | 48 kHz/24-bit recordings, 16 velocity layers, release/resonance samples. CC-BY-3.0: credit Alexander Holm, link the license and identify modifications. |
| [Surge XT](https://surge-synthesizer.github.io/) | Designed sci-fi tones, pulses, accents and SFX layers | Free open-source synth, native Linux support. Complements sampled instruments. |
| [Audacity](https://www.audacityteam.org/) | SFX trimming, noise cleanup, EQ, fades and export | Free open-source editor for Linux/macOS/Windows. It is an editor, not an orchestral instrument library. |

Optional desktop route: [BBC Symphony Orchestra Discover](https://www.spitfireaudio.com/bbc-symphony-orchestra-discover)
is free and currently lists 34 instruments and 47 techniques, including piano. It
requires a Spitfire account/installer and supports Windows/macOS; it is not the native
Linux cloud route. Rendered music should be exported from the author's workstation.

Optional additional sampler: [Decent Sampler](https://www.decentsamples.com/product/decent-sampler-plugin/)
has free Linux/Windows/macOS versions. Its official download asks for an email.
Each accompanying instrument library has its own terms; the free player does not
establish the license for every library. It is not installed here.

Virtual Playing Orchestra is another SFZ candidate mentioned by the sfizz project;
its official site returned HTTP 406 during this review, so its current download and
license were not verified and it is not the primary recommendation.

## Cloud verification

This environment is Debian 13/x86_64. FFmpeg and the FluidSynth shared library are
already present; no full DAW, sfizz or FluidSynth command-line app was initially
available. This session has no sudo executable or administrative package-install
route. A user-local build avoids requiring an OS package installation.

Built the upstream **sfizz 1.2.3** release with its bundled dependencies, CMake/Ninja,
JACK disabled and the offline renderer enabled. Installed the executable at:

```text
/workspace/.starfire-setup/audio-tools/bin/sfizz_render
```

Tooling and source stay under `/workspace/.starfire-setup/audio-tools/`; downloaded
primary-source evidence/build logs are under `/workspace/.starfire-setup/audio-research/`.
Ardour, sfizz's GUI plugins, Surge, Audacity and the complete sample libraries have
not been installed or tested in this session.

The smoke test uses one upstream Salamander `A4v8.flac` sample, a small SFZ mapping
and four MIDI notes. Rendering succeeded and produced non-silent 48 kHz stereo PCM
without clipping. The resulting 3.82-second file is a technical test, not a full
16-layer piano instrument, production master or finished score. The stock renderer
writes 16-bit WAV; a DAW/float-capable rendering route should be used for production
masters/stems when preserving 24-bit/float headroom matters.

- [Technical piano render](../../reports/audio_tool_research/piano_sampler_smoke.wav).
- [Machine verification and sample provenance](../../reports/audio_tool_research/verification.json).
- Sample author: Alexander Holm, **Salamander Grand Piano v3**.
- Source snapshot: `3382bf9496bba2486f5ab0de55a264d1dfc38404`.
- License: [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/).
- Test modification: one recorded note mapped/transposed to four pitches; no full pedal,
  resonance or velocity-layer implementation. The generated clip credits the sample
  source; it must not be presented as an audition of the complete instrument.
- VSCO source snapshot checked: `440300901dfe9275fd84e0b7763af1f8443ae62e`;
  the source LICENSE and publisher page both identify CC0.

## Fit with Starfire Hearth

`app/audio.gd` already loads delivered audio by cue ID, has separate UI/Effects/Voice/
Music buses and uses two players for 1.2-second music crossfades. Music normally loops;
`sting_*` cues play once. Optional voice remains independent. Instrument libraries
and music tools belong to authoring; only rendered music/SFX need to ship in the game.

`tools/import_assets.py` already converts music to Ogg Vorbis and ordinary effects
to WAV, checking sample rates, peaks, loudness and loop seams. Existing cue IDs can
be retained when replacing audio. Research/composition does not require changing
simulation saves or graphics compatibility.

SFX direction: clear short attacks, less wash/reverb for common clicks, distinct
confirm/error/critical-alert patterns and a controlled range of pitches. Larger
ship/construction sounds can combine recorded transients with subtle synthesis.
Audition at the normal music mix level so frequent actions remain pleasant and
important alerts remain distinguishable.

First artistic comparison should use the same short theme in a warm orchestral
arrangement and an orchestral/sci-fi hybrid, plus a small click/confirm/alert set.
Decide on those audible comparisons before replacing the full soundtrack. Free
libraries can establish this direction; they have fewer performance/articulation
options than large commercial libraries, so the final quality depends on the
arrangement, sample selection, dynamics and mixing.

## Reproduce the existing smoke render

```sh
/workspace/.starfire-setup/audio-tools/bin/sfizz_render \
  --sfz /workspace/.starfire-setup/audio-research/pilot/single_note_piano.sfz \
  --midi /workspace/.starfire-setup/audio-research/pilot/smoke.mid \
  --wav reports/audio_tool_research/piano_sampler_smoke.wav \
  --samplerate 48000
```

To rebuild from the upstream `sfizz-1.2.3.tar.gz` release, use the isolated tooling
virtual environment's CMake/Ninja with `SFIZZ_JACK=OFF`, `SFIZZ_RENDER=ON`,
`SFIZZ_TESTS=OFF`, `SFIZZ_SHARED=OFF`, Release mode and
`CMAKE_POLICY_VERSION_MINIMUM=3.5`. Build target `sfizz_render`. This proof uses the
upstream sample data, not the existing procedural fallback wave generator.
