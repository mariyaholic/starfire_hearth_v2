# M1.1 Stage B — production foundation

Stage B is functionally validated on the existing M1 lineage. No new branch was
created. Source remains local and uncommitted; simulation rules and content are
unchanged. Stage C's native/browser validation follows this foundation checkpoint.

The application now owns session epochs, a bounded camera-state store, a shared
surface scheduler and an estimated-byte LRU texture cache. New games, loads and
returning to title invalidate the prior session. Worker retirement during navigation
does not join unfinished tasks; the application service drains cancelled tasks
after completion. Web generation uses the same pixel algorithm cooperatively.
Focus requests take priority, owners share pending work, and uploads reject obsolete
epochs and mismatched body profiles. Active cache pins protect displayed resources;
temporary quality-driven overruns are recorded rather than blocking the view.

GameScreen owns a persistent viewport host/controller independently of disposable
inspectors. The host follows a mount rectangle and clips to the current scroll
region without reparenting its scene. This preserves renderer, body and camera
identity through ordinary order refreshes and responsive relayouts. Navigation
releases inactive geometry, and returning restores the bounded session camera.
Overlay input is suspended. A presentation failure switches to Strategic while
preserving the current game and orders.

The snapshot builder copies permitted facts, adds session/viewer/disclosure/version
and revision metadata, and omits unknown systems' spectral/name/ownership details.
Selection intentions are rechecked against a fresh permitted description before
reaching the existing screen/command path. Appearance and quality preferences have
validated settings values and persistence; their player-facing controls arrive
with Stage C. Production System integration can be enabled with Appearance 3D;
the default remains Strategic at this intermediate foundation checkpoint.

Validation on 1 October 2026:

| Check | Result |
| --- | --- |
| Full headless regression suite | 180 passed, 0 failed; 3,360 checks, 34 files |
| Foundation regression tests | 6 passed, 45 checks |
| Data validation | 20 tables, 328 records, 1,376 strings; no errors or skipped checks |
| Worker/cooperative parity and cancellation | Passed |
| Epoch rejection, pinned LRU, bounded camera storage | Passed |
| Renderer/body/camera identity across refresh and relayout | Passed |
| Navigation restoration and Strategic fallback preserve state hash | Passed |

Commands, after sourcing `/workspace/.starfire-setup/activate.sh`:

```sh
godot --headless --path . --editor --import
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tests/run_tests.gd -- --filter test_world_foundation
godot --headless --path . -s tools/validate_data.gd
```

Evidence is copied to `starfire_3d_proposal/m1_1_stage_b/`. This checkpoint validates
foundation behavior, not visual finish or actual-device performance. Camera/anchor
save-envelope work remains Stage D, integrated colony planning Stage E, and the
finished art/accessibility pass Stage F. The Stage A memory/timing debt remains
tracked under the Owner's quality-first instruction.
