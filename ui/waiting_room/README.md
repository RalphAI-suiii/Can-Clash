# Waiting room and practice bay

Open `res://ui/waiting_room/waiting_room.tscn` and press **F6** in Godot 4.

The directly overhead, orthographic clubhouse has a waiting room on the right and a connected
slipper-practice bay on the left. Both areas are walkable. The player board and
buttons follow the main menu's Titan One lettering, cream text with black
outlines, burnt-orange framing, cream rows, and green/gold/blue buttons.
Soft, offset drop shadows ground the player, cans, slippers, room decorations, and UI. A few sports props decorate the waiting-room perimeter while the practice lanes remain clear. The old bottom-left instruction panel is removed. Room boundaries match the overhead floor plan.

## Play

- WASD / arrow keys move; Shift sprints.
- Aim with the mouse, hold the left button to charge, and release to throw.
- Walk to your stopped slipper and press E to retrieve it.
- Three standing cans sit near the left edge of the practice lanes at the marked positions from the reference image. Each hit updates the counter;
  each can resets at its own base two seconds after settling. Your slipper still
  needs retrieval.
- Slippers bounce off the vertical room divider from either side. Players can
  walk freely across it; slippers cannot enter the other room through it.
- Reset recovers your slipper, cancels a pending throw, restores the can, and
  clears the practice hit counter. All three cans reset together with this button.
- The bottom-right Ready button toggles only the local player's status. Player
  rows display status only. Movement and practice remain available while ready.
- Hosts see Start beside Ready. It stays disabled until every listed player is
  ready, then gains a gold glow. Unreadying or roster changes update it immediately;
  an empty roster cannot start. Start opens the existing `level/level.tscn`.
  Guests keep the full-width Ready button and do not see Start.
- Leave / Escape returns to the existing host lobby.

`Player` instances the complete `scenes/Thrower Hat Thrower.tscn` with its original
script and all charge, release, slipper, retrieval, sprint, and animation logic.
There is no movement-only script override. Physical walls bound the room and
allow slipper ricochets. A separate physics layer makes the divider block only
slippers. Their first motion sweep includes the hand-to-release offset to prevent
close throws from spawning beyond the divider. The shared Thrower script ignores a new charge while
hovering UI controls; clicking Ready, Reset, or the player board doesn't fire a
slipper. The ready panel still instances `scenes/Player_ready.tscn`.

## Art

`assets/ui/waiting_room/clubhouse.png` was created with the built-in Imagegen tool,
using `assets/ui/Sunset Campground Battle Stage.png` as the style reference. The latest decor pass adds a duffel bag, towel crate, basketball, bottles, and a woven mat; those props are decorative background artwork. The
original prompt and provenance are stored in `clubhouse.prompt.md` beside the image;
`clubhouse-props.prompt.md` records the latest props and environment shadows.
The former court extraction is replaced; `level/level.tscn` and the main menu
remain unchanged.

## Scope and checks

This remains a local preview: the five rows are the existing roster placeholders.
LAN joining, remote players, and ready replication are not implemented yet.
`local_is_host` selects the offline preview role (host by default). With a multiplayer
peer, the server role determines Start access; its handler rechecks both role and
readiness. The five placeholder rows must be updated through `set_player_ready`
to preview a fully ready room. The level transition is local; synchronized LAN
match startup is not implemented. Practice hits do not award match points.

Run from the project root:

```powershell
godot --headless --path . --script res://tests/waiting_room_smoke.gd
```

The check uses mouse and keyboard events to verify that UI clicks don't throw,
ready/unready updates only the local player, movement reaches the practice bay,
a charged throw knocks over the can, the target resets, E retrieves the slipper,
Reset restores practice, and the physical boundary stops the player. It also checks
all three can resets, high-speed and close-release divider collisions in both
directions, and players crossing the divider freely.

Visual checks cover 1920x1080 and 1280x720, including ready and not-ready states.
The smoke check also verifies host/guest Start visibility, ready/unready glow,
member removal, an empty roster, and starting the existing level.
