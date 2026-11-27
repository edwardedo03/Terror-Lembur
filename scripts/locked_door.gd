extends Node2D
## LockedDoor — jalan pintas yang tertutup sampai tugas terkait selesai.
## Pintu A (barat, Arsip) dibuka tugas Arsip. Pintu B (timur, HR) dibuka
## tugas Panel Listrik. Keduanya hanya pintas: map tetap bisa dilalui
## penuh saat tertutup (dicek BFS di tools/design_map.py).
## Pintu baru: duplikasi node ini di Doors, ganti huruf di NAMA node DAN
## di properti door_id (mis. DoorD + door_id "D"), lalu isi door_cells
## dengan 2 sel pintunya. Kalau door_cells lupa diisi / salah salin,
## _door_cells() di level_1.gd tetap memblokir 2 sel dari posisi pintu.
## Soliditas dari StaticBody2D di sini, BUKAN dari TileMap, supaya
## membuka pintu tidak perlu mengubah tile.

@export var door_id: String = "A"
@export var door_cells: Array[Vector2i] = []

var is_open: bool = false

var _body: StaticBody2D = null
var _visual: ColorRect = null
var _label: Label = null


func _ready() -> void:
	z_index = 7
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 64)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)
	_visual = ColorRect.new()
	_visual.color = Color(0.45, 0.3, 0.18, 1.0)
	_visual.size = Vector2(30, 62)
	_visual.position = Vector2(-15, -31)
	add_child(_visual)
	var stripe := ColorRect.new()
	stripe.color = Color(0.9, 0.75, 0.3)
	stripe.size = Vector2(30, 6)
	stripe.position = Vector2(-15, -3)
	add_child(stripe)
	_label = Label.new()
	_label.text = "TERKUNCI"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-40, -48)
	_label.size = Vector2(80, 14)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 0.95))
	add_child(_label)


func open_door() -> void:
	if is_open:
		return
	is_open = true
	if _body != null:
		_body.get_child(0).set_deferred("disabled", true)
	if _visual != null:
		_visual.color = Color(0.2, 0.35, 0.2, 0.4)
	if _label != null:
		_label.text = "TERBUKA"
		_label.add_theme_color_override("font_color", Color(0.6, 1, 0.65, 0.9))
