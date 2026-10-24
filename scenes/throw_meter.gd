extends ProgressBar

var art: Control

## The marker is timing, not power: only the green window is a perfect throw.
@export_range(0.25, 0.75) var target_center := 0.5:
	set(next):
		target_center = clampf(next, 0.25, 0.75)
		queue_redraw()
		if is_instance_valid(art): art.queue_redraw()

const GREEN := Color("64ce66")
const ORANGE := Color("f5a23c")
const GREEN_HALF_WIDTH := 0.02
const GOOD_HALF_WIDTH := 0.25
const RED := Color("e86b55")

static func marker_at(elapsed: float, sweep: float = 1.25) -> float:
	return 1.0 - absf(fposmod(maxf(0.0, elapsed) / maxf(sweep, 0.01), 2.0) - 1.0)

static func quality_at(marker: float, center: float) -> Dictionary:
	var distance := absf(clampf(marker, 0.0, 1.0) - center)
	if distance <= GREEN_HALF_WIDTH + 0.000001:
		return {"band": "PERFECT", "power": 1.0, "spread": 0.0, "color": GREEN}
	if distance <= 0.250001:
		var error := clampf((distance - GREEN_HALF_WIDTH) / (GOOD_HALF_WIDTH - GREEN_HALF_WIDTH), 0.0, 1.0)
		return {"band": "GOOD", "power": lerpf(0.95, 0.65, error), "spread": 5.0 * error, "color": ORANGE}
	var error := clampf((distance - 0.25) / maxf(0.01, maxf(center, 1.0 - center) - 0.25), 0.0, 1.0)
	return {"band": "RISKY", "power": lerpf(0.60, 0.25, error), "spread": 20.0, "color": RED}

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("background", StyleBoxEmpty.new())
	add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	art = Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.draw.connect(_draw_meter)
	value_changed.connect(func(_value: float) -> void: art.queue_redraw())

func _draw_meter() -> void:
	var track := Rect2(Vector2.ZERO, size)
	art.draw_rect(track.grow(4.0), Color("20130f"))
	art.draw_rect(track, RED)
	var yellow_left := target_center - 0.25
	art.draw_rect(Rect2(Vector2(size.x * yellow_left, 0), Vector2(size.x * 0.5, size.y)), ORANGE)
	art.draw_rect(Rect2(Vector2(size.x * (target_center - GREEN_HALF_WIDTH), 0), Vector2(size.x * GREEN_HALF_WIDTH * 2.0, size.y)), GREEN)
	var marker_x := size.x * value
	art.draw_line(Vector2(marker_x, -6), Vector2(marker_x, size.y + 6), Color("20130f"), 9.0)
	art.draw_line(Vector2(marker_x, -5), Vector2(marker_x, size.y + 5), Color("fff5dc"), 4.0)
