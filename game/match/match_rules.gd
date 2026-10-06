extends Resource
class_name MatchRules

# Duration remains unset until the team decides; gameplay must reject zero.
@export var match_duration_seconds: float = 0.0
@export var lunge_cooldown_seconds: float = 10.0
@export var hits_for_power_up: int = 2
@export var can_hit_points: int = 1
@export var safe_return_points: int = 1
@export var miss_points: int = 1
@export var tag_points: int = 1

# TODO: Add charge, flight, carry speed, and lunge tuning during implementation.
