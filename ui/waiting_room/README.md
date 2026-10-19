# Waiting room

Open `res://ui/waiting_room/waiting_room.tscn` and press **F6** in Godot 4.

- WASD or arrow keys move the local player; Shift sprints.
- The bottom-right Ready button toggles Player 1 between READY and NOT READY.
- Ready-panel rows display status only. Clicking them never changes readiness.
- Players can continue moving while ready. No throws or gameplay objects run here.
- Leave or Escape returns to the existing host lobby.

The background scene is an artwork-only extraction of `level/level.tscn`:
`Backdrop`, `Ground`, and `Decals`, using the original textures, tiles, and court
shader. The original level is unchanged. Its `World` (props, fences, collisions,
and test player), spawn markers, and gameplay camera are excluded. Tile collisions
are disabled in the extracted background. A grass-colored fill covers gaps
between the original painted layers.

The ready panel reuses `scenes/Player_ready.tscn` with the existing blue panel,
cream rows, and Titan One lettering. The waiting-room HUD keeps that visual style
and adds a blue action button, green selected state, and visible keyboard focus.

This is a local waiting-room preview: the five rows retain the existing roster
placeholders. LAN joining, remote movement, and ready-state replication remain
unimplemented in `autoload/lan_session.gd`. `local_player_id` defaults to 1; a
future session can supply the assigned player ID and call `set_player_ready` on
the panel for replicated updates.

Run the interaction check from the project root:

```powershell
godot --headless --path . --script res://tests/waiting_room_smoke.gd
```

The check clicks rows and the Ready button, verifies ready/unready transitions
and independent player states, moves while ready, checks movement bounds and
button placement, and tests roster updates after a player leaves.
