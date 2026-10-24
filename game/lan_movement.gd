extends RefCounted

## Presentation-only LAN prediction. The host still decides every game outcome.
const MAX_PENDING := 64
const STALE_SECONDS := 0.35
var actor: CharacterBody2D
var ready := false
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var visual_error := Vector2.ZERO
var last_snapshot := -1.0
var last_authority := Vector2.ZERO
var pending: Array[Dictionary] = []

func _init(player: CharacterBody2D) -> void:
	actor = player

func fresh() -> bool:
	return ready and Time.get_ticks_msec() / 1000.0 - last_snapshot < STALE_SECONDS

func step(delta: float, sequence: int, packet: Dictionary, movable: bool) -> void:
	if not fresh(): return
	var command := {"sequence": sequence, "delta": delta, "move": packet.move, "sprint": packet.sprint, "movable": movable, "carrying": actor.carrying_can}
	_simulate(command, true)
	pending.append(command)
	if pending.size() > MAX_PENDING: pending.pop_front()
	visual_error *= exp(-delta / 0.06)
	actor.position = position + visual_error

func receive(data: Dictionary, reset: bool) -> void:
	last_snapshot = Time.get_ticks_msec() / 1000.0
	reset = reset or not ready or last_authority.distance_to(data.position) > 128.0
	last_authority = data.position
	var displayed := actor.position
	if reset: pending.clear()
	var acknowledged := int(data.get("lan_ack", 0))
	pending = pending.filter(func(command: Dictionary) -> bool: return int(command.sequence) > acknowledged)
	position = data.position
	velocity = data.velocity
	for command in pending: _simulate(command, false)
	visual_error = Vector2.ZERO if reset or displayed.distance_to(position) > 128.0 else displayed - position
	actor.position = position + visual_error
	actor.velocity = velocity
	ready = true

func _simulate(command: Dictionary, animate: bool) -> void:
	actor.position = position
	actor.velocity = velocity
	if command.movable:
		var original_walk: float = actor.walk_speed
		var original_sprint: float = actor.sprint_speed
		if command.carrying:
			actor.walk_speed = actor.carry_speed
			actor.sprint_speed = actor.carry_speed
		actor.move_from_input(command.delta, command.move, command.sprint, animate, true)
		actor.walk_speed = original_walk
		actor.sprint_speed = original_sprint
	else:
		actor.velocity = Vector2.ZERO
	position = actor.position
	velocity = actor.velocity
