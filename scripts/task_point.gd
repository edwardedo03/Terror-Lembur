extends Node2D

var task_id := -1
var label_text := ""
var need_players := 1
var time_needed := 8.0
var noise_radius := 150.0
var progress := 0.0
var done := false
var pulse := 0.0

func _ready() -> void:
	set_multiplayer_authority(1)

func setup(id: int, text: String, need: int, time_s: float, noise_r: float) -> void:
	task_id = id
	label_text = text
	need_players = need
	time_needed = time_s
	noise_radius = noise_r

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	if done:
		draw_circle(Vector2.ZERO, 14, Color(0.2, 0.9, 0.3, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(-4, 5), "✓", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0, 0, 0, 1))
		return
	var a := 0.6 + 0.3 * sin(pulse * 4.0)
	draw_circle(Vector2.ZERO, 14, Color(1, 0.85, 0.2, a))
	draw_arc(Vector2.ZERO, 14, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.5)
	var bar_w := 56.0
	var bar_pos := Vector2(-bar_w * 0.5, -38)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, 8)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * clampf(progress, 0.0, 1.0), 8)), Color(1, 0.85, 0.2, 1))
	var tw := label_text.length() * 9.0
	draw_rect(Rect2(Vector2(-tw * 0.5 - 4, -58), Vector2(tw + 8, 18)), Color(0, 0, 0, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(0, -44), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 1))

func is_complete() -> bool:
	return done
