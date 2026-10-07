# M1.1 F.1 — Command / Immersive view

The Owner approved this addition after the Stage F review and before Stage G.
Work remains on the existing pinned M1 checkout, without a new branch, commit,
push, merge, tag or deployment. Stage G has not started. This report describes
the completed implementation and its review evidence, dated 2 October 2026.

**Checkpoint status update (2 October 2026):** Stage G has since been run locally.
Its automated campaign, exports, lifecycle and browser evidence, together with the
remaining Pending gates, are recorded in [the M1.1 report](M1_1_REPORT.md) and
[Stage G report](M1_1_STAGE_G_REPORT.md). Owner art/playtest and physical-device
acceptance remain open.

## What the player gets

**Command** retains the existing information-first game screen: resource readouts,
navigation, advisor, colony statistics, planner, inspectors and queues.
**Immersive** gives the Galaxy, System or Colony map almost the entire screen, with
a compact resource strip and a short toolbar. The same city, planets, ships and
outposts become the main visual surface of play, using Stage F's current material
finish and mesh LODs. The player switches with the view button or F10; Settings
also exposes the two named choices. Command remains the default for missing or
unknown preferences.

Select a permitted parcel, planet, ship or facility to open its existing inspector.
The dismissible panel supports real construction and space orders, costs,
refusals, previews and queue controls. Management opens colony statistics, queues,
jobs, governor, shipyard when available, colony selection and empire navigation.
Objects supplies accessible named body choices and canonical parcel numbers.
Scene controls expose overview/reset, pause, daytime/dusk, parcel outlines,
Strategic fallback, supported finish upgrades and Auto/Low/Standard quality.
The advisor remains reachable through Manage. End Turn, Undo, all resources,
Noise/date, save/load, settings and the menu remain available.

Desktop and landscape use a side panel; portrait uses a bottom dock. Panels can
be closed to expose the full map. Controls intercept input only within their own
rectangles, allowing camera use in the remaining map area. Back/Escape closes
an open context panel before opening the game menu. Pointer orbit, Shift-drag or
middle-drag pan, wheel zoom, keyboard object selection and Home/reset complement
touch orbit and pinch zoom. Camera panning is bounded; this is a view of M1's
existing region, not a freely walking or unlimited city simulation.

Research, ordinances, market and objectives use their existing dedicated management
screens. Returning to a map restores Immersive and the session camera. Owned
outpost summaries and Strategic use the readable Command layout while keeping the
layout preference for the next supported 3D map. Unknown intel stays filtered by
the same VisualSnapshotBuilder and WorldViewController permission checks.

## Richness and cost

Layout and rendering quality are independent. Standard renders the enlarged city
viewport at its full scene resolution (stretch shrink 1) with 2x MSAA and the
existing distance-based high-detail
meshes; planet focus continues to refine its saved surface. Low and conservative
Auto phone/Web profiles remain selectable. Entering Immersive does not silently
change quality, reroll the world or add decorative buildings that impersonate
actual development. A larger viewport renders more pixels and permits closer
inspection of Stage F detail; this does not claim a new photorealistic art library.

The temporary performance allowance still applies. Software OpenGL/SwiftShader
runs demonstrate function and layout, not real-device frame rate. Target-device
GPU performance, memory/texture compression, sustained switching and the complete
campaign/export matrix remain Stage G. Artistic acceptance remains the Owner's
review decision.

## Architectural and persistence contract

`Settings.view_mode` accepts only `command` and `immersive`. It is a device-local
`display/view_mode` preference in settings.cfg, independent of `appearance` and
`visual_quality`. Web also writes the scalar choice immediately to origin-local
browser storage (`starfire_hearth.view_mode.v1`): closing the page need not wait
for asynchronous user:// synchronization. Storage-denied browsers retain the
settings-file fallback and remain playable. Loading an older config with no key, or an unknown future value,
uses Command and retains other valid settings. It is deliberately absent from
GameState, command queues, save schemas and graphics envelopes: a save can travel
between devices with different layouts without changing its geography or look.

GameScreen composes either the existing screen or ImmersiveWorldView. The latter
owns a mount rectangle, toolbar and disposable context controls. Both compositions
attach to the same persistent WorldViewportHost. Mode switches retain the live
renderer instance, selected object, camera, light/outline/pause state and pending
orders. Context refreshes change UI around it; construction and space commands
still go through the existing M1 inspectors and Game.submit path.

