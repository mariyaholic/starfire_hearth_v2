# Whole-game state, responsiveness, security and privacy audit

Started after the 4 PM Manila feature cutoff and the completed M2F wrap-up

## Baseline and scope

Baseline `bb6e993` contains the completed continuation feature and corrected Web
save barrier. PR #9 is frozen at `90e3db5`, ready for review and unmerged. Audit
changes stay on `feat/expedition-continuation` in draft PR #10. No further gameplay
features, public release, merge or deployment are authorized in this phase

Assess the whole repository's implicit state machines and failure boundaries,
debug demonstrated faults, improve measurable responsiveness and trace personal
data read, storage and transmission. Source inspection is not runtime proof;
synthetic faults and actual interaction evidence must be labeled separately

## Ownership

| Role | Scope |
| --- | --- |
| Sol lead | Coordination, documentation, consolidated validation and PRs |
| Terra A | Pure simulation, commands, saves/schema, ingestion tools and focused unit regressions |
| Terra B | App/UI/session/persistence/render lifecycle, release probes, CI integration and integration regressions |
| Astra High adviser | Read-only contract/risk inventory and coverage gaps |
| Sol reviewer | Independent checks, source/visual judgment and coverage review |
| Sol playtester | Actual controls, screenshots, browser network/storage observations and bounded timing probes |

At most two Terra code writers operate concurrently. Each author owns its audit
document; shared code changes are coordinated before touching another scope

## Evidence and acceptance

- Inventory states, transitions, authoritative writes, guards and failure points
- Reproduce a suspected fault before calling it a confirmed defect
- Preserve supported saves, campaign progression, existing presentation and goldens
- Document the synthetic TinyState replay exception explicitly
- Use synthetic history, disposable browser profiles and owned temporary paths
- Capture and inspect actual screenshots for visual claims
- Trace runtime and developer-tool data paths separately
- Distinguish local storage, intentional external links and autonomous transmission
- Measure processor timing separately from UI/frame/input latency
- Avoid duplicate full-suite runs during concurrent source edits
- Consolidate focused regressions, data validation, full tests and exports after freeze
- Enforce complete CI worker/matrix coverage without adding repeated Actions runs

## Initial demonstrated issues

The audit owners have reproduced command aliasing, terminal API advancement,
unknown pending-event softlock, release smoke-URL save writes, stale load/delete
and advisor callbacks, silent autosave errors and asset-report path traversal.
Individual owner reports track each fix and its actual verification

This initial list is not a declaration that every possible defect has been found
