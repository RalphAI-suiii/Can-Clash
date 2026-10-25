# Design decisions

## Screen fit and LAN presentation — 2026-10-25

- Keep the 1920×1080 design canvas centered and scale it uniformly to the available window. On screens with a different aspect ratio, use bars in the spare space so menus, HUD, and camera framing are not cropped or stretched.
- Send host LAN snapshots at 30 Hz while keeping online at 20 Hz. Retain physics-rate client input and host-owned outcomes. Bound remote visual extrapolation to 50 ms and smooth toward the newer snapshots over 35 ms; discard acknowledged input commands in place to avoid rebuilding the prediction history each snapshot.
- Godot 4.7.2 loaded the game headlessly with this setting. The existing two-process ENet responsiveness check passed from a clean main checkout with 120 ms delayed snapshots and 10% dropped snapshots: 6.695 ms first local movement, 61/61 local moving frames, 52/61 remote moving frames, and 0 px settled drift. A rendered resolution check and physical five-PC LAN latency check are still needed. The earlier 2026-10-24 measurements below predate this tuning.

## Distinct Eskinita and Dusty Yard — 2026-10-24

- Keep COURTYARD's floor, hoops, props and fence placement unchanged.
- Eskinita uses repaired light concrete, edge drains, colorful homes and laundry
  around the perimeter. Its asymmetric roadside cover differs from the court.
- Dusty Yard uses an ochre earth floor, worn paths, palms and an open staggered
  cover arrangement. Replace the shared asphalt rather than recoloring it.
- Retain every non-hoop obstacle, its existing collision and shadows. Perimeter
  scenery is decorative and outside the enclosure. Keep blue/spawns clear, the
  center throwing route open, the can at (1450,610), and fence movement bounds.
- Update map-selection previews/descriptions to the corresponding floor art.
  Both host and client use the same static map configuration; no new gameplay API.

## LAN client movement responsiveness — 2026-10-24

- LAN-only local movement prediction uses acknowledged-input replay and bounded
  history. Smooth remote movement between snapshots; keep host-owned outcomes.
- Send LAN input at physics rate, publish host snapshots after actor physics and
  acknowledge input actually consumed. Replays use explicit recorded timesteps.
- Reset prediction on role/action/phase changes and teleports; stop speculative
  movement after 350 ms without snapshots. Preserve real collision constraints.
- Online retains its existing input/render path and protocol. LAN uses the new
  canclash-lan-motion-1 compatibility identifier so old builds are rejected.
- With 120 ms snapshot delay and 10% loss, local response improved from 172.5 ms
  to 7.2 ms, moving on 61/61 sampled frames instead of 9/61, with zero settled
  position error. This was measured with separate ENet processes on one PC.

## Rules UI removed — 2026-10-24

- Remove the match rules popup, its text and the Rules button. Fresh profiles
  automatically enter the same seven-second Taya preparation as returning ones.
- Retain the existing network acknowledgement transport as an automatic scene-load
  handshake, including client retries. The host starts preparation after all human
  scenes load; no acknowledgement button or saved tutorial flag is required.
- Verified fresh-profile flow, five-process LAN and focused GD-Sync local match
  loading/results. The full GD-Sync check still fails its separate waiting-room
  green-release timing assertion under latency; that behavior was not changed.

## Developer map and opening-role controls — 2026-10-24

- Developer waiting rooms expose Map (Random or any arena) and Play As
  (Random, Player, Taya) beside the existing bot controls. Defaults stay random;
  choices last for this app session and apply only to developer matches.
- Player guarantees a bot is selected as opening Taya and keeps at least one bot.
  Taya selects the local player. Normal role transfers still work after tagging.
- LAN/online keep random maps and opening roles. Remove the developer-code hint
  from Join's visible copy while retaining the existing hidden test shortcut.

## Fence-aligned movement bounds — 2026-10-24

- Replace the inset court blockers with 32-pixel barriers along the visible
  enclosure: inner edges x=153/1721 and y=49/1072. Corners overlap. The bottom fence is lowered 32 pixels to meet the pavement edge,
  plus a 16-pixel artwork offset compensating for transparent tile padding.
- Match slipper bounds and camera framing use that full enclosed rectangle.
  Blue-zone permissions, prop collisions and the can base remain unchanged.

## Basketball hoops — 2026-10-24

- COURTYARD keeps the two hoops at the original authored court-end positions.
- Shared map configuration removes the entire hoop instances from ESKINITA and
  DUSTY YARD, including shadows and collision. Other props retain their layout.

## Supplied music — 2026-10-24

- Preserve the five named MP3s from the supplied Drive folder in assets/audio/music.
- Main menu/results use mainmenu; lobby/Practice/selection/preparation use lobby.
  Active matches use battle until 60 seconds remain, then intense battle.
- A persistent two-player autoload loops and crossfades tracks, without restarting
  on repeated timer snapshots. The host-owned match timer chooses the cue locally
  on every PC. Retain trailer music for trailer use; no trailer scene exists yet.


