# M2F — Continue an expedition after victory

14 November 2026 · branch `feat/expedition-continuation` from `90e3db5`

## Scope and separation

PR #9 is frozen at its validated head and ready for Maria's review. It must not
receive this work. Open a separate PR for this increment, using GitHub's assigned
number. Until PR #9 is merged, target its feature branch so only the new work is
shown; target main instead if that validated head is already an ancestor

## Goal

Keep optional exploration, construction and research playable after completing
the preview's required goals, while retaining the original victory record

The current beacon research chain costs 1,105 Physics before colony surcharges,
restoration exceeds base metal storage, and the map has no usable beacon link.
An isolated restoration button would provide no transport payoff. Continuation
creates the longer investment horizon before a full restoration/transit package

## Transition contract

- Enable a validated scenario opt-in only on the expedition preview
- Offer a distinct Continue expedition action on its victory debrief
- Keep the return-to-campaign action and all canonical progression rules
- Validate the authoritative won state rather than recomputing expanded goals
- Clone the state and preserve maps, tasks, stocks, objectives, events and intent
- Store the original victory turn and continuation marker in existing integer flags
- Clear only the active outcome fields, without advancing time or production
- Continue optional objective progress and defeat checks; suppress repeat victory
- Preserve schema 2 and leave ordinary won/lost-state behavior unchanged

## Session and persistence contract

Guard source-state identity, session serial, attached screen and an empty order
queue. Capture current presentation from `Worlds.save_fields`, not stale initial
load strings. Persist the transition through one atomic current-auto-slot save
before resuming. Do not rewrite checkpoints or fabricate a resolved turn

If persistence fails, leave the winning state, queue, prior result, presentation,
session and debrief unchanged. If it succeeds, resume the clone through the normal
session boundary so stale callbacks cannot affect the new session. A crash after
the save and before navigation should still reload continued play

Show the original goal-completion date during continued play. A later defeat may
end the expedition without erasing that first completion record

## Acceptance

Use exact Godot 4.7.2, pure transition tests, real checksum envelopes, old won
four-system saves, canonical/unfinished/lost refusals, failure rollback,
checkpoint preservation, stale and repeated actions, live presentation and 200%
phone layouts. Run genuine command-driven post-win construction and research
with invariants and repeatable traces

A separate Sol playtester uses a labeled near-win initial fixture, then actual
OS controls for victory, continuation, immediate quit/reload before another turn,
later construction and further turns. Inspect screenshots before naming evidence
and never retry a state-changing click blindly

## Time boundary and next phase

At **08:00 UTC / 4 PM Asia/Manila on 14 November 2026**, finish the one feature
task then in progress and start no additional feature tasks. Record unfinished
features for a later session. After that wrap-up, audit the entire game's implicit
state machines, debug as needed, improve responsiveness and review security and
privacy, particularly unnecessary personal-data collection or transmission

Defer sensor visibility/history separation and the complete beacon
restoration → usable link → transit/Noise package. Do not merge or deploy either PR
