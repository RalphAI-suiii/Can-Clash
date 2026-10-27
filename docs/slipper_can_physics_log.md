# Slipper and can physics pass — 2026-10-19

## What changed

- `scenes/slipper_visual.gd`: replaced the timed disappearing projectile with a persistent, owned slipper. Its fixed-step travel keeps the cursor aim, uses a gravity arc for height, damped spin, swept can contact, World-layer wall ricochet, floor bounce, friction, and a resting state. The original slipper silhouette stays the same size in flight and at rest. A ground shadow follows the track.
- `scenes/player_movement_neutral.gd`: release frame 2 launches one owned slipper using the existing 2.5-second charge. Speed rises from 260 to 540 pixels per second as charge fills; the arc also lasts longer. The thrower cannot launch another while that slipper is out. A nearby settled slipper shows `E  Pick up your slipper`, and only its owner can retrieve it. The eight existing release/aim rows remain the character art; down-left aim is mirrored while down-left release is not, and both up-left poses are mirrored so the arm points toward the cursor side.
- `scenes/taya_can.gd` and `scenes/Taya can.tscn`: the can now has a small physics footprint on the Can layer and collides with World-layer obstacles while moving. A valid slipper hit flips its state once, scales its fling and rotation with impact speed and charge, adds a short vertical pop, then damps floor and wall bounces into a settled sideways pose. Taya pickup waits until motion settles. Carry and reset behavior remains available. The original silver can texture and crop are unchanged; rotation keeps its bottom near the ground and its scale remains uniform.
- `scenes/Slipper can demo.tscn` and `scenes/slipper_can_demo.gd`: a focused preview with Player Neutral and a standing can. WASD moves, hold/release M1 throws, E retrieves the stopped slipper, and R resets the can for another local demonstration. R is preview-only. The existing Taya demo remains available.
- `scenes/taya_demo.gd`: shows `CAN MOVING` while an impacted can is still tumbling, then the pickup instruction when it settles.

## Verification in Godot 4.7.2

- The throw preview loaded for 120 headless frames without scene or script errors. The actual Player Neutral release animation created one slipper; a second charge was blocked until its owner used E to retrieve it, after which charging was available again.
- In the open preview at 490 pixels between actor and can, an immediate release stopped short; a full charge hit and toppled the can. Both slippers bounced and stopped. With the can placed closer, both charges hit: the weak hit's peak can speed was about 54 px/s and it moved 18 pixels, while the full charge reached about 298 px/s and moved 217 pixels. The can settled in both cases. Pickup by a non-owner failed.
- A World-layer wall reflected both a moving slipper and an impacted can. Taya's existing pickup and reset still succeeded with the new can body.
- Rendered six frames of a full throw, hit, can tumble, and settle. The can remains the same sprite and the slipper silhouette remains a single coherent shape. An eight-direction grid exposed two wrong left-diagonal mirror choices; they were corrected after comparing both aim and release poses.

## Review steps and limits

Open `scenes/Slipper can demo.tscn` and run that scene. Aim at the silver can, hold M1 for a full charge, then release. Watch the slipper deflect and come to rest while the can tips, travels, bounces, and settles. Walk to the slipper and press E; press R to stand the can back up for another preview. Try a short charge after moving closer. `scenes/Taya can demo.tscn` still exercises Taya pickup, carry, reset, and lunge.

This is a local mechanics pass. No five-player LAN authority, score award, power-up, or role-transfer ownership rule was added. The slipper checks the World layer for ricochets; any new obstacle must use that layer to participate. The rendered preview used a scripted charge and was visually inspected; continuous live mouse-and-keyboard play remains for the user to judge in Godot.

## Slipper silhouette pass — 2026-10-27

The procedural projectile now has a tapered heel, rounded toe, layered sole,
toe post, and split V-strap instead of the previous broad oval silhouette.
`draw_footwear` is shared by the thrown projectile and the possession icon,
so both show the same flip-flop design. Launch orientation points its toe along
the aim direction, and visual spin is slower so the straps remain readable.
The visual stays one size through flight, can impact, bouncing, and rest;
collision/scoring radii and travel physics were not changed by this pass.
`tests/slipper_shape_render.gd` generated `tests/slipper_shape_preview.png`
with grounded, flying, and special versions at game size and a 3× close-up.
The preview was inspected. Godot's slipper pickup and can impact smoke checks
passed; live input and a physical LAN view remain for in-game review.
