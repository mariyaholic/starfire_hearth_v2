# Browser smoke lifecycle follow-up

The first consolidated CI run at `a4db294` passed the full data/tests/bot job,
the complete 100-run balance matrix, and the screenshot tour. All three release
exports built, and the release-query save guard passed. The browser job then
failed while capturing the iPad gameplay screenshot, after PC and phone passed

The [retained failure trace](browser-followup/ci-failed.log) records
`page.screenshot: Timeout 30000ms exceeded` at `tools/web_smoke.mjs:107`.
The original script kept both title and gameplay Godot instances alive and
reused the same browser across device profiles. The iPad's final assertions had
not executed when capture threw; this is not a proven game-state or layout
regression, nor proof of a particular GPU/driver root cause

The earlier local pass used Playwright 1.62.1 and Chromium 151. CI used pinned
Playwright 1.56.1 and Chromium 141.0.7390.37. Follow-up comparison uses the pinned
pair, without claiming that version alone caused the difference

## Correction and unchanged acceptance

- Close the title context before starting gameplay, keeping only one live Godot
  instance, then close the browser after each device profile
- Keep PC, phone and iPad profiles, DPR values and all six required screenshots
- Keep the 30-second capture/navigation and 90-second boot limits unchanged
- Keep expected layout, turn 2, positive save count, desktop-hash parity and
  browser-error checks; a capture error still fails its profile
- Write bounded console history and per-profile stage/error/timing JSON; cleanup
  failure cannot be turned into a pass or leave later profiles silently accepted

There are no game, data, save-format, workflow or Godot-test changes in this
follow-up. The 418-test suite and actual save/reload evidence retain their
documented source scope. The historical build manifest describes the tree when
those artifacts were produced; the later change is browser-test tooling only

Pinned before/after results and independent harness review are recorded below.
The next CI status is tracked on PR #10

## Observed comparison and independent review

The untouched baseline also passed all three profiles on this cloud host with
the exact pinned browser pair; title boot times were 9.4, 6.5 and 6.6 seconds.
The remote failure therefore was not reproduced locally. Reduced lifecycle
contention is a reasonable correction, not an experimentally established root
cause or a proven player-visible performance improvement

The independent reviewer source-checked unchanged thresholds/assertions and
exercised the harness with a lightweight Playwright mock: a clean run exits zero;
injected iPad capture failure, hash mismatch and browser error each exit nonzero
with profile diagnostics. Those checks counted three browser launches, six closed
contexts, at most one live engine context and six capture attempts. This verifies
orchestration/failure accounting; it is not a substitute for the actual browser run

## Pinned real-browser result

The corrected script passed all three actual profiles, all six screenshots and
the exact desktop state hash `911cdd430061`, with no console errors or failed
problems. Title boot took 7.4, 6.8 and 6.4 seconds; gameplay captures took 1.964,
2.405 and 3.442 seconds for PC, phone and iPad respectively. These are one run's
test timings, not a controlled speedup or a physical-device benchmark

[Original pinned output](browser-followup/baseline.log),
[corrected pinned output](browser-followup/fixed.log),
[actual screenshots and per-profile diagnostics](browser-followup/fixed/), and
[independent mock-only results](browser-followup/mock/result.json) are retained.
The iPad frame proves the UI/capture/state gate; its gray terrain placeholder
does not establish completed world generation. No screenshot is an AI image

The corrected harness SHA-256 is
`0a76652885414b751e7745902f952b943c7a8d7aeff0d6d07530744f69289d64`.
The retained mock driver/module are fixtures authored by the reviewer, not a
vendored Playwright installation. Their original private-path references are
provenance; adapt the checkout/output path when replaying the fixture elsewhere

The full suite remains the 418-test run at its recorded aggregate. Application,
simulation, UI, content, strings, project/export configuration, workflows and
Godot tests did not change in this follow-up. Only `tools/web_smoke.mjs` and
audit documentation/evidence changed; the current source aggregate is recorded
in the root audit manifest. A second consolidated CI run checks the new tool