## Character size and role names — 2026-10-24

- Reduce live match/waiting-room characters by another 20%, from scale 0.72 to
  0.576. Shared root scaling keeps sprites, colliders and throw origins aligned.
- Overhead names are green for throwers and red for Taya, refreshed immediately
  by the shared role setter on hosts and replicas. Keep name text readable.


## Gameplay adjustments — 2026-10-24

These decisions supersede earlier grace-period, initial-Taya, can recovery and
throw-meter tuning below, following Gameplay adjustments.docx and user corrections.

- The protected blue area covers the visible left floor to the fence and curb,
  ending at x=530. Only throwers inside it can begin/release a throw. Taya cannot
  cross that boundary, including lunges. Validation is host-owned.
- After rules acknowledgments, choose Taya randomly from all participants,
  including the human in developer mode. Freeze throwers for seven seconds while
  Taya can move, show the selected name and countdown, then start 600 seconds of
  scoring. A solo developer player is Taya and also resets the can manually.
- The can's original and reset position is (1450,610), near the far-right end.
  Taya starts 180 pixels to its left. Match cans stay toppled until Taya uses E
  to pick up, carries to the original circle, and uses E to place. Practice keeps
  automatic recovery. Existing power-dependent tumbling remains.
- Green covers 4% of the meter, orange 23% on either side, red the remaining 50%.
  Sweep timing, randomized targets and power/error ranges remain. Base horizontal
  launch speeds increase 20%; match-specific 1.45 speed scaling keeps the far-right
  can reachable from blue. Actual physics and preview use the same values.
- A bottom foreground fence reuses the upper fence tiles and joins the lower
  curb on every map. The existing bottom world border remains the collider.
- Keep all 17 original prop nodes and their collisions. Arrange benches, hoops,
  barrels, crates, tires and cones with clear spacing and an open throwing lane;
  do not interpret cleanup as deleting the scenery. Account for the authored
  level root offset when positioning props.
- Keep characters at 0.72 scale and use the existing shared Taya/thrower artwork
  and role actions. Each bot gets its own throwing position inside blue.
- A local Camera2D follows the player/can midpoint with 0.9 baseline zoom and
  widens when needed to keep both visible. HUD uses its existing CanvasLayer.
- Results retain character identity and show silver/gold/bronze left/center/right,
  remaining ranks below, empty unused places, stable tie ordering and shared wins.
- Network compatibility is canclash-rules-3. Match phase deadlines use synchronized
  host time with bounds to avoid displaying more than 7 seconds or 10 minutes.

Acceptance: all-map geometry, throw eligibility, Taya boundary/lunge, seven-second
preparation, manual E recovery, power-dependent tumbling, far-right throw reach,
0–4 bots, movement/pickup/waiting-room checks, five-process LAN, and GD-Sync local
transport under latency/loss. Viewports inspected at 1920×1080 and 1280×720.
Headless tests still emit the existing tree-shader dummy-renderer diagnostic;
real OpenGL captures do not. Real cloud connectivity remains unverified.


The original concept note is the current design reference.

## Open decisions

- Confirm Godot 4 and the exact engine version.
- Match duration and ranking tie-break rule.
- Opening throw-off ties and the precise distance measurement.
- Arena setting, visual style, layout, and camera implementation.
- Input bindings, charge times, throw speeds, and power-up balance.
- Lunge distance, wind-up, and recovery.
- Disconnect behavior and interrupted matches.
- Ownership and recovery of slippers when roles change.
- Miss scoring when the can is already toppled.

Record each resolved decision here with its date and rationale.

## Adjustments implementation — 2026-10-21

- The requested match duration is three minutes, after a separate 30-second
  grace period. First-time rules acknowledgments precede the grace timer; all
  human members must finish reading. The rules remain available during play.
- The roster contains actual members rather than five placeholders. LAN starts
  with a host, accepts four clients, and requires at least two ready humans to
  start. The `developer-mode` Join shortcut starts with one human and fills the
  match with four computer-controlled opponents. Practice is a separate solo mode.
- Seven-character room codes encode the host's IPv4 address on UDP port 54652.
  They remain valid while the address is unchanged. Direct-IP joining is also
  supported, without a discovery server or internet matchmaking dependency.
- Slippers collect automatically at first landing when the owner runs within
  72 pixels. Each member's stable color marks their name, ring, roster badge,
  and slipper outline. This supersedes E-based retrieval below. Leaving the
  arena hides the slipper for three seconds, then returns it to the owner's hand.
- The map roulette chooses one of three variants of the existing 2D level:
  Courtyard, Eskinita, or Dusty Yard. Their prop layouts and palettes differ;
  the existing art remains the source. Selection is host-owned and shared.
- Initial Taya is chosen from the host's match seed; developer mode starts a bot
  as Taya. This is the provisional match entry for the adjustments, rather than
  claiming the concept's opening throw-off is implemented.
