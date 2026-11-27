extends Node2D
## KeyItem — kunci pintu. Mirip ReviveItem, tapi terlihat sejak awal
## dan tidak hilang sendiri. Level yang memutuskan siapa membawanya.
## Pasang satu node per pintu (KeyItemA, KeyItemB, ...) di scene
## level_1.tscn, di bawah Level sejajar ReviveItem — duplikasi node
## yang ada, lalu ganti huruf di NAMA node DAN di properti key_id-nya
## (mis. KeyItemD + key_id "D"). Jangan disembunyikan di _ready.

@export var key_id: String = "A"

var _bob: float = 0.0
var _visual: Node2D = null


func _ready() -> void:
	z_index = 8
	_visual = Node2D.new()
	add_child(_visual)
	var body := ColorRect.new()
	body.color = Color(0.95, 0.8, 0.25)
	body.size = Vector2(10, 26)
	body.position = Vector2(-5, -13)
	_visual.add_child(body)
	var bow := ColorRect.new()
	bow.color = Color(0.95, 0.8, 0.25)
	bow.size = Vector2(14, 14)
	bow.position = Vector2(-7, -20)
	_visual.add_child(bow)
	var teeth := ColorRect.new()
	teeth.color = Color(0.95, 0.8, 0.25)
	teeth.size = Vector2(12, 4)
	teeth.position = Vector2(5, 6)
	_visual.add_child(teeth)
	var label := Label.new()
	label.text = "KUNCI " + key_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -40)
	label.size = Vector2(100, 14)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 0.95))
	add_child(label)


func _process(delta: float) -> void:
	if not visible:
		return
	_bob += delta * 3.0
	if _visual != null:
		_visual.position.y = sin(_bob) * 3.0


func show_at(pos: Vector2) -> void:
	global_position = pos
	visible = true


func hide_item() -> void:
	visible = false
