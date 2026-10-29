# Taya can interaction and animation log — 2026-10-18

## Design reference

`docs/Can_Clash_Concept_Note_Draft.docx`, `docs/Can_Clash_Concept_Note.docx`, and `docs/Can_Clash_Game_Concept.docx` agree on the can loop: Taya approaches a toppled can, presses Interact to pick it up, carries it to the marked base at reduced speed, presses Interact again to stand it upright, and cannot lunge or tag until reset. The lunge has a proposed 10-second cooldown. The documents say the host must validate these outcomes in the eventual LAN match.

## Implemented

1. Changed sprint dust from five separate drawn circles to one connected scalloped cloud silhouette per puff. A smooth polygon supplies the outline and warm fill, expands while fading, and keeps the existing alternating-foot emission and backward drift.
2. Created new transparent Hat Thrower artwork for pickup and placement, carrying in front/right/back/diagonal directions, and wind-up/extended lunge poses. Added a separate silver can sprite. The source sheets stay intact; the drawing code selects atlas cells and uses measured per-frame foot baselines so the character remains close to the existing ~200-pixel apparent height and the feet remain planted.
3. Added a local 2D can with `STANDING`, `TOPPLED`, and `CARRIED` states. Pickup requires a toppled can within 60 pixels. Reset requires the same carrier within 62 pixels of the marked base. Carrying hides the world can; placing reveals it upright at the base. Losing Taya while carrying drops the can.
4. Added Taya role behavior to the existing Hat Thrower player script. E triggers the pickup and placement sequences, and prompts appear near the character. Taya cannot use the slipper throw. Carrying speed is 68 pixels per second and Shift cannot increase it; ordinary walk and sprint values resume once the can is placed. Sprint dust is suppressed during carrying.
5. Added a Space lunge after reset. The lunge finds the nearest eligible thrower within 260 pixels, turns toward that thrower during the dash, and travels up to 210 pixels over 0.30 seconds after a 0.13-second wind-up. When no thrower is close, it aims at the mouse, then falls back to the facing direction. It uses direction-matched wind-up and extension drawings and has a 10-second cooldown. Left-facing drawings mirror their right-facing counterparts. `can_tag()` and `can_lunge()` gate actions on a standing can; contact within 54 pixels of a node in the `throwers` group emits one `tag_requested` signal upon entry into range. The lock and tag checks ignore targets inside the configured toe-line safe strip.
6. A flying 2D slipper checks its path segment against standing 2D cans and topples a can on contact, including fast steps that might skip over its center. The existing visual projectile does not bounce or handle score.
7. Added `scenes/Taya can demo.tscn`, with a toppled can, gold reset marker, on-screen instructions, a stationary Head Band thrower target, a tag notice, and a demo-only T key to topple the can again at its original location. The project's startup scene now opens this demo. The old `scenes/Player movement neutral.tscn` remains available and its thrower behavior is retained when `is_taya` is false.
8. Reused the connected cloud dust effect for lunge takeoff and landing. Three larger puffs appear at the feet as motion begins, and four wider puffs appear when Taya lands or hits an obstacle. The puffs spread sideways, drift, and fade separately from sprint dust.

## Controls in the demo

- WASD: move.
- Shift: sprint only when not carrying.
- E: pick up when close to the toppled can; stand it upright when close to the base.
- Space: lunge after the can is reset and the cooldown is ready. A nearby thrower is acquired automatically; otherwise point the mouse. The reach is set in screen pixels because this 2D project has no established meters-to-pixels scale. Its 210-pixel travel is about one character height.
- T: topple and reposition the can for another local preview cycle. This key is demo-only.

## Files

