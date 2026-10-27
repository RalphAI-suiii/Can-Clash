# LAN and online networking

Status: implemented for the active 2D menu, waiting room, and match flow.

The match host owns each participant's three-hit special meter, equipped thrower
special, Taya stun cooldown, and stun/immunity timers. Reliable RMB press/release
requests include a finite bounded cursor target. Host snapshots carry the armed
state, timers, the main slipper, up to two extra Rapid Fire slippers, and Taya's
stun projectile. Current LAN compatibility is `canclash-lan-abilities-6`;
current online compatibility is `canclash-rules-10`. These identifiers require
all connected PCs to run the seven-character roster build.

One PC hosts and plays. Four other PCs join, for five players total.
Godot 4.7.2 ENet uses UDP port 54652, with four remote peers plus the host.
The LAN host binds explicitly to all IPv4 interfaces (`0.0.0.0`); on one
Windows PC, Godot's default `*` wildcard failed to create an ENet host even
though an explicit IPv4 bind succeeded.
LanSession owns connection setup, real member roster, readiness, room codes,
map selection, tutorial acknowledgments, shared transitions, and results.

The host validates input requests and owns movement outcomes, can state,
slipper outcomes, tags, scores, match phase, and timer.
Clients display replicated state. A client must not award itself points or
declare a tag, can hit, safe return, or role transfer.
Match throwers can charge and release only while the host's can is standing;
the toppled and carried states pause new throws until Taya resets it. Clients
display the same rule from the replicated can state.

Validate the sending peer, player ownership, phase, role, legal action,
cooldowns, and request values before applying requests.

LAN clients send sequenced input each physics tick (60 Hz by default). Host
snapshots are sent at 30 Hz after actor physics, including the last input sequence
actually processed. The joining player predicts movement immediately, then replays
unacknowledged input from the authoritative position with a short visual correction.
Prediction uses explicit recorded timesteps, real scenery/player collisions, and
the same speeds, acceleration, friction, and Taya movement restriction as the host.
History is limited to 64 commands and prediction stops after 350 ms without a host
snapshot. Role/action/phase changes and teleports reset the prediction buffer.
Remote LAN actors are smoothed between snapshots with at most 50 ms extrapolation.
Client prediction never decides hits, tags, pickup, role transfers, or scores.

Online keeps its existing 30 Hz input and 20 Hz replica path. Both modes use bounded
Zstandard-compressed Godot Variant snapshots on an unreliable ordered channel.
Registration, character choices, readiness, map selection, automatic scene-load acknowledgements,
events, and results use reliable delivery. Current LAN compatibility is
`canclash-lan-abilities-5`; all PCs must run the updated build. Online protocol
is `canclash-rules-9`.

Players enter the waiting room without a character. Each player chooses one of five
characters there before becoming ready. Choices use a reliable request; the host
checks the sender, waiting phase, and index, then replicates the roster. Multiple
players may choose the same character. Changing a choice clears that player's
ready state. The host checks valid choices again at Start. Developer bots take
remaining characters where possible. The saved player color is
sent at registration and used for the roster badge and in-game marker; colors may
repeat. Cosmetic options in the main-menu customization preview remain local
and are not sent to a room or drawn on match actors.
Character scenes are loaded by roster ID, so repeated character choices still
create separate player actors. If a local character scene or its frame bank fails
to load, the client logs the missing path and uses Head Band art for that actor
instead of stopping match scene setup. The affected PC still needs its game files
repaired or reimported to restore the selected art. A reported crash on another
PC with four of the five characters could not be tied to a specific error without
that PC's Godot log.

Only the host accepts registered peer input. Movement is limited to unit length,
aim must be finite and bounded, action keys are explicitly selected, and stale
input is cleared after 0.5 seconds. A player may change only their own readiness.
Starting checks host authority, lobby phase, actual member count, and all-ready
state. Joining during an in-progress match does not register a new player.

