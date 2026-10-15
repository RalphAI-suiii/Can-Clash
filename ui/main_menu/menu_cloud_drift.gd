extends Sprite2D

@export var drift_pixels: float = 24.0
@export var cycle_seconds: float = 24.0
@export var phase: float = 0.0

var _start_x: float
var _elapsed: float = 0.0


func _ready() -> void:
	_start_x = position.x


func _process(delta: float) -> void:
	_elapsed += delta
	position.x = _start_x + sin(TAU * _elapsed / cycle_seconds + phase) * drift_pixels
