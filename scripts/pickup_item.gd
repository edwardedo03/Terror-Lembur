extends Node2D

var taken := false
var bob := 0.0

func _ready() -> void:
	set_multiplayer_authority(1)

func _process(delta: float) -> void:
	bob += delta
	queue_redraw()

func _draw() -> void:
	if taken:
		return
	var y := sin(bob * 3.0) * 2.0
	draw_circle(Vector2(0, y), 6, Color(0.9, 0.7, 0.3, 1))
	draw_arc(Vector2(0, y), 6, 0, TAU, 12, Color(1, 1, 1, 0.9), 1.5)
	draw_circle(Vector2(0, y - 2), 2.5, Color(0.3, 0.2, 0.1, 1))
