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

Clients send input at 30 Hz on an unreliable ordered channel. Host snapshots are
sent at 20 Hz on another channel, using bounded Zstandard-compressed Godot Variant
data to avoid oversized uncompressed state packets. Clients do not simulate
collisions, hits, tags, or scores. Registration, readiness, map selection,
tutorial acknowledgments, events, and results use reliable RPCs.

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
GD-Sync relay adapter with four-player rooms; see [online setup](online_setup.md). Snapshot interpolation/prediction and the concept's powered throw
and opening throw-off remain future work; these are not required by Adjustments.

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

The host chooses initial Taya from every registered participant after tutorial
acknowledgments. Seven seconds of preparation unlock only Taya's movement;
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
