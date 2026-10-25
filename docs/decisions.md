# Design decisions

## Integrated customization, abilities and possession UI — 2026-10-25

- Merge the new lobby character claims, customization and five specials with the relaxed movement artwork, large possession badges, three-second tag delay, manual 15% slower carrying, private aim guides, clean podium and selection sound. Preserve both ability and possession fields in host snapshots.
- Stun and cast locks now suspend LAN prediction and reset its history on state changes. Reaction/cast animation aliases remain available, while item-bearing wind-up/carry artwork stays hidden behind possession badges. Bullcap retains the newer eight-direction release sheet.
- Combined compatibility is `canclash-lan-abilities-4` for LAN and `canclash-rules-8` for online, rejecting either pre-merge build.
- Merge verification passed: Godot import; all-five-character animation, possession, pickup, timing-meter and LAN prediction checks; all-map rules and podium checks; map-selection sound; full five-process localhost LAN character selection/ready/start/match/results/disconnect flow; and two-process special-projectile, steering and stun replication. Physical multi-PC and real internet play remain unverified.

## Map-selection spinning sound — 2026-10-25

- Reuse the user's named spinning-wheel MP3 from the soundtrack Drive folder. Keep the original file intact, skip its silent lead-in during playback and align the final cue with the existing five-second map shuffle. Selection duration, host map choice and networking stay unchanged.
- A scene-owned AudioStreamPlayer plays once on entry, mixes with the continuing lobby track, and stops on transition or early exit. No new global audio manager or network messages are needed.

## Possession icons, tag cooldown and private aiming — 2026-10-25

- Circle badges above each actor show owned slippers or a carried can. Hand props and item-bearing wind-up/carry artwork are hidden; empty-hand release and lunge drawings remain visible. Hidden pickup/place animation clocks still complete normally, and only the host places the can.
- Becoming Taya sets a host-clock deadline three seconds ahead. Tags are rejected before that deadline, while movement and lunges remain usable. The new Taya alone sees a fixed-screen countdown. Reapplying the same role does not restart the delay; the deadline is replicated unchanged to clients.
- Can return stays manual: carry at 85% of normal walking speed, with no sprint boost, and press E near the original spot to place. No automatic return, steering or placement is added.
- Timing meters, trajectory paths and spread previews are rendered only for the locally owned human actor. Other players and bots retain synchronized gameplay state without visible aiming guides on this PC.
- Podium actors disable gameplay overlays entirely so skill circles and possession badges cannot cover their place numbers.
- The new possession regression check covers every character, real pickup/place completion, carrying speed, three-second unlocking and owner-only aim state. Updated animation, pickup and five-process LAN checks retain role/retrieval coverage.

## Movement artwork follows role and slipper ownership — 2026-10-25

- All five characters select relaxed `idle`/`walk`/`sprint` while holding a slipper, separate `empty_` movement while retrieving it, and `taya_` movement only in the Taya role. Role transfers refresh immediately. Existing aim, release, pickup, carry, place and lunge actions remain distinct.
- Head Band, Glasses and Curly receive six relaxed empty-hand sheets derived from their original aiming-walk artwork. Hat and Bullcap keep their authored neutral motion. A small native slipper drawing follows the lowered hand only in free movement when the actor actually owns the slipper; the projectile uses the same silhouette. Original aiming/release artwork is preserved. Bullcap now has its own eight-direction aiming/release sheet, replacing the old walk-frame throw placeholder. Taya still uses the existing character-specific Taya action coverage described below.
- Held-slipper visibility and movement selection update on both host state and replicated snapshots, including the locally predicted LAN actor. Updated animation names require the current LAN/online compatibility versions; old builds are rejected at registration.
- `tests/role_animation_smoke.gd` exercises both starting roles for every character, eight directions, idle/walk/sprint, held/empty/Taya selection, charge interruption and can actions. Pickup and five-process LAN checks verify the live transition paths.

## Five thrower specials and Taya stun — 2026-10-25

