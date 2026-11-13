extends Node2D

const ROOM_W := 40
const ROOM_H := 23
const TILESET_PATH := "res://office_tileset.tres"
const BOSS_SCENE := "res://scenes/boss.tscn"
const THROWABLE_SCENE := "res://scenes/throwable.tscn"
const TASK_SCENE := "res://scenes/task_point.tscn"
const PICKUP_SCENE := "res://scenes/pickup_item.tscn"

const TASK_DEFS := [
	{"id": 0, "label": "GENERATOR", "pos": Vector2(640, 100), "need": 2, "time": 8.0, "noise": 400.0},
	{"id": 1, "label": "KOMPUTER", "pos": Vector2(170, 170), "need": 1, "time": 10.0, "noise": 150.0},
	{"id": 2, "label": "BRANKAS", "pos": Vector2(460, 100), "need": 1, "time": 6.0, "noise": 150.0},
	{"id": 3, "label": "PINTU KELUAR", "pos": Vector2(640, 700), "need": 2, "time": 5.0, "noise": 400.0},
	{"id": 4, "label": "TUAS SEL", "pos": Vector2(1120, 140), "need": 1, "time": 3.0, "noise": 150.0},
]
const CELL_POS := Vector2(1180, 140)
const BOSS_ROOM := Rect2(1050, 64, 198, 156)
const MEETING_ROOM := Rect2(480, 288, 352, 320)
const IT_ROOM := Rect2(32, 64, 256, 192)
const ARCHIVE_ROOM := Rect2(320, 64, 192, 128)
const SERVER_ROOM := Rect2(544, 64, 224, 128)
const HRD_ROOM := Rect2(800, 64, 224, 128)
const PANTRY_ROOM := Rect2(992, 512, 256, 192)
const TOILET_ROOM := Rect2(32, 544, 224, 160)
const ALL_ROOMS := [BOSS_ROOM, MEETING_ROOM, IT_ROOM, ARCHIVE_ROOM, SERVER_ROOM, HRD_ROOM, PANTRY_ROOM, TOILET_ROOM]
const INTERACT_RANGE := 80.0

var ysort: Node2D
var spawner: MultiplayerSpawner
var boss: CharacterBody2D
var tasks: Array = []
var pickups: Array = []
var desk_positions: Array[Vector2] = []
var noise_queue: Array = []
var lit_areas: Array[Vector2] = []
var game_over := false
var game_result := ""
var stars := 0
var ever_caught := false
var boss_speed_mult := 1.0
var warn_timer := 0.0
var noise_emit_timer := 0.0
var debug_timer := 0.0

var flicker_lights: Array[PointLight2D] = []
var flicker_base: Array[float] = []
var flicker_timer := 0.0

var hud_task_label: Label
var hud_prompt_label: Label
var hud_warn_label: Label
var hud_status_label: Label
var end_panel: PanelContainer
var end_title: Label
var end_detail: Label

func _ready() -> void:
	var tile_set := load(TILESET_PATH) as TileSet
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = tile_set
	floor_layer.z_index = -2
	add_child(floor_layer)
	var wall_layer := TileMapLayer.new()
	wall_layer.name = "WallLayer"
	wall_layer.tile_set = tile_set
	wall_layer.collision_enabled = true
	wall_layer.z_index = -1
	add_child(wall_layer)
	for y in range(ROOM_H):
		for x in range(ROOM_W):
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
	for x in range(ROOM_W):
		_set_wall(wall_layer, x, 0, Vector2i(1, 0) if x == 0 else (Vector2i(5, 0) if x == ROOM_W - 1 else Vector2i(2, 0)))
		_set_wall(wall_layer, x, 1, Vector2i(6, 0) if x == 0 else (Vector2i(2, 1) if x == ROOM_W - 1 else Vector2i(7, 0)))
		_set_wall(wall_layer, x, ROOM_H - 1, Vector2i(4, 2) if x == 0 else (Vector2i(0, 3) if x == ROOM_W - 1 else Vector2i(7, 2)))
	for y in range(2, ROOM_H - 1):
		_set_wall(wall_layer, 0, y, Vector2i(3, 1))
		_set_wall(wall_layer, ROOM_W - 1, y, Vector2i(5, 1))
	_build_partitions(wall_layer)
	ysort = $"YSort"
	spawner = $"Spawner"
	_build_props()
	_build_darkness()
	_build_horror()
	_build_cell()
	_build_tasks()
	_build_pickups()
	_build_hud()
	lit_areas.append(Vector2(640, 700))
	spawner.add_spawnable_scene(BOSS_SCENE)
	spawner.add_spawnable_scene(THROWABLE_SCENE)
	spawner.add_spawnable_scene(TASK_SCENE)
	if multiplayer.is_server():
		var boss_scene := load(BOSS_SCENE) as PackedScene
		boss = boss_scene.instantiate() as CharacterBody2D
		boss.global_position = boss_room_center()
		boss.speed_mult = boss_speed_mult
		ysort.add_child(boss, true)

