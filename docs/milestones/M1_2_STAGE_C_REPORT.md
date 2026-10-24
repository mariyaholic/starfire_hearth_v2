# M1.2 Stage C — display and scaling

**Status: validated for the next stage on the existing M1 lineage.** This
stage adds capability-gated display controls, reversible native window
changes, fine independent scaling and supported graphics settings. It does
not claim a physical Windows runtime gate.

## Implementation

- `app/display_settings.gd` is the display service and `DisplaySettings` is an
  autoload. It detects browser, headless and native backends before exposing
  native window modes, monitor selection or arbitrary desktop sizes. Browser
  fullscreen is exposed only when the page reports a user-gesture-capable
  `requestFullscreen` API; browser tabs never advertise monitor selection or
  native window modes.
- Native window requests use windowed, borderless and fullscreen on native
  backends; exclusive fullscreen is offered only when the backend identifies
  the Windows platform. Borderless fills the selected monitor while retaining
  the last windowed rectangle for restore. The service validates monitor and
  size inputs, recentres an off-screen saved rectangle on a reachable display,
  and persists resize/move/maximize state. Mode/monitor/size changes use an
  eight-second preview with Apply, Keep and Revert operations; focus loss,
  settings-screen exit and an unanswered preview restore the prior mode and
  rectangle.
- `app/settings.gd` now uses a versioned display section with defaults and
  sanitization for old or invalid values. Saving loads the existing
  `ConfigFile` first, so unknown keys and sections from newer builds survive a
  resave. Text, interface and render scales use independent five-percent
  steps and reset to their defaults. Render resolution, VSync, frame cap,
  anti-aliasing, orbit visibility and orbit opacity remain outside game saves.
- `settings_screen.gd` exposes those controls and hides unsupported native
  controls rather than presenting settings that a browser cannot apply. It
  includes manual width/height and maximize/restore controls. The existing
  appearance, view and quality controls remain separate from render
  resolution.
- `WorldViewportHost` applies the selected render scale where the backend
  supports it, and anti-aliasing to each production world `SubViewport` after
  mount and when settings change.
  Its metrics expose the actual viewport size, MSAA mode, quality stretch
  divisor and effective pixel ratio, without scaling the UI.
  Compatibility rendering reports 3D scaling as unsupported, so the settings
  screen hides the render-scale slider instead of exposing a no-op control;
  the production host still applies supported MSAA and quality stretch.
- `AppearanceProfileStore.set_component` now repacks supported component
  wrappers through `PresentationEnvelope.repack_component`, retaining unknown
  component-wrapper fields when a known road/orbit value changes. No road or
  orbit public API shape was changed.

## Revalidation evidence

The focused display tests pass **6 tests / 21 checks / zero failures** under
the headless backend:

```text
godot --headless --audio-driver Dummy --path . -s tests/run_tests.gd -- --filter test_display_settings
6 passed, 0 failed, 21 checks, 45 files
```

The same tests pass **6 tests / 34 checks / zero failures** under the available
Linux X11/llvmpipe smoke environment (`xvfb-run`), including actual native
preview expiry/Keep/recovery, invalid-monitor recovery, and production-world
SubViewport pixel-size and MSAA application. Compatibility correctly reports
render-scale as unsupported, so this smoke run does not claim a render-scale
change in the production world. That environment emitted a driver warning
that VSync cannot be changed, which confirms the capability operation is
attempted and rejected by the backend; it is not evidence of Windows
behavior. Settings-flow layout/audit tests pass in both headless and X11
smoke runs. The full headless suite passes **242 tests / 12,242 checks /
zero failures** across 45 files. Project import completes cleanly with Godot
4.6.3 after the archived fixture's `.gdignore` exclusion.

Physical Windows validation remains open. The service reports
`windows_runtime: unverified` on every platform until a physical runtime gate
is run. Browser fullscreen and WebGL behavior also require a browser
user-gesture run; no browser capability is inferred from the headless or X11
checks.

## Handoff

Stage D can rely on independent UI/text/render scales and the layout refresh
signal without mutating campaign state. Root's Stage F renderer can consume
`Settings.orbit_visible`, `Settings.orbit_opacity` and `Settings.reduce_motion`
while retaining its own saved orbital recipe and filtered projection.
