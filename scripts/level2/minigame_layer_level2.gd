class_name MinigameLayerLevel2
extends CanvasLayer
## Lapisan minigame KHUSUS LEVEL 2 (salinan scripts/minigame_layer.gd; file
## aslinya tidak diubah). Tambahan: minigame "kabel" (Sambung Kabel) dan
## pakai_gaya_monitor() untuk bingkai monitor CCTV.
##
## Lapisan UI minigame tugas — berjalan LOKAL di layar pemain yang
## mengerjakan tugas. Level (host) yang memutuskan tugas selesai lewat
## submit_minigame_result(); layer ini hanya menampilkan game, mengunci
## gerakan pemain, dan melaporkan progres untuk bilah stasiun tugas.
## Esc membatalkan (progres percobaan hilang). Otomatis tertutup kalau
## pemain tertangkap, tugas sudah selesai, atau level berakhir.

signal minigame_finished(task_id: StringName)
signal minigame_cancelled(task_id: StringName)

const GAME_SCRIPTS: Dictionary = {
	&"excel": "res://scripts/minigames/mg_excel.gd",
	&"slides": "res://scripts/minigames/mg_slides.gd",
	&"email": "res://scripts/minigames/mg_email.gd",
	&"copy": "res://scripts/minigames/mg_copy.gd",
	&"archive": "res://scripts/minigames/mg_archive.gd",
	&"simon": "res://scripts/minigames/mg_simon.gd",
	&"server": "res://scripts/minigames/mg_server.gd",
	&"kabel": "res://scripts/level2/minigames/mg_kabel.gd",  # Level 2: perbaikan error komputer
}
const CLOSE_RANGE: float = 102.0

var _open: bool = false
var _task_id: StringName = StringName("")
var _game: MinigameBase = null
var _report_timer: float = 0.0
var _last_reported: float = -1.0

var _root: Control = null
var _title_label: Label = null
var _instructions_label: Label = null
var _game_holder: Control = null
var _status_label: Label = null
var _progress_bar: ProgressBar = null
var _panel: PanelContainer = null
var _margin: MarginContainer = null
var _hint_label: Label = null
var _gaya_monitor: bool = false


func _ready() -> void:
	layer = 20
	add_to_group("MinigameLayer")
	_build_ui()
	_root.visible = false


func is_open() -> bool:
	return _open


func current_task() -> StringName:
	return _task_id


func current_game() -> MinigameBase:
	return _game


func open_minigame(task_id: StringName, game_type: StringName) -> bool:
	if _open:
		return false
	if not GAME_SCRIPTS.has(game_type):
		push_warning("MinigameLayer: tipe game tidak dikenal: %s" % game_type)
		return false
	var level: Node = _level()
	if level == null:
		return false
	var script: GDScript = load(GAME_SCRIPTS[game_type])
	_game = script.new() as MinigameBase
	if _game == null:
		return false
	_task_id = task_id
	_game_holder.add_child(_game)
	_game.setup()
	_title_label.text = _game.game_title
	_instructions_label.text = _game.instructions
	_status_label.text = ""
	_progress_bar.value = 0.0
	_game.finished.connect(_on_game_finished)
	_game.status_changed.connect(_on_game_status)
	_open = true
	_report_timer = 0.0
	_last_reported = -1.0
	_root.visible = true
	level.set_local_minigame_open(true)
	return true


func close_minigame(cancelled: bool) -> void:
	if not _open:
		return
	var tid: StringName = _task_id
	_open = false
	_task_id = StringName("")
	if _game != null:
		_game.queue_free()
		_game = null
	_root.visible = false
	var level: Node = _level()
	if level != null:
		level.set_local_minigame_open(false)
	if cancelled:
		minigame_cancelled.emit(tid)
	else:
		minigame_finished.emit(tid)


func force_close() -> void:
	close_minigame(true)


func simulate_key(keycode: int, unicode: int = 0) -> void:
	# Dipakai smoke test: menyuntikkan tombol ke game yang sedang terbuka.
	if _game == null:
		return
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = keycode
	ev.unicode = unicode
	_game.handle_key(ev)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
			close_minigame(true)
			get_viewport().set_input_as_handled()
			return
		if _game != null:
			_game.handle_key(event)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _open or _game == null:
		return
	_game.tick(delta)
	var prog: float = clampf(_game.get_progress(), 0.0, 1.0)
	_progress_bar.value = prog * 100.0
	_report_timer -= delta
	if _report_timer <= 0.0:
		_report_timer = 0.25
		if absf(prog - _last_reported) >= 0.05:
			_last_reported = prog
			var lv: Node = _level()
			if lv != null:
				lv.report_minigame_progress(_task_id, prog)
	_validate_open()


func _validate_open() -> void:
	var level: Node = _level()
	if level == null or not level.is_level_running():
		close_minigame(true)
		return
	if level.is_task_completed(_task_id):
		close_minigame(true)
		return
	var p: Node = level.get_local_player()
	if p == null or p.is_downed or p.is_hidden:
		close_minigame(true)
		return
	if p.global_position.distance_to(level.task_position(_task_id)) > CLOSE_RANGE:
		close_minigame(true)


func _on_game_finished() -> void:
	var tid: StringName = _task_id
	var level: Node = _level()
	close_minigame(false)
	if level != null:
		level.submit_minigame_result(tid)


func _on_game_status(text: String, good: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.55) if good else Color(1, 0.6, 0.55))