func _set_wall(layer: TileMapLayer, x: int, y: int, atlas: Vector2i) -> void:
	layer.set_cell(Vector2i(x, y), 1, atlas)

func _build_partitions(layer: TileMapLayer) -> void:
	var h := Vector2i(7, 0)
	var v := Vector2i(3, 1)
	var v2 := Vector2i(5, 1)
	for y in [2, 3, 6]:
		_set_wall(layer, 32, y, v)
	for x in range(32, 39):
		_set_wall(layer, x, 7, h)
	for x in range(15, 19):
		_set_wall(layer, x, 9, h)
	for x in range(21, 26):
		_set_wall(layer, x, 9, h)
	for x in range(15, 26):
		_set_wall(layer, x, 18, h)
	for y in range(9, 19):
		_set_wall(layer, 15, y, v)
		_set_wall(layer, 25, y, v2)
	for y in range(2, 8):
		_set_wall(layer, 9, y, v2)
	for x in range(1, 4):
		_set_wall(layer, x, 8, h)
	for x in range(6, 9):
		_set_wall(layer, x, 8, h)
	for y in range(2, 6):
		_set_wall(layer, 16, y, v2)
	for x in range(10, 12):
		_set_wall(layer, x, 6, h)
	for x in range(14, 16):
		_set_wall(layer, x, 6, h)
	for y in range(2, 6):
		_set_wall(layer, 24, y, v2)
	for x in range(17, 20):
		_set_wall(layer, x, 6, h)
	for x in range(22, 24):
		_set_wall(layer, x, 6, h)
	for y in range(2, 6):
		_set_wall(layer, 25, y, v)
	for x in range(25, 27):
		_set_wall(layer, x, 6, h)
	for x in range(29, 32):
		_set_wall(layer, x, 6, h)
	for y in range(15, 22):
		_set_wall(layer, 30, y, v)
	for x in range(30, 33):
		_set_wall(layer, x, 15, h)
	for x in range(35, 39):
		_set_wall(layer, x, 15, h)
	for y in range(16, 22):
		_set_wall(layer, 8, y, v2)
	for x in range(1, 4):
		_set_wall(layer, x, 16, h)
	for x in range(6, 8):
		_set_wall(layer, x, 16, h)

func _build_darkness() -> void:
	var mod := CanvasModulate.new()
	mod.color = Color(0.22, 0.22, 0.28)
	add_child(mod)

func _blood_spot(pos: Vector2, s: float) -> void:
	var b := Polygon2D.new()
	b.color = Color(0.35, 0.02, 0.02, 0.75)
	b.z_index = -1
	var pts := PackedVector2Array()
	var n := 9
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var r := s * (0.7 + 0.6 * absf(sin(a * 2.3 + pos.x)))
		pts.append(Vector2(cos(a), sin(a)) * r)
	b.polygon = pts
	b.position = pos
	add_child(b)

