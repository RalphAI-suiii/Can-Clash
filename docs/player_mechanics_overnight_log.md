# Hat Thrower movement and throw log — 2026-10-18

Branch: `feature/player-movement`
Scene: `scenes/Player movement neutral.tscn`
Status: local changes only; no commit or push.

## Changes made

1. **Cursor-accurate throws.** The character still selects one of the eight existing aim and release animations. The projectile now uses the full normalized vector from the character's throwing point to the cursor, so it can fly between those eight visual directions. Its start offset shortens for close targets, keeping the cursor on the flight line. The aim direction is locked when the mouse button is released.
2. **Charge strength.** Holding M1 fills the charge bar over the existing 2.5 seconds. Charge now raises slipper speed from 260 to 540 pixels per second and lifetime from 0.58 to 0.86 seconds. The approximate unblocked travel range therefore rises from 151 to 464 pixels. The bar becomes brighter as it fills, and a full charge gets a stronger trail and faster spin. Projectile size stays fixed.
3. **Throw feedback and direction.** Kept the existing four-frame charge and four-frame release drawings for each of the eight directions. Mirrored the down-left artwork because that row pointed right. Added a short launch burst, warm motion streaks, a subtle glow, and an end-of-flight fade to the drawn slipper. Aim and release use separate per-direction scales so their visible heights remain close to 200 pixels and their feet stay anchored when the animation changes.
4. **Sprint dust.** Added short-lived, tan dust puffs alternating beside the feet while Shift is held and the character is moving at sprint speed. The puffs stay in world space, drift backward, and fade out. They stop being emitted when sprinting stops or the player begins charging.

## Files changed

- `scenes/player_movement_neutral.gd` — aim vector, charge strength, visual pose sizing, and dust emission.
- `scenes/slipper_visual.gd` — powered flight appearance, spin, and fade.
- `scenes/sprint_dust.gd` — new dust puff drawing and lifetime.
- `scenes/throw_burst.gd` — expanding release ring and forward sparks.
- `docs/player_mechanics_overnight_log.md` — this log.

## Review notes

- The existing throw sprite sheets were inspected: right, left, up, and up-diagonal rows are used in their matching directions. Down-left now mirrors its source pose so the head, body, and pointing arm face left.
- The slipper remains a visual projectile. The 3D slipper placeholder in `game/slipper/` has no 2D collision or damage implementation, so this work does not add damage, hits, or LAN replication. Charge strength currently changes flight speed, travel distance, spin, and effects.
- The project has existing unrelated uncommitted files. This work changes only the files listed above.
- Godot playback was **not** verified. Automatic approval review rejected launching the Godot editor because it may modify project import/cache state and treated verification as requiring separate explicit authorization. Static scene, script, sprite-frame, and resource references were inspected instead.

## Manual playback checks

1. Run `scenes/Player movement neutral.tscn`. Hold M1 and move the cursor through all eight sectors; the body should face the selected sector. Down-left should point left.
2. Release M1 while aiming between two sectors. The body should use its nearest eight-direction pose while the slipper travels exactly along the cursor line.
3. Compare an immediate release with a full 2.5-second charge. The full throw should move faster, fly farther, spin faster, and show a brighter trail. The slipper itself should remain the same size.
4. Hold Shift while moving with WASD. Dust should appear by alternating feet and stop when sprinting or movement stops.
5. Compare idle, charge, and release in each direction. The player's apparent height and ground contact should remain steady.

## Visual effects follow-up — 2026-10-18

- Enlarged each sprint dust puff from three small circles to five outlined, tan clouds. Each cloud starts roughly 75 pixels wide, expands past 100 pixels, lasts 0.52 seconds, and drifts behind the runner. Puffs still alternate by foot and emit about every 0.16 seconds while sprinting.
- Added a separate throw burst at the release point: an expanding orange and cream ring with directional sparks. The burst stays at the hand while the slipper flies away.
- Made the slipper trail longer and brighter, with a tapered warm streak, a bright inner line, and side streaks. More charge strengthens the trail; the slipper drawing itself remains the same size.
- Godot playback remains unverified because the automatic approval review rejected launching the editor. The new effects were inspected in source only.

## Taya follow-up — 2026-10-18

- Replaced the five visible dust circles with a single smooth, connected cloud silhouette for each puff. The full Taya implementation and its new sprite sheets are recorded in `docs/taya_mechanics_log.md`.
