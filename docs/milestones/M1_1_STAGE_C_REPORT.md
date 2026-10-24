# M1.1 Stage C — integrated space

Stage C is functionally validated on the existing M1 lineage. The normal Galaxy and
System screens now incorporate 3D views and existing gameplay commands. No new branch, commit, push, merge,
tag or deployment was created. Simulation rules, balance content, save schema and
golden hashes remain unchanged.

## Delivered behavior

Galaxy/System now default to 3D and retain the game's top bar, navigation, inspectors,
Undo and End Turn. The persistent host survives inspector refreshes and responsive
relayouts. Galaxy uses actual M1 positions and locked lanes; known systems open their
System screen, while unknown systems retain neutral markers and the locked reason.
Hidden names, spectral appearance, foreign colonies and foreign ships do not reach
the renderer. The previous study-only System modal entry is retired.

System overview/focus supports all eight planet families and seven stellar families,
including seeded asteroid belts, ringed gas giants, white dwarfs and a composite
binary. Solid worlds refine from cheap previews to seeded albedo, surface, normal
and cloud maps; focused width is 1024 in Standard and 512 in Low/browser Auto.
The same pixel generator runs on bounded native workers and cooperatively in the
non-threaded browser. It retains appearance identity without using gameplay RNG.
Shared globe/region geography and saved appearance profiles remain Stage D.

Actual owned Survey Probes, Construction Ships, Colony Ships and outposts have
distinct assemblies using the newer Blender part library and baked PBR tiles.
Task targets position busy ships; completed/consumed objects update by stable ID.
Owned settled colonies have selectable markers that open the existing Colony planner.
Survey, Colonise and Outpost use the existing command validation, costs, refusal
explanations and turn processor. Space selection never creates new gameplay objects.

Accessible object selectors accompany canvas picking. Pointer drag/wheel and touch
drag/pinch control the camera. A selector brings the viewport into view on compact
screens so refinement resumes after scrolling. Pause and Reduced Motion stop the
visual clock. Auto/Low/Standard and 3D/Strategic are real persisted settings, with
in-view controls. Strategic releases the inactive scene and preserves game state;
returning restores session camera/focus. Auto currently uses capability/compact
heuristics; adaptive frame-time selection is still optimization work.

## Validation and evidence

| Check | Result |
| --- | --- |
| Full regression suite | 185 passed, 0 failed; 3,576 checks, 35 files |
| Data validation | 20 tables, 328 records, 1,385 strings; 0 errors, 0 skipped checks |
| Native rendered tour | 117 checks, 0 failures; 22 captures |
| Native layout audit | PC/compact at 100% and 200% text: 0 issues |
| Browser release validation | Desktop 34/34 and phone 36/36 checks pass; 14 captures, no browser/engine errors |
| Repository bot smoke | Balanced/random-legal, seeds 1–3, 60 turns: 6/6 deterministic replays, no invariant failures |
| Simulation end-turn p95 | 41.80 ms across 360 smoke turns; below 300 ms target |
| Imports, web export, whitespace | Passed |

Native commands match independent pure turn replay. The unit suite covers all
planet/spectral representations, owned/foreign filtering, session replacement,
touch zoom and the Stage B host/scheduler/cache contracts. No golden rebaseline
was performed. The CI-style 60-turn bot smoke passes invariants/determinism/timing;
its advisory balance report fails `everything_matters` and balanced `winnable`, and
skips Story/pacing coverage. A 60-turn smoke is not the full 105-turn balance gate;
no balance change is claimed or introduced.

Both browser profiles run the actual non-threaded release export with cooperative
generation, normal canvas controls, canonical Survey and named Colonise/Outpost
fixtures. Each command matches pure replay. Completed markers appear, colony
selection opens the existing planner, and Strategic switching releases/restores the
space scene without changing state. Phone validation includes real touch taps and
a two-finger browser pinch. Automation advances turns through `Game.end_turn()` and
closes reports; it does not replace command validation. Existing End Turn/checklist
UI coverage remains in the full regression suite. Both profiles produce canonical
Survey hash `0e234243c5c9731fd30fd8f50a2ae8452d520f8f21db7ec94d7f9f63407d7f48`
and final fixture hash `09070f004c0c34fa5c4ddf52c10d1cc16c4609925affa25bd4f318ebad6b12b5`.

