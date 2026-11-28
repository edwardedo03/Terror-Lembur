extends CanvasLayer
## HUD KHUSUS LEVEL 2 (salinan scripts/hud.gd; file aslinya tidak diubah).
## Tambahan untuk Level 2: mode_minimal(), set_tasks_text(), set_timer_text(),
## set_hint_text(). Yang tampil di Level 2 cuma panel hasil & panel putus
## koneksi; sisanya digantikan HudMalam (scripts/level2/hud_malam.gd).
##
## HUD — dibangun dari kode supaya mudah diubah tanpa mengotak-atik
## file .tscn. Menampilkan tugas, waktu, status pemain, prompt interaksi,
## pesan tengah layar, panel hasil (ending + bintang), dan panel putus koneksi.

var _tasks_label: Label = null
var _timer_label: Label = null
var _status_label: Label = null
var _hint_label: Label = null
var _top_bg: ColorRect = null
var _prompt_bg: ColorRect = null
var _prompt_label: Label = null
var _message_label: Label = null
var _flash_rect: ColorRect = null
var _hasil: PanelHasil = null  # panel hasil akhir, sama dengan Level 1 (scripts/panel_hasil.gd)
var _putus: PanelPutus = null  # panel koneksi putus (scripts/panel_putus.gd)
var _message_timer: float = 0.0
var _flash_alpha: float = 0.0
var _task_total: int = 0


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_prompt_and_message()
	_build_result_panel()
	_build_disconnect_panel()
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0, 0, 0, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	# Panel hasil (layer 25) dan panel koneksi putus (layer 26) punya
	# CanvasLayer sendiri, jadi selalu di atas elemen HUD lain.


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0 and _message_label != null:
			_message_label.text = ""
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 0.8)
		_flash_rect.color = Color(0, 0, 0, _flash_alpha)


func set_task_total(total: int) -> void:
	_task_total = total


func update_tasks(done: int, total: int, exit_open: bool) -> void:
	if _tasks_label == null:
		return
	var extra: String = "  PINTU TERBUKA!" if exit_open else ""
	_tasks_label.text = "Tugas: %d/%d%s" % [done, total, extra]


func update_timer(time_sec: float) -> void:
	if _timer_label == null:
		return
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	_timer_label.text = "Waktu: %02d:%02d" % [m, s]


# --- Dipakai Level 2: sembunyikan bar atas, prompt & pesan bawaan (Level 2
# punya HUD sendiri: HudMalam). Panel hasil & putus koneksi tetap dipakai.
func mode_minimal() -> void:
	for n: CanvasItem in [_top_bg, _tasks_label, _timer_label, _status_label, _hint_label, _prompt_bg, _prompt_label, _message_label]:
		if n != null:
			n.visible = false


# --- Dipakai Level 2: teks bebas untuk baris tugas, baris waktu & bantuan tombol.
func set_tasks_text(text: String) -> void:
	if _tasks_label != null:
		_tasks_label.text = text


func set_timer_text(text: String) -> void:
	if _timer_label != null:
		_timer_label.text = text


