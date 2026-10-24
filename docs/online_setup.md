# GD-Sync Free setup

Play Local uses ENet for up to five players on the same LAN. It does not use
GD-Sync credentials or cloud bandwidth. Practice and developer mode remain offline.
Play Online uses GD-Sync for up to four players, including the host.

## Configure the developer's game

1. Create a free developer account at https://www.gd-sync.com/ and generate an API
   key pair for Can Clash. All players must use the same game configuration.
2. Copy `addons/GD-Sync/keys.example.cfg` to `addons/GD-Sync/keys.cfg` and enter the
   public/private **game API keys** from that account. The actual file is ignored
   by Git. Do not put account passwords or keys in source, screenshots, or logs.
3. Alternatively, set `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY` in the environment
   used to launch Godot/the game. File-based configuration takes precedence.
4. Restart the game after configuring keys. Play Online -> Create Room provides a
   seven-character code; friends select Join Room and enter that code.

Room codes are unlisted lobby names, not passwords. No player account screen or
router port forwarding is required. The host controls gameplay and must remain
connected. Rooms close to new members when a match starts.

The free plan currently permits four players/lobby and 200 MB/day of transfer.
Reaching the allowance disconnects online sessions; there is no automatic paid
upgrade. Check https://www.gd-sync.com/plans and the service dashboard for current
limits and measured usage. LAN does not consume the allowance.

## Sharing a Windows build

Use the included Windows Desktop export preset. Its non-resource include filter
embeds the locally configured `addons/GD-Sync/keys.cfg`; the credentials themselves
are never committed. Use only the game's GD-Sync API keys in a distributed build,
never developer-account credentials. Environment-only configuration is not embedded:
provide the same launch environment on each test PC, or configure the ignored file
before exporting. Verify exports include the configured keys before distribution.

Everyone must use the same updated build. Old network builds are rejected because
the skill meter changes the throw protocol. Invalid/full/started rooms, missing
configuration, host loss and service failures return actionable messages.

## Verification status and commands

Automated tests use isolated profile paths through `CAN_CLASH_SAVE_PATH`.

- `godot --headless --path . --script res://tests/skill_throw_smoke.gd`
- `godot --headless --path . --script res://tests/lan_session_smoke.gd -- host DIR`
  plus clients `client1` through `client4` using the same existing DIR.
- `godot --headless --path . --script res://tests/online_session_smoke.gd -- host DIR`
  plus `client1` through `client3` and `overflow` (the rejected fifth player). This explicitly uses GD-Sync's real **local**
  transport with a synthetic key, seeded loopback discovery, artificial latency
  and packet loss. It never contacts the cloud or consumes the free allowance.

Local transport tests do not verify GD-Sync cloud availability or NAT traversal.
After configuring real keys, use two Windows PCs on different internet connections
(for example, home Wi-Fi and a phone hotspot). Create/join using only the room code,
then check movement, timing releases, ready/start, shared results and host departure.
Expand to four real players and verify that a fifth join is rejected. Internet play
is not considered verified until this cross-network check passes.

## Dependency

GD-Sync 1.0.2, upstream commit `ba7f8e4068f6afb4b72e7b864a1e0c0c4e1069c2`,
vendored from https://github.com/GD-Sync/GD-Sync. Its license is retained alongside
the plugin. Local compatibility changes guard missing current scenes at startup,
avoid debugger calls without an attached debugger, and bound log cleanup when
multiple files share a timestamp. Its cloud protocol/cryptography is unchanged.