func _level() -> Node:
	return get_tree().get_first_node_in_group("LevelManager")


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 470)
	center.add_child(panel)
	_panel = panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	_margin = margin
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	_title_label = _mk_label("", 28, Color(1, 0.9, 0.55))
	vbox.add_child(_title_label)
	_instructions_label = _mk_label("", 16, Color(0.9, 0.9, 0.95))
	_instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_instructions_label)
	_game_holder = Control.new()
	_game_holder.custom_minimum_size = Vector2(560, 240)
	_game_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_game_holder)
	_status_label = _mk_label("", 17, Color.WHITE)
	_status_label.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(_status_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = true
	_progress_bar.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(_progress_bar)
	var hint := _mk_label("Esc = batalkan tugas (progres hilang)  |  Musuh tetap bergerak selagi kamu kerja!", 13, Color(1, 1, 1, 0.6))
	vbox.add_child(hint)
	_hint_label = hint


func _mk_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


# ------------------------------------------------------------------
# Gaya "monitor CCTV" — dipanggil Level 2 saja (Level 1 tetap gaya lama).
# Isi minigame tidak diubah; yang berubah hanya bingkai & teks judulnya.
func pakai_gaya_monitor(f_biasa: Font, f_tebal: Font) -> void:
	if _gaya_monitor or _panel == null:
		return
	_gaya_monitor = true
	var bezel := StyleBoxFlat.new()
	bezel.bg_color = Color(0.18, 0.18, 0.2)
	bezel.border_color = Color(0.31, 0.31, 0.35)
	bezel.set_border_width_all(2)
	bezel.set_corner_radius_all(18)
	bezel.content_margin_left = 22
	bezel.content_margin_right = 22
	bezel.content_margin_top = 20
	bezel.content_margin_bottom = 46
	bezel.shadow_color = Color(0, 0, 0, 0.55)
	bezel.shadow_size = 14
	bezel.anti_aliasing = true
	_panel.add_theme_stylebox_override("panel", bezel)
	# layar gelap di dalam bingkai
	var layar := PanelContainer.new()
	layar.name = "LayarMonitor"
	var gaya_layar := StyleBoxFlat.new()
	gaya_layar.bg_color = Color(0.04, 0.055, 0.063)
	gaya_layar.set_corner_radius_all(12)
	gaya_layar.content_margin_left = 18
	gaya_layar.content_margin_right = 18
	gaya_layar.content_margin_top = 14
	gaya_layar.content_margin_bottom = 12
	gaya_layar.anti_aliasing = true
	layar.add_theme_stylebox_override("panel", gaya_layar)
	_panel.remove_child(_margin)
	_panel.add_child(layar)
	layar.add_child(_margin)
	for sisi: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_margin.add_theme_constant_override(sisi, 0)
	var garis := _Scanline.new()
	garis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layar.add_child(garis)
	# teks: huruf mesin ketik, warna fosfor
	var hijau := Color(0.78, 0.91, 0.77)
	var hijau_redup := Color(0.45, 0.56, 0.44)
	_title_label.add_theme_font_override("font", f_tebal)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", hijau)
	_title_label.add_theme_constant_override("outline_size", 0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_instructions_label.add_theme_font_override("font", f_biasa)
	_instructions_label.add_theme_font_size_override("font_size", 14)
	_instructions_label.add_theme_color_override("font_color", hijau_redup)
	_instructions_label.add_theme_constant_override("outline_size", 0)
	_instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.add_theme_font_override("font", f_tebal)
	_status_label.add_theme_constant_override("outline_size", 0)
	# progres = deretan blok segmen
	var latar_bar := StyleBoxFlat.new()
	latar_bar.bg_color = Color(0.16, 0.2, 0.18)
	var isi_bar := StyleBoxFlat.new()
	isi_bar.bg_color = Color(1.0, 0.69, 0.27)
	_progress_bar.add_theme_stylebox_override("background", latar_bar)
	_progress_bar.add_theme_stylebox_override("fill", isi_bar)
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	var segmen := _SegmenProgres.new()
	segmen.set_anchors_preset(Control.PRESET_FULL_RECT)
	segmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_child(segmen)
	_hint_label.visible = false
	# pelat merek, lampu power & label Dymo "ESC = BATAL" di bingkai bawah
	var pelat := _Pelat.new()
	pelat.panel = _panel
	pelat.f_tebal = f_tebal
	pelat.set_anchors_preset(Control.PRESET_FULL_RECT)
	pelat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pelat)


class _Scanline extends Control:
	func _draw() -> void:
		var y: float = 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.16), 1.0)
			y += 3.0


class _SegmenProgres extends Control:
	func _draw() -> void:
		var langkah: float = size.x / 16.0
		for k: int in range(1, 16):
			draw_rect(Rect2(k * langkah - 2.0, 0, 4.0, size.y), Color(0.04, 0.055, 0.063))


class _Pelat extends Control:
	var panel: Control = null
	var f_tebal: Font = null

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if panel == null or f_tebal == null:
			return
		var r: Rect2 = panel.get_global_rect()
		r.position -= get_global_rect().position
		var y: float = r.end.y - 23.0
		draw_string(f_tebal, Vector2(r.position.x + 28, y + 4), "SECURA  ·  CH-03", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.63))
		draw_circle(Vector2(r.end.x - 30, y), 4.0, Color(0.43, 0.9, 0.47))
		var teks: String = "ESC = BATAL"
		var lebar: float = f_tebal.get_string_size(teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 30.0
		var x: float = r.end.x - 60.0 - lebar
		var pita := PackedVector2Array([Vector2(x + 5, y - 12), Vector2(x + lebar - 5, y - 12), Vector2(x + lebar, y),
			Vector2(x + lebar - 5, y + 12), Vector2(x + 5, y + 12), Vector2(x, y)])
		draw_colored_polygon(pita, Color(0.086, 0.086, 0.1))
		draw_string(f_tebal, Vector2(x + 15, y + 4), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.93, 0.93, 0.94))
