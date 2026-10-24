# LAN and online networking

Status: implemented for the active 2D menu, waiting room, and match flow.

One PC hosts and plays. Four other PCs join, for five players total.
Godot 4.7.2 ENet uses UDP port 54652, with four remote peers plus the host.
LanSession owns connection setup, real member roster, readiness, room codes,
map selection, tutorial acknowledgments, shared transitions, and results.

The host validates input requests and owns movement outcomes, can state,
slipper outcomes, tags, scores, match phase, and timer.
Clients display replicated state. A client must not award itself points or
declare a tag, can hit, safe return, or role transfer.

Validate the sending peer, player ownership, phase, role, legal action,
cooldowns, and request values before applying requests.

LAN clients send sequenced input each physics tick (60 Hz by default). Host
snapshots are sent at 20 Hz after actor physics, including the last input sequence
actually processed. The joining player predicts movement immediately, then replays
unacknowledged input from the authoritative position with a short visual correction.
Prediction uses explicit recorded timesteps, real scenery/player collisions, and
the same speeds, acceleration, friction, and Taya movement restriction as the host.
History is limited to 64 commands and prediction stops after 350 ms without a host
snapshot. Role/action/phase changes and teleports reset the prediction buffer.
Remote LAN actors are smoothed between snapshots with at most 80 ms extrapolation.
Client prediction never decides hits, tags, pickup, role transfers, or scores.

Online keeps its existing 30 Hz input and replica path. Both modes use bounded
Zstandard-compressed Godot Variant snapshots on an unreliable ordered channel.
Registration, readiness, map selection, automatic scene-load acknowledgements,
events, and results use reliable delivery. LAN compatibility is now
`canclash-lan-motion-1`; both PCs must run the updated build. Online compatibility
and its adapter are unchanged.

Only the host accepts registered peer input. Movement is limited to unit length,
aim must be finite and bounded, action keys are explicitly selected, and stale
input is cleared after 0.5 seconds. A player may change only their own readiness.
Starting checks host authority, lobby phase, actual member count, and all-ready
state. Joining during an in-progress match does not register a new player.

A seven-character room code reversibly encodes the host's LAN IPv4 address; the
Join field also accepts the IP itself. Codes are LAN addresses, not passwords or
internet matchmaking. The host-address tooltip is available for PCs with multiple
network adapters. A failed connection times out after ten seconds.

Departing clients leave the roster and active world. Host loss returns clients
to the menu with a notice. If Taya leaves during preparation or active play, a remaining member
takes over and the can resets at its base, including when it was being carried.
There is no host migration or late match joining. Play Online now uses a
GD-Sync relay adapter with four-player rooms; see [online setup](online_setup.md). The concept's powered throw and opening throw-off remain future work;
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

## Gameplay rules protocol 3

The host chooses initial Taya from every registered participant after automatic scene-load
acknowledgements. Seven seconds of preparation unlock only Taya's movement;
throwers' movement/action requests are rejected until the 600-second match starts.
Snapshots include the phase deadline against synchronized host time. Clients
clamp the displayed timer to its phase duration.

The same host-owned blue rectangle validates charge, release and the actual
animation-frame spawn. Taya walking/lunging is constrained outside its right edge.
Tags require a standing can, an unprotected thrower, and expired re-tag immunity.
Match can recovery is manual and returns to the fixed far-right base. Original
host disconnect rules and scoring authority are unchanged.

Result entries now include the member's character index for podium art. Builds
with a different protocol are rejected during registration; all peers must update.


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