- Updated: `project.godot`, `scenes/Player movement neutral.tscn`, `scenes/player_movement_neutral.gd`, `scenes/slipper_visual.gd`, `scenes/sprint_dust.gd`, `docs/player_mechanics_overnight_log.md`.
- New scripts/scenes: `scenes/taya_visual.gd`, `scenes/taya_can.gd`, `scenes/taya_base_marker.gd`, `scenes/taya_demo.gd`, `scenes/Taya can.tscn`, `scenes/Taya can demo.tscn`.
- New images: `assets/characters/sprites/taya/hat_thrower_can_lift_place.png`, `hat_thrower_carry_cardinal.png`, `hat_thrower_carry_turns.png`, `hat_thrower_carry_back.png`, `hat_thrower_lunge.png`, `tin_can_upright.png`.

## Asset generation prompts and method

All six transparent raster assets were generated with the built-in image generation tool using the existing Hat Thrower sprite as the identity and style reference. The pickup sheet prompt requested eight front-facing key poses from neutral through crouch, grasp, lift, carry, crouch, set down, and rise. The carrying sheets requested can held in both hands at chest height, grounded steps in cardinal and diagonal orientations, and a separate rear-view walk with the can visible beside the torso. The lunge sheet requested four facing directions with both wind-up and extended poses. The can prompt requested one plain silver cylindrical street-game tin with a dark rim and thick cartoon outline. All prompts required true transparency, no added text, coherent proportions, no disconnected body parts, and consistent feet baseline. The generated sources were copied into the project under `assets/characters/sprites/taya/`.

Final prompt set, condensed to its asset instructions:

- `hat_thrower_can_lift_place.png`: “Same Hat Thrower identity and style; transparent four-column, two-row sheet. Front-facing neutral, crouch/reach, grasp tin, rise with tin; then carry, crouch, set tin upright, rise. Grounded feet, connected anatomy, consistent size.”
- `hat_thrower_carry_cardinal.png`: “Same Hat Thrower holding a silver can at chest height with both hands; transparent front, right profile, rear, up-right, and down-right carry poses with grounded walking steps. Keep the can visible.”
- `hat_thrower_carry_turns.png`: “Eight transparent carry-walk key drawings for down-right, up-right, right, front, and mirrored left-facing counterparts; can steady in both hands, logical leg movement, stable body size.”
- `hat_thrower_carry_back.png`: “Four grounded rear-view carry frames of the same Hat Thrower; can visible at the right side, neutral and alternating walking steps, coherent hat and feet.”
- `hat_thrower_lunge.png`: “Four directions (front, right, rear, down-right), each with low planted wind-up and extended full-body lunge key pose, all the same Hat Thrower, no can or slipper.”
- `tin_can_upright.png`: “One plain silver cylindrical Tumbang Preso tin can, dark top rim, thick cartoon outline, transparent background, readable at small game size.”

## Integration notes

- This is the playable local 2D Taya prototype. The existing `game/can/can.gd` and `game/can/can.tscn` are 3D stubs, so they were not used in the 2D player scene.
- The LAN match must listen for `tag_requested`, validate it on the host, transfer roles, and award points once. The signal deliberately does not award a local point or force a client-side role swap.
- The project's current slipper is a visual 2D projectile. The new can hit detection topples a standing can, but ricochet, authoritative hit/scoring validation, and projectile ownership are still part of match integration.
- The generated character sheets have no separately editable limb layers. They are discrete full-body drawings selected at 6 frames per second for carry movement and timed key poses for interaction/lunge.
- At the initial Taya pass, Godot playback was not run because an automatic approval review rejected launching the editor. The later eight-direction animation pass imported assets and loaded both relevant scenes; see its checks below.

## Manual playback path

Open the project and run `scenes/Taya can demo.tscn`. Move near the fallen can until `E  Pick up can` appears, press E, walk to the gold marker, and press E again. While carrying, verify the can remains in the character's hands in each direction, walking is slower, Shift does not accelerate, and Space cannot lunge. After reset, approach the Head Band target on the right, aim the mouse away from it, and press Space. Taya should curve toward the nearby target, show cloud dust at takeoff and landing, and display `TAG!` on contact. Move away from the target and try Space again after cooldown to see mouse-directed lunging. Press T to repeat the can loop. Run `scenes/Player movement neutral.tscn` separately to check the joined sprint cloud puffs and unchanged thrower controls.

