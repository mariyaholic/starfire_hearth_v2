# M1.2 owner follow-up — compact UI, planet spacing and D–G revalidation

4 October 2026. Approved compact Immersive UI is implemented, including real
Matte/Frosted/Glossy controls. The system map now has more space between planets
and ring edges. Saved orbital timing and campaign rules are preserved. Work
remains on the existing M1 lineage; no branch, commit, push, tag or release was created.

## Actual game screenshots

These are runtime captures from the updated game, not generated concept pictures.
Desktop captures are 1920×1080 using Godot 4.7.2 and Mesa llvmpipe.

- [Spaced system overview](../../screens/m12_owner_revalidation/05_spaced_system.png).
- [City with compact summary](../../screens/m12_owner_revalidation/01_compact_city_default.png).
- [Selected building context](../../screens/m12_owner_revalidation/02_compact_city_inspector.png).
- [Manage → Jobs](../../screens/m12_owner_revalidation/03_management_jobs.png).
- [Research branch tabs](../../screens/m12_owner_revalidation/04_research_tabs.png).
- [System appearance controls](../../screens/m12_owner_revalidation/06_system_appearance_controls.png).
- Actual finish comparison: [Matte](../../screens/m12_owner_revalidation/07_matte_actual.png),
  [Frosted](../../screens/m12_owner_revalidation/07_frosted_actual.png),
  [Glossy](../../screens/m12_owner_revalidation/07_glossy_actual.png).
- Native phone viewport emulation: [100% text](../../screens/m12_owner_revalidation/08_phone_100.png)
  and [200% text](../../screens/m12_owner_revalidation/08_phone_200.png).

## Stage results

| Stage | Result | Latest headless evidence |
| --- | --- | --- |
| D — Immersive workspace | Summary-only default, context on selection, queue pill, tabbed tools, persistent turn/resources and real finish controls | 8 tests / 144 checks / zero failures |
| E — Voice capacity | Stable optional cues, independent Voice bus/volume, missing-clip fallback and stop-on-close/load | Voice: 3 tests / 24 checks; audio: 5 tests / 187 checks; zero failures |
| F — Living orbital map | Ring-aware spacing, fitted overview, circular turn interpolation, paused followers, belt camera tracking and closeup guide suppression | 5 tests / 76 checks / zero failures |
| G — Integrated checkpoint | Full pinned-engine regression, data audit and refreshed Windows/Web release exports | 255 tests / 12,392 checks / zero failures; 20 tables / 328 records / 1,485 strings / zero data errors or skipped checks |

The full suite includes graphics integrity, frozen geography and anchors, manual/
auto/checkpoint load routes, archived M1.1 writer roundtrips, future components,
unknown-extension retention, intel filtering and session/camera lifecycle checks.
The voice importer and browser runner pass Python syntax validation.

Targeted Chromium checks pass **58 checks / zero failures / zero browser, script or
shader errors**: 29 desktop mouse checks and 29 touch-emulated phone checks. These
exercise summary-only defaults, actual Manage/Jobs orders, finish changes without
campaign/graphics/order/renderer mutation, reachable End turn at 200% text, pure
simulation parity, fitted system guides and destroyed-page IndexedDB save/reload
with identical turn-derived orbital positions. Twelve browser captures and machine
results are in [verification.json](../../screens/m12_owner_revalidation_web/verification.json).
Examples: [desktop system](../../screens/m12_owner_revalidation_web/desktop_05_system_spacing.png),
[phone Jobs](../../screens/m12_owner_revalidation_web/phone_02_jobs_window.png),
[phone after save reload](../../screens/m12_owner_revalidation_web/phone_06_system_after_reload.png).

The subsequent pause/belt edge corrections were covered by the final full suite and
focused Stage F tests, followed by refreshed exports. The browser flow exercises the
same normal UI/camera/save path; paused follower and belt-camera behavior were checked
in the native scene-graph tests.

## Save and update behavior

Spacing is derived from a deep copy of the disclosed system recipe. It does not
rewrite physical distances, phases, periods, epochs, identity or the graphics
save envelope. Only bodies already permitted by intel enter this calculation.
Positions derive from the saved turn, so turns resolved on another screen are
reflected when the system opens. Visible planet/belt transitions follow their orbit
rather than cutting across the circle. Paused ambient effects do not detach markers;
focused belt cameras follow turn motion. Overview framing includes near-side perspective
and waits for real layout dimensions; an existing player camera is retained.

Older campaigns without an orbital recipe keep their existing static layout until
an explicit upgrade. Future unknown graphics components remain preserved and
unsupported generation uses the existing preserving fallback. This validates the
implemented compatibility contract; it does not promise compatibility with every
future binary. The original pre-envelope executable's metadata-dropping resave
boundary remains documented in Stage A.

Workspace version 2 replaces untouched oversized v1 defaults and retains custom
geometry. Window layouts and finish settings remain device-local; changing them
does not modify the campaign or saved world appearance. Settings retain unknown
keys. Matte/high contrast remain available for a quiet, opaque surface. Glass
samples the 3D scene only, leaving text/buttons fully opaque.

## Review build and remaining limits

[Windows x86_64 review ZIP](../../build/m12_review/StarfireHearth_M1_2_Windows.zip):
**82,774,414 bytes, about 79 MiB**, compressed without changing render assets.
SHA-256: `5a834f674f74e7bf19397e80a7ae374874ace5541b905251cbc5e2aa7378d0ba`.
Extract and run `StarfireHearth_M1_2.exe`. Godot 4.7.2 Release exports for Windows
and Web succeeded. The Windows executable has not been run on Windows here.

Cloud native rendering uses llvmpipe and browser rendering uses SwiftShader.
Phone checks are viewport/touch emulation, not a physical-device performance
certification. Owner art/playtest acceptance and Windows display behavior remain
hardware checks. Voice recordings have not been delivered; optional capacity is
implemented. Glass currently uses nine scene samples per visible panel; a shared
blur pass and target-hardware profiling remain optimization work under the
owner's quality-first preference.

Native capture shutdown still reports four ObjectDB instances and two resources
in use, matching the earlier native baseline. Live captures show no script or
shader failures. This cleanup warning is tracked separately from the passing
headless regression and browser runtime checks.

## Reproduce

Use the pinned environment, then run the suite and targeted checks:

```sh
. /workspace/.starfire-setup/activate.sh
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd
godot --headless --audio-driver Dummy --path . -s tools/validate_data.gd
python3 tools/m12_review_web_smoke.py --build build/m12_review/web --out screens/m12_owner_revalidation_web
```

Native capture tool: `tools/m12_owner_revalidation.gd`. Use an isolated
`XDG_DATA_HOME` and Xvfb with OpenGL3; `-- --system-only` refreshes just the system
captures. Capture metadata is in `screens/m12_owner_revalidation/capture_info.json`.