- The existing three-orb meter is the sole thrower power system. Retire the draft concept's unimplemented two-hit powered-throw rule. The host fills one orb per confirmed can hit, caps it at three, and spends all three when an armed special slipper actually launches. RMB toggles arming without cost; becoming Taya disarms but preserves the meter. A down or carried can pauses all new thrower shots.
- Character order maps to Rapid Fire (Hat Thrower), Ricochet (Head Band), Self-Returning (Glasses Thrower), Stunning (Curly Haired), and Mind-Controlled (Bullcap Head). Rapid Fire schedules two more shots at 0.25-second intervals, cancels pending shots if the can falls, returns all three automatically, and resolves one hit or miss for the burst. Ricochet redirects within 75 degrees after its first wall bounce. Self-Returning comes home after impact, rest, or timeout; safe-return scoring still requires leaving and recrossing safety. Stunning stops Taya on direct contact. Mind-Controlled turns toward the current host-received cursor at up to 150 degrees per second for two seconds without increasing speed.
- Any Taya has a separate aimed stun slipper on held/released RMB. Its 120-second launch cooldown stays with the player through role swaps, uses no orbs, and works while carrying or when the can is down. It stuns one thrower outside the safe strip for three seconds; any recovered player has five seconds of stun immunity. Space remains the lunge.
- The host simulates special projectiles, validates the request and match state, awards points, and applies stun. Snapshots replicate armed state, cooldowns, stun timers, the main slipper, two bounded Rapid Fire extras, and the Taya projectile. LAN compatibility is `canclash-lan-abilities-3`; online compatibility is `canclash-rules-7`.
- The current animation pass creates eight-direction cast and reaction animation states from each character's existing clean art. Activation glow, colored projectile trails, stun stars, and cooldown arc distinguish them. A generated replacement sheet was rejected because it changed cell transparency and alignment. Dedicated newly drawn action and reaction poses remain an art task, especially Bullcap's throw; the existing Bullcap walk drawings are still the casting source. Do not describe the current aliases as new hand-drawn frames.
- Godot 4.7.2 loaded the match and passed `tests/ability_smoke.tscn`: all five special launches and meter spending, eight-direction state availability, one-score Rapid Fire cap, pending-burst cancellation, cursor turn without speed gain, stun immunity, Taya's carried-can case, and cooldown persistence. Two localhost ENet processes passed `tests/ability_lan_probe.tscn`: the joiner armed by reliable RMB request and saw Rapid Fire extras, Bullcap cursor steering, stun state, and Taya projectile/cooldown. Eight direction contact sheets were saved under `tests/ability_visual/` and inspected at the match's 0.576 actor scale; the repeated cast art and static reaction poses remain visible limitations. Physical five-PC play, real scoring under chained collisions, and full manual input play are still unverified.

## Player customization and lobby character claims — 2026-10-25

- The main menu's former Avatar entry opens player customization for the saved display name and one of five marker colors. Fixed character sprite art is unchanged by the color choice.
- Choose a character in the waiting room before pressing Ready. The host reserves each of the five characters for one player at a time, rejects competing claims, and clears Ready when a player switches. Start rechecks every choice for validity and uniqueness. The waiting-room roster shows each choice and developer bots use the remaining characters.
- A character change replaces that player's waiting-room practice actor while preserving its position. The match uses the host-confirmed roster choice. LAN and online compatibility identifiers advance because registration and character-claim messages changed. This pass has static review only; visual layout, live character switching, and multi-process claim races remain to be reviewed in Godot.

## Screen fit and LAN presentation — 2026-10-25

- Keep the 1920×1080 design canvas centered and scale it uniformly to the available window. On screens with a different aspect ratio, use bars in the spare space so menus, HUD, and camera framing are not cropped or stretched.
- Send host LAN snapshots at 30 Hz while keeping online at 20 Hz. Retain physics-rate client input and host-owned outcomes. Bound remote visual extrapolation to 50 ms and smooth toward the newer snapshots over 35 ms; discard acknowledged input commands in place to avoid rebuilding the prediction history each snapshot.
- Godot 4.7.2 loaded the game headlessly with this setting. The existing two-process ENet responsiveness check passed with 120 ms delayed snapshots and 10% dropped snapshots: 7.965 ms first local movement, 62/62 local moving frames, 47/62 remote moving frames, and 0 px settled drift. A rendered resolution check and physical five-PC LAN latency check are still needed. The earlier 2026-10-24 measurements below predate this tuning.

## Match scoreboard placement and layout — 2026-10-25

- Keep the existing orange panel, dark outline, and shadow, but anchor it 24 pixels from the top and right edges of the game viewport. This removes it from the left play area shown in the user's screenshot.
- Draw the map name as the header, a small court-center line motif, clear player and points columns, alternating dark-orange rows, roster-color markers, and a red Taya badge. Put developer mode information in one quiet footer line. The board updates from the same host-owned scores and role snapshot as before; this is presentation only.
- This change has had static inspection only; check the rendered panel at different window sizes and with five player names before treating the layout as final.

## Three-hit character special placeholder (superseded) — 2026-10-25

- Each participant has an individual three-orb special meter below their character. It starts empty and gains one orb only when the host confirms that player's slipper struck and toppled a standing can during active play. Each slipper can award at most one orb. The meter stays with the participant through Taya transfers and is capped at three.
- At three orbs, show `RMB SPECIAL` below the meter and accept a reliable right-click request. The host validates the active match, player identity, and full meter, then broadcasts a `SPECIAL ABILITY IS COMING SOON` notice. No effect or charge consumption occurs until the five character abilities are specified; this prevents players from losing earned charge to a nonfunctional placeholder.
- The later five-special decision above retired the two-hit powered throw and replaced this placeholder.
- LAN and online protocol identifiers advance because older builds do not carry the orb state or right-click request. This pass has static inspection only; live input, can-hit count, layout, and multi-process replication remain unverified.

