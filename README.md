# Can Clash

A Godot 4.7.2 arena game inspired by Tumbang Preso, with a playable menu,
waiting room, bots, host-authoritative matches and podium results.

## Run and play

Import `project.godot` in Godot and run the main scene.

- **Play Local:** up to five players on the same LAN, using ENet UDP 54652.
- **Play Online:** up to four players using GD-Sync Free room codes. Configure
  the developer's game keys using [the setup guide](docs/online_setup.md).
- **Practice:** solo waiting-room practice; no keys or network required.
- Enter `developer-mode` in Play Local's Join field for a solo bot match.
  Set 0–4 bots in that waiting room before pressing Ready and Start.

LAN, Practice and developer mode work without GD-Sync credentials.

## Match rules

After everyone loads the map, a random participant becomes Taya.
Throwers remain frozen for seven seconds while Taya prepares, then a five-minute
match begins. Taya has no slipper and cannot enter the full-height blue area.

Throw only from blue: aim with the mouse, hold left-click and release the bouncing
marker in the narrow green window for full power and accuracy. Orange gives
intermediate power; red adds substantial aim error. Retrieve your own colored
slipper by running over it, then return to blue for a safe-return point.

The can starts on the far right. When it falls, Taya waits for it to settle,
presses E to pick it up, carries it to its original marked spot, and presses E
to place it. Tagging works only outside blue while the can stands. Space lunges;
Shift sprints. Tagged players recover control immediately with one second of
protection against re-tagging.

Can hits, safe returns, Taya tags and opponents' missed throws award points under
the host's authority. Highest score wins; tied leaders share victory. The top
three appear on gold, silver and bronze podiums. Developer games do not affect
saved statistics.

## Verification

Headless checks live in `tests/`, including `gameplay_rules_smoke.gd`,
`far_right_can_smoke.gd`, `lan_session_smoke.gd` and `online_session_smoke.gd`.
Set `CAN_CLASH_SAVE_PATH` to isolate test profiles from your saved statistics.

LAN has been checked with five separate processes on one PC. GD-Sync's local
transport has been checked with four players, a rejected fifth peer, simulated
latency and packet loss. Physical LAN and cross-network internet playtests remain
manual. See [networking details](docs/networking.md).