- Local statistics persist in `user://profile.cfg`. A successful throw is a
  projectile's first standing-can hit, which also records one knockdown. Normal
  LAN results count wins/losses once per match ID; tied leaders share victory.
  Practice and developer games never change lifetime totals. `CAN_CLASH_SAVE_PATH`
  isolates automated test profiles from the user's data.
- The match host owns simulation and scoring. First landing prediction includes
  existing World/divider ricochets and standing-can deflection. Prediction is a
  preview rather than a guarantee if another player changes the can mid-flight.
- Safe-return points require leaving the strip, physically collecting the owned
  slipper, and re-entering the strip. Out-of-bounds respawns do not earn that point.

## Slipper pickup responsiveness — 2026-10-19

- Throwers can press or hold E while walking or sprinting into their own slipper's
  existing 72-pixel pickup radius. After its first landing, the slipper can be
  retrieved during its small floor bounce (up to 12 pixels of simulated height),
  sliding, or spin. Collection preserves movement and clears ownership immediately
  so another throw can begin; there is no pickup animation or cooldown.
- This supersedes the older settle-before-retrieval rule below. Initial flight
  remains ineligible, as do slippers owned by another player or outside reach.
  Taya's can pickup and placement timing stays unchanged.
- Check with `godot --headless --path . --script res://tests/slipper_pickup_smoke.gd`.

## Provisional prototype choices — 2026-10-18

- The local 2D Taya prototype displays the lunge in eight directional sectors so the body and feet face the target while steering. Five right/front/back source views and horizontal mirroring cover all eight sectors. This only resolves the prototype's animation coverage; the concept note's 2.5D camera and four-direction movement remain a team design decision.
- The lunge uses four full-body key poses and begins recovery when gameplay movement lands. Its initial 210-pixel travel, 0.13-second wind-up, 0.30-second travel, and 0.20-second visual recovery were provisional tuning values for playtesting.
- The local 2D player prototypes initially used a 27-pixel circular feet collider on the Player physics layer with World and Player masks. Taya requests a tag on body contact as well as by proximity. Match authority still has to validate and award tags.

## Local collision tuning — 2026-10-19

- Players stay solid to one another during ordinary movement. A Taya lunge temporarily ignores only its locked thrower's body when the remaining lunge reach can carry Taya past that body. The lunge can tag while passing through, then restores collision at a clear landing position. Short lunges still stop at contact. World obstacles and other players continue to block the dash. This is a local prototype rule; the host still needs to validate tags and role changes in a match.
- After a rendered preview showed shoes still overlapping, the prototype player bodies use a 65-pixel circular footprint and a 132-pixel tag distance. Lunge travel is 300 pixels so a close target can still be crossed and the Taya can land beyond the larger body. These are visual and gameplay tuning values for the local 2D prototype, not a final meters-to-pixels decision.
- The Taya demo now instances the existing Head Band `CharacterBody2D` player scene as its stationary second actor. Local input is disabled on that instance because this preview has only one keyboard. Its separate Head Band art and movement script remain available when controlled independently later.
- The Taya demo sorts actors by their feet position: a player lower on the screen draws in front of a player behind them. Player collisions remain 65-pixel circles around the feet, so normal movement cannot merge the bodies while the upper sprites may overlap naturally. The lunge still uses its targeted, temporary collision exception and restores a clear landing.

## Local slipper and can motion — 2026-10-19

- A Player Neutral thrower has one owned slipper in play. Charge increases launch speed from 260 to 540 pixels per second and gives it a longer arc. The slipper follows the exact cursor direction, sweeps its path against standing cans, ricochets off World-layer obstacles, bounces on the floor, and remains where it stops. Only its owner can retrieve it with E after it settles; another throw is blocked until retrieval.
- A standing can accepts one moving-slipper impact, tips, and receives linear and angular motion based on the incoming direction, speed, and charge. It bounces off the floor and World-layer obstacles, loses momentum, and settles on its side. Taya can pick it up only after it settles. These are provisional screen-pixel tuning values for the local 2D prototype, not final match balance.
- The existing Hat Thrower and silver can art stay intact. The left diagonal aim and release rows require different mirroring; up-left needs mirroring in both. A separate `scenes/Slipper can demo.tscn` lets one keyboard exercise charge, impact, E retrieval, and a demo-only R can reset. Host validation, scoring, slipper ownership on role transfer, and network replication remain match integration work.

## Character role scenes — 2026-10-19

- Each of the five characters has a separate `Thrower <Character>` and `Taya <Character>` scene for choosing a starting role. They share one local mechanic controller, collider size, and feet origin. The controller's `set_taya_role()` remains available for a later authoritative role swap.
- The older character animation atlases were preserved as reusable SpriteFrames resources. Head Band, Glasses, and Curly use existing empty-hand release poses for Taya so no character visibly carries a slipper in that role. These are temporary visual coverage until dedicated Taya motion sheets exist; Bullcap's existing directional walk art likewise times its throw release until authored throw frames exist.
- The old prototype scenes were removed after the level, character selection, and compatibility Player scene were updated to use named role scenes. The combined local preview is for visual and mechanic review only; its R can shortcut is outside match rules.
