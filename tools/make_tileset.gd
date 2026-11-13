extends SceneTree

# One-off tool: builds office_tileset.tres from the Imersa office pack.
# Run: godot --headless --path . --script res://tools/make_tileset.gd
# Floor atlas: 96x32, 3 tiles of 32x32. Wall atlas: 256x128, 8 cols, 25 tiles.
# All wall tiles get a full-tile collision polygon on physics layer 0.

const FLOOR_TEX := "res://assets/office_assets/main/Office_Pixel_Art_Free_v1.0/Tilesets/Floors/office_floors_tileset.png"
const WALL_TEX := "res://assets/office_assets/main/Office_Pixel_Art_Free_v1.0/Tilesets/Walls_Plain/office_walls_tileset.png"
const OUT_PATH := "res://office_tileset.tres"
const TILE := Vector2i(32, 32)

func _init() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var floor_tex := load(FLOOR_TEX) as Texture2D
	if floor_tex == null:
		push_error("cannot load floor texture")
		quit(1)
		return
	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = floor_tex
	floor_source.texture_region_size = TILE
	var floor_id := tile_set.add_source(floor_source)
	for i in range(3):
		floor_source.create_tile(Vector2i(i, 0))

	var wall_tex := load(WALL_TEX) as Texture2D
	if wall_tex == null:
		push_error("cannot load wall texture")
		quit(1)
		return
	var wall_source := TileSetAtlasSource.new()
	wall_source.texture = wall_tex
	wall_source.texture_region_size = TILE
	var wall_id := tile_set.add_source(wall_source)
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)])
	for i in range(25):
		var coords := Vector2i(i % 8, i / 8)
		wall_source.create_tile(coords)
		var tile_data := wall_source.get_tile_data(coords, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, poly)

	print("floor source id: ", floor_id, " wall source id: ", wall_id)
	var err := ResourceSaver.save(tile_set, OUT_PATH)
	print("save: ", err, " -> ", OUT_PATH)
	quit()
