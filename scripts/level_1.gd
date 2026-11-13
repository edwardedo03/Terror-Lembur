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

var hud_layer: CanvasLayer = null
var hud_task_bars: Array[ProgressBar] = []
var hud_task_rows: Array[Label] = []
var hud_task_count: Label
var hud_timer_label: Label
var hud_boss_label: Label
var hud_boss_row: HBoxContainer
var hud_boss_dot: PanelContainer
var hud_prompt_label: Label
var hud_prompt_pill: PanelContainer
var hud_prompt_bar: ProgressBar
var hud_warn_label: Label
var hud_status_label: Label
var hud_status_pill: PanelContainer
var hud_edge_rects: Array[ColorRect] = []
var hud_pulse_t := 0.0
var flash_rect: ColorRect
var flash_a := 0.0
var hud_stamina_bar: ProgressBar
var sfx: SFX
var heartbeat_timer := 0.0
var tick_timer := 0.0
var task_done_sounded: Dictionary = {}
var end_dim: ColorRect
var end_center: CenterContainer
var elapsed := 0.0
var times_caught := 0
var shake_strength := 0.0
var local_camera: Camera2D = null
var end_panel: PanelContainer
var end_title: Label
var end_detail: Label
var end_stars: Array[Label] = []

func _ready() -> void:
	sfx = SFX.new()
	add_child(sfx)
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
			floor_layer.set_cell(Vector2i(x, y), 0, _floor_tile_for(x, y))
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
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		show_hud()
	elif "--host" in OS.get_cmdline_user_args() or "--join" in OS.get_cmdline_user_args():
		show_hud()
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

func _floor_tile_for(tx: int, ty: int) -> Vector2i:
	var c := Vector2(tx * 32 + 16, ty * 32 + 16)
	if BOSS_ROOM.has_point(c):
		return Vector2i(0, 0)
	if PANTRY_ROOM.has_point(c) or TOILET_ROOM.has_point(c) or SERVER_ROOM.has_point(c):
		return Vector2i(2, 0)
	if ty == 8 or tx == 14:
		return Vector2i(2, 0)
	return Vector2i(1, 0)

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

func _rug(center: Vector2, size: Vector2, color: Color) -> void:
	var border := Polygon2D.new()
	border.color = Color(0.1, 0.07, 0.07, 0.9)
	border.z_index = -1
	border.polygon = PackedVector2Array([Vector2(-size.x / 2 - 6, -size.y / 2 - 6), Vector2(size.x / 2 + 6, -size.y / 2 - 6), Vector2(size.x / 2 + 6, size.y / 2 + 6), Vector2(-size.x / 2 - 6, size.y / 2 + 6)])
	border.position = center
	add_child(border)
	var fill := Polygon2D.new()
	fill.color = color
	fill.z_index = -1
	fill.polygon = PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2), Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
	fill.position = center
	add_child(fill)

func _cable(points: PackedVector2Array) -> void:
	var l := Line2D.new()
	l.points = points
	l.width = 2.0
	l.default_color = Color(0.05, 0.05, 0.06, 0.9)
	l.z_index = -1
	add_child(l)

func _build_horror() -> void:
	_blood_spot(Vector2(300, 300), 26.0)
	_blood_spot(Vector2(340, 320), 14.0)
	_blood_spot(Vector2(700, 560), 30.0)
	_blood_spot(Vector2(740, 590), 12.0)
	_blood_spot(Vector2(1120, 500), 22.0)
	_blood_spot(Vector2(200, 620), 18.0)
	_blood_spot(Vector2(640, 180), 16.0)
	_blood_spot(Vector2(500, 200), 15.0)
	_blood_spot(Vector2(900, 600), 20.0)
	_blood_spot(Vector2(1100, 250), 13.0)
	_blood_spot(Vector2(480, 640), 17.0)
	_paper(Vector2(420, 280), 0.4)
	_paper(Vector2(460, 300), -0.7)
	_paper(Vector2(560, 480), 1.1)
	_paper(Vector2(900, 300), 0.2)
	_paper(Vector2(940, 340), -1.2)
	_paper(Vector2(300, 560), 0.9)
	_paper(Vector2(1080, 300), -0.4)
	_paper(Vector2(640, 620), 0.6)
	_paper(Vector2(350, 450), 1.4)
	_paper(Vector2(800, 200), -0.5)
	_paper(Vector2(1150, 550), 0.8)
	_paper(Vector2(200, 400), -1.0)
	_paper(Vector2(700, 260), 0.3)
	_rug(Vector2(1140, 185), Vector2(150, 60), Color(0.35, 0.08, 0.1, 0.85))
	_rug(Vector2(640, 430), Vector2(260, 150), Color(0.15, 0.18, 0.28, 0.85))
	_rug(Vector2(1120, 610), Vector2(130, 70), Color(0.4, 0.28, 0.15, 0.85))
	_cable(PackedVector2Array([Vector2(155, 160), Vector2(150, 120), Vector2(150, 80)]))
	_cable(PackedVector2Array([Vector2(995, 160), Vector2(995, 120), Vector2(995, 80)]))
	_cable(PackedVector2Array([Vector2(640, 110), Vector2(640, 80)]))
	_cable(PackedVector2Array([Vector2(615, 400), Vector2(600, 430), Vector2(600, 460)]))
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