A seven-character room code reversibly encodes the host's LAN IPv4 address; the
Join field also accepts the IP itself. Codes are LAN addresses, not passwords or
internet matchmaking. The host-address tooltip is available for PCs with multiple
network adapters. A failed connection times out after ten seconds.
On Windows, the host now chooses the IPv4 address on the lowest-metric default
route before considering other local adapters. This avoids advertising a
VirtualBox host-only address when Wi-Fi is the active LAN. If a VPN or unusual
router setup still selects the wrong address, joiners can enter the host's
active LAN IPv4 address directly in the Join field.
On 2026-10-25, the explicit IPv4 bind passed a two-process host/client probe
using the active Ethernet address `192.168.18.21`, and a five-process local LAN
smoke test passed registration, roster, movement, ready/start, match phases,
projectile feedback, results, and disconnect handling. A separate physical PC
and its firewall/router path were not tested.

Departing clients leave the roster and active world. Host loss returns clients
to the menu with a notice. If Taya leaves during preparation or active play, a remaining member
takes over and the can resets at its base, including when it was being carried.
There is no host migration or late match joining. Play Online now uses a
GD-Sync relay adapter with four-player rooms; see [online setup](online_setup.md). The earlier two-hit powered throw rule was retired in favor of five three-orb specials. The opening throw-off is implemented but has not yet been playtested;
LAN movement prediction and smoothing are implemented as described above.

Verified using five separate processes on one PC. A physical five-PC LAN test,
including Windows firewall configuration and adapter selection, remains manual.


## Skill throws and online transport

The existing LanSession API also owns GD-Sync internet rooms. Its online adapter
maps the creator to game ID 1 and other service IDs to distinct client IDs.
Only allowlisted methods with validated argument types reach the session handlers.
The creator stays authoritative; losing that original host closes the session even
if the service chooses another owner. LAN still uses ENet with five total players.

Movement/world packets carry monotonically increasing sequences. Charge press and
release edges use reliable delivery separately from movement; stale and duplicate
edges are ignored. The host chooses each charge target and start time. Clients
render the bouncing marker against a ping-synchronized host clock. Releases carry
the charge ID, synchronized timestamp and aim, never a client-selected power or
accuracy result. The host accepts at most 250 ms of release rewind (and 30 ms
clock tolerance into the future), then computes quality and aim deviation itself.
Releases predating that charge or referring to another charge are rejected.

Online adapter acceptance has passed using four separate gameplay processes and
a rejected fifth peer, real GD-Sync local transport, artificial per-direction
latency (40 ms host / 80 ms clients) and 10% dropped unreliable sends. These are
local integration checks; real cloud keys and a physical cross-network playtest
are still required before internet connectivity can be marked verified.

## Gameplay rules protocol 4

After automatic scene-load acknowledgements, the host runs the opening banner and moves each actor to the toe-line. All players get one throw; the host measures settled slippers from the can base, treating no throw or out-of-bounds as a forfeit. The farthest selects Taya, with lowest roster slot breaking ties. A result notice precedes seven seconds of preparation, which unlocks only Taya's movement;
throwers' movement/action requests are rejected until the 300-second match starts.
Snapshots include the phase deadline against synchronized host time. Clients
clamp the displayed timer to its phase duration.

The same host-owned blue rectangle validates charge, release and the actual
animation-frame spawn. Taya walking/lunging is constrained outside its right edge.
Tags require a standing can, an unprotected thrower, and expired re-tag immunity.
Match can recovery is manual and returns to the fixed far-right base. Original
host disconnect rules and scoring authority are unchanged.

Result entries now include the member's character index for podium art. Builds
with a different protocol are rejected during registration; all peers must update.


## Tag handoff snapshot — 2026-10-27

After a host-validated tag, `tag_reset` freezes input and match scoring for 2.6 seconds. The host removes owned projectiles without awarding outcome points, moves the new Taya near the standing can and all four throwers to their toe-line slots, and resumes the paused match timer. Existing world snapshots carry phase, deadline, player positions, roles, scores, and the tag notice; clients clear LAN prediction on the phase transition. LAN/online compatibility identifiers are `canclash-lan-abilities-9` / `canclash-rules-13`. A two-process localhost ENet host/joiner probe passed; physical cross-PC play remains unverified.

## LAN responsiveness check — 2026-10-24

`tests/lan_responsiveness_smoke.gd` runs as a host/client pair with arguments
`host|client <shared-test-folder> [baseline]`. It uses actual ENet, 120 ms delayed
received snapshots and one dropped snapshot in ten. On this PC, before/after:

