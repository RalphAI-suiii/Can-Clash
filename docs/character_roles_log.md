# Five character role scenes — 2026-10-19

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
