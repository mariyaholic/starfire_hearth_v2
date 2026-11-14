# M2C — Stop at the next system

14 November 2026 · continue from `93f8cb3` on PR #9

## Goal

Let the player shorten an existing civilian journey without cancelling elapsed
travel or teleporting a fleet back to its departure system

## Contract

- Accept an owned civilian fleet with a valid active route
- Offer stopping when later legs remain, or when a single leg has auto-explore on
- Keep the first destination, current system and current-leg progress
- Remove later waypoints and disable future automatic exploration
- Use the existing arrival processing, remaining ETA and save representation
- Keep the separate automation-off action, which preserves the entire route
- Preserve queue Undo, serialization, session guards and unknown-star labels
- Reject invalid, foreign or already-stopping requests without changing state

## Verification

Use pinned Godot 4.7.2. Check mid-leg timing against the original journey,
checksum-verified save/resume, same-turn move then stop, Undo and invalid
commands. Have an independent Sol reviewer inspect the contract and a separate
Sol playtester exercise the actual controls in both map presentations and a
phone-sized 200% layout, with screenshots and an explicit initial-fixture label

Preserve PR #9. Consolidate checks before pushing; do not merge or deploy
