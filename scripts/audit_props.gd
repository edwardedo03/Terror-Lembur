extends SceneTree
## Audit pathfinding vs collision nyata di TileMap (headless).
## Untuk tiap layer: hitung sel terpakai & berapa yang tile-nya punya
## collision (physics_layer_0). Lalu cek: dengan setup pathfinder
## seperti yang dipakai level, adakah sel ber-collision yang masih
## walkable (musuh bisa jalan menembus objek padat)?
##
## Dijalankan dari folder repo: godot --headless -s audit_props.gd
## (Scene di-instantiate TANPA add_child, _ready tidak jalan.)

var _failures: Array[String] = []


func _layer_solid_cells(layer: TileMapLayer) -> Dictionary:
	# Return {cell: true} untuk sel yang tile-nya punya collision.
	var solid: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		var td: TileData = layer.get_cell_tile_data(cell)
		if td != null and td.get_collision_polygons_count(0) > 0:
			solid[cell] = true
	return solid


func _check_walkable_vs_solid(pf: GridPathfinder, layers: Dictionary, label: String) -> void:
	# Kumpulkan semua sel ber-collision dari SEMUA layer.
	var solid_cells: Dictionary = {}
	for lname: String in layers.keys():
		var layer: TileMapLayer = layers[lname]
		if layer == null:
			continue
		var solid: Dictionary = _layer_solid_cells(layer)
		for cell: Vector2i in solid.keys():
			solid_cells[cell] = lname
	var leaked: Dictionary = {}
	for cell: Vector2i in solid_cells.keys():
		if not pf.is_cell_blocked(cell):
			leaked[cell] = solid_cells[cell]
	print("  [%s] sel ber-collision total=%d, MASIH WALKABLE (bocor)=%d" % [label, solid_cells.size(), leaked.size()])
	if leaked.size() > 0:
		var shown: int = 0
		for cell: Vector2i in leaked.keys():
			if shown >= 12:
				break
			print("    BOCOR sel %s dari layer %s" % [str(cell), str(leaked[cell])])
			shown += 1
		_failures.append("%s: %d sel ber-collision masih walkable" % [label, leaked.size()])
	else:
		print("    OK: semua sel ber-collision terblokir")


func _init() -> void:
	print("==== res://scenes/level_1.tscn ====")
	var s1: PackedScene = load("res://scenes/level_1.tscn")
	var l1: Node = s1.instantiate()
	var f1: TileMapLayer = l1.get_node_or_null("Floor")
	var w1: TileMapLayer = l1.get_node_or_null("Walls")
	var p1: TileMapLayer = l1.get_node_or_null("Props")
	var p01: TileMapLayer = l1.get_node_or_null("Props0")
	var p11: TileMapLayer = l1.get_node_or_null("Props1")
	var layers1: Dictionary = {"Floor": f1, "Walls": w1, "DekorDinding": l1.get_node_or_null("DekorDinding"), "Props0": p01, "Props": p1, "Props1": p11, "DekorKecil": l1.get_node_or_null("DekorKecil")}
	for lname: String in layers1.keys():
		var layer: TileMapLayer = layers1[lname]
		if layer == null:
			print("  L1 layer ", lname, ": TIDAK ADA")
			continue
		var solid: Dictionary = _layer_solid_cells(layer)
		print("  L1 layer %-14s sel terpakai=%-4d sel ber-collision=%d" % [lname, layer.get_used_cells().size(), solid.size()])
	var pf1 := GridPathfinder.new()
	pf1.setup(f1, w1, p1, {})
	_check_walkable_vs_solid(pf1, layers1, "L1 SETUP SAAT INI (Floor/Walls/Props saja)")
	var pf1b := GridPathfinder.new()
	pf1b.setup(f1, w1, p1, {}, [p01, p11])
	_check_walkable_vs_solid(pf1b, layers1, "L1 SETUP PATCH (extra Props0/Props1)")
	l1.queue_free()

	print("==== res://scenes/level_2.tscn ====")
	var s2: PackedScene = load("res://scenes/level_2.tscn")
	var l2: Node = s2.instantiate()
	var f2: TileMapLayer = l2.get_node_or_null("Lantai")
	var w2: TileMapLayer = l2.get_node_or_null("Dinding")
	var p2: TileMapLayer = l2.get_node_or_null("Props")
	var pa2: TileMapLayer = l2.get_node_or_null("props_atas")
	var p22: TileMapLayer = l2.get_node_or_null("Props2")
	var layers2: Dictionary = {"Lantai": f2, "Dinding": w2, "karpet": l2.get_node_or_null("karpet"), "hiasan_dinding": l2.get_node_or_null("hiasan_dinding"), "Props": p2, "props_atas": pa2, "Props2": p22}
	for lname: String in layers2.keys():
		var layer: TileMapLayer = layers2[lname]
		if layer == null:
			print("  L2 layer ", lname, ": TIDAK ADA")
			continue
		var solid: Dictionary = _layer_solid_cells(layer)
		print("  L2 layer %-14s sel terpakai=%-4d sel ber-collision=%d" % [lname, layer.get_used_cells().size(), solid.size()])
	var pf2 := GridPathfinder.new()
	pf2.setup(f2, w2, p2, {})
	_check_walkable_vs_solid(pf2, layers2, "L2 SETUP SAAT INI (Lantai/Dinding/Props saja)")
	var pf2b := GridPathfinder.new()
	pf2b.setup(f2, w2, p2, {}, [pa2, p22])
	_check_walkable_vs_solid(pf2b, layers2, "L2 SETUP PATCH (extra props_atas/Props2)")
	l2.queue_free()

	if _failures.is_empty():
		print("AUDIT LULUS")
		quit(0)
	else:
		print("AUDIT GAGAL: ", _failures.size(), " masalah")
		for f: String in _failures:
			print(" - ", f)
		quit(1)
