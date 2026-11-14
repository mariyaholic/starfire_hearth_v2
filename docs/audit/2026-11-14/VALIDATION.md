# Consolidated validation

Godot `4.7.2.stable.official.ed1daf0bf`, Linux cloud, 14 November 2026
Software rendering only: llvmpipe for native, SwiftShader for Chromium
No test used the owner's real saves, browser profile or laptop

## Frozen code and results

The consolidated suite's source/test aggregate is
`7b1f583c2fe00acdc18bc74bd08eca8245c769f0e424b85c88a7ae75a136e79e`.
It matches before and after the final suite

The first remote CI run subsequently found a browser-harness capture timeout.
The follow-up changes only that test tool; its separate reproduction, correction
and validation are recorded in [the browser follow-up](CI_BROWSER_FOLLOWUP.md).
Earlier aggregate hashes and raw manifests retain their original scope

| Check | Actual result |
| --- | --- |
| Full Godot suite | **418 passed, 0 failed, 15,038 checks, 74 files**, 91.9 s |
| Content validator | 20 tables, 391 records, 1,587 strings; 0 errors and 0 skips |
| First Light visual/asset audit | 367 checks, 0 failures |
| Asset-intake Python security regressions | 7 tests passed |
| Background-worker shell regression | Passed, including failed-child detection and waiting for every child |
| Strict bot coverage/replay smoke | 6 requested runs across 2 policies × 3 seeds, all replayed hashes match, 0 invariant problems |
| Release exports | Web, Windows and Linux completed; Windows runtime not available |
| Separate debug Web export | Completed; instrumented smoke routes are confined to debug builds |
| Actual release URL regression | `?smoke=begin` ignored, no smoke line, pre-existing `auto_2` bytes unchanged |
| Actual release manual-save reload | First observed success toast → immediate reload in the same script; stored turn-2 simulation exactly matched the actual S1 fixture; Title Continue restored Month 2 UI |
| Debug Web browser profiles | PC, phone and iPad profiles all reached turn 2 and desktop hash `911cdd430061` |
| Web size | 140,090,161 bytes raw / 107,533,260 gzip bytes, below the 150 MB download budget |

The bot report's p95 end-turn time was 54.10 ms over 360 turns during concurrent
validation. It measures simulation work on this machine, not UI/frame latency.
The 60-turn smoke deliberately uses advisory balance gates: balanced Normal had
no wins in those three short runs and the usage gate failed. Those are retained
in the [raw report](validation/telemetry_report.log), not relabeled as a balance
pass. This sample cannot establish a win-rate or gameplay-balance verdict

The first suite run had 417 passes and one failure: an old StopFleet regression
expected fleet-ownership rejection before the new player-actor guard. The test
now checks both direct fleet validation and queue authority, plus an unchanged
preview; no production logic was relaxed. Both [first-run output](validation/tests-first-run.log)
and [passing output](validation/tests.log) are retained. The missing-key warning
in the voice test deliberately checks localization fallback and is not a failure

Exports were made at aggregate
`367f8c944620eb9678cb82d6fb26b8456805ef7ee7fc937356ddf9e7d1400ec0`.
The only source change after export was that StopFleet test correction; tests
are excluded from exports. Reconstructing the earlier aggregate with the old
test reproduces it exactly, establishing that exported production source did
not change. The [build manifest](validation/build_manifest.json) records all 20
export files, sizes and SHA-256 hashes without committing the large binaries

The aggregate hashes sorted paths and file SHA-256 values in `app`, `sim`, `ui`,
`data`, `strings`, `tests` and `tools`, for `.gd`, `.json`, `.csv`, `.cfg`,
`.gdshader`, `.uid`, `.py` and `.mjs`. Documentation is excluded. Workflow and shell
files are separately hashed in [their manifest](validation/workflow_manifest.json)

## Reproduce the main checks

```sh
godot --headless --path . --import
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd
godot --headless --audio-driver Dummy --path . -s tools/validate_data.gd
python3 tools/art/audit_finish_v1.py --out build/asset_audit.json
python3 -m unittest discover -s tests/tools -p test_import_assets_security.py
bash tools/test_wait_all.sh
```

Python asset tools use `tools/requirements-assets.txt`. The first local run
stubbed an unavailable `soundfile`; the lead then created a fresh virtual
environment, successfully installed every pinned dependency and reran all seven
tests with real imports. [Package versions](validation/asset_packages.json) and
[passing output](validation/asset-security-pinned.log) are retained. The tests
exercise metadata/write boundaries with an image-handler fixture; the author
also reproduced the original traversal using actual vignette decoding. Neither
test is audio-decoder validation. CI installs the same pinned requirements

The strict six-run bot invocation matches CI's checks job: two policies,
`--seeds 1-3 --turns 60 --check-determinism`, then

```sh
godot --headless --path . -s tools/telemetry_report.gd -- \
  --in telemetry --balance advisory --expect-runs 6 --expect-seeds 1-3 \
  --expect-scenario s1_first_light \
  --expect-group balanced:normal:3 --expect-group random-legal:normal:3 \
  --require-determinism
```

Export release presets `Web`, `Windows` and `Linux`, plus a separate debug `Web`
build. Run `tools/web_release_probe.mjs` on release and `tools/web_smoke.mjs` on
debug, passing the hash from `tools/smoke_hash.gd`. The local smoke used an exact
private adapter that changes only Chromium's executable path to `/usr/bin/chromium`;
CI uses Playwright's installed Chromium. Browser device profiles are emulation,
not physical Safari/iPad/Android acceptance

## Interaction, persistence and privacy evidence

See [the app audit](APP_AUDIT.md) and [independent review](REVIEW.md) for fault
injection, browser-verifier concurrency, actual UI screenshots and evidence
limits. Headless fixtures, normal gameplay, private read-only observers and
network/storage inspection are labeled separately. Earlier M2F rapid-reload
evidence remains in its own milestone report; it is not replaced by these tests

The GitHub CI result for the final commit is tracked on PR #10. Local passes and
successful exports do not assert that a later remote run has completed
