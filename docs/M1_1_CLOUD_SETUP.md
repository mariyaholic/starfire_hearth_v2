# M1.1 cloud setup and staged verification

Setup is usable. Godot 4.7.2, its matching export templates, Xvfb/software OpenGL,
Blender 4.3.2, Chromium, Node and Python Playwright are available in this workspace.
The templates came from the official Godot release and were checked against its
SHA-512 manifest. The web preset retains `variant/thread_support=false`.

The M1 checkout is `/workspace/starfire_hearth_m1`, based on existing branch
`claude/starfire-hearth-build-cs2vb6` at
`a160d9d334c59a2796b8c88e8eaca7f49b42c029`. It is a detached local worktree;
changes remain uncommitted. No new branch is needed. The original checkout at
`/workspace/starfire_hearth_v2` and its earlier study changes are preserved.

## Activate and validate

```sh
. /workspace/.starfire-setup/activate.sh
cd /workspace/starfire_hearth_m1
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tools/validate_data.gd
godot --headless --path . -s tools/bot_run.gd -- --scenario s1 --policy balanced --seeds 1,11 --turns 105 --out telemetry/m11_stage_a --check-determinism
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release Web build/web/index.html
python tools/m11_stage_a_profile.py native
python tools/m11_stage_a_profile.py native --profile-only --out build/stage_a/native_live_process.json --log build/stage_a/native_live.log
python tools/m11_stage_a_web_smoke.py
python tools/m11_stage_a_profile.py size --baseline /workspace/.starfire-setup/m11_stage_a/m1_baseline/build/web
```

The native tour writes seven captures and a JSON result under
`screens/m11_stage_a`. `--profile-only` exercises the same game route without PNG
readback and writes a separate result under `build/stage_a`. The profiling wrapper
terminates its own process group on timeout. Run memory/performance cases separately
from other rendering workloads for a cleaner comparison.

The Python browser tour uses installed `/usr/bin/chromium` with software WebGL and
serves the export on an ephemeral local port for the test only. It records actual
canvas selection/Survey interactions on desktop and phone-sized browser profiles,
then closes its browser and server. The phone profile verifies responsive behavior;
actual Android/iOS hardware, touch gestures and GPU performance remain later gates.

The original M1 Node smoke was also run against pinned M1 and this checkout using a
copy with only Chromium's executable path changed. That helper is
`/workspace/.starfire-setup/m11_stage_a/m1_web_smoke_system_chromium.mjs`:

```sh
PLAYWRIGHT_DIR=/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules node /workspace/.starfire-setup/m11_stage_a/m1_web_smoke_system_chromium.mjs --build build/web --out screens/web_regression
```

For a review outside this cloud workspace, install Godot 4.7.2 and its export
templates, Python Playwright and Chromium; adjust the executable path in the Python
browser tool when using a different installation. Serve the included web directory
with a local HTTP server, open `index.html?smoke=m11-stage-a`, then select Brume and
use its real Survey command. The opt-in hook starts a disposable test game with
persistence disabled. Normal `index.html` preserves the ordinary M1 route.

Source/export changes stay local. This setup does not publish, push, merge or tag.
Measured Stage A results and open performance gates are in
[`milestones/M1_1_STAGE_A_REPORT.md`](milestones/M1_1_STAGE_A_REPORT.md).

## Stages B and C

Ordinary `index.html` now uses integrated 3D Galaxy/System views. Appearance 3D /
Strategic and Auto / Low / Standard quality are available in the real Settings
screen and space-view controls. Auto currently chooses conservative web/compact
profiles from capabilities; adaptive frame-time quality remains optimization work.
The Colony planner retains the existing presentation until Stage E.

After the shared import, data and regression commands above:

```sh
python tools/m11_stage_a_profile.py native --script tools/m11_stage_c_smoke.gd --timeout 360 --log build/stage_c/native.log --out build/stage_c/native_process.json
python tools/m11_stage_c_web_smoke.py
```