func _paper(pos: Vector2, rot: float) -> void:
	var p := Polygon2D.new()
	p.color = Color(0.85, 0.85, 0.8, 0.9)
	p.z_index = -1
	p.polygon = PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(9, 6), Vector2(-9, 6)])
	p.position = pos
	p.rotation = rot
	add_child(p)

func _build_horror() -> void:
	_blood_spot(Vector2(300, 300), 26.0)
	_blood_spot(Vector2(340, 320), 14.0)
	_blood_spot(Vector2(700, 560), 30.0)
	_blood_spot(Vector2(740, 590), 12.0)
	_blood_spot(Vector2(1120, 500), 22.0)
	_blood_spot(Vector2(200, 620), 18.0)
	_blood_spot(Vector2(640, 180), 16.0)
	_paper(Vector2(420, 280), 0.4)
	_paper(Vector2(460, 300), -0.7)
	_paper(Vector2(560, 480), 1.1)
	_paper(Vector2(900, 300), 0.2)
	_paper(Vector2(940, 340), -1.2)
	_paper(Vector2(300, 560), 0.9)
	_paper(Vector2(1080, 300), -0.4)
	_paper(Vector2(640, 620), 0.6)
	for pos in [Vector2(400, 260), Vector2(880, 420), Vector2(640, 620)]:
		var fl := PointLight2D.new()
		fl.position = pos
		fl.color = Color(1, 0.85, 0.6, 1)
		fl.energy = 0.9
		fl.texture_scale = 2.5
		add_child(fl)
		flicker_lights.append(fl)
		flicker_base.append(0.9)
	var red := PointLight2D.new()
	red.position = Vector2(1149, 142)
	red.color = Color(0.9, 0.1, 0.1, 1)
	red.energy = 0.5
	red.texture_scale = 2.0
	add_child(red)
	var chair_tex := load(PROP_BASE + "Seating/office_chair/office_chair_front.png") as Texture2D
	if chair_tex != null:
		var root := Node2D.new()
		root.position = Vector2(980, 420)
		root.rotation = PI / 2.0
		ysort.add_child(root)
		var spr := Sprite2D.new()
		spr.texture = chair_tex
		root.add_child(spr)

func _build_cell() -> void:
	var room := Polygon2D.new()
	room.color = Color(0, 0, 0, 0.35)
	room.polygon = PackedVector2Array([
		BOSS_ROOM.position, Vector2(BOSS_ROOM.end.x, BOSS_ROOM.position.y),
		BOSS_ROOM.end, Vector2(BOSS_ROOM.position.x, BOSS_ROOM.end.y),
	])
	room.z_index = 5
	add_child(room)
	var cell := Node2D.new()
	cell.position = CELL_POS
	ysort.add_child(cell)
	for i in range(5):
		var bar := Polygon2D.new()
		var bx := -30.0 + float(i) * 15.0
		bar.color = Color(0.15, 0.15, 0.15, 1)
		bar.polygon = PackedVector2Array([
			Vector2(bx - 2, -24), Vector2(bx + 2, -24),
			Vector2(bx + 2, 24), Vector2(bx - 2, 24),
		])
		cell.add_child(bar)
	var frame := Polygon2D.new()
	frame.color = Color(0.15, 0.15, 0.15, 1)
	frame.polygon = PackedVector2Array([
		Vector2(-32, -26), Vector2(32, -26), Vector2(32, -22), Vector2(-32, -22),
	])
	cell.add_child(frame)
	var frame2 := Polygon2D.new()
	frame2.color = Color(0.15, 0.15, 0.15, 1)
	frame2.polygon = PackedVector2Array([
		Vector2(-32, 22), Vector2(32, 22), Vector2(32, 26), Vector2(-32, 26),
	])
	cell.add_child(frame2)

func _build_tasks() -> void:
	var scene := load(TASK_SCENE) as PackedScene
	for def in TASK_DEFS:
		var tp := scene.instantiate() as Node2D
		tp.setup(def["id"], def["label"], def["need"], def["time"], def["noise"])
		tp.position = def["pos"]
		add_child(tp)
		tasks.append(tp)

