
extends Control

@export var match_duration: int = 120

@onready var timer_label: Label = $PanelContainer/TimerLabel

var time_remaining: float = 0.0
var timer_running: bool = false


func _ready() -> void:
	time_remaining = match_duration
	update_timer_display()
	start_timer()


func _process(delta: float) -> void:
	if not timer_running:
		return

	time_remaining -= delta

	if time_remaining <= 0.0:
		time_remaining = 0.0
		timer_running = false
		update_timer_display()
		on_timer_finished()
		return

	update_timer_display()


func update_timer_display() -> void:
	var total_seconds: int = int(ceil(time_remaining))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	timer_label.text = "%02d:%02d" % [minutes, seconds]


func start_timer() -> void:
	if time_remaining > 0.0:
		timer_running = true


func pause_timer() -> void:
	timer_running = false


func reset_timer() -> void:
	timer_running = false
	time_remaining = match_duration
	update_timer_display()


func on_timer_finished() -> void:
	print("Time is up!")
	# Add your match-ending logic here.