Run rendering measurements separately. The native tour checks Galaxy/System,
all eight planet families and seven spectral families, Survey/Colonise/Outpost
commands, session replacement, motion controls and PC/phone 100–200% layouts.
It writes captures and `verification.json` in `screens/m11_stage_c`.
The browser tour uses a real non-threaded release export, actual canvas clicks /
touch taps and a two-finger phone pinch. It checks the same three command routes,
pure simulation replay and Strategic restoration on desktop and phone profiles.
Outputs are in `screens/m11_stage_c_web`. Browser emulation verifies functionality;
physical Android/iOS hardware performance remains pending.

Both tours explicitly add a Colony Ship and sufficient influence **after** the
canonical Survey check to exercise Colonise/Outpost without a long economy setup.
Native appearance-family captures use named type/spectral substitutions. These are
test fixtures; ordinary entry never adds ships/resources or alters world types.
The `?smoke=m11-stage-c` browser route disables persistence and auto-starts its test
game. Use ordinary `index.html` for normal play.

The reusable dependency refresh is `/workspace/.starfire-setup/m11_dependencies.sh`;
it validates official template SHA-512 checksums, installs Python Playwright 1.62.0,
and verifies retained Blender/Chromium. Tool activation is still required each shell.
Stages B/C implementation changes are authorized coding work, separate from setup.

## Stage D: saves and geography

The shared regression suite covers graphics versions, independent integrity,
legacy/future transport, all player load routes, anchors, seams/poles and actual
parcel counts. Keep `tests/fixtures/visual/surface_v1.json` and `appearance_v1.json`
frozen when adding future generator/catalog versions.

```sh
python tools/m11_stage_a_profile.py native --script tools/m11_stage_d_smoke.gd --timeout 360 --log build/stage_d/native.log --out build/stage_d/native_process.json
godot --headless --path . --export-release Web build/web/index.html
python tools/m11_stage_d_web_smoke.py
```

The browser route `?smoke=m11-stage-d` writes only to the isolated
`user://stage_d_review` directory. It does not use the ordinary player save directory.
The tour explicitly saves and closes the page/WASM instance, then restores from
IndexedDB in a new page at the same origin. Desktop and touch-sized browser contexts
are separate. A compatible future-save fixture and a Strategic fallback fixture
exercise preservation of unknown graphics strings. Ordinary entry never creates
these test saves or auto-starts a game.

Stage D's regional view remains an inspection study until Stage E integrates the
normal Colony planner. It uses the shared scheduler on both native and web. Web
uses a 6 ms cooperative allowance and a half-resolution, non-MSAA regional viewport;
this is recorded quality/performance debt, with physical-device tuning still pending.
See `milestones/M1_1_STAGE_D_REPORT.md` and
`milestones/M1_1_GRAPHICS_SAVE_CONTRACT.md` for compatibility boundaries and evidence.


## Stage E: normal Colony planner

The anchored city now occupies the normal Colony planner. The study-only city entry
is retired from ordinary play; Strategic uses the same M1 inspector/actions. Reuse
the existing activation, Godot 4.7.2/templates, Blender, Chromium and Playwright setup.
After import, full tests and data validation:

```sh
python tools/m11_stage_a_profile.py native --script tools/m11_stage_e_smoke.gd --timeout 720 --log build/stage_e/native.log --out build/stage_e/native_process.json
godot --headless --path . --export-release Web build/web/index.html
python tools/m11_stage_e_web_smoke.py
```

Run native and browser rendering tours separately. The browser helper exercises
actual canvas clicks/taps, keyboard and pinch, then destroys/reopens the page and
restores an IndexedDB city save. `?smoke=m11-stage-e` is opt-in and uses only
`user://stage_e_review`; normal entry never adds its fixture resources/technologies.
Family/catalog native captures are named fixtures. New games use city catalog 2;
existing saved catalog 1 remains supported. Frozen planet/profile fixtures stay
unchanged. The Stage E report records performance and physical-device limitations.