func _build_pickups() -> void:
	var scene := load(PICKUP_SCENE) as PackedScene
	var spots := [
		Vector2(200, 160), Vector2(300, 160), Vector2(1040, 160),
		Vector2(1140, 160), Vector2(200, 360), Vector2(1040, 360),
	]
	for s in spots:
		var pk := scene.instantiate() as Node2D
		pk.position = s
		add_child(pk)
		pickups.append(pk)

func _update_pickups() -> void:
	for pk in pickups:
		if pk.taken:
			continue
		for child in ysort.get_children():
			if not _is_player(child):
				continue
			if child.get("locked") or child.get("hiding"):
				continue
			if child.get("has_throwable"):
				continue
			if child.global_position.distance_to(pk.global_position) < 30.0:
				pk.taken = true
				child.rpc_id(int(child.name), "give_throwable")
				break

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	hud_task_label = Label.new()
	hud_task_label.position = Vector2(16, 12)
	hud_task_label.add_theme_font_size_override("font_size", 16)
	hud_task_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hud.add_child(hud_task_label)
	hud_warn_label = Label.new()
	hud_warn_label.position = Vector2(440, 12)
	hud_warn_label.add_theme_font_size_override("font_size", 20)
	hud_warn_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	hud.add_child(hud_warn_label)
	hud_status_label = Label.new()
	hud_status_label.position = Vector2(16, 44)
	hud_status_label.add_theme_font_size_override("font_size", 15)
	hud_status_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	hud.add_child(hud_status_label)
	hud_prompt_label = Label.new()
	hud_prompt_label.position = Vector2(440, 680)
	hud_prompt_label.add_theme_font_size_override("font_size", 16)
	hud_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hud.add_child(hud_prompt_label)
	end_panel = PanelContainer.new()
	end_panel.visible = false
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.custom_minimum_size = Vector2(560, 260)
	hud.add_child(end_panel)
	var vb := VBoxContainer.new()
	end_panel.add_child(vb)
	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 32)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_title)
	end_detail = Label.new()
	end_detail.add_theme_font_size_override("font_size", 17)
	end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(end_detail)

func _process(delta: float) -> void:
	if warn_timer > 0.0:
		warn_timer -= delta
		if warn_timer <= 0.0:
			hud_warn_label.text = ""
	flicker_timer += delta
	if flicker_timer > 0.12:
		flicker_timer = 0.0
		for i in range(flicker_lights.size()):
			var f := flicker_lights[i]
			if randf() < 0.12:
				f.energy = flicker_base[i] * randf_range(0.15, 0.5)
			else:
				f.energy = flicker_base[i] * randf_range(0.85, 1.05)
	if multiplayer.is_server() and not game_over:
		_update_tasks(delta)
		_update_pickups()
		_check_endings()
	_update_hud()
	if "--bot" in OS.get_cmdline_user_args():
		debug_timer += delta
		if debug_timer >= 2.0:
			debug_timer = 0.0
			if ysort != null:
				for child in ysort.get_children():
					if child is CharacterBody2D:
						print("POS peer=", multiplayer.get_unique_id(), " player=", child.name, " pos=", child.position, " vel=", child.velocity)

func _is_player(node: Node) -> bool:
	return node is CharacterBody2D and node.has_method("set_locked")