func show_hud() -> void:
	if hud_layer != null:
		hud_layer.visible = true

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if sfx != null:
		sfx.play(sound_name, volume_db, pitch)

func flash_red(amount: float = 0.35) -> void:
	flash_a = maxf(flash_a, amount)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud_layer = hud
	hud.visible = false
	add_child(hud)
	var task_panel := PanelContainer.new()
	UITheme.apply_panel(task_panel, Color(0.05, 0.05, 0.06, 0.85), Color(0.42, 0.36, 0.3), 1, 8)
	task_panel.position = Vector2(12, 10)
	task_panel.custom_minimum_size = Vector2(264, 0)
	hud.add_child(task_panel)
	var tvb := VBoxContainer.new()
	tvb.add_theme_constant_override("separation", 5)
	task_panel.add_child(tvb)
	var head_row := HBoxContainer.new()
	tvb.add_child(head_row)
	var task_head := UITheme.make_label("TUGAS", UITheme.body_font(), 16, UITheme.COL_GOLD)
	head_row.add_child(task_head)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(spacer)
	hud_task_count = UITheme.make_label("0/3", UITheme.body_font(), 14, UITheme.COL_GREY)
	head_row.add_child(hud_task_count)
	var divider := ColorRect.new()
	divider.color = Color(0.62, 0.5, 0.22, 0.9)
	divider.custom_minimum_size = Vector2(0, 2)
	tvb.add_child(divider)
	hud_task_bars.clear()
	hud_task_rows.clear()
	for tp in tasks:
		if tp.task_id == 4:
			continue
		var row := UITheme.make_label("\u2610 " + tp.label_text, UITheme.body_font(), 15, UITheme.COL_PAPER)
		tvb.add_child(row)
		hud_task_rows.append(row)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = 0.0
		bar.custom_minimum_size = Vector2(232, 9)
		bar.show_percentage = false
		UITheme.apply_progress_bar(bar)
		tvb.add_child(bar)
		hud_task_bars.append(bar)
	var status_panel := PanelContainer.new()
	UITheme.apply_panel(status_panel, Color(0.05, 0.05, 0.06, 0.85), Color(0.42, 0.36, 0.3), 1, 8)
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.position = Vector2(-268, 10)
	status_panel.custom_minimum_size = Vector2(256, 0)
	hud.add_child(status_panel)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 4)
	status_panel.add_child(svb)
	var timer_row := HBoxContainer.new()
	svb.add_child(timer_row)
	timer_row.add_child(UITheme.make_label("WAKTU", UITheme.body_font(), 13, UITheme.COL_GREY))
	var tspacer := Control.new()
	tspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_row.add_child(tspacer)
	hud_timer_label = UITheme.make_label("0:00", UITheme.body_font(), 20, UITheme.COL_PAPER)
	timer_row.add_child(hud_timer_label)
	hud_boss_row = HBoxContainer.new()
	hud_boss_row.add_theme_constant_override("separation", 8)
	hud_boss_row.visible = false
	svb.add_child(hud_boss_row)
	hud_boss_dot = PanelContainer.new()
	UITheme.apply_panel(hud_boss_dot, UITheme.COL_BLOOD, UITheme.COL_BLOOD_BRIGHT, 1, 14)
	hud_boss_dot.custom_minimum_size = Vector2(28, 28)
	var dot_lbl := UITheme.make_label("!", UITheme.body_font(), 16, Color.WHITE)
	dot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_boss_dot.add_child(dot_lbl)
	hud_boss_row.add_child(hud_boss_dot)
	hud_boss_label = UITheme.make_label("", UITheme.body_font(), 15, UITheme.COL_BLOOD_BRIGHT)
	hud_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_boss_row.add_child(hud_boss_label)
	hud_warn_label = UITheme.make_label("", UITheme.title_font(), 30, UITheme.COL_BLOOD_BRIGHT)
	hud_warn_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_warn_label.offset_top = 16
	hud_warn_label.offset_bottom = 60
	hud_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_warn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hud_warn_label.add_theme_constant_override("outline_size", 8)
	hud_warn_label.visible = false
	hud.add_child(hud_warn_label)
	hud_status_pill = PanelContainer.new()
	UITheme.apply_panel(hud_status_pill, Color(0.2, 0.12, 0.02, 0.9), UITheme.COL_GOLD, 1, 14)
	hud_status_pill.position = Vector2(16, 226)
	hud_status_pill.custom_minimum_size = Vector2(0, 0)
	hud_status_pill.visible = false
	hud.add_child(hud_status_pill)
	hud_status_label = UITheme.make_label("", UITheme.body_font(), 15, UITheme.COL_GOLD)
	hud_status_pill.add_child(hud_status_label)
	var prompt_center := CenterContainer.new()
	prompt_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_center.offset_top = -96
	prompt_center.offset_bottom = -8
	prompt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(prompt_center)
	var prompt_outer_vb := VBoxContainer.new()
	prompt_outer_vb.add_theme_constant_override("separation", 6)
	prompt_center.add_child(prompt_outer_vb)
	var stamina_row := HBoxContainer.new()
	stamina_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_outer_vb.add_child(stamina_row)
	hud_stamina_bar = ProgressBar.new()
	hud_stamina_bar.min_value = 0.0
	hud_stamina_bar.max_value = 100.0
	hud_stamina_bar.value = 100.0
	hud_stamina_bar.custom_minimum_size = Vector2(220, 8)
	hud_stamina_bar.show_percentage = false
	hud_stamina_bar.add_theme_stylebox_override("background", UITheme.bar_bg_style())
	hud_stamina_bar.add_theme_stylebox_override("fill", UITheme.bar_fill_style(Color(0.35, 0.85, 0.6)))
	stamina_row.add_child(hud_stamina_bar)
	hud_prompt_pill = PanelContainer.new()
	UITheme.apply_panel(hud_prompt_pill, Color(0.05, 0.05, 0.06, 0.88), UITheme.COL_GOLD, 1, 16)
	hud_prompt_pill.custom_minimum_size = Vector2(640, 0)
	hud_prompt_pill.visible = false
	prompt_outer_vb.add_child(hud_prompt_pill)
	var prompt_vb := VBoxContainer.new()
	prompt_vb.add_theme_constant_override("separation", 4)
	hud_prompt_pill.add_child(prompt_vb)
	hud_prompt_label = UITheme.make_label("", UITheme.body_font(), 16, UITheme.COL_PAPER)
	hud_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_vb.add_child(hud_prompt_label)
	hud_prompt_bar = ProgressBar.new()
	hud_prompt_bar.min_value = 0.0
	hud_prompt_bar.max_value = 1.0
	hud_prompt_bar.value = 0.0
	hud_prompt_bar.custom_minimum_size = Vector2(460, 8)
	hud_prompt_bar.show_percentage = false
	hud_prompt_bar.visible = false
	UITheme.apply_progress_bar(hud_prompt_bar)
	prompt_vb.add_child(hud_prompt_bar)
	for i in range(4):
		var edge := ColorRect.new()
		edge.color = Color(0.9, 0.1, 0.1, 0.0)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
			edge.offset_bottom = 22
		elif i == 1:
			edge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			edge.offset_top = -22
		elif i == 2:
			edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			edge.offset_right = 22
		else:
			edge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			edge.offset_left = -22
		hud.add_child(edge)
		hud_edge_rects.append(edge)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.9, 0.05, 0.05, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash_rect)
	end_dim = ColorRect.new()
	end_dim.color = Color(0, 0, 0, 0.65)
	end_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dim.visible = false
	hud.add_child(end_dim)
	end_center = CenterContainer.new()
	end_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_center.visible = false
	hud.add_child(end_center)
	end_panel = PanelContainer.new()
	UITheme.apply_panel(end_panel, Color(0.07, 0.05, 0.05, 0.95), UITheme.COL_BLOOD, 2, 12)
	end_panel.custom_minimum_size = Vector2(580, 0)
	end_center.add_child(end_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	end_panel.add_child(vb)
	end_title = UITheme.make_label("", UITheme.title_font(), 44, UITheme.COL_BLOOD_BRIGHT)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_title)
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 10)
	vb.add_child(star_row)
	end_stars.clear()
	for i in range(3):
		var s := UITheme.make_label("\u2605", UITheme.title_font(), 56, Color(0.3, 0.3, 0.3, 1))
		s.pivot_offset = Vector2(28, 28)
		star_row.add_child(s)
		end_stars.append(s)
	end_detail = UITheme.make_label("", UITheme.body_font(), 17, UITheme.COL_PAPER)
	end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(end_detail)
	var again_btn := Button.new()
	again_btn.text = "Main Lagi (R)"
	again_btn.custom_minimum_size = Vector2(0, 44)
	UITheme.apply_button(again_btn, 18)
	again_btn.pressed.connect(func() -> void: rpc("_restart_game"))
	vb.add_child(again_btn)

