extends SceneTree
## Reproduksi bug pintu terkunci vs pathfinding (headless).
## 1. Baca door_cells tiap pintu dari scene + sel sebenarnya dari posisi.
## 2. Bangun pathfinder persis seperti level_1.gd _setup_pathfinder.
## 3. Cek: apakah sel pintu terkunci terblokir? Apakah jalur musuh
##    dari satu sisi pintu ke sisi lain melewati sel pintu?
##
## Dijalankan dari folder repo: godot --headless -s test_doors.gd

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	print("FAIL: ", msg)


func _init() -> void:
	var scene: PackedScene = load("res://scenes/level_1.tscn")
	var level: Node = scene.instantiate()
	var floor_layer: TileMapLayer = level.get_node_or_null("Floor")
	var walls_layer: TileMapLayer = level.get_node_or_null("Walls")
	var props_layer: TileMapLayer = level.get_node_or_null("Props")
	var props0_layer: TileMapLayer = level.get_node_or_null("Props0")
	var props1_layer: TileMapLayer = level.get_node_or_null("Props1")
	var doors_container: Node = level.get_node_or_null("Doors")
	var traps_container: Node = level.get_node_or_null("Traps")
	var enemy: Node = level.get_node_or_null("Enemy")

	# --- 1. Data pintu dari scene ---
	var doors: Array[Node] = []
	if doors_container != null:
		for d: Node in doors_container.get_children():
			doors.append(d)
	print("pintu di scene: ", doors.size())
	for d: Node in doors:
		var pos: Vector2 = (d as Node2D).global_position
		var true_cell: Vector2i = Vector2i((pos / 32.0).floor())
		print("  pintu %s pos=%s sel-dari-pos=%s door_cells=%s" % [str(d.get("door_id")), str(pos), str(true_cell), str(d.get("door_cells"))])

	# --- 2. Pathfinder seperti level ---
	var pf := GridPathfinder.new()
	var blocked: Dictionary = {}
	for d: Node in doors:
		for cell: Vector2i in (d.get("door_cells") as Array[Vector2i]):
			blocked[cell] = true
	pf.setup(floor_layer, walls_layer, props_layer, blocked, [props0_layer, props1_layer])
	if traps_container != null:
		for tr: Node in traps_container.get_children():
			pf.set_trap_blocked(pf.world_to_cell((tr as Node2D).global_position), true)

	# --- 3a. Sel pintu terkunci harus terblokir ---
	for d: Node in doors:
		for cell: Vector2i in (d.get("door_cells") as Array[Vector2i]):
			if not pf.is_cell_blocked(cell):
				_fail("sel pintu %s %s TIDAK terblokir padahal terkunci" % [str(d.get("door_id")), str(cell)])
			else:
				print("OK: sel pintu %s %s terblokir" % [str(d.get("door_id")), str(cell)])
		# Sel sebenarnya dari posisi pintu (2 sel vertikal, pintu 32x64)
		var pos: Vector2 = (d as Node2D).global_position
		var c0: Vector2i = Vector2i(int(pos.x / 32.0), int((pos.y - 16.0) / 32.0))
		var c1: Vector2i = Vector2i(int(pos.x / 32.0), int((pos.y + 16.0) / 32.0))
		for cell: Vector2i in [c0, c1]:
			var declared: bool = (d.get("door_cells") as Array[Vector2i]).has(cell)
			print("  pintu %s sel-fisik %s: terblokir=%s, ada-di-door_cells=%s" % [str(d.get("door_id")), str(cell), str(pf.is_cell_blocked(cell)), str(declared)])
			if not declared:
				_fail("pintu %s: sel fisik %s TIDAK ada di door_cells (data scene salah?)" % [str(d.get("door_id")), str(cell)])
			if not pf.is_cell_blocked(cell):
				_fail("pintu %s: sel fisik %s MASIH WALKABLE (musuh bisa lewat pintu terkunci!)" % [str(d.get("door_id")), str(cell)])

	# --- 3b. Jalur melintasi tiap pintu harus memutar, bukan lewat sel pintu ---
	var tests: Array = [
		["A", Vector2(11 * 32 + 16, 27 * 32 + 16), Vector2(7 * 32 + 16, 27 * 32 + 16), [Vector2i(9, 26), Vector2i(9, 27)]],
		["B", Vector2(62 * 32 + 16, 22 * 32 + 16), Vector2(58 * 32 + 16, 22 * 32 + 16), [Vector2i(60, 21), Vector2i(60, 22)]],
		["C", Vector2(11 * 32 + 16, 36 * 32 + 16), Vector2(7 * 32 + 16, 36 * 32 + 16), [Vector2i(9, 35), Vector2i(9, 36)]],
	]
	for t: Array in tests:
		var label: String = t[0]
		var from_pos: Vector2 = t[1]
		var to_pos: Vector2 = t[2]
		var door_cells: Array = t[3]
		var lewat_pintu: bool = false
		var path: PackedVector2Array = pf.find_path_world(from_pos, to_pos)
		print("jalur pintu %s (%s -> %s): %d titik" % [label, str(from_pos), str(to_pos), path.size()])
		if path.is_empty():
			# Bukan kegagalan: sayap barat memang tersegel saat kedua
			# pintunya terkunci (dinding kolom 9 hanya berlubang di
			# Pintu A & C). Musuh tidak bisa masuk sebelum ada pintu
			# yang dibuka — itu perilaku yang benar.
			print("OK: pintu %s: tidak ada jalur (sayap tersegel rapat saat terkunci)" % label)
			continue
		for pt: Vector2 in path:
			var cell: Vector2i = pf.world_to_cell(pt)
			if door_cells.has(cell):
				_fail("pintu %s: jalur MELEWATI sel pintu terkunci %s" % [label, str(cell)])
				lewat_pintu = true
				break
		if not lewat_pintu:
			print("OK: jalur pintu %s memutar, tidak lewat sel pintu" % label)

	# --- 3c. Pintu yang DIBUKA harus bisa dilewati lagi ---
	if doors.size() > 0:
		var d0: Node = doors[0]
		for cell: Vector2i in (d0.get("door_cells") as Array[Vector2i]):
			pf.set_door_blocked(cell, false)
		var all_open: bool = true
		for cell: Vector2i in (d0.get("door_cells") as Array[Vector2i]):
			if pf.is_cell_blocked(cell):
				all_open = false
		if all_open:
			print("OK: setelah set_door_blocked(false), sel pintu %s bisa dilewati lagi" % str(d0.get("door_id")))
		else:
			_fail("setelah dibuka, sel pintu masih terblokir")

	# --- 4. Patrol points musuh: ada yang di dalam / di sebelah sel pintu? ---
	# Marker Patrol1..27 dibaca langsung dari scene (script enemy tidak
	# termuat di mode -s, jadi patrol_points-nya tidak bisa dibaca).
	var spawns: Node = level.get_node_or_null("Spawns")
	var patrol_n: int = 0
	if spawns != null:
		for m: Node in spawns.get_children():
			if (m as Node).name.begins_with("Patrol"):
				patrol_n += 1
				var cell: Vector2i = pf.world_to_cell((m as Node2D).global_position)
				if pf.is_cell_blocked(cell):
					print("  patrol %s sel %s TERBLOKIR (musuh akan nyangkut di sini!)" % [(m as Node).name, str(cell)])
	print("patrol points musuh di scene: ", patrol_n)
	level.queue_free()

	if _failures.is_empty():
		print("SEMUA TES PINTU LULUS")
		quit(0)
	else:
		print("GAGAL: ", _failures.size(), " kegagalan")
		quit(1)
