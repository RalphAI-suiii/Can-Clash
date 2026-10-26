# Waiting room and practice bay

Run the project for the main menu. **Play Local → Host** opens this waiting room;
**Join** accepts its room code or LAN IP. Enter `developer-mode` in Join for a
solo test with four bots when the match begins. **Practice** opens free practice.
Running `res://ui/waiting_room/waiting_room.tscn` directly defaults to developer mode.

The directly overhead, orthographic clubhouse has a waiting room on the right and a connected
slipper-practice bay on the left. Both areas are walkable. The player board and
buttons follow the main menu's Titan One lettering, cream text with black
outlines, burnt-orange framing, cream rows, and green/gold/blue buttons.
Soft, offset drop shadows ground the player, cans, slippers, room decorations, and UI. A few sports props decorate the waiting-room perimeter while the practice lanes remain clear. The old bottom-left instruction panel is removed. Room boundaries match the overhead floor plan.

`TopLeftLight` provides steady, soft warm illumination from `(160, 120)` with a
1,500-pixel radial falloff. `RoomAmbient` gently shades the rest of the room;
both affect the world canvas, including the player, cans, and slippers. The
player board and HUD use separate canvas layers, preserving their colors and
Start's gold readiness glow. Existing soft shadows continue toward bottom-right.
Adjust position, color, Energy, Texture Scale, and the texture's Gradient in the
Godot Inspector; adjust `RoomAmbient`'s Color for the baseline brightness.

## Play

- WASD / arrow keys move; Shift sprints.
- Aim with the mouse, hold the left button to charge, and release to throw.
- Run over your own colored slipper to collect it automatically. No E press is
  needed, and collection preserves movement. Initial flight remains ineligible;
  pickup begins at the first landing, including its small floor bounce.
- Each member has a stable color shown by their name, feet ring, roster badge,
  and slipper outline. Another member cannot collect your slipper.
- Three standing cans sit near the left edge of the practice lanes at the marked positions from the reference image. Each hit updates the counter;
  each can resets at its own base two seconds after settling. Your slipper still
  needs retrieval.
- Slippers bounce off the vertical room divider from either side. Players can
  walk freely across it; slippers cannot enter the other room through it.
- Reset recovers your slipper, cancels a pending throw, restores the can, and
  clears the practice hit counter. All three cans reset together with this button.
- The bottom-right Ready button toggles only the local player's status. Player
  rows display status only. Movement and practice remain available while ready.
- Choose Character sits beneath the player roster. Players claim a free
  character before Ready becomes available. The host prevents duplicate picks;
  changing a character clears that player's Ready status. The roster shows each
  player's character, and developer bots receive the remaining characters.
- Hosts see Start beside Ready. It stays disabled until every actual member is
  ready (at least two humans for LAN, one for developer mode), then glows gold.
  Start opens the shared map roulette, then the chosen match arena.
  Guests keep the full-width Ready button and do not see Start.
- The roster starts with one member and grows only when players join. Departures
  remove the member and their actor. The footer room-code button shows the LAN
  code and current host IP, and copies the code when clicked.
- Leave / Escape closes your connection and returns to the main menu.

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
The former court extraction is replaced; `level/basketball_court.tscn` and the main menu
remain unchanged.

## Match flow and checks

LAN rooms support one host and four clients using ENet on UDP port 54652. The host
simulates players, cans, slippers, readiness, scoring, and match progression;
clients send bounded input and render replicated state. Room codes encode the
host's LAN IPv4 address, so all PCs must be on the same reachable LAN.

Three arena variants reuse the existing level art with different prop layouts
and palettes: Courtyard, Eskinita, and Dusty Yard. The host chooses once; every
member sees the same decelerating map carousel and loads the chosen variant.
Matches begin seven seconds of Taya preparation once everyone loads the map; no rules popup is shown.
Scoring then lasts five minutes and results rank individual scores.

Developer mode offers minus/plus controls below the roster for zero to four bots
(four by default). Bots join on Start, throw, retrieve, return to the safe strip,
and guard/tag as Taya. With zero bots the player can test mechanics
alone without a Taya; the can resets automatically after settling. The count is
remembered until the app closes.
Players in the waiting room and match use an Inspector-editable 72% scale,
including collision bodies and shadows. Names and throw status keep their readable
text size; throw origins and trajectory previews follow the scaled character.
Hit cans tumble, bounce, and roll before standing at their settled position after
a two-second pause. Their base marker follows the new position, including on LAN
clients. Taya cannot carry a can while it is recovering automatically. Practice
Reset restores the three original target locations.
Practice and developer sessions
do not modify lifetime statistics. Main-menu Statistics shows saved LAN wins,
losses, successful throws, and can knockdowns. Practice hits do not award points.

Run from the project root:

```powershell
godot --headless --path . --script res://tests/waiting_room_smoke.gd
```

The check uses mouse and keyboard events to verify that UI clicks don't throw,
ready/unready updates only the local player, movement reaches the practice bay,
a charged throw knocks over the can, the target resets, walking retrieves the slipper,
Reset restores practice, and the physical boundary stops the player. It also checks
all three can resets, high-speed and close-release divider collisions in both
directions, and players crossing the divider freely.

Visual checks cover 1920x1080 and 1280x720, including ready and not-ready states.
`tests/slipper_pickup_smoke.gd` checks automatic moving pickup across all five
characters. `tests/adjustments_smoke.gd` covers the new menu-to-results flow,
bots, timers, automatic match loading, trajectory, penalties, scoring, and saves.
`tests/lan_session_smoke.gd` runs as a host and four separate client processes to
check real registration, movement, readiness, shared map/phase/results, and exits.
`tests/bot_count_smoke.gd` checks every zero-to-four bot setting through Start,
solo can reset, movement, scaled collisions and throw origins, and the direct-scene fallback.
`tests/can_tumble_smoke.gd` checks spinning, vertical and wall bounces, recovery at
the settled point, repeat hits, marker relocation, and the original practice Reset.
See `docs/adjustments_2026-10-21.md` for the requirement-by-requirement record.

Developer-only Map and Play As selectors below the roster choose any arena and
the local opening role (Player or Taya), or leave either Random. Player keeps at
least one bot to fill Taya. Normal matches ignore these test choices; later tags
still transfer roles normally. The Join screen does not advertise the shortcut.
