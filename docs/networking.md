# LAN networking plan

Status: proposed architecture; not implemented.

One PC hosts and plays. Four other PCs join, for five players total.
Use Godot's built-in multiplayer facilities with an ENet peer if Godot is confirmed.
LanSession owns connection setup, player roster, and scene transitions.

The host validates input requests and owns movement outcomes, can state,
slipper outcomes, tags, scores, power-up progress, match phase, and timer.
Clients display replicated state. A client must not award itself points or
declare a tag, can hit, safe return, or role transfer.

Validate the sending peer, player ownership, phase, role, legal action,
cooldowns, and request values before applying requests.

Port, state replication frequency, prediction/interpolation, and disconnect
handling remain implementation decisions. Start with direct LAN IP joining.