func _update_tasks(delta: float) -> void:
	for tp in tasks:
		if tp.done:
			continue
		var id: int = tp.task_id
		if id == 3 and not _main_tasks_done():
			continue
		if id == 4 and not _any_locked():
			tp.progress = maxf(0.0, tp.progress - delta * 0.05)
			continue
		var workers := 0
		for child in ysort.get_children():
			if not _is_player(child):
				continue
			if child.get("locked"):
				continue
			if child.get("interacting") and child.get("interact_target") == id:
				if child.global_position.distance_to(tp.global_position) < INTERACT_RANGE + 20.0:
					workers += 1
		var advancing := false
		if id == 0:
			if workers >= 2:
				tp.progress += delta / tp.time_needed
				advancing = true
		elif id == 3:
			if workers >= 2:
				tp.progress += delta / 5.0
				advancing = true
			elif workers == 1 and _any_locked():
				tp.progress += delta / 10.0
				advancing = true
		elif id == 4:
			if workers >= 1:
				tp.progress += delta / tp.time_needed
				advancing = true
			else:
				tp.progress = maxf(0.0, tp.progress - delta * 0.05)
		else:
			if workers >= 1:
				tp.progress += delta / tp.time_needed
				advancing = true
		if advancing:
			noise_emit_timer += delta
			if noise_emit_timer > 0.5:
				noise_emit_timer = 0.0
				report_noise(tp.global_position, tp.noise_radius)
		if tp.progress >= 1.0:
			tp.progress = 1.0
			tp.done = true
			_on_task_done(tp)

func _on_task_done(tp) -> void:
	if tp.task_id == 4:
		_unlock_all()
		return
	boss_speed_mult += 0.1
	if boss != null:
		boss.speed_mult = boss_speed_mult
	lit_areas.append(tp.global_position)
	var light := PointLight2D.new()
	light.position = tp.global_position
	light.color = Color(1, 0.9, 0.7, 1)
	light.energy = 1.0
	light.texture_scale = 3.0
	add_child(light)
	if tp.task_id == 3:
		_finish_level()

func _unlock_all() -> void:
	for child in ysort.get_children():
		if not _is_player(child):
			continue
		if child.get("locked"):
			child.rpc_id(int(child.name), "set_locked", false)

func _main_tasks_done() -> bool:
	for tp in tasks:
		if tp.task_id < 3 and not tp.done:
			return false
	return true

func _any_locked() -> bool:
	for child in ysort.get_children():
		if not _is_player(child):
			continue
		if child.get("locked"):
			return true
	return false

func _locked_count() -> int:
	var n := 0
	for child in ysort.get_children():
		if not _is_player(child):
			continue
		if child.get("locked"):
			n += 1
	return n

func _player_count() -> int:
	var n := 0
	for child in ysort.get_children():
		if _is_player(child):
			n += 1
	return n

func _check_endings() -> void:
	var total := _player_count()
	if total >= 2 and _locked_count() >= 2:
		rpc("_show_end", "GAME OVER", "Keduanya dikurung di ruang bos. Tidak ada yang bisa membebaskan siapa-siapa.", 0)

func _finish_level() -> void:
	if _any_locked():
		rpc("_show_end", "ENDING PAHIT", "Pintu terbuka, tapi satu teman masih dikurung di ruang bos. Yang bebas kabur sendiri. Yang dikurung kena nerf di level berikut.", 1)
	else:
		var s := 3 if not ever_caught else 2
		rpc("_show_end", "HAPPY ENDING", "Keduanya kabur bareng lewat pintu keluar. Gotong royong berhasil.", s)

@rpc("any_peer", "call_local")
func _show_end(title: String, detail: String, s: int) -> void:
	if game_over:
		return
	game_over = true
	game_result = title
	stars = s
	end_title.text = title
	var star_text := ""
	for i in range(s):
		star_text += "★"
	end_detail.text = detail + "\n\nBintang: " + star_text + "\n\nTekan R untuk main lagi."
	end_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("flashlight"):
		rpc("_restart_game")

@rpc("any_peer", "call_local")
func _restart_game() -> void:
	get_tree().reload_current_scene()