| Measure | Before | After |
| --- | ---: | ---: |
| First visible local movement | 172.5 ms | 7.2 ms |
| Local movement frames per 61 samples | 9 | 61 |
| Remote movement frames per 61 samples | 9 | 48 |
| Position error after stopping | 0 px | 0 px |

These are controlled process measurements, not a physical Wi-Fi benchmark.
`lan_prediction_smoke.gd` checks all five characters' reconciliation, boundaries,
action locks, role/spawn changes, stale-network cutoff and bounded history.

On 2026-10-25, LAN host snapshots increased to 30 Hz, remote visual extrapolation
was capped at 50 ms, and acknowledged inputs are removed without filtering a new
history array. The same two-process ENet check with 120 ms snapshot delay and 10%
loss passed: 7.965 ms first local movement, 62/62 local moving frames, 47/62
remote moving frames, and 0 px settled drift. This remains a one-PC check; five
physical PCs and different Wi-Fi conditions need a playtest.

## LAN diagnosis and packet-gap tuning — 2026-10-27

This PC's active default route is Ethernet `192.168.18.21`; VirtualBox and hotspot
adapters are also present. Hosting advertises `192.168.18.21` and its room code.
A separate Godot process joined that actual adapter address and selected Kay.
Windows reports the active Ethernet profile as Private and has enabled inbound
UDP 54652 rules limited to LocalSubnet. This verifies the host PC's local route,
not reachability from a friend's PC or their firewall/router.

The working tree uses LAN protocol `canclash-lan-abilities-9`, while the current
checked-in `origin/main` uses `canclash-lan-abilities-6`. A friend who pulled
only that older main build cannot join this version; both machines need the same
updated files and an editor reimport. Keep the version rejection because match
snapshots and rules changed. The host lobby now displays the LAN build number,
and Join timeouts show the attempted IP and UDP port.

`tests/lan_snapshot_profile.gd` measured five-actor snapshots at 761 bytes
compressed in the lobby and 880 bytes in the match (6,872 and 6,704 bytes raw).
Build, encode, and ZSTD compression took about 0.09–0.14 ms per snapshot on
this PC. At 30 Hz for four joiners, the match snapshot payload is roughly
106 KB/s total before transport overhead; snapshot serialization was not a
measured bottleneck. The LAN input path remains 60 Hz for responsiveness.

Client prediction now begins at the shared roster spawn before the first world
packet and tolerates a 0.65-second snapshot gap instead of 0.35 seconds. It still
stops predicting after the gap and reconciles to the host on the next snapshot.
The responsiveness probe was updated for the new character-select overlay and
waits for ten world packets before measuring, so shader/startup stalls do not
masquerade as steady-state network loss. A two-process check with 120 ms delayed
snapshots and one dropped packet in ten passed: 20.624 ms first visible movement,
61/61 local moving frames, 49/61 remote moving frames, and 0 px settled drift.
The LAN prediction unit check and two-process tag-reset match probe also passed.
Physical cross-PC connectivity and real Wi-Fi jitter remain unverified.

## Joiner visual smoothness — 2026-10-27

The joiner used to overwrite every remote actor's walking sprite frame on each
world snapshot. Uneven packet arrival could rewind or skip the walk cycle even
while position interpolation was smooth. Remote idle/walk/sprint animations now
advance locally between snapshots at the host's replicated animation speed;
animation changes and action poses still synchronize from the host. Remote
position extrapolation now eases to a stop over a bounded 120 ms lead instead
of stopping abruptly at a fixed 50 ms cap. These changes affect presentation
only; host positions and collisions remain authoritative.

Snapshot application no longer updates hidden throw-status labels for every
remote actor, and the can only schedules a collision-shape change when its
carried state actually changes. In the two-actor headless probe, mean snapshot
application fell from about 0.52 ms to 0.35–0.40 ms. A host/joiner test with
120 ms delayed snapshots and 10% dropped packets passed 61/61 local moving
frames, 51/61 remote moving frames, and negligible settled drift. A separate
stress run with 160 ms delay and 20% loss also settled correctly. The probe
asserts that an incoming snapshot does not reset a remote walk frame. A full
physical hotspot playtest and rendered visual review are still needed.