func _process(delta: float) -> void:
	if not game_over:
		elapsed += delta
	if warn_timer > 0.0:
		warn_timer -= delta
		if warn_timer <= 0.0:
			hud_warn_label.text = ""
	hud_pulse_t += delta
	if flash_a > 0.0:
		flash_a = maxf(0.0, flash_a - delta * 1.4)
		flash_rect.color = Color(0.9, 0.05, 0.05, flash_a)
	if boss != null and not game_over:
		var bd := _boss_distance()
		if bd >= 0.0 and bd < 320.0:
			heartbeat_timer -= delta
			if heartbeat_timer <= 0.0:
				heartbeat_timer = lerpf(0.45, 1.0, clampf(bd / 320.0, 0.0, 1.0))
				play_sfx("heartbeat", -8.0)
	var me2 := _my_player()
	if me2 != null and me2.get("interacting") and not game_over:
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = 0.4
			play_sfx("tick", -10.0)
	hud_warn_label.visible = hud_warn_label.text != ""
	if hud_warn_label.visible:
		hud_warn_label.modulate.a = 0.75 + 0.25 * sin(hud_pulse_t * 8.0)
	var boss_d := _boss_distance()
	var edge_alpha := 0.0
	if boss_d >= 0.0 and boss_d < 150.0:
		edge_alpha = 0.22 + 0.12 * sin(hud_pulse_t * 7.0)
	elif boss_d >= 0.0 and boss_d < 260.0:
		edge_alpha = 0.1
	for edge in hud_edge_rects:
		edge.color = Color(0.9, 0.1, 0.1, edge_alpha)
	if hud_boss_row.visible:
		hud_boss_dot.modulate.a = 0.6 + 0.4 * sin(hud_pulse_t * 6.0)
	flicker_timer += delta
	if flicker_timer > 0.12:
		flicker_timer = 0.0
		for i in range(flicker_lights.size()):
			var f := flicker_lights[i]
			if randf() < 0.12:
				f.energy = flicker_base[i] * randf_range(0.15, 0.5)
			else:
				f.energy = flicker_base[i] * randf_range(0.85, 1.05)
	if local_camera == null:
		var me := _my_player()
		if me != null:
			local_camera = me.get_node_or_null("Camera2D") as Camera2D
	if shake_strength > 0.0:
		shake_strength = maxf(0.0, shake_strength - delta * 22.0)
		if local_camera != null:
			local_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength
	elif local_camera != null and local_camera.offset != Vector2.ZERO:
		local_camera.offset = Vector2.ZERO
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
	if title == "HAPPY ENDING":
		end_title.add_theme_color_override("font_color", UITheme.COL_GREEN)
	else:
		end_title.add_theme_color_override("font_color", UITheme.COL_BLOOD_BRIGHT)
	for i in range(end_stars.size()):
		if i < s:
			end_stars[i].add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		else:
			end_stars[i].add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
		end_stars[i].scale = Vector2(0.01, 0.01)
	var mins := int(elapsed) / 60
	var secs := int(elapsed) % 60
	var time_txt := "%d:%02d" % [mins, secs]
	end_detail.text = detail + "\n\nWaktu: " + time_txt + "   |   Ketangkep: " + str(times_caught) + "x"
	end_dim.visible = true
	end_center.visible = true
	end_panel.visible = true
	for i in range(end_stars.size()):
		var tw := create_tween()
		tw.tween_interval(0.12 * float(i))
		tw.tween_property(end_stars[i], "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("flashlight"):
		rpc("_restart_game")

@rpc("any_peer", "call_local")
func _restart_game() -> void:
	get_tree().reload_current_scene()

func _update_hud() -> void:
	var bi := 0
	var done_count := 0
	for tp in tasks:
		if tp.task_id == 4:
			continue
		if tp.done:
			done_count += 1
		if bi < hud_task_rows.size():
			var mark := "\u2611" if tp.done else "\u2610"
			var extra := ""
			if tp.task_id == 3 and not _main_tasks_done():
				extra = " (terkunci)"
			hud_task_rows[bi].text = mark + " " + tp.label_text + extra
			if tp.done:
				hud_task_rows[bi].add_theme_color_override("font_color", UITheme.COL_GREEN)
			else:
				hud_task_rows[bi].add_theme_color_override("font_color", UITheme.COL_PAPER)
		if bi < hud_task_bars.size():
			hud_task_bars[bi].value = tp.progress
			if tp.done:
				hud_task_bars[bi].add_theme_stylebox_override("fill", UITheme.bar_fill_style(UITheme.COL_GREEN))
		bi += 1
	if hud_task_count != null:
		hud_task_count.text = str(done_count) + "/3"
	for tp2 in tasks:
		if tp2.done and not task_done_sounded.get(tp2.task_id, false):
			task_done_sounded[tp2.task_id] = true
			play_sfx("complete", -4.0)
	var me_st := _my_player()
	if me_st != null:
		hud_stamina_bar.value = float(me_st.get("stamina"))
	var mins := int(elapsed) / 60
	var secs := int(elapsed) % 60
	hud_timer_label.text = "%d:%02d" % [mins, secs]
	var boss_d := _boss_distance()
	var boss_txt := ""
	if boss_d >= 0.0 and boss_d < 400.0:
		if boss_d < 150.0:
			boss_txt = "BOS SANGAT DEKAT!"
		elif boss_d < 260.0:
			boss_txt = "Bos dekat..."
		else:
			boss_txt = "Ada yang mengawasi..."
	hud_boss_label.text = boss_txt
	hud_boss_row.visible = boss_txt != ""
	var locked_names := ""
	for child in ysort.get_children():
		if not _is_player(child):
			continue
		if child.get("locked"):
			var disp := "Pemain 1" if str(child.name) == "1" else "Pemain 2"
			locked_names += disp + " DIKURUNG di ruang bos! "
	if locked_names != "":
		hud_status_label.text = locked_names + "Tahan E di TUAS SEL buat bebaskan (3 detik)."
		hud_status_pill.visible = true
	else:
		hud_status_label.text = ""
		hud_status_pill.visible = false
	var prompt_txt := ""
	var prompt_prog := -1.0
	var me := _my_player()
	if me != null and not game_over:
		if me.get("interacting") and me.get("interact_target") >= 0:
			var tid: int = me.get("interact_target")
			var tp = tasks[tid] if tid < tasks.size() else null
			if tp != null:
				prompt_txt = "Mengerjakan " + tp.label_text + "... " + str(int(tp.progress * 100.0)) + "%"
				prompt_prog = tp.progress
		else:
			var nid := nearest_interactable(me.global_position)
			if nid >= 0:
				var tp = tasks[nid]
				var need_txt := ""
				if tp.task_id == 0:
					need_txt = " (butuh 2 orang)"
				elif tp.task_id == 3:
					need_txt = " (butuh 2 orang, atau 1 orang 10 detik kalau teman dikurung)"
				prompt_txt = "Tahan E: " + tp.label_text + need_txt
			elif me.get("hiding"):
				prompt_txt = "NGUMPET — gerak atau tekan C buat keluar"
			elif nearest_desk(me.global_position) != Vector2.INF:
				prompt_txt = "C: ngumpet di bawah meja"
			elif me.get("has_throwable"):
				prompt_txt = "Q: lempar barang  |  F: teriak  |  R: senter  |  C: ngumpet  |  SHIFT: lari"
			else:
				prompt_txt = "E: interaksi  |  F: teriak  |  R: senter  |  C: ngumpet  |  SHIFT: lari"
	hud_prompt_label.text = prompt_txt
	hud_prompt_pill.visible = prompt_txt != ""
	if prompt_prog >= 0.0:
		hud_prompt_bar.visible = true
		hud_prompt_bar.value = prompt_prog
	else:
		hud_prompt_bar.visible = false
func _boss_distance() -> float:
	var me := _my_player()
	if me == null or boss == null:
		return -1.0
	return me.global_position.distance_to(boss.global_position)

func add_shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)

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
	times_caught += 1
	player.global_position = CELL_POS
	player.rpc_id(int(player.name), "set_locked", true)
	rpc("_fx_caught")

