# M2B — A discovery worth reaching

Continue from `0a3ce61` and preserve PR #9 on 14 November 2026

## Goal

Give Halden a consequential, one-shot discovery and let players opt a survey
probe into exploration without issuing every individual order

## Discovery contract

- Trigger a preview-only scripted scene after Halden is discovered
- Offer salvage, timed research and a free leave-intact choice
- Show actual costs, storage-cap limits and the research modifier duration
- Require a new resolution objective so arrival cannot bypass the scene
- Preserve the dormant landmark and avoid the canonical Dark Beacon revelation
- Verify each branch, duplicate choices, undo, revisit and save/reload

The proposed initial numbers are 15 energy for up to 40 minerals, 20 energy for
50% additional research over ten production turns, or no cost and no reward.
These are tuning choices, not balance results

## Automation contract

- Save explicit intent as a namespaced integer in the owning empire's flags
- Restrict enabling to an owned single-probe fleet
- Process sorted fleet IDs after commands, before later turn phases
- Assign at most one task to each idle fleet in a turn
- Survey a legal local planet first; otherwise choose the least-time destination
- Use only public map information for unknown destinations
- Pause new assignments while a player event needs an answer
- Keep current travel or survey progress when automation is disabled
- Accepted manual orders override intent; rejected orders preserve it
- Preserve queue undo and midflight/midsurvey save-resume behavior
- Clear intent and report once when no reachable target remains

## Ownership and checks

Keep the same Sol lead, Astra adviser, two Terra writers, independent Sol judge
and independent Sol playtester. Writer A owns simulation, command integration
and closed event-trigger validation. Writer B owns content, localized controls,
the expedition harness and UI tests

Use exact Godot 4.7.2, focused regression tests, full-suite consolidation,
deterministic expedition replays and screenshot-backed actual interaction.
Record a separate actual gameplay walkthrough; label synthetic initial setups,
cuts and software-rendering limits. Save the compressed video to Library

Do not merge, deploy or replace earlier evidence. Push a consolidated update
only after independent review; avoid unnecessary Actions runs