## Taya tag announcement — 2026-10-25

- The host alone changes the Taya role after a valid tag. It sends a numbered tag announcement with the new Taya's ID, impact position, and expiry in match snapshots; clients show each red burst once and use the shared clock for the centered notice.
- Keep a bright red `TAYA` label above the current Taya's name throughout play. On a tag, show a short red impact burst and a centered `%PLAYER% IS NOW TAYA!` card with a brief red screen tint. The card does not pause movement or change tag rules.
- This pass has static inspection only; rendered layout and a multi-process tag handoff still need review.

## Opening throw-off and camera — 2026-10-25

- After all human scenes load, place the roster characters near midcourt, show a sliding THROW OFF!! banner over a dimmed screen, and have the host run them through the clear center lane to their own toe-line slots. The host then allows one charged throw per player, with movement locked until it resolves. Bots throw automatically.
- The host compares each slipper's final ground position to the standing can's base. The farthest landing becomes the first Taya. An unthrown or out-of-bounds slipper counts as a forfeit and is ranked farthest; ties use the lowest roster slot. This follows the current player request, which supersedes the draft concept note's proposed toe-line distance. The can stays standing and an accurate slipper stops on contact during the throw-off. No score is awarded for these opening throws.
- A winner card shows the selected player's name, character, and idle portrait before the existing seven-second Taya preparation. Developer-only Play As remains an explicit local override for role testing; LAN and online always use the host's landing-distance result.
- Each client frames its own character and the can in a wider view. Charging widens the view further without moving the camera in response to the cursor. Both throw-off and regular match throws move that client's camera with their own slipper, hold its landing spot for one second, then return to their character. Camera motion and zoom are presentation only; the host still owns throw outcomes.
- Bump LAN and online compatibility identifiers because older clients do not understand this opening sequence. This change has had static inspection only; rendered timing, obstacle pathing, input, and multi-process synchronization still need a playtest.

## Character throw grunts — 2026-10-25

- Use the five English child-voice grunt samples in `assets/audio/voices/`, one per character.
- Play a grunt once when the slipper actually leaves the hand, not when charging starts or the button is released. Host playback follows the release animation frame; clients play when a fresh slipper appears in the authoritative snapshot.
- Keep these as local positional audio. They do not affect host-owned throw rules.
- The 2026-10-25 energy pass keeps the original child voice performances, trims excess silence, speeds each by 10%, compresses gently, and matches their levels. Unprocessed takes remain in `../voice_line_samples/english_cartoon_kids/`.

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
- On 2026-10-25, Head Band, Glasses Thrower, and Curly Haired use the existing empty-hand release recovery frame for their normal idle. Their supplied `idle_throw` sheets are aiming poses, so those remain exclusive to charging. Bullcap and Hat Thrower keep their existing neutral idle art. This reuses current full-body drawings; dedicated multi-frame neutral idles for the other three are still an art task.
- The older character animation atlases were preserved as reusable SpriteFrames resources. Head Band, Glasses, and Curly use existing empty-hand release poses for Taya so no character visibly carries a slipper in that role. These are temporary visual coverage until dedicated Taya motion sheets exist; Bullcap's existing directional walk art likewise times its throw release until authored throw frames exist.
- The old prototype scenes were removed after the level, character selection, and compatibility Player scene were updated to use named role scenes. The combined local preview is for visual and mechanic review only; its R can shortcut is outside match rules.

## Player customization — 2026-10-25

- Main-menu Customize now opens a full-screen live preview. Players can set their name and marker color, and equip a duck hat plus either a bow or scarf (or neither). The five character models in the preview are visual samples; character claims remain exclusive in the lobby.
- Cosmetic choices are saved locally for the customization demo only. They are absent from registration, roster replication, and all lobby/match actors. Name and marker color retain their existing gameplay behavior. The LAN/online protocol remains at the character-claim version.
- The preview holds one fixed pose per character: neutral art for Hat Thrower and Bullcap Head, a menu pose for Head Band and Glasses Thrower, and an existing idle pose for Curly Haired. Hat Thrower and Bullcap Head use a preview-only masked frame when the duck hat is chosen so their baked-in hats do not stack with it. The duck, bow, and scarf fit to alpha-thresholded painted bounds and character-specific size ratios. Match animation atlases and gameplay sprites remain untouched.

## Can-down throw pause — 2026-10-25

- In a match, throwers may start or release a slipper throw only while the can is standing. Toppled and carried states block new throws until Taya resets the can at its base. A charge in progress cancels if the can falls; slippers already in flight continue normally. The opening throw-off remains one throw per player, and standalone movement demos keep their prior behavior. The host applies the rule; clients use the replicated can state for the local status label and movement prediction.