func _update_hud() -> void:
	var lines := ""
	for tp in tasks:
		if tp.task_id == 4:
			continue
		var mark := "✓" if tp.done else "☐"
		var extra := ""
		if tp.task_id == 3 and not _main_tasks_done():
			extra = " (terkunci)"
		lines += mark + " " + tp.label_text + extra + "\n"
	hud_task_label.text = lines
	var locked_names := ""
	for child in ysort.get_children():
		if not _is_player(child):
			continue
		if child.get("locked"):
			locked_names += "Pemain " + str(child.name) + " DIKURUNG di ruang bos! "
	if locked_names != "":
		hud_status_label.text = locked_names + "Tahan E di TUAS SEL buat bebaskan (3 detik)."
	else:
		hud_status_label.text = ""
	var me := _my_player()
	if me != null and not game_over:
		if me.get("interacting") and me.get("interact_target") >= 0:
			var tid: int = me.get("interact_target")
			var tp = tasks[tid] if tid < tasks.size() else null
			if tp != null:
				hud_prompt_label.text = "Mengerjakan " + tp.label_text + "... " + str(int(tp.progress * 100.0)) + "%"
		else:
			var nid := nearest_interactable(me.global_position)
			if nid >= 0:
				var tp = tasks[nid]
				var need_txt := ""
				if tp.task_id == 0:
					need_txt = " (butuh 2 orang)"
				elif tp.task_id == 3:
					need_txt = " (butuh 2 orang, atau 1 orang 10 detik kalau teman dikurung)"
				hud_prompt_label.text = "Tahan E: " + tp.label_text + need_txt
			elif me.get("has_throwable"):
				hud_prompt_label.text = "Q: lempar barang  |  F: teriak  |  R: senter  |  C: ngumpet di bawah meja"
			else:
				hud_prompt_label.text = "E: interaksi  |  F: teriak  |  R: senter  |  C: ngumpet di bawah meja"

func _my_player() -> Node2D:
	var my_id := multiplayer.get_unique_id()
	for child in ysort.get_children():
		if _is_player(child) and int(child.name) == my_id:
			return child
	return null

func nearest_interactable(pos: Vector2) -> int:
	var best := -1
	var best_d := INTERACT_RANGE
	for tp in tasks:
		if tp.done:
			continue
		if tp.task_id == 3 and not _main_tasks_done():
			continue
		if tp.task_id == 4 and not _any_locked():
			continue
		var d := pos.distance_to(tp.global_position)
		if d < best_d:
			best_d = d
			best = tp.task_id
	return best