Canonical coverage starts from First Light seed 11 and completes Brume's Survey.
After that, **explicit command fixtures** add one owned Colony Ship and set influence
to 50,000 internal units to exercise Colonise/Outpost without a long economic setup.
Those orders still validate, pay and complete normally. Additional native appearance
captures substitute arid/ice/toxic planet types and six non-K spectral families through
the ordinary snapshot/host path, with no orders in those appearance fixtures.
The fixtures are labeled in JSON/captions and never run from ordinary game entry.

Verbose shutdown diagnosis identified the earlier four leaked instances/two retained
resources as an Ogg music stream/playback held by the audio mixer at abrupt scripted
exit. The final native tour frees Audio through its existing cleanup and allows mixer
retirement before quit. Its final log contains no engine errors or leak warnings;
the unsupported Xvfb V-Sync warning remains benign. Production audio code is unchanged.

## Performance and unfinished scope

The release download is approximately 48.05 MB with gzip-9, versus the pinned M1
baseline's 47.26 MB: approximately 0.79 MB additional download, below both the 150 MB
total and 25 MB incremental targets. Exact final sizes are retained in `size.json`.
The native capture tour peaks at approximately 698 MB process-tree RSS, including
software OpenGL and 22 PNG readbacks, exceeding the 400 MB optimization target.
It is not a live-only or GPU measurement. The end snapshot reports approximately
83.5 MB Godot static memory and 15.4 MB conservative cached-texture estimate; those
are distinct measurements and do not replace RSS or device GPU profiling.

Final browser timing samples are retained separately in the profile JSON. Software
WebGL timings are diagnostic cloud measurements, not physical-device certification.

| Focused browser sample | Desktop software WebGL | Phone profile, software WebGL |
| --- | --- | --- |
| Cooperative generation slice p95 | 2.0 ms | 2.0 ms |
| Texture upload p95 | 1.8 ms | 5.5 ms |
| Frame-time p95 | 113.3 ms | 116.7 ms |
| Cached texture estimate | 2.84 MB | 2.84 MB |

Frame timings exceed the 16.7/33.3 ms targets in this cloud software renderer.
Generation/upload/frame-time debt remains under the Owner's quality-first directive.
Optimize batching, uploads and viewport/material cost after the quality checkpoint.

The agreed finished art is still Stage F: hero silhouettes, trim sheets, authored
LODs, lighting/corona refinement, terrain/foliage and complete keyboard/touch/high-
contrast polish. The current integration captures are not the final artistic finish.
Stage D joins globe/region geography and save appearance; Stage E integrates city
planning; Stage G completes playthroughs, export matrix and actual device profiling.
No claim is made that the entire M1.1 checkpoint is complete.

## Reproduce and review

After sourcing `/workspace/.starfire-setup/activate.sh`, from the M1 checkout:

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tools/validate_data.gd
godot --headless --path . --export-release Web build/web/index.html
python tools/m11_stage_a_profile.py native --script tools/m11_stage_c_smoke.gd --timeout 360 --log build/stage_c/native.log --out build/stage_c/native_process.json
python tools/m11_stage_c_web_smoke.py
```

Run rendering measurements separately. Native captures/JSON are under
`screens/m11_stage_c`; browser captures/JSON under `screens/m11_stage_c_web`.
Logs are under `build/stage_c`. The review package at
`starfire_3d_proposal/m1_1_stages_b_c/` contains the playable HTTP-served web export,
current screenshots, stage reports, evidence and a binary patch of the complete local
M1 delta, including prior study/Stage A changes. The ZIP is
`starfire_3d_proposal/m1_1_stages_b_c_review.zip`.
