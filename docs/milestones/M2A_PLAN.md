# M2A — Exploration preview

Start: current `main` at `2c478cb` on 14 November 2026

## Goal

Make the first interstellar expedition playable, with deterministic civilian
travel and the existing survey, outpost and colony loops. This is a separate
preview, not completion of The Crossing campaign chapter

## Work

- Add integer-only route selection, travel times, movement orders and arrivals
- Reject unsafe orders while a fleet travels, preserve Scenario 1 lane locks
- Add a four-system expedition with an explained objective and no campaign legacy
- Present fleet orders, route time and transit state in both map appearances
- Verify saves, deterministic journeys, a completed expedition and actual rendering

## Ownership

- Sol lead: scope, integration, evidence and handoff
- Astra High: gameplay advice and follow-up recommendations
- Terra xhigh writer A: travel rules, commands, invariants and simulation tests
- Terra xhigh writer B: interface, preview content and expedition harness
- Separate Sol xhigh: independent code review and judgment
- Separate Sol xhigh: actual rendered playtesting and screenshot-backed reports

At most two Terra writers work concurrently. The requested 5.6 Sol playtester
is unavailable; the owner authorized 6.1 Sol instead. Fast routing is not exposed
by this environment's agent selector

## Files and boundaries

Simulation work lives in `sim/rules`, `sim/commands`, `sim/core/invariants.gd`
and the existing movement phase. Preview content lives in `data/scenarios`,
`data/codex`, `strings/en.csv`, the campaign flow and map/fleet presentation

Retain the existing save fields where possible, the integer simulation boundary,
localized explanations, Scenario 1 goldens and canonical campaign order. Do not
change main, merge or deploy automatically

## Verification gates

- Exact Godot 4.7.2 import, data validation and full test suite
- Focused route, transit-order, arrival, invalid-state and save/resume tests
- An expedition bot uses production commands and completes the preview
- Scenario 1 bot determinism and goldens remain intact
- Independent review, targeted fixes and re-review
- Actual rendered desktop and phone layouts, including 200% text
- Web export and browser interaction where the environment permits

Keep test logs and full screenshots outside the source tree; include compact,
inspectable captures and exact commands in the milestone report. Distinguish
software rendering, automated input and headless checks from hardware playtests

## Risks and deferred work

Fog must not disclose undiscovered planets or allow remote tasks. Midflight saves
must not reset travel, and rejected commands must explain why. Preview wins must
not complete canonical Scenario 2 or unlock Scenario 3

Combat, active beacons, Noise, diplomacy, anomaly rewards and full campaign
balance remain later increments. Do not imply they are implemented