func nearest_desk(pos: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := 60.0
	for d in desk_positions:
		var dist := pos.distance_to(d)
		if dist < best_d:
			best_d = dist
			best = d
	return best

func is_lit(pos: Vector2) -> bool:
	for a in lit_areas:
		if pos.distance_to(a) < 130.0:
			return true
	return false

func boss_room_center() -> Vector2:
	return BOSS_ROOM.get_center()

func teleport_destination() -> Vector2:
	var candidates: Array[Vector2] = []
	for child in ysort.get_children():
		if not _is_player(child):
			continue
		if child.get("locked"):
			continue
		if child.get("interacting"):
			candidates.append(child.global_position)
	if candidates.is_empty():
		for child in ysort.get_children():
			if _is_player(child) and not child.get("locked"):
				candidates.append(child.global_position)
	if candidates.is_empty():
		return boss_room_center()
	var base: Vector2 = candidates[randi() % candidates.size()]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dest := base + Vector2(rng.randf_range(-180, 180), rng.randf_range(-180, 180))
	dest.x = clampf(dest.x, 80, 1200)
	dest.y = clampf(dest.y, 100, 680)
	for child in ysort.get_children():
		if _is_player(child) and child.get("hiding"):
			if dest.distance_to(child.global_position) < 80.0:
				dest = child.global_position + Vector2(200, 0)
	return dest

@rpc("any_peer", "call_local")
func report_noise(pos: Vector2, radius: float) -> void:
	if not multiplayer.is_server():
		return
	noise_queue.append({"pos": pos, "radius": radius})

func consume_noise() -> Vector2:
	if noise_queue.is_empty():
		return Vector2.ZERO
	var bp: Vector2 = boss.global_position if boss != null else Vector2.ZERO
	var best := Vector2.ZERO
	var best_d := 1e9
	var best_i := -1
	for i in range(noise_queue.size()):
		var n = noise_queue[i]
		var d: float = bp.distance_to(n["pos"])
		if d <= n["radius"] and d < best_d:
			best_d = d
			best = n["pos"]
			best_i = i
	if best_i >= 0:
		noise_queue.remove_at(best_i)
	return best

func on_player_caught(player: Node2D) -> void:
	ever_caught = true
	player.global_position = CELL_POS
	player.rpc_id(int(player.name), "set_locked", true)
	hud_warn_label.text = "TEMANMU DITANGKAP!"
	warn_timer = 3.0

func on_boss_chase() -> void:
	hud_warn_label.text = "BOS MENGEJAR!"
	warn_timer = 2.0

func on_boss_telegraph() -> void:
	hud_warn_label.text = "Bisikan... bos mau pindah!"
	warn_timer = 1.2

func on_boss_teleported(dest: Vector2) -> void:
	hud_warn_label.text = "Bos muncul di dekatmu!"
	warn_timer = 2.0

@rpc("any_peer", "call_local")
func spawn_throwable(pos: Vector2, dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var scene := load(THROWABLE_SCENE) as PackedScene
	var th := scene.instantiate() as Node2D
	ysort.add_child(th, true)
	th.launch(pos + dir * 24.0, dir)

const PROP_BASE := "res://assets/office_assets/main/Office_Pixel_Art_Free_v1.0/Props/"

func _build_props() -> void:
	var desk := "Desks/office_desk/office_desk_front.png"
	var chair_f := "Seating/office_chair/office_chair_front.png"
	var chair_b := "Seating/office_chair/office_chair_back.png"
	var chair_l := "Seating/office_chair/office_chair_left.png"
	var chair_r := "Seating/office_chair/office_chair_right.png"
	var pc := "Tech/computer/computer_front.png"
	var lap := "Tech/laptop/laptop_front.png"
	var cab := "Storage/filing_cabinet/filing_cabinet_front.png"
	var plant := "Decor/office_plant/office_plant_front.png"
	var tplant := "Decor/tall_plant/tall_plant_front.png"
	var cooler := "Kitchen/water_cooler/water_cooler_left.png"
	var trash := "Kitchen/trash_bin/trash_bin_front.png"
	var lamp := "Desk_Items/desk_lamp/desk_lamp_front.png"
	var mug := "Desk_Items/coffee_mug/coffee_mug_front.png"
	var paper := "Desk_Items/paper_stack/paper_stack_front.png"
	var conf := "Meeting/conference_table/conference_table_front.png"
	var flip := "Meeting/flip_chart/flip_chart_right.png"
	var clock := "Decor/wall_clock/wall_clock_front.png"
	var screen := "Meeting/projector_screen/projector_screen_front.png"
	_place_prop(cab, Vector2(380, 88), true, Vector2(28, 24))
	_place_prop(cab, Vector2(420, 88), true, Vector2(28, 24))
	_place_prop(cab, Vector2(460, 88), true, Vector2(28, 24))
	_place_prop(cab, Vector2(820, 88), true, Vector2(28, 24))
	_place_prop(cab, Vector2(860, 88), true, Vector2(28, 24))
	_place_prop(cab, Vector2(900, 88), true, Vector2(28, 24))
	_place_prop(clock, Vector2(480, 40), false, Vector2.ZERO)
	_place_prop(screen, Vector2(640, 40), false, Vector2.ZERO)
	_place_prop(desk, Vector2(170, 170), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(170, 240), true, Vector2(26, 20))
	_place_prop(pc, Vector2(155, 152), false, Vector2.ZERO)
	_place_prop(lamp, Vector2(195, 154), false, Vector2.ZERO)
	_place_prop(desk, Vector2(270, 170), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(270, 240), true, Vector2(26, 20))
	_place_prop(lap, Vector2(265, 152), false, Vector2.ZERO)
	_place_prop(mug, Vector2(290, 156), false, Vector2.ZERO)
	_place_prop(desk, Vector2(170, 370), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(170, 440), true, Vector2(26, 20))
	_place_prop(pc, Vector2(155, 352), false, Vector2.ZERO)
	_place_prop(paper, Vector2(195, 354), false, Vector2.ZERO)
	_place_prop(desk, Vector2(270, 370), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(270, 440), true, Vector2(26, 20))
	_place_prop(lap, Vector2(265, 352), false, Vector2.ZERO)
	_place_prop(lamp, Vector2(290, 354), false, Vector2.ZERO)
	_place_prop(desk, Vector2(1010, 170), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(1010, 240), true, Vector2(26, 20))
	_place_prop(pc, Vector2(995, 152), false, Vector2.ZERO)
	_place_prop(mug, Vector2(1035, 156), false, Vector2.ZERO)
	_place_prop(desk, Vector2(1110, 170), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(1110, 240), true, Vector2(26, 20))
	_place_prop(lap, Vector2(1105, 152), false, Vector2.ZERO)
	_place_prop(paper, Vector2(1130, 154), false, Vector2.ZERO)
	_place_prop(desk, Vector2(1010, 370), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(1010, 440), true, Vector2(26, 20))
	_place_prop(pc, Vector2(995, 352), false, Vector2.ZERO)
	_place_prop(lamp, Vector2(1035, 354), false, Vector2.ZERO)
	_place_prop(desk, Vector2(1110, 370), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(1110, 440), true, Vector2(26, 20))
	_place_prop(lap, Vector2(1105, 352), false, Vector2.ZERO)
	_place_prop(mug, Vector2(1130, 356), false, Vector2.ZERO)
	_place_prop(conf, Vector2(640, 430), true, Vector2(96, 40))
	_place_prop(chair_f, Vector2(590, 350), true, Vector2(26, 20))
	_place_prop(chair_f, Vector2(640, 350), true, Vector2(26, 20))
	_place_prop(chair_f, Vector2(690, 350), true, Vector2(26, 20))
	_place_prop(chair_b, Vector2(590, 505), true, Vector2(26, 20))
	_place_prop(chair_b, Vector2(640, 505), true, Vector2(26, 20))
	_place_prop(chair_b, Vector2(690, 505), true, Vector2(26, 20))
	_place_prop(chair_r, Vector2(530, 430), true, Vector2(26, 20))
	_place_prop(chair_l, Vector2(750, 430), true, Vector2(26, 20))
	_place_prop(lap, Vector2(615, 395), false, Vector2.ZERO)
	_place_prop(paper, Vector2(660, 400), false, Vector2.ZERO)
	_place_prop(flip, Vector2(520, 560), true, Vector2(24, 14))
	_place_prop(plant, Vector2(70, 100), true, Vector2(26, 16))
	_place_prop(tplant, Vector2(1210, 100), true, Vector2(18, 16))
	_place_prop(plant, Vector2(70, 660), true, Vector2(26, 16))
	_place_prop(tplant, Vector2(1210, 660), true, Vector2(18, 16))
	_place_prop(cooler, Vector2(1210, 620), true, Vector2(20, 16))
	_place_prop(trash, Vector2(1150, 620), true, Vector2(16, 12))
	_place_prop(trash, Vector2(320, 232), true, Vector2(16, 12))
	_place_prop(trash, Vector2(960, 232), true, Vector2(16, 12))
	_place_prop(trash, Vector2(760, 520), true, Vector2(16, 12))

func _place_prop(rel: String, pos: Vector2, solid: bool, col_size: Vector2) -> void:
	var tex := load(PROP_BASE + rel) as Texture2D
	if tex == null:
		return
	var root := Node2D.new()
	root.position = pos
	ysort.add_child(root)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = Vector2(0, -tex.get_height() / 2.0 + 16)
	root.add_child(spr)
	if solid:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = col_size
		shape.shape = rect
		shape.position = Vector2(0, 8)
		body.add_child(shape)
		root.add_child(body)
	if rel.begins_with("Desks/"):
		desk_positions.append(pos)
