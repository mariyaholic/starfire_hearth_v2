# Design log

Decisions the brief left open, each with a one-line reason. Newest last. Anything here can be
overruled by the Owner; overruled entries are struck through, not deleted.

## M0

1. **Godot 4.7.2-stable is pinned.** It was the latest stable 4.x release on 2026-09-24 (4.8 is
   not out); the brief asks for the latest stable, 4.3 or newer.
2. **Fonts: IBM Plex Sans 1.1.0 and IBM Plex Mono 2.5.0**, Regular, Medium and SemiBold of each.
   These are the current official releases; the three weights cover the type scale of §8.5.
3. **Licence is "All rights reserved"** until the Owner picks one, as the brief instructs.
4. **Fixed-point rounding floors toward negative infinity** (`Fx.div_floor`, `Fx.mul_bp`). One
   rule everywhere makes breakdown lines sum exactly to their totals.
5. **Units.** Resources, rates and combat stats are centi-units; percentages are basis points;
   lane lengths are centi-light-years; counts (pops, turns, stability and opinion points) are
   plain integers. Everything in state is an integer.
6. **RNG seeding.** The four inputs (seed, turn, stream, salt) are folded with MurmurHash3's
   `fmix32` and `mul32` into one 32-bit key; splitmix32 (golden-ratio increment, fmix32 output)
   expands it into the four xoshiro128** words. Streams are stateless, so nothing about RNG is
   saved; `rng_meta` in a save only names the algorithm. Test vectors come from an independent
   arbitrary-precision reference implementation and include the published xoshiro128** vector for
   state {1, 2, 3, 4}.
7. **`RngStream.range(lo, hi)` is inclusive at both ends** and uses rejection sampling, so it is
   unbiased. String salts use FNV-1a (`Rng.salt_of`), because the engine's `hash()` may change
   between versions.
8. **Canonical JSON is a small custom writer** (sorted keys, no whitespace, integers only). A float
   anywhere in state is an error, so the state hash doubles as the "every value is an integer"
   invariant.
9. **Simulation code iterates collections in sorted-id order** (`DictIO.sorted_keys`), and ids are
   zero-padded (`col_0001`), so a loaded game and a live game visit entities in the same order.
10. **Scripts must be imported before headless runs.** Godot registers `class_name` types during
    the editor's import scan, so CI and the README run `godot --headless --import` first.