func set_hint_text(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func update_status(lines: Array[String]) -> void:
	if _status_label == null:
		return
	_status_label.text = "\n".join(lines)


func show_prompt(text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = text


func show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_timer = 3.5


func flash_blackout() -> void:
	_flash_alpha = 0.6


func show_result(success: bool, stars: int, ending: String, time_sec: float, deaths: int, done: int, total: int, level_baru: String = "") -> void:
	if _hasil == null:
		return
	_hasil.tampilkan(success, stars, ending, time_sec, deaths, done, total, level_baru)


## Tampilkan panel koneksi putus. jenis: "host_keluar", "host_putus",
## atau "teman_putus" (lihat scripts/panel_putus.gd). detik = lama hitung
## mundur ke menu utama (0 = tanpa hitung mundur).
func show_putus(jenis: String, detik: float = 0.0) -> void:
	if _putus == null:
		return
	# Panel hasil akan tertutup panel ini, jadi disembunyikan dulu,
	# misalnya saat host keluar setelah level selesai.
	if _hasil != null:
		_hasil.sembunyikan()
	_putus.tampilkan(jenis, detik)


## Versi lama (teks bebas), tetap ada supaya pemanggil lama tidak rusak.
func show_disconnect(text: String) -> void:
	var t: String = text.to_lower()
	if t.contains("host keluar"):
		show_putus("host_keluar", 4.0)
	elif t.contains("host"):
		show_putus("host_putus", 4.0)
	else:
		show_putus("teman_putus")


## Dipanggil saat teman yang sempat terputus bergabung lagi (level_2.gd).
## Dipanggil saat teman yang sempat terputus bergabung lagi (game lanjut).
func hide_disconnect() -> void:
	if _putus == null:
		return
	_putus.sembunyikan()


func _build_top_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.position = Vector2(10, 10)
	bg.size = Vector2(320, 62)
	add_child(bg)
	_top_bg = bg
	_tasks_label = _mk_label("Tugas: 0/0", 16, Color.WHITE, Vector2(18, 16))
	_tasks_label.size = Vector2(304, 22)
	add_child(_tasks_label)
	_timer_label = _mk_label("Waktu: 00:00", 16, Color(1, 0.9, 0.6), Vector2(18, 42))
	_timer_label.size = Vector2(304, 22)
	add_child(_timer_label)
	_status_label = _mk_label("", 14, Color.WHITE, Vector2.ZERO)
	_status_label.anchor_left = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = -320
	_status_label.offset_right = -14
	_status_label.offset_top = 12
	_status_label.offset_bottom = 60
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status_label)
	var hint := _mk_label("WASD/Panah: Gerak  |  Shift: Lari (berisik!)  |  E: Interaksi  |  Esc: Batalkan tugas", 12, Color(1, 1, 1, 0.6), Vector2.ZERO)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 12
	hint.offset_right = 900
	hint.offset_top = -26
	hint.offset_bottom = -6
	add_child(hint)
	_hint_label = hint


func _build_prompt_and_message() -> void:
	var prompt_bg := ColorRect.new()
	prompt_bg.color = Color(0, 0, 0, 0.55)
	prompt_bg.anchor_left = 0.5
	prompt_bg.anchor_right = 0.5
	prompt_bg.anchor_top = 1.0
	prompt_bg.anchor_bottom = 1.0
	prompt_bg.offset_left = -320
	prompt_bg.offset_right = 320
	prompt_bg.offset_top = -58
	prompt_bg.offset_bottom = -30
	add_child(prompt_bg)
	_prompt_bg = prompt_bg
	_prompt_label = _mk_label("", 16, Color(1, 1, 0.7), Vector2.ZERO)
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -320
	_prompt_label.offset_right = 320
	_prompt_label.offset_top = -56
	_prompt_label.offset_bottom = -32
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt_label)
	_message_label = _mk_label("", 17, Color(1, 0.85, 0.5), Vector2.ZERO)
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.offset_left = -400
	_message_label.offset_right = 400
	_message_label.offset_top = 78
	_message_label.offset_bottom = 104
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)


func _build_result_panel() -> void:
	_hasil = PanelHasil.new()
	_hasil.name = "PanelHasil"
	_hasil.main_lagi.connect(_on_retry_pressed)
	_hasil.pilih_level.connect(_on_pilih_level_pressed)
	_hasil.menu_utama.connect(_on_menu_pressed)
	_hasil.atur_level("LEVEL 2  LOBI GELAP")
	add_child(_hasil)


func _build_disconnect_panel() -> void:
	# Panel koneksi putus sama untuk Level 1 dan Level 2 (scripts/panel_putus.gd).
	_putus = PanelPutus.new()
	_putus.name = "PanelPutus"
	_putus.menu_utama.connect(_on_menu_pressed)
	add_child(_putus)


func _mk_label(text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _level() -> Node:
	return get_tree().get_first_node_in_group("LevelManager")


func _on_retry_pressed() -> void:
	var lv: Node = _level()
	if lv != null:
		lv.request_restart()


func _on_pilih_level_pressed() -> void:
	var lv: Node = _level()
	if lv != null and lv.has_method("request_pilih_level"):
		lv.request_pilih_level()


func _on_menu_pressed() -> void:
	var lv: Node = _level()
	if lv != null:
		lv.request_menu()
	else:
		AlurLevel.ke_menu_utama()
