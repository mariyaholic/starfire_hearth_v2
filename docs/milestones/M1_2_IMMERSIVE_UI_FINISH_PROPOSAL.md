# M1.2 Immersive UI and surface finish proposal

Prepared for owner visual review, 4 October 2026. **Owner approved; core layout and
finish settings are now implemented.** Latest validation is in the
[D–G revalidation report](M1_2_D_G_REVALIDATION_REPORT.md).
The comparison images below remain generated design mockups with illustrative
gameplay values. Actual production screenshots are linked separately at the end.

## Proposed default layout

Give the scene approximately 75–80% of the desktop composition while keeping
resources, navigation, orders and End turn immediately reachable.

- Keep the slim resource/time HUD at the top; add a short system/colony breadcrumb.
- Replace the large default Manage window with a small colony summary containing
  population, stability and a clearly labelled Manage button.
- Show a compact context card only when a building, parcel, planet or ship is
  selected. Size it to its content. A blank selection must not create a tall panel.
- Collapse an empty queue to a labelled status pill. A populated queue can expand
  into a short strip and an on-demand window, keeping existing order controls.
- Use a compact bottom dock with icons and text for Build, Manage, Research,
  Policies, Fleet and Objectives. Keep Command view, Undo and End turn separate.
  Galaxy/System/Colony remain visible navigation choices or breadcrumbs.
- Keep camera reset and scene tools at the edge. Avoid controls over selected
  buildings, planets and the main camera target.

Manage opens a tabbed window for Overview, Jobs, Governor and Shipyard instead of
putting the entire colony screen in one long panel. Windows remain movable,
resizable, dockable and minimizable; several useful windows can coexist. Initial
size fits the current content rather than a fixed fraction of the full height.

Research, policies and other detailed tools open on request. Research can use a
compact category/tab view and expand into a larger workbench when the player
chooses. Closing it restores the open scene immediately. Empty/default windows
should not remain beneath it and consume the rest of the map.

On phones, retain a compact labelled dock and one active bottom sheet, with text
scale and reachable touch targets respected. The same order handlers and intel
rules continue to apply in both layouts.

## Finish settings to compare

| Finish | Intended appearance | Proposed initial settings |
| --- | --- | --- |
| A — Matte | Quiet navy cards; strongest visual separation and lowest rendering cost | 100% opacity, no blur, no gloss |
| B — Frosted glass | Smoked blue glass; diffuse scenery behind the card with readable solid text | 82% opacity, 8 logical pixels blur, 10% gloss, 15% edge highlight |
| C — Glossy glass | Polished smoked glass with a restrained title-edge sheen | 75% opacity, 4 logical pixels blur, 25% gloss, 25% edge highlight |

Recommend B as the Immersive default and retain A as a one-click option. C is an
optional visual preference. Layout and action availability must remain identical
across finishes.

Expose Interface appearance independently from world lighting/material quality:

- Finish: Matte / Frosted / Glossy.
- Panel opacity: 70–100%, with a visible live preview.
- Blur: 0–16 logical pixels; unavailable quality/backend options are labelled.
- Gloss: 0–30%; affects a quiet title/edge sheen, never the text layer.
- Edge highlight: 0–30%.
- High contrast: nearly opaque panels with subdued decoration and crisp text.
- Reset to preset and Reset interface layout are separate actions.

Text, icons and meaningful buttons stay fully opaque. Gloss must not put a bright
reflection over labels. Avoid moving shine, scanlines or animation that distracts
from orders. Preserve reduced-motion settings. Apply a minimum contrast treatment
on bright terrain; sliders must not make controls unreadable.

## Implementation and optimization follow-up

1. Adjust ImmersiveWorkspace defaults and context/queue behavior; reuse existing
   command handlers. Add explicit workspace-version migration so old oversized
   defaults do not silently reappear and player custom layouts remain recoverable.
2. Give ImmersivePanel a shared surface theme and the smaller summary/context
   components. Keep Escape, input capture and persistent reachable turn controls.
3. Add sanitized device-local finish settings with old-file defaults and unknown
   field retention. Finish choice must not enter campaign saves or alter appearance
   recipes or simulation state.
4. Real frosting now samples the existing 3D SubViewport texture before UI
   composition. Each visible card uses nine scene samples and clips to its own
   rounded bounds. UI/text never enters that texture. Matte/high contrast disable
   sampling; a missing scene uses the same tint. A shared downsampled/separable
   blur remains an optimization candidate if hardware profiling justifies it.
5. Revalidate text/contrast on bright city terrain and dark space, small viewports,
   large text, draggable windows, scale changes, intel filtering and save/load.
   Measure blur cost before picking automatic quality fallbacks.

## Comparison images

The city variants use the same compact layout and selected habitation scene so
the finish differences can be compared. The space mockup shows the proposed
appearance controls. Files are local proposal artifacts:

- [A — Matte](../../screens/m12_immersive_ui_proposal/A_matte_city.png)
- [B — Frosted glass](../../screens/m12_immersive_ui_proposal/B_frosted_city.png)
- [C — Glossy glass](../../screens/m12_immersive_ui_proposal/C_glossy_city.png)
- [D — Space and appearance controls](../../screens/m12_immersive_ui_proposal/D_space_settings.png)
- [E — Jobs window opened on demand](../../screens/m12_immersive_ui_proposal/E_manage_window.png)

Implemented production comparison (actual runtime screenshots):
[city default](../../screens/m12_owner_revalidation/01_compact_city_default.png),
[Jobs window](../../screens/m12_owner_revalidation/03_management_jobs.png),
[Research tabs](../../screens/m12_owner_revalidation/04_research_tabs.png),
[spaced system](../../screens/m12_owner_revalidation/05_spaced_system.png),
[Matte](../../screens/m12_owner_revalidation/07_matte_actual.png),
[Frosted](../../screens/m12_owner_revalidation/07_frosted_actual.png) and
[Glossy](../../screens/m12_owner_revalidation/07_glossy_actual.png).

The exact mockup dock labels and breadcrumb decoration remain design references.
The implemented dock uses the existing game tools and navigation labels. Performance
of the glass finishes has not yet been measured on owner hardware.
