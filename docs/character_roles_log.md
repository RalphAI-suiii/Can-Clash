# Five character role scenes — 2026-10-19

## Direction and Taya movement correction — 2026-10-25

Visual inspection of the existing sheets found the empty-hand down diagonals reversed for Head Band, Glasses Thrower, and Curly Haired. Their shared role adapter now assigns down-left and down-right to the painted rows, and uses the same four-frame empty-hand movement for Taya walking and sprinting. Bullcap's separate eight-direction release sheet now uses the atlas's painted row order. Hat Thrower's original authored animation mapping was kept. Godot 4.7.2's existing `tests/role_animation_smoke.gd` passed for all five characters, both roles, and eight idle/walk/sprint directions. Live rendered playback remains pending; Godot reported only sandboxed `user://` log-directory errors during the headless check.

Taya now automatically picks up a toppled can at pickup range once it is near the ground, even while it is sliding or spinning, and places it immediately upon reaching the base. The previous E prompt and placement wait have been removed for the can. The carry-speed limit and thrower slipper retrieval remain.

## Scene roster

`scenes/` now contains `Thrower <Character>` and `Taya <Character>` scenes for Hat Thrower, Head Band, Glasses Thrower, Curly Haired, and Bullcap Head. Each role uses the same 65-pixel feet collider and the current local mechanics in `player_movement_neutral.gd`: eight-direction walking/sprinting and dust, charged cursor-directed slipper with one owned slipper at a time and E pickup, Taya can pickup/carry/reset, contact tag requests, and cooldown lunge. `set_taya_role()` can still switch an existing actor during a future match; scene names specify the starting role.

Head Band, Glasses, Curly, and Bullcap reuse their own original `SpriteFrames` saved as four `.tres` resources. `character_role_player.gd` maps their source animation names to the shared controller. Hat Thrower retains the more detailed neutral/sprint/throw and Taya action sheets. All ten scenes use the same body footprint and feet origin; previews were inspected at the project's 960×540 window size. Taya poses for Head Band, Glasses, and Curly come from empty-hand release drawings, avoiding the visible slipper in their older walk art. Their dedicated Taya walk, pickup, carry, and lunge sheets have not been drawn; the current empty-hand poses animate those actions with the shared motion/effects. Bullcap has no authored throw sheet, so three of its existing directional walk frames serve as the release timing while the common slipper and burst effect provide the projectile motion.

`Character roles preview.tscn` allows 1–5 to switch characters and Tab to switch starting role. WASD moves, Shift sprints, M1 holds/releases a throw, E retrieves a settled slipper or picks up/resets the can, Space lunges, and R topples/resets the can for preview only. The other actor has local input disabled. The existing `Slipper can demo.tscn`, `Taya can demo.tscn`, and `Player.tscn` now reference named role scenes. The preview uses local scene spawning; it is not a five-player network match or authoritative role transfer.

## Cleanup

After checking `.tscn`, `.gd`, `.tres`, and project references, the five old character scene files, `Player movement neutral.tscn`, `Player movement base.tscn`, its unused frame resource, and the obsolete lunge preview scene/script were removed. The shared movement/throw/can scripts, Hat animation resources, both focused demos, and the menu-linked `Player.tscn` remain. Older controllers under `Script/` were left outside this `scenes/` cleanup scope.

## Verification

- Godot 4.7.2 loaded all ten named role scenes for three frames each without script/resource errors after cleanup.
- An in-engine script checked all eight idle/walk/sprint direction animations for every role, collider layers, starting roles, and 1–5/Tab preview switching. All passed.
- Each of the five Thrower scenes completed a fully charged release, spawned its owned slipper, and toppled a standing can in the local physics scene. All passed.
- Each of the five Taya scenes picked up a toppled can, completed the carry/place action, reset it at the base, and made one lunge tag request against a thrower. All passed. The check advanced action animation time explicitly; the actual keyboard timing still needs human play review.
- Both focused demos and the combined character preview loaded without script/resource errors. The combined preview rendered Hat Thrower, Head Band Taya, and the standing can with clear separation and labels.
- Rendered stills of Head Band, Glasses, and Curly Taya confirm empty hands. Hat, Head Band, and Bullcap standalone renders have similar apparent heights and grounded feet.
- The inherited slipper/can and Taya mechanics were also exercised in the preceding `slipper_can_physics_log.md` and `taya_mechanics_log.md`. This pass verified their wiring across all five characters through focused in-engine checks. Keyboard timing and the full animation loops still need interactive visual review in Godot.

The editor's startup continues to report an existing main menu shader compilation error unrelated to these role scenes. No LAN host authority, scoring, safe return, powered throw, or results logic was added here.

## Main integration — 2026-10-19

The role work was merged on top of the latest main branch, retaining its lobby, scoreboard, and level changes. Character selection now saves the corresponding `Thrower <Character>` scene. The level starts with `Thrower Hat Thrower`, and `Player.tscn` is a compatibility instance of `Thrower Curly Haired`. Six older prototype character/player scenes were removed after their remaining references were replaced.

The merge passed `git diff --check` and a resource-path existence scan across changed Godot scenes, scripts, and resources. A standalone Godot executable was not located in this shell environment during merge review, so the integrated main branch still needs a scene-load and interactive playback check in the editor. The earlier five-character mechanic checks above ran before this merge.

## Leonardo and Kay — 2026-10-26

Two new characters from the supplied photo references now have named Thrower and Taya scenes and lobby choices. Their artwork is simplified to the game's thick-outline chibi style. Hat Thrower's movement frame counts were checked in Godot: four idle and eight walk/sprint frames per direction. Leonardo and Kay now have the same frame counts in all eight directions, with separate four-frame directional throw/aim and four-frame Taya lunge poses. Their walking and sprinting frames include painted in-betweens, and the crop bounds were checked for neighboring-frame bleed. Taya pickup and placement have four new connected poses each; the visual plays briefly when replicated can ownership changes without delaying the immediate gameplay pickup/reset. Carry uses each character's animated movement art with the shared can overlay. Both use the existing collider and host-owned movement, throw, tag, can, stun and lunge mechanics. Thrower specials remain unassigned, so their ordinary throws neither gain nor spend orbs.

Godot 4.7.2 imported the atlases and loaded the lobby, customization and waiting-room scenes. `tests/new_roster_probe.gd` instantiated all four role scenes and passed checks for all eight idle/walk/sprint/aim/throw directions, Taya movement aliases, pickup/place, lunge frames, and disabled thrower specials. `tests/new_roster_match_smoke.tscn` spawned both choices in an actual developer match and verified their ordinary-throw, Taya role, and can transition visual paths. The art sheets were visually inspected and alpha crop edges checked. Interactive action timing, character size in a rendered match, and a physical LAN match with both new choices remain to be reviewed. The sandboxed headless Godot run could not write its `user://` logs and reported the pre-existing main-menu shader compiler condition; no scene script/parser errors appeared.