@rpc("any_peer", "call_local")
func _fx_caught() -> void:
	add_shake(10.0)
	flash_red(0.4)
	hud_warn_label.text = "TEMANMU DITANGKAP!"
	warn_timer = 3.0
	play_sfx("sting", -2.0)

@rpc("any_peer", "call_local")
func on_boss_chase() -> void:
	add_shake(3.0)
	hud_warn_label.text = "BOS MENGEJAR!"
	warn_timer = 2.0
	play_sfx("alarm", -6.0)

@rpc("any_peer", "call_local")
func on_boss_telegraph() -> void:
	hud_warn_label.text = "Bisikan... bos mau pindah!"
	warn_timer = 1.2
	play_sfx("whisper", -4.0)

@rpc("any_peer", "call_local")
func on_boss_teleported(dest: Vector2) -> void:
	add_shake(6.0)
	hud_warn_label.text = "Bos muncul di dekatmu!"
	warn_timer = 2.0
	play_sfx("thud", -4.0)

@rpc("any_peer", "call_local")
func spawn_throwable(pos: Vector2, dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var scene := load(THROWABLE_SCENE) as PackedScene
	var th := scene.instantiate() as Node2D
	ysort.add_child(th, true)
	th.launch(pos + dir * 24.0, dir)

const PROP_BASE := "res://assets/office_assets/main/Office_Pixel_Art_Free_v1.0/Props/"
const MODERN_BASE := "res://assets/office_assets/modern/objects/"

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
	desk_positions.append(Vector2(640, 430))
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
	_place_prop(desk, Vector2(1090, 90), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(1090, 120), true, Vector2(26, 20))
	_place_prop(lap, Vector2(1085, 72), false, Vector2.ZERO)
	_place_prop(plant, Vector2(1240, 200), true, Vector2(26, 16))
	_place_prop(cab, Vector2(500, 88), true, Vector2(28, 24))
	_place_prop(paper, Vector2(480, 150), false, Vector2.ZERO)
	_place_prop(paper, Vector2(490, 170), false, Vector2.ZERO)
	_place_prop(cab, Vector2(720, 88), true, Vector2(28, 24))
	_place_prop(cab, Vector2(750, 88), true, Vector2(28, 24))
	_place_prop(desk, Vector2(1060, 600), true, Vector2(64, 24))
	_place_prop(chair_f, Vector2(1060, 570), true, Vector2(26, 20))
	_place_prop(chair_b, Vector2(1060, 630), true, Vector2(26, 20))
	_place_prop(plant, Vector2(1010, 540), true, Vector2(26, 16))
	_place_prop(plant, Vector2(60, 580), true, Vector2(26, 16))
	_place_prop(trash, Vector2(220, 660), true, Vector2(16, 12))
	_place_prop(desk, Vector2(880, 140), true, Vector2(64, 24))
	_place_prop(chair_b, Vector2(880, 170), true, Vector2(26, 20))
	_place_prop(pc, Vector2(865, 122), false, Vector2.ZERO)
	_place_prop(plant, Vector2(60, 220), true, Vector2(26, 16))
	_place_prop(paper, Vector2(250, 220), false, Vector2.ZERO)
	_place_prop(cab, Vector2(500, 300), true, Vector2(28, 24))
	_place_prop(plant, Vector2(810, 300), true, Vector2(26, 16))
	_place_modern("bookshelf.png", Vector2(1150, 80), true, Vector2(30, 20))
	_place_modern("sofa.png", Vector2(1200, 560), true, Vector2(44, 20))
	_place_modern("whiteboard.png", Vector2(700, 300), false, Vector2.ZERO)

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

func _place_modern(rel: String, pos: Vector2, solid: bool, col_size: Vector2) -> void:
	var tex := load(MODERN_BASE + rel) as Texture2D
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