## Eight-direction lunge animation — 2026-10-18

- Added five transparent four-pose sheets for right, down-right, down, up-right, and up. Each has a planted wind-up, driving step, extended reach, and planted recovery. The corresponding left directions mirror the rightward sheet, so every one of the eight aim sectors has a direction-correct head, torso, arm, and foot pose. The up diagonals now use rear three-quarter art instead of the straight-back pose.
- `taya_visual.gd` selects tight atlas regions for each drawing, including poses that extend past the midpoint of their generated sheet. Each full-body pose is centered, its lowest shoe is placed at the character origin, and its screen height is normalized to roughly 184–200 pixels. The renderer changes key poses at 0.13 and 0.22 seconds; landing begins a 0.20-second recovery. The scene still draws every display frame, including at 60 FPS, without changing lunge travel or gameplay timing.
- `player_movement_neutral.gd` now tells the visual when the actual lunge lands, so recovery begins immediately on tag, obstacle, or maximum reach. Launch and landing dust still come from the same movement events.
- Added `scenes/Taya lunge preview.tscn` to loop all eight animations together without waiting for the gameplay cooldown. This is an art preview, not a match rule scene.
- New project assets: `assets/characters/sprites/taya/hat_thrower_lunge_{right,down_right,down,up_right,up}_4.png`. The original two-pose sheet remains as a source reference.

The five new sheets were made with the built-in image generation tool, using `hat_thrower_lunge.png` as an identity and style reference. Each prompt required the same Hat Thrower costume and proportions, full connected body, thick black outlines, true transparency, four separated poses, a consistent foot baseline, and no text, extra limbs, can, or slipper. Direction-specific prompts required direct-down front view, direct-right side profile, direct-up back view, down-right front three-quarter view, and up-right back three-quarter view respectively. Source images were copied into the project unchanged; atlas regions, display size, and feet alignment are set in Godot code.

Static inspection confirmed four isolated opaque character components in each sheet and measured their atlas bounds. Godot 4.7.2 imported all five new sheets, loaded `scenes/Taya lunge preview.tscn` and `scenes/Taya can demo.tscn` headlessly for 100 frames each, and produced a 38-frame rendered preview. The captured wind-up, first step, reach, recovery, and restart were visually inspected; all eight directions stayed grounded and the preview loop no longer flashed to the carry pose. A looping GIF is saved at `C:/Users/User/Documents/ChatGPT/CanClash 2/taya_lunge_work/Taya eight-direction lunge preview.gif`. The lunge was not exercised with real input against a moving target, so gameplay contact and dust timing still need in-game review. During editor startup Godot reported an unrelated shader compile error in the existing `ui/main_menu/*shader` code.

## Player body collisions — 2026-10-18

- Put both reusable movement scenes on the Player physics layer with a World + Player mask. Their existing 27-pixel circles remain at the feet, so character art does not form an oversized obstacle and player instances block one another.
- Changed the stationary Head Band thrower in `scenes/Taya can demo.tscn` into a StaticBody2D with the same feet circle. Taya now collides with this target instead of passing through its visual.
- A Taya body contact with an eligible thrower now emits the existing `tag_requested` signal even when physics stops movement just outside the 54-pixel center-distance check. Safe-strip and can-standing checks still apply. This remains a local signal for later host validation, not a local role or score change.
- Verification: Godot 4.7.2 loaded the demo for 100 headless frames with no scene or script errors. A local physics check moved Taya into the thrower target, then into a second instance of the playable player scene. Both contacts stopped at 54.53 pixels between origins; the target contact emitted one tag request. Real keyboard/mouse gameplay and network behavior were not exercised.

## Lunge collision exception — 2026-10-19

