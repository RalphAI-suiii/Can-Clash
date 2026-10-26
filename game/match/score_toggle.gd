extends Button

var expanded := true:
	set(value):
		if expanded == value:
			return
		expanded = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var tip_y := 5.0 if expanded else -5.0
	var edge_y := -4.0 if expanded else 4.0
	var chevron := PackedVector2Array([
		center + Vector2(-9, edge_y),
		center + Vector2(0, tip_y),
		center + Vector2(9, edge_y),
	])
	draw_polyline(chevron, Color("fff5dc"), 4.0, true)
