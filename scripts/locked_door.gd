extends Node2D
## LockedDoor — pintu terkunci di celah tembok 1x2 tile (32x64).
## Visualnya sengaja LEBIH KECIL dari celah: kusen gelap mengisi celah,
## daun pintu 24x56 di dalamnya, jadi pintu terbaca sebagai pintu yang
## terpasang di tembok — bukan papan cokelat besar yang menutupi tembok.
## (Versi lama: panel 30x62 memenuhi celah + garis emas selebar pintu
## + tulisan TERKUNCI 80px yang meluber ke tembok — kelihatan kebesaran.
## Tulisan di pintu sengaja DIHAPUS: status terkunci ditunjukkan gembok
## emas di daun pintu + prompt "Pintu X terkunci — cari Kunci X" di bar
## bawah layar. Label Godot juga tidak bisa dipaksa sekecil itu — min
## size-nya diukur dengan font default sebelum theme override jalan.)
## Pintu di tembok HORIZONTAL (celah 2x1 tile): centang `horizontal`
## di Inspector (jangan putar rotation node — kalau node diputar 90°,
## semua visual ikut berputar dan pintu tidak lagi pas di celahnya).
## Soliditas dari StaticBody2D di sini, BUKAN dari TileMap, supaya
## membuka pintu tidak perlu mengubah tile.

@export var door_id: String = "A"
@export var door_cells: Array[Vector2i] = []
@export var horizontal: bool = false

var is_open: bool = false

var _body: StaticBody2D = null
var _frame: ColorRect = null
var _visual: ColorRect = null
var _plank_a: ColorRect = null
var _plank_b: ColorRect = null
var _handle: ColorRect = null
var _lock: ColorRect = null
var _lock_hole: ColorRect = null


func _ready() -> void:
	z_index = 7
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Bentuk tabrakan mengikuti orientasi pintu: vertikal 32x64,
	# horizontal 64x32. (Gameplay tidak berubah: celah tetap tertutup.)
	rect.size = Vector2(64, 32) if horizontal else Vector2(32, 64)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)
	_build_visual()


func _build_visual() -> void:
	# Semua ukuran di bawah dalam orientasi VERTIKAL (lebar x tinggi);
	# kalau horizontal, lebar dan tinggi ditukar.
	var gap := Vector2(30, 62) if not horizontal else Vector2(62, 30)
	var door := Vector2(24, 56) if not horizontal else Vector2(56, 24)
	var frame_off := Vector2(-15, -31) if not horizontal else Vector2(-31, -15)
	var door_off := Vector2(-12, -28) if not horizontal else Vector2(-28, -12)
	# Kusen: mengisi celah dengan kayu gelap — bingkai di sekeliling pintu.
	_frame = ColorRect.new()
	_frame.color = Color(0.26, 0.2, 0.15, 1.0)
	_frame.size = gap
	_frame.position = frame_off
	add_child(_frame)
	# Daun pintu: lebih kecil dari celah (kusen 3px terlihat di tiap sisi).
	_visual = ColorRect.new()
	_visual.color = Color(0.52, 0.36, 0.21, 1.0)
	_visual.size = door
	_visual.position = door_off
	add_child(_visual)
	# Dua garis papan pada daun pintu (vertikal kalau pintu vertikal,
	# horizontal kalau pintu horizontal).
	var plank_size := Vector2(2, 56) if not horizontal else Vector2(56, 2)
	_plank_a = ColorRect.new()
	_plank_a.color = Color(0.4, 0.27, 0.15, 1.0)
	_plank_a.size = plank_size
	_plank_a.position = Vector2(-4, -28) if not horizontal else Vector2(-28, -4)
	add_child(_plank_a)
	_plank_b = ColorRect.new()
	_plank_b.color = Color(0.4, 0.27, 0.15, 1.0)
	_plank_b.size = plank_size
	_plank_b.position = Vector2(4, -28) if not horizontal else Vector2(-28, 4)
	add_child(_plank_b)
	# Gagang kecil di sisi pintu (dulu: garis emas selebar pintu).
	_handle = ColorRect.new()
	_handle.color = Color(0.9, 0.75, 0.3, 1.0)
	_handle.size = Vector2(4, 4)
	_handle.position = Vector2(6, -2) if not horizontal else Vector2(-2, 6)
	add_child(_handle)
	# Gembok kecil di tengah atas daun pintu.
	_lock = ColorRect.new()
	_lock.color = Color(0.9, 0.75, 0.3, 1.0)
	_lock.size = Vector2(8, 7) if not horizontal else Vector2(7, 8)
	_lock.position = Vector2(-4, -20) if not horizontal else Vector2(-20, -4)
	add_child(_lock)
	_lock_hole = ColorRect.new()
	_lock_hole.color = Color(0.15, 0.1, 0.05, 1.0)
	_lock_hole.size = Vector2(2, 3) if not horizontal else Vector2(3, 2)
	_lock_hole.position = Vector2(-1, -18) if not horizontal else Vector2(-18, -1)
	add_child(_lock_hole)


func open_door() -> void:
	if is_open:
		return
	is_open = true
	if _body != null:
		_body.get_child(0).set_deferred("disabled", true)
	if _visual != null:
		_visual.color = Color(0.2, 0.35, 0.2, 0.4)
	for part: ColorRect in [_plank_a, _plank_b, _handle, _lock, _lock_hole]:
		if part != null:
			part.visible = false