ColonySpatialView shares preview, selection synchronisation and parcel selector
helpers between layouts. SystemSpatialView shares inspector construction. The
immersive composition does not implement another rules engine, independent state
or a second graphics generator. Existing physical and material catalog versions
remain unchanged. Stage D/F graphics compatibility boundaries therefore still
apply, including the original M1 executable dropping graphics metadata on resave.

The viewport sits behind transparent Immersive layout containers; the UI is drawn
and hit-tested above it. Host clipping remains limited to the active map rectangle.
Contexts fit the visible map rectangle after container reflow, including landscape
phones whose content starts taller than the final viewport. This prevents controls
from falling behind the toolbar. Context scrolling prevents long inspectors from
expanding the viewport. Quality
changes can restore a close camera before asynchronous terrain exists; the finish
LOD path tolerates that interval and applies the requested detail when the terrain
arrives. Rendering
failure returns to Strategic while retaining the device's layout preference.

## Revalidation

- Full regression: **219 tests / 12,015 checks / 41 files**, zero failures.
  The new integration checks exercise old/missing/future settings, repeated layouts,
  retained renderer/camera/orders, F10 and Escape from a focused map, management
  return, Strategic failure fallback, asynchronous close-camera quality changes, and
  clipped phone context/quality-control reachability in both orientations at 100/200%.
- Native software OpenGL tour: **319 checks**, zero failures or runtime
  errors; **30 audited layout/context cases**, zero audit issues.
  Actual GUI input orbits and pans city and space. Existing controls build, Rush,
  Cancel/Undo, complete construction, upgrade and demolish/Undo in both layouts.
  Both tours produce identical gameplay/geography. A real Survey starts from the
  planet inspector. Save/load retains state, graphics, clearings and anchor.
- Actual non-threaded Web export: **127 checks** across desktop mouse and emulated
  phone touch, zero engine/script errors. Real canvas controls select a parcel,
  preview/place construction, Cancel/Undo, preserve its queue through both modes,
  and resolve turns against pure simulation. Orbit/pan and pinch pass. Save/load
  and destroying/recreating the page retain gameplay, geography, graphics and the
  device-local layout. Standard remains independently selectable at full resolution.
  Portrait context and close controls also pass at 200% text.
- **42 fresh in-game PNGs** cover the same-city layout comparison, contextual
  construction/management, current developed-city fixture, system/planet/galaxy,
  desktop and landscape/portrait phones at 100/200% text. The first comparison pair,
  developed city and native space references use Standard. Functional context and
  layout matrices also use Low. Fixtures expose legitimate unlocked controls and
  catalog art; they are labelled separately from normal campaign progression.

The map rectangle's share of the full native screen, with contexts closed:

| Layout | 100% text | 200% text |
| --- | ---: | ---: |
| Desktop | 91.11% | 86.67% |
| Phone Landscape | 69.20% | 67.17% |
| Phone Portrait | 85.43% | 84.47% |

Opened contexts overlay this rectangle rather than resize the scene: up to 40% of
its width on desktop, 48% in phone landscape, or the lower 46% in portrait. Closing
one exposes the map. Compact controls retain at least 48dp touch targets. Phone
landscape deliberately spends more height on readable/touchable HUD controls.

The native software-rendered tour took **562.3 seconds**, with
peak child RSS **878.0 MiB** including rendering
and screenshot readback. Native and browser software rendering overlapped during
this tour; this is an environment measurement, not an isolated benchmark or target-device
frame-rate or memory certification. The approved temporary performance allowance
continues; physical GPUs and sustained campaign/resource profiling remain Stage G.

Commands and logs are reproducible through `docs/M1_1_CLOUD_SETUP.md`. The review
includes the completed native/browser evidence, regression log, fresh playable Web
export and complete source patch against the unchanged pinned M1 commit. Portable
ZIP integrity, all picture links, phone/desktop report and comparison-slider layout,
SHA256 manifest and clean-baseline patch applicability are checked separately.
Technical checks do not replace the Owner's artistic review or Stage G certification.

## Stage G additions

Include Command and Immersive in the full title-to-debrief playthrough, physical
desktop/mobile device profiles and release exports. Repeated switching must cover
both layouts, dedicated management screens, context opening/closing and save/load;
measure target-GPU memory, job/resource trends, frame time and input latency. Review
map framing, panel visibility, resource/toolbar clarity and close-view material
finish with the Owner before claiming M1.1 accepted.
