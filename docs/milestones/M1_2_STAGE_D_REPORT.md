# M1.2 Stage D — Immersive workspace

**Status: implemented and revalidated; approved compact layout incorporated on 4 October 2026.**
The map occupies the main scene. A small summary card is the only default window;
selection opens a context card, and an empty construction queue becomes a status pill.
Manage, Research and the other tools open on request. Resources and End turn remain reachable.

Manage has Overview, Jobs, Governor and Shipyard tabs that reuse the existing model
and order handlers. Research shows one branch at a time. Desktop windows can coexist,
move, resize, minimize, dock and close. Escape closes the active window. Phone layouts
use one active scrollable sheet with the other tools accessible through the dock.

Workspace version 2 migrates untouched oversized v1 defaults to the summary layout.
Custom window geometry is retained and clamped to the available viewport. Layout
remains device-local in `user://immersive_workspace.cfg`; unknown fields are retained
and workspace preferences do not enter campaign saves.

Matte, Frosted and Glossy finishes are available in Settings and Scene controls, with
opacity, blur, gloss and edge sliders. Frosted is the default. High contrast uses an
opaque surface. Real frosting samples only the renderer's 3D scene texture; text,
buttons and other windows are excluded from the sampled texture. Settings are
sanitized and device-local. Changing the finish retains the renderer, pending orders,
campaign hash and saved appearance recipes.

## Validation

- Focused Immersive integration/workspace tests: **8 tests / 144 checks / zero failures**.
  Covers actions, camera and renderer continuity, layout migration, persistence,
  unknown-field retention, compact sheets, 100–200% text and appearance preferences.
- Full suite and latest actual browser input/save checks are recorded in the
  [D–G follow-up report](M1_2_D_G_REVALIDATION_REPORT.md).
- Actual production captures: [default city](../../screens/m12_owner_revalidation/01_compact_city_default.png),
  [selected building](../../screens/m12_owner_revalidation/02_compact_city_inspector.png),
  [Jobs window](../../screens/m12_owner_revalidation/03_management_jobs.png) and
  [Research tabs](../../screens/m12_owner_revalidation/04_research_tabs.png).
- Actual finishes: [Matte](../../screens/m12_owner_revalidation/07_matte_actual.png),
  [Frosted](../../screens/m12_owner_revalidation/07_frosted_actual.png),
  [Glossy](../../screens/m12_owner_revalidation/07_glossy_actual.png).

Cloud native screenshots use Godot 4.7.2 and Mesa llvmpipe. Browser/phone checks use
software WebGL and touch emulation. Physical-device performance remains to be reviewed.
