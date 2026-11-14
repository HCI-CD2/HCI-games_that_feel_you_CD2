extends Control
## Row of small diamonds, filled up to `done`. Used top-left as question progress.

@export var total: int = 6:
	set(v):
		total = v
		update_minimum_size()
		queue_redraw()
@export var done: int = 0:
	set(v):
		done = v
		queue_redraw()
@export var radius: float = 6.0
@export var gap: float = 8.0
@export var color_done := Color(0.95, 0.9, 0.8, 1.0)
@export var color_todo := Color(0.95, 0.9, 0.8, 0.9)


func _get_minimum_size() -> Vector2:
	return Vector2(total * radius * 2.0 + max(total - 1, 0) * gap, radius * 2.0 + 2.0)


func _draw() -> void:
	for i in total:
		var cx := radius + i * (radius * 2.0 + gap)
		var cy := radius + 1.0
		var pts := PackedVector2Array([
			Vector2(cx, cy - radius), Vector2(cx + radius, cy),
			Vector2(cx, cy + radius), Vector2(cx - radius, cy),
		])
		if i < done:
			draw_colored_polygon(pts, color_done)
		else:
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, color_todo, 1.5, true)