- Normal player collisions remain active. A lunge can temporarily ignore its locked thrower when its remaining reach can carry Taya all the way past the thrower. Taya tags through the existing request signal while crossing, does not steer back toward the thrower after reaching them, and lands beyond their body. A short lunge still stops at the near side. Collision is restored on landing or if Taya's role changes during the lunge.
- Godot 4.7.2 loaded `scenes/Taya can demo.tscn` for 100 headless frames. Local physics checks covered a 130-pixel close lunge, a 200-pixel short-reach lunge, and another player standing in the path. The close lunge crossed the locked target and landed 80 pixels beyond it with one tag request; afterward, walking back into the target was blocked. The short-reach lunge landed 56 pixels before the target with one tag request. The other player blocked the lunge about 119 pixels before the locked target, with no tag request. No scene or script errors were reported. Real keyboard/mouse and network play remain unverified.

## Head Band as a player and visual spacing — 2026-10-19

- Replaced the demo's standalone Head Band sprite and StaticBody2D with an instance of `scenes/Head_Band.tscn`, a CharacterBody2D with its own idle/walk/throw animations and charge UI. The demo instance does not read the shared keyboard, so Taya remains the locally controlled actor. The root is now positioned at the character's feet, matching the Taya player origin.
- Enlarged the shared prototype and Head Band circular body colliders from 27 to 65 pixels, with a 132-pixel Taya tag distance. The screenshot showed the previous narrow colliders allowed the shoes and torsos to visually merge. The 300-pixel lunge reach lets a close Taya pass the tagged player and land clear of the larger body; ordinary movement and short lunges remain blocked.
- Godot 4.7.2 loaded the updated demo for 100 headless frames. Physics checks confirmed that a 140-pixel close lunge crossed the player, landed 160 pixels beyond with one tag request, and restored normal collision; a 200-pixel lunge stopped 134 pixels before the player with one tag request; a third player blocked a lunge without a tag. Two rendered scene captures were inspected: normal contact and lunge landing both show separate planted feet and readable character silhouettes. This is still a local preview with no role transfer, match scoring, slipper ownership, or LAN state.

## Player depth sorting — 2026-10-19

- Enabled Y sorting on `scenes/Taya can demo.tscn`. Both player roots are at their feet, so the player with the lower screen position draws in front. Kept 65-pixel foot colliders on Head Band and the reusable Hat Thrower scenes instead of using full-height body capsules; this lets the sprites layer while normal movement remains solid. The Taya lunge retains the 132-pixel tag distance, 300-pixel reach, and a temporary exception only for a locked thrower when Taya can land clear.
- Rendered front, back, and both diagonal contact arrangements in Godot 4.7.2 and inspected the draw order. A physics check approached Head Band from all eight directions; each move was blocked at about 130.8 pixels between player origins. The close-pass, short-stop, and third-player-blocker lunge checks also passed with one tag request only in the first two cases. This remains a local demo; live input and LAN play were not checked.

## Later slipper/can physics integration — 2026-10-19

The earlier visual-only slipper and one-tween can fall described above have been replaced in the active `feature/player-movement` checkout. The can now receives a charge-scaled impact, bounces, and must settle before Taya can pick it up; the owner retrieves the persistent slipper after it stops. The prior Taya pickup/reset behavior passed a regression check. Full change details, measured weak/strong hit results, visual review, and remaining LAN limits are in `docs/slipper_can_physics_log.md`.

## Integrated facing dash — 2026-10-27

The current `merge_player_roles/` match supersedes the older automatic-target lunge described above. Space uses Taya's visible eight-way facing direction for a straight dash; neither the nearest thrower nor the cursor changes its course. Only a thrower directly in the dash path can get the temporary pass-through collision exception, and only when the dash can land beyond them. Contact tagging and the cooldown still apply. `tests/taya_facing_lunge_smoke.gd` passed all eight facing/animation sectors, an in-between facing angle, off-path and cursor-away checks, a straight-path tag, and collision restoration in Godot 4.7.2. Human input and physical LAN play remain pending.