Stage E raises the temporary web regional work allowance to 18 ms to prevent prolonged
refinement behind the completed city; space jobs retain 6 ms. The half-resolution,
non-MSAA city viewport remains. Actual-device optimization is still pending.

## Stage F: finish and responsive review

The current M1 checkout remains local/uncommitted; no new branch/worktree was made.
Activate retained tools, import and inspect logs for errors before running checks.
Godot 4.7.2 and Blender 4.3.2 remain the tested versions.

```sh
blender --background --threads 4 --python tools/art/build_finish_v1.py
godot --headless --path . --editor --import
python tools/art/audit_finish_v1.py
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tools/validate_data.gd
python tools/m11_stage_a_profile.py native --script tools/m11_stage_f_smoke.gd --timeout 1200 --log build/stage_f/native.log --out build/stage_f/native_process.json
python tools/m11_stage_a_profile.py native --script tools/m11_stage_f_details.gd --timeout 600 --log build/stage_f/details.log --out build/stage_f/details_process.json
godot --headless --path . --export-release Web build/web/index.html
python tools/m11_stage_f_web_smoke.py
python tools/m11_stage_f_web_quality.py
```

Run native/browser rendering tours sequentially to avoid software-renderer contention.
Native takes high-resolution reference captures plus the real planner/save/layout tour;
`--art-only` / `--functional-only` after Godot's `--` allow focused reproduction.
The supplemental tour checks actual map bindings, spaceport/owned outpost, shared motion,
high contrast and portrait drawers/navigation. Browser supports `--profile desktop`
or `--profile phone`; single-profile reruns retain the other passing result.
Its opt-in route `?smoke=m11-stage-f` writes only `user://stage_f_review` and adds
controlled fixture resources/technology/population/telemetry. Ordinary entry uses normal
gameplay and save directories. Native/Web tests use real M1 controls and pure replay;
touch emulation is not physical-device certification.

The Blender source builds geometry, six tileable map sets and the actual high/low trim
normal/AO pair. `--geometry-only` rebuilds meshes without rebaking images; after `--`,
`--only-material concrete` rebakes one material set. See `assets/3d/finish_v1/README.md`
for pivots/units/roles/color spaces/LODs. Retain reviewed `.png.import` settings:
lossless mode 0, generated mips, normal_map 1 for normals / 2 for other maps and
detect_3d/compress_to 0. `.blend` sources have `.gdignore` and are excluded from Godot's
runtime import. Target texture compression belongs to G after software-GL trial stalls.

Actual older-writer reproduction starts from the checksum-verified E review archive
SHA256 `8aeae9c99849d15f90dae5f618cba9b8cb25d800c35eb84b0d76d6fce39f4e58`.
The review bundle includes its complete E patch and adapted test-only helper. Apply
the E delta to a plain clean pinned-M1 copy (not on top of the F patch), copy the helper
to `tools/m11_stage_f_compatibility.gd`, import, and run the middle command there:

```sh
# Current F checkout
godot --headless --path . -s tools/m11_stage_f_compatibility.gd -- produce /absolute/evidence
# Archived E source plus only the adapted test helper
godot --headless --path . -s tools/m11_stage_f_compatibility.gd -- older /absolute/evidence
# Current F checkout
godot --headless --path . -s tools/m11_stage_f_compatibility.gd -- verify /absolute/evidence
```

This proves old catalogs 1/2 and new catalog 3 plus clearing-only history from an E
completion/demolition. Original M1's writer drops graphics metadata; retain the original
save when using it. Do not rebaseline physical-profile or simulation goldens for art.
The phone-readable report/current gallery, twenty-image ZIP, playable Web and complete
source delta are in `starfire_3d_proposal/m1_1_stage_f*`. Owner art acceptance and Stage G
remain open; no release or public deployment is performed.

## Command / Immersive (F.1) revalidation

