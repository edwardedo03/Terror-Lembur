extends Node2D

var direction := Vector2.RIGHT
var speed := 420.0
var flight := 0.6
var landed := false
var land_timer := 0.0
var level: Node2D

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _ready() -> void:
	level = get_parent().get_parent()

func launch(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direction = dir.normalized()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if landed:
		land_timer += delta
		if land_timer > 1.2:
			queue_free()
		return
	flight -= delta
	global_position += direction * speed * delta
	if flight <= 0.0:
		landed = true
		if level != null and level.has_method("report_noise"):
			level.report_noise(global_position, 300.0)
	queue_redraw()

func _draw() -> void:
	if landed:
		draw_arc(Vector2.ZERO, 10 + land_timer * 30.0, 0, TAU, 20, Color(1, 1, 1, maxf(0.0, 0.8 - land_timer)), 2.0)
	draw_circle(Vector2.ZERO, 5, Color(0.1, 0.1, 0.1, 1))
	draw_arc(Vector2.ZERO, 5, 0, TAU, 12, Color(1, 1, 1, 0.9), 1.5)
