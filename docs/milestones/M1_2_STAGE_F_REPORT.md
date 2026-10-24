# M1.2 Stage F — Turn-driven orbital presentation

**Status: implemented and locally revalidated.** System-view planets now have saved,
identity-stable orbital recipes. Their positions derive from the campaign turn (one month), so
re-entering a system or loading a save reconstructs the same positions without an offscreen timer.
On a rendered system, a turn change eases planets from their previous positions to the newly
resolved ones. Planet markers, orbit-targeted ships and outposts follow their associated planet.

Recipes are presentation-only optional components in the existing graphics save envelope. Fresh
games get a versioned recipe. Existing saves without one retain their current layout until the
player chooses **Enable orbital motion for this save** from System → Scene controls. Unknown future
orbit components remain preserved by the save compatibility path. The renderer receives only the
selected known system and body records already allowed through the intel boundary.

The first version uses quantized circular, coplanar paths and a Kepler-inspired period from a
documented illustrative stellar-mass estimate and generated distance. Orbit visibility and
opacity follow the existing graphics settings and have controls in System → Scene controls.
Guides are closed unlit line meshes without collision areas. They are suppressed during
body closeups and restored in overview. The planet's material rotation remains independent.

The 4 October owner spacing correction derives wider display radii from the disclosed
snapshot, including gas-ring and belt extents plus a surface gap. It modifies a render
copy only: saved physical distances, phases, periods, epochs and identity stay intact.
The overview accounts for viewport aspect and near-side perspective after layout settles;
saved player cameras are retained. Visible turn motion follows a circular arc and attached
markers follow their parent body even with ambient effects paused or blocked by an
overlay. Asteroid belts share the same transition and focused-camera tracking path.

## Validation

- Orbital layout tests: **5 tests / 76 checks / zero failures**. Covers stable generation, distance
  and mass effects, turn positions/periods, disclosed-body filtering, save reload, explicit old-save
  migration, unchanged campaign hash, ring clearance, immutable saved clocks, initial
  camera framing, circular motion, closeup guide suppression, paused parent followers
  and focused asteroid-belt tracking.
- Actual updated [system overview](../../screens/m12_owner_revalidation/05_spaced_system.png)
  and [appearance controls](../../screens/m12_owner_revalidation/06_system_appearance_controls.png)
  captured with Godot 4.7.2 / llvmpipe.
- Full suite and fresh browser save/reload orbital-position checks are recorded in the
  [D–G follow-up report](M1_2_D_G_REVALIDATION_REPORT.md).

This is not an n-body model: binary systems use an effective mass, paths are circular and mostly
coplanar, and ship travel/combat rules are unchanged. Native Windows and physical browser behavior
were not exercised in the Linux cloud environment.