The existing Godot/Blender/Xvfb/Chromium/Playwright setup remains sufficient. On the
same M1 checkout, import once and run:

```sh
. /workspace/.starfire-setup/activate.sh
godot --headless --editor --path . --import
godot --headless --path . -s tests/run_tests.gd
xvfb-run -a -s '-screen 0 2560x2400x24' godot --audio-driver Dummy --path . -s tools/m11_immersive_smoke.gd
godot --headless --path . --export-release Web build/web/index.html
python3 tools/m11_immersive_web_smoke.py
```

Use `-- --layouts-only` on the native helper for focused compact-HUD checks.
Browser `--profile desktop` or `--profile phone` reruns one profile and preserves
the other result. Full runs create fresh evidence under `screens/m11_immersive*`.
The native helper closes the fixture's deferred opening dialog before the actual
input/capture comparison. The Web portrait tour dismisses its refreshed fixture
report through the actual Continue button and verifies the requested panel before
capture; normal gameplay still presents the report. Isolated review saves
use `user://immersive_review` (native) and `user://immersive_review_web` (Web).
The `?smoke=m11-immersive` bridge is opt-in and never changes ordinary entry.
The browser tour explicitly persists its test device choice and destroys/recreates
its page to verify both immediate layout preference and saved game continuity.

Native preferences use settings.cfg. Web additionally stores only the layout
scalar in immediate origin-local browser storage, avoiding asynchronous file-sync
loss on closure. Storage-denied browsers keep the settings fallback. SaveService,
graphics versions, physical identities and old-writer compatibility boundaries
remain unchanged. Standard is available independently of layout; software GPU
costs are recorded, with optimization/physical devices deferred to Stage G.

The completed report/gallery, eight original pictures and full playable/source
review ZIP are under `starfire_3d_proposal/m1_1_immersive*`. Artifact verification
checks phone/desktop readability, the comparison slider, all image links, PNG/ZIP
integrity, hashes and patch applicability to the unchanged pinned M1 baseline.

## Stage G checkpoint validation and launch

The existing cloud setup is retained. Activate it in this checkout before running
Godot commands:

```sh
. /workspace/.starfire-setup/activate.sh
cd /workspace/starfire_hearth_m1
godot --headless --path . --import
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd
godot --headless --audio-driver Dummy --path . -s tools/validate_data.gd
python3 tools/art/audit_finish_v1.py --out build/stage_g/asset_audit.json
```

`tools/m11_stage_g_campaign.gd` runs the deterministic First Light production-screen
route under Xvfb/OpenGL. `tools/m11_stage_g_lifecycle_profile.py` profiles the 100
switch stress; `tools/m11_stage_g_web_recovery.py` tests the live WebGL loss/reload
path, and `tools/m11_stage_g_web_memory_profile.py` samples its full test/browser
process tree. The actual current-export browser tour supports `M11_BUILD_DIR` and
`M11_OUT_DIR`, so it can be run without overwriting earlier Stage F.1 evidence:

```sh
M11_BUILD_DIR=build/stage_g/web M11_OUT_DIR=build/stage_g/web_interaction \
  python3 tools/m11_immersive_web_smoke.py
```

Release exports are under `build/stage_g/web`, `build/stage_g/windows`, and
`build/stage_g/linux`. Serve the Web files over HTTP because the browser loads the
Godot PCK/WASM resources:

```sh
python3 -m http.server 8000 --directory build/stage_g/web
```

Then open `http://127.0.0.1:8000/`. On Linux, run
`build/stage_g/linux/StarfireHearth.x86_64`; on Windows, run
`build/stage_g/windows/StarfireHearth.exe` on a Windows host. Only the Linux binary
received a runtime smoke here; Windows runtime, Android/iOS devices, target GPUs and
Owner art/playtest acceptance remain Pending. The exact local evidence and measured
limits are in [the M1.1 report](milestones/M1_1_REPORT.md) and
[Stage G report](milestones/M1_1_STAGE_G_REPORT.md).
