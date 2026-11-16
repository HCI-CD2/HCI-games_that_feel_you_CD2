extends Control
## Signal-strength style meter: bars rising left to right, lit up to `value`.
## All bars turn hot when value reaches `levels`.

@export var levels: int = 3
@export var value: int = 0:
	set(v):
		value = v
		queue_redraw()
@export var bar_width: float = 8.0
@export var gap: float = 4.0
@export var color_on := Color(0.95, 0.9, 0.8, 1.0)
@export var color_hot := Color(1.0, 0.36, 0.3, 1.0)
@export var color_off := Color(0.95, 0.9, 0.8, 0.22)


func _get_minimum_size() -> Vector2:
	return Vector2(levels * bar_width + (levels - 1) * gap, 24)


func _draw() -> void:
	var h := size.y
	for i in levels:
		var bh := h * float(i + 1) / float(levels)
		var x := i * (bar_width + gap)
		var c := color_off
		if i < value:
			c = color_hot if value >= levels else color_on
		draw_rect(Rect2(x, h - bh, bar_width, bh), c)
