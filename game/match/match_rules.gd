extends Resource
class_name MatchRules

# Three minutes of scoring after the separate 30-second grace period.
@export var match_duration_seconds: float = 180.0
@export var lunge_cooldown_seconds: float = 10.0
@export var hits_for_power_up: int = 2
@export var can_hit_points: int = 1
@export var safe_return_points: int = 1
@export var miss_points: int = 1
@export var tag_points: int = 1

# TODO: Add charge, flight, carry speed, and lunge tuning during implementation.
