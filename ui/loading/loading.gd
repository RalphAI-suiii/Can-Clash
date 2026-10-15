extends Control

const MENU_SCENE := "res://ui/main_menu/main_menuu.tscn"
const MIN_DISPLAY_TIME := 1.4

@onready var progress_bar: ProgressBar = $LoadingCard/Progress
@onready var status_label: Label = $LoadingCard/Status
@onready var retry_button: Button = $LoadingCard/Retry
@onready var fade: ColorRect = $Fade

var elapsed := 0.0
var transitioning := false


func _ready() -> void:
	retry_button.pressed.connect(_start_loading)
	retry_button.hide()
	fade.hide()
	_start_loading()


func _start_loading() -> void:
	elapsed = 0.0
	transitioning = false
	progress_bar.value = 0.0
	status_label.text = "LOADING..."
	retry_button.hide()
	if ResourceLoader.load_threaded_request(MENU_SCENE) != OK:
		_show_error()


func _process(delta: float) -> void:
	if transitioning or retry_button.visible:
		return

	elapsed += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MENU_SCENE, progress)
	var loaded_fraction := 1.0 if status == ResourceLoader.THREAD_LOAD_LOADED else 0.0
	if not progress.is_empty():
		loaded_fraction = float(progress[0])
	progress_bar.value = minf(loaded_fraction, elapsed / MIN_DISPLAY_TIME) * 100.0

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			if elapsed >= MIN_DISPLAY_TIME:
				_enter_menu()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_error()


func _enter_menu() -> void:
	transitioning = true
	var menu_scene := ResourceLoader.load_threaded_get(MENU_SCENE) as PackedScene
	if menu_scene == null:
		_show_error()
		return
	status_label.text = "READY!"
	fade.show()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.25)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_packed(menu_scene))


func _show_error() -> void:
	status_label.text = "MENU COULDN'T LOAD"
	progress_bar.value = 0.0
	retry_button.show()
	retry_button.grab_focus()
