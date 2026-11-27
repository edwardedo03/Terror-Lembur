class_name GridPathfinder
extends RefCounted
## Grid A* di atas TileMap Level 1 untuk AI enemy.
##
## Walkable = ada tile Floor DAN tidak ada tile Walls/Props/Props0/Props1
## DAN bukan pintu terkunci yang masih tertutup. Tetangga 4-arah
## (tanpa diagonal) supaya enemy tidak memotong sudut dinding.
## Dipakai enemy untuk patrol & chase. Rebuild saat pintu dibuka.
## Props0/Props1 (objek yang menimpa objek lain) ikut dihitung sebagai
## penghalang — sebelumnya tidak dicek, jadi musuh disuruh jalan
## menabrak objek ber-collision di kedua layer itu. DekorDinding /
## DekorKecil sengaja TIDAK dicek: tile-nya tidak punya collision.

const TILE_SIZE: int = 32

var _astar := AStar2D.new()
var _width: int = 0
var _height: int = 0
var _floor_layer: TileMapLayer = null
var _walls_layer: TileMapLayer = null
var _props_layer: TileMapLayer = null
var _extra_blockers: Array[TileMapLayer] = []  # layer penghalang tambahan (Props0, Props1, ...)
var _blocked_doors: Dictionary = {}  # Vector2i cell -> true (masih tertutup)
var _blocked_traps: Dictionary = {}  # Vector2i cell -> true (ada perangkap; musuh tidak boleh menginjaknya)


# extra_blocker_layers: layer tambahan yang tiap tile-nya menghalangi jalan
# (mis. Props0/Props1). Opsional — panggilan lama 4 argumen tetap jalan.
func setup(floor_layer: TileMapLayer, walls_layer: TileMapLayer, props_layer: TileMapLayer, blocked_doors: Dictionary, extra_blocker_layers: Array = []) -> void:
	_floor_layer = floor_layer
	_walls_layer = walls_layer
	_props_layer = props_layer
	_extra_blockers.clear()
	for layer: TileMapLayer in extra_blocker_layers:
		if layer != null:
			_extra_blockers.append(layer)
	_blocked_doors = blocked_doors.duplicate()
	var rect: Rect2i = floor_layer.get_used_rect()
	_width = rect.size.x
	_height = rect.size.y
	rebuild()


func rebuild() -> void:
	_astar.clear()
	var rect: Rect2i = _floor_layer.get_used_rect()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if _is_walkable_cell(cell):
				_astar.add_point(_cell_id(cell), cell_to_world(cell))
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not _astar.has_point(_cell_id(cell)):
				continue
			for nb: Vector2i in [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if _astar.has_point(_cell_id(nb)):
					_astar.connect_points(_cell_id(cell), _cell_id(nb))


func set_door_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked_doors[cell] = true
	else:
		_blocked_doors.erase(cell)
	rebuild()


# Sel perangkap: musuh tidak boleh menginjak trap (hanya pemain yang
# bisa memicunya). Dipanggil sekali saat level disiapkan untuk tiap
# trap; jalur A* musuh lalu memutar melewati sel trap. Saat musuh
# dipancing (lure) ke trap, find_path_world menjepit tujuan ke sel
# terdekat yang bisa dilewati, jadi musuh berhenti di sebelah trap
# (lihat enemy.gd: lure selesai saat jalur habis).
func set_trap_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked_traps[cell] = true
	else:
		_blocked_traps.erase(cell)
	rebuild()


func is_cell_blocked(cell: Vector2i) -> bool:
	return not _is_walkable_cell(cell)


func find_path_world(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	if _astar.get_point_count() == 0:
		return PackedVector2Array()
	# Kedua ujung dijepit ke sel lantai terdekat lewat grid (BFS),
	# jadi A* tidak pernah diminta ke sel di seberang tembok.
	var from_id: int = _cell_id(nearest_walkable_cell(world_to_cell(from_pos)))
	var to_id: int = _cell_id(nearest_walkable_cell(world_to_cell(to_pos)))
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector2Array()
	if from_id == to_id:
		return PackedVector2Array([_astar.get_point_position(to_id)])
	return _astar.get_point_path(from_id, to_id)



func snap_to_walkable(pos: Vector2) -> Vector2:
	if _astar.get_point_count() == 0:
		return pos
	return cell_to_world(nearest_walkable_cell(world_to_cell(pos)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE_SIZE).floor())


func walkable_point_count() -> int:
	return _astar.get_point_count()


func _cell_id(cell: Vector2i) -> int:
	# Offset +1 supaya cell (0,0) tidak bentrok; grid max 128x128 aman.
	return (cell.y + 64) * 256 + (cell.x + 64)


func _is_walkable_cell(cell: Vector2i) -> bool:
	if cell in _blocked_doors:
		return false
	if cell in _blocked_traps:
		return false
	if _floor_layer.get_cell_source_id(cell) == -1:
		return false
	if _walls_layer != null and _walls_layer.get_cell_source_id(cell) != -1:
		return false
	if _props_layer != null and _props_layer.get_cell_source_id(cell) != -1:
		return false
	for layer: TileMapLayer in _extra_blockers:
		if layer.get_cell_source_id(cell) != -1:
			return false
	return true


func nearest_walkable_cell(cell: Vector2i) -> Vector2i:
	# Sel terdekat yang bisa dilewati, dicari per langkah grid (BFS)
	# menyusuri lantai — BUKAN jarak lurus, supaya tujuan tidak
	# "melompat" ke sel di seberang sudut tembok.
	if _is_walkable_cell(cell):
		return cell
	var seen: Dictionary = {cell: true}
	var queue: Array[Vector2i] = [cell]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for nb: Vector2i in [cur + Vector2i(1, 0), cur + Vector2i(-1, 0), cur + Vector2i(0, 1), cur + Vector2i(0, -1)]:
			if seen.has(nb):
				continue
			seen[nb] = true
			if _is_walkable_cell(nb):
				return nb
			queue.append(nb)
		if queue.size() > 4096:
			break
	return cell
