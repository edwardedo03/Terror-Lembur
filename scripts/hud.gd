extends CanvasLayer
## HUD Level 1 — dibangun dari kode supaya mudah diubah tanpa mengotak-atik
## file .tscn. Menampilkan tugas, waktu, status pemain, prompt interaksi,
## pesan tengah layar, panel hasil (ending + penilaian), dan panel putus koneksi.
## Gaya visual: UiTheme (kantor lembur: gelap hangat, garis rambut, mono,
## satu aksen amber).

var _tasks_label: Label = null
var _timer_label: Label = null
var _status_label: Label = null
var _prompt_label: Label = null
var _message_label: Label = null
var _flash_rect: ColorRect = null
var _result_panel: CenterContainer = null
var _result_dim: ColorRect = null
var _result_title: Label = null
var _result_stats: VBoxContainer = null
var _stat_time: Label = null
var _stat_deaths: Label = null
var _stat_tasks: Label = null
var _result_star_boxes: Array[UiTheme.StarIcon] = []
var _result_star_count: Label = null
var _disconnect_panel: CenterContainer = null
var _disconnect_label: Label = null
var _message_timer: float = 0.0
var _flash_alpha: float = 0.0
var _task_total: int = 0
var _stamina_bar: ProgressBar = null
var _stamina_fill: StyleBoxFlat = null

# --- Alert musuh di tepi layar ---
# Musuh yang mendekat (masih di luar layar) memerahkan tepi layar di
# arah musuh berada, supaya pertemuan tidak tiba-tiba: pemain dapat
# peringatan + arah sebelum musuh masuk ke tampilan layar.
# Bentuknya glow gradien (bukan strip kotak): tiap tepi memakai
# GradientTexture2D — merah pekat di tepi luar, memudar lembut ke
# dalam sejauh ALERT_THICKNESS — jadi terbaca sebagai cahaya bahaya,
# bukan kotak. ALERT_RANGE 320 px: kamera zoom 5.55 -> setengah lebar
# layar cuma ~115 px, jadi alert sudah menyala jauh sebelum musuh
# terlihat. Intensitas naik linear saat musuh mendekat, dan berdenyut
# saat CHASE.
const ALERT_RANGE: float = 320.0
const ALERT_MAX_ALPHA: float = 0.9
const ALERT_THICKNESS: float = 110.0
const ALERT_COLOR := Color(0.9, 0.12, 0.12)
var _alert_top: TextureRect = null
var _alert_bottom: TextureRect = null
var _alert_left: TextureRect = null
var _alert_right: TextureRect = null
var _alert_time: float = 0.0

# --- Panduan (dropdown kanan atas, tombol TAB) ---
# Isi default = Level 1; Level 2 menimpa lewat set_guide_lines().
const GUIDE_LINES_L1: Array[String] = [
	"Selesaikan 10 task untuk bisa keluar.",
	"Peta hanya bisa dibuka di ruang Gudang (pojok kiri atas). Tekan M di sana.",
	"Kerja samalah dengan temanmu: satu mengawasi / mengalihkan musuh, satu menyelesaikan task.",
	"Tekan TAB untuk membuka / menutup panduan ini.",
]
var _guide_panel: PanelContainer = null
var _guide_header: Button = null
var _guide_body: VBoxContainer = null
var _guide_open: bool = false

# --- Peta kantor (tombol M, hanya saat pemain lokal di ruang Gudang) ---
# Kotak ruangan saja (tanpa koridor, tanpa props); data ruangan datang
# dari level lewat setup_map(). Dunia Level 1 = 2048x1280 px (64x40 sel).
const MAP_WORLD := Vector2(2048.0, 1280.0)
const MAP_AREA := Vector2(760.0, 476.0)
var _map_dim: ColorRect = null
var _map_panel: CenterContainer = null
var _map_area: Control = null
var _map_rooms: Array = []
var _map_available: bool = false
var _map_open: bool = false
var _map_scale: float = 0.0
var _map_dot_self: ColorRect = null
var _map_dot_friend: ColorRect = null


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_stamina_bar()
	_build_prompt_and_message()
	_build_result_panel()
	_build_disconnect_panel()
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0, 0, 0, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	_build_enemy_alert()
	_build_guide()
	_build_map()
	# Flash dan alert harus di bawah panel hasil: pindahkan panel ke depan.
	if _result_panel != null:
		move_child(_result_panel, -1)
	if _disconnect_panel != null:
		move_child(_disconnect_panel, -1)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0 and _message_label != null:
			_message_label.text = ""
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 0.8)
		_flash_rect.color = Color(0, 0, 0, _flash_alpha)
	_update_enemy_alert(delta)
	if _map_open:
		_update_map_dots()


func _unhandled_key_input(event: InputEvent) -> void:
	# TAB = panduan, M = peta (hanya kalau tersedia), ESC = tutup peta.
	# Saat minigame terbuka semua tombol ini dimatikan: minigame punya
	# input sendiri (termasuk ESC untuk batal), dan panduan/peta tidak
	# boleh menumpuk di atasnya.
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _minigame_open():
		return
	if k.keycode == KEY_TAB:
		toggle_guide()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_M:
		if _map_open:
			close_map()
		elif _map_available:
			open_map()
		else:
			return
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ESCAPE and _map_open:
		close_map()
		get_viewport().set_input_as_handled()


func _minigame_open() -> bool:
	var lv: Node = _level()
	if lv == null or not lv.has_method("is_minigame_open"):
		return false
	return bool(lv.is_minigame_open())


# --- Panduan ---

func toggle_guide() -> void:
	set_guide_open(not _guide_open)


func set_guide_open(open: bool) -> void:
	_guide_open = open
	if _guide_body != null:
		_guide_body.visible = open
	if _guide_header != null:
		_guide_header.text = "PANDUAN [TAB] - TUTUP" if open else "PANDUAN [TAB]"
	_fit_guide_panel()


func set_guide_lines(lines: Array[String]) -> void:
	# Dipakai Level 2 untuk menimpa isi panduan default Level 1.
	if _guide_body == null:
		return
	for c: Node in _guide_body.get_children():
		c.queue_free()
	for line: String in lines:
		var l := UiTheme.mk_label("- " + line, 13, UiTheme.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(340, 0)
		_guide_body.add_child(l)
	_fit_guide_panel()


# --- Peta ---

func setup_map(rooms: Array) -> void:
	# Dipanggil level sekali di _ready. Tiap ruangan: {"name": String,
	# "rect": Rect2i} dalam SEL (32 px). Kotak digambar apa adanya:
	# hanya ruangan, tanpa koridor dan tanpa props.
	_map_rooms = rooms
	if _map_area == null:
		return
	for c: Node in _map_area.get_children():
		if c != _map_dot_self and c != _map_dot_friend:
			c.queue_free()
	_map_scale = minf(MAP_AREA.x / MAP_WORLD.x, MAP_AREA.y / MAP_WORLD.y)
	for room: Dictionary in _map_rooms:
		var r: Rect2i = room["rect"]
		var box := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UiTheme.TRACK.r, UiTheme.TRACK.g, UiTheme.TRACK.b, 0.92)
		style.border_color = UiTheme.MUTED
		style.set_border_width_all(1)
		style.set_corner_radius_all(0)
		box.add_theme_stylebox_override("panel", style)
		box.position = Vector2(r.position.x * 32.0 * _map_scale, r.position.y * 32.0 * _map_scale)
		box.size = Vector2(r.size.x * 32.0 * _map_scale, r.size.y * 32.0 * _map_scale)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := UiTheme.mk_label(str(room["name"]), 12, UiTheme.INK, null, HORIZONTAL_ALIGNMENT_CENTER)
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
		_map_area.add_child(box)
	# Titik pemain harus di atas kotak ruangan.
	if _map_dot_self != null:
		_map_area.move_child(_map_dot_self, -1)
	if _map_dot_friend != null:
		_map_area.move_child(_map_dot_friend, -1)


func set_map_available(available: bool) -> void:
	# Dipanggil level tiap frame: true hanya saat pemain lokal berdiri
	# di ruang Gudang, level jalan, dan tidak ada minigame terbuka.
	_map_available = available


func is_map_open() -> bool:
	return _map_open


func open_map() -> void:
	if _map_open or not _map_available or _map_rooms.is_empty():
		return
	if _minigame_open():
		return
	_map_open = true
	if _map_dim != null:
		_map_dim.visible = true
	if _map_panel != null:
		_map_panel.visible = true
	_notify_map_open(true)


func close_map() -> void:
	if not _map_open:
		return
	_map_open = false
	if _map_dim != null:
		_map_dim.visible = false
	if _map_panel != null:
		_map_panel.visible = false
	_notify_map_open(false)


func toggle_map() -> void:
	if _map_open:
		close_map()
	else:
		open_map()


func _notify_map_open(open: bool) -> void:
	# Level membekukan gerak + interaksi pemain lokal saat peta
	# terbuka (seperti saat minigame terbuka).
	var lv: Node = _level()
	if lv != null and lv.has_method("set_local_map_open"):
		lv.set_local_map_open(open)


func _update_map_dots() -> void:
	var lv: Node = _level()
	if lv == null or not lv.has_method("get_map_players") or _map_scale <= 0.0:
		if _map_dot_self != null:
			_map_dot_self.visible = false
		if _map_dot_friend != null:
			_map_dot_friend.visible = false
		return
	var saw_self: bool = false
	var saw_friend: bool = false
	for row: Dictionary in lv.get_map_players():
		var mp: Vector2 = Vector2(row["pos"]) * _map_scale - Vector2(6, 6)
		if bool(row["local"]):
			_map_dot_self.position = mp
			_map_dot_self.visible = true
			saw_self = true
		elif not saw_friend:
			_map_dot_friend.position = mp
			_map_dot_friend.visible = true
			saw_friend = true
	if not saw_self and _map_dot_self != null:
		_map_dot_self.visible = false
	if not saw_friend and _map_dot_friend != null:
		_map_dot_friend.visible = false


func set_task_total(total: int) -> void:
	_task_total = total


func update_tasks(done: int, total: int, exit_open: bool) -> void:
	if _tasks_label == null:
		return
	var extra: String = " | PINTU TERBUKA!" if exit_open else ""
	_tasks_label.text = "Tugas: %d/%d%s" % [done, total, extra]
	_tasks_label.add_theme_color_override("font_color", UiTheme.AMBER if exit_open else UiTheme.INK)


func update_timer(time_sec: float) -> void:
	if _timer_label == null:
		return
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	_timer_label.text = "Waktu: %02d:%02d" % [m, s]


# Dipakai Level 2: jam game ("21.00") dan teks laporan sudah diformat
# oleh level, jadi HUD hanya menampilkan string-nya apa adanya.
func set_timer_text(text: String) -> void:
	if _timer_label != null:
		_timer_label.text = text


func set_tasks_text(text: String) -> void:
	if _tasks_label != null:
		_tasks_label.text = text


func update_status(lines: Array[String]) -> void:
	if _status_label == null:
		return
	_status_label.text = "\n".join(lines)


func show_prompt(text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = text

func set_stamina(ratio: float) -> void:
	if _stamina_bar == null:
		return
	_stamina_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	if _stamina_fill != null:
		_stamina_fill.bg_color = UiTheme.RED if ratio < 0.25 else UiTheme.GREEN


func _build_stamina_bar() -> void:
	var label := _mk_label("STAMINA", 12, UiTheme.MUTED, Vector2.ZERO)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_right = 80
	label.offset_top = -56
	label.offset_bottom = -36
	add_child(label)
	_stamina_fill = UiTheme.bar_fill_style(UiTheme.GREEN)
	var bg := UiTheme.bar_bg_style()
	_stamina_bar = ProgressBar.new()
	_stamina_bar.min_value = 0.0
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.show_percentage = false
	_stamina_bar.add_theme_stylebox_override("background", bg)
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	_stamina_bar.anchor_top = 1.0
	_stamina_bar.anchor_bottom = 1.0
	_stamina_bar.offset_left = 84
	_stamina_bar.offset_right = 284
	_stamina_bar.offset_top = -54
	_stamina_bar.offset_bottom = -34
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bar)

func show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_timer = 3.5


func flash_blackout() -> void:
	_flash_alpha = 0.6


func _build_enemy_alert() -> void:
	# Empat glow gradien di tepi layar (atas/bawah/kiri/kanan). Strip
	# kiri/kanan dijepit di antara strip atas/bawah supaya sudut tidak
	# bertumpuk dua kali lebih terang.
	_alert_top = _mk_alert_glow(0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, ALERT_THICKNESS, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	_alert_bottom = _mk_alert_glow(0.0, 1.0, 1.0, 1.0, 0.0, -ALERT_THICKNESS, 0.0, 0.0, Vector2(0.5, 1.0), Vector2(0.5, 0.0))
	_alert_left = _mk_alert_glow(0.0, 0.0, 0.0, 1.0, 0.0, ALERT_THICKNESS, ALERT_THICKNESS, -ALERT_THICKNESS, Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	_alert_right = _mk_alert_glow(1.0, 0.0, 1.0, 1.0, -ALERT_THICKNESS, ALERT_THICKNESS, 0.0, -ALERT_THICKNESS, Vector2(1.0, 0.5), Vector2(0.0, 0.5))


func _mk_alert_glow(al: float, at: float, ar: float, ab: float, off_left: float, off_top: float, off_right: float, off_bottom: float, grad_from: Vector2, grad_to: Vector2) -> TextureRect:
	# Gradien linear: merah pekat di tepi luar layar, memudar sampai
	# transparan di tepi dalam — glow lembut, bukan kotak keras.
	var grad := Gradient.new()
	grad.set_color(0, Color(ALERT_COLOR.r, ALERT_COLOR.g, ALERT_COLOR.b, 0.9))
	grad.set_color(1, Color(ALERT_COLOR.r, ALERT_COLOR.g, ALERT_COLOR.b, 0.0))
	grad.add_point(0.45, Color(ALERT_COLOR.r, ALERT_COLOR.g, ALERT_COLOR.b, 0.3))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = grad_from
	tex.fill_to = grad_to
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.anchor_left = al
	r.anchor_top = at
	r.anchor_right = ar
	r.anchor_bottom = ab
	r.offset_left = off_left
	r.offset_right = off_right
	r.offset_top = off_top
	r.offset_bottom = off_bottom
	r.modulate = Color(1, 1, 1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _update_enemy_alert(delta: float) -> void:
	_alert_time += delta
	var a_top: float = 0.0
	var a_bottom: float = 0.0
	var a_left: float = 0.0
	var a_right: float = 0.0
	var lv: Node = _level()
	var running: bool = lv != null and lv.has_method("is_level_running") and bool(lv.is_level_running())
	var enemy: Node = get_tree().get_first_node_in_group("Enemy")
	var p: Node = null
	if lv != null and lv.has_method("get_local_player"):
		p = lv.get_local_player()
	if running and enemy != null and p != null and not bool(p.get("is_downed")):
		# Musuh hanya berbahaya saat PATROL/CHASE/SEARCH; saat BLIND /
		# VANISH / STUNNED ia tidak bisa menangkap (_check_catch di
		# enemy.gd langsung return), jadi alert dimatikan.
		var st: int = int(enemy.get("state")) if enemy.get("state") != null else 0
		if st == 0 or st == 1 or st == 2:
			var d: Vector2 = (enemy as Node2D).global_position - (p as Node2D).global_position
			var dist: float = d.length()
			if dist < ALERT_RANGE and dist > 1.0:
				var t: float = 1.0 - dist / ALERT_RANGE
				var ax: float = absf(d.x)
				var ay: float = absf(d.y)
				var s: float = ax + ay
				if s > 0.0:
					var w: float = t * ALERT_MAX_ALPHA
					if d.x > 0.0:
						a_right = w * ax / s
					elif d.x < 0.0:
						a_left = w * ax / s
					if d.y > 0.0:
						a_bottom = w * ay / s
					elif d.y < 0.0:
						a_top = w * ay / s
					if st == 1:  # CHASE: berdenyut supaya terasa genting
						var pulse: float = 0.85 + 0.15 * sin(_alert_time * 6.0)
						a_top *= pulse
						a_bottom *= pulse
						a_left *= pulse
						a_right *= pulse
	_set_alert_alpha(_alert_top, a_top)
	_set_alert_alpha(_alert_bottom, a_bottom)
	_set_alert_alpha(_alert_left, a_left)
	_set_alert_alpha(_alert_right, a_right)


func _set_alert_alpha(rect: TextureRect, alpha: float) -> void:
	if rect == null:
		return
	# Intensitas (0..ALERT_MAX_ALPHA) dipetakan ke modulate (0..1);
	# alpha gradien di dalam tekstur yang mengatur jatuhnya cahaya.
	rect.modulate = Color(1, 1, 1, clampf(alpha / ALERT_MAX_ALPHA, 0.0, 1.0))


func show_result(success: bool, stars: int, ending: String, time_sec: float, deaths: int, done: int, total: int) -> void:
	if _result_panel == null:
		return
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	var title_color: Color = UiTheme.GREEN if success and ending == "Happy Ending" else (UiTheme.AMBER if success else UiTheme.RED)
	_result_title.text = (ending if success else "GAGAL: KEDUA PEMAIN TERTANGKAP").to_upper()
	_result_title.add_theme_color_override("font_color", title_color)
	_stat_time.text = "%02d:%02d" % [m, s]
	_stat_deaths.text = str(deaths)
	_stat_tasks.text = "%d/%d" % [done, total]
	for i in range(3):
		_set_star_box(_result_star_boxes[i], i < stars)
	_result_star_count.text = "%d/3" % stars
	_result_dim.visible = true
	_result_panel.visible = true


func show_disconnect(text: String) -> void:
	if _disconnect_panel == null:
		return
	_disconnect_label.text = text
	_disconnect_panel.visible = true


func hide_disconnect() -> void:
	# Dipanggil saat partner yang sempat terputus bergabung lagi,
	# supaya pesan "Partner terputus" hilang bersamaan dengan
	# game yang dilanjutkan (lihat _on_peer_joined di level_1.gd).
	if _disconnect_panel == null:
		return
	_disconnect_panel.visible = false


func _build_guide() -> void:
	# Dropdown kanan BAWAH, di atas tepi bawah layar. Tertutup secara
	# default; dibuka dengan TAB atau klik header. Tinggi panel mengikuti
	# isi lewat _fit_guide_panel (offset_bottom tetap, offset_top yang
	# bergerak) supaya panel tumbuh ke ATAS saat dibuka.
	_guide_panel = PanelContainer.new()
	_guide_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_guide_panel.anchor_left = 1.0
	_guide_panel.anchor_right = 1.0
	_guide_panel.anchor_top = 1.0
	_guide_panel.anchor_bottom = 1.0
	_guide_panel.offset_left = -380
	_guide_panel.offset_right = -14
	_guide_panel.offset_top = -70
	_guide_panel.offset_bottom = -14
	add_child(_guide_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_guide_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	_guide_header = Button.new()
	_guide_header.text = "PANDUAN [TAB]"
	_guide_header.custom_minimum_size = Vector2(340, 30)
	_guide_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiTheme.style_button(_guide_header)
	_guide_header.pressed.connect(_on_guide_header_pressed)
	vbox.add_child(_guide_header)
	_guide_body = VBoxContainer.new()
	_guide_body.add_theme_constant_override("separation", 6)
	_guide_body.visible = false
	vbox.add_child(_guide_body)
	set_guide_lines(GUIDE_LINES_L1)
	_fit_guide_panel()


func _fit_guide_panel() -> void:
	# Tinggi panel mengikuti isi (header saja saat tertutup, + isi saat
	# terbuka) supaya teks tidak keluar dari kotak panel. Panel menempel
	# di kanan bawah: offset_bottom tetap, offset_top yang bergerak,
	# jadi panel tumbuh ke atas saat dibuka.
	if _guide_panel == null:
		return
	var h: float = _guide_panel.get_combined_minimum_size().y
	_guide_panel.offset_top = _guide_panel.offset_bottom - h


func _on_guide_header_pressed() -> void:
	toggle_guide()


func _build_map() -> void:
	# Panel peta: layar gelap + panel tengah berisi kotak ruangan.
	# Dibangun di sini (kode) supaya tidak ada file .tscn yang berubah.
	_map_dim = ColorRect.new()
	_map_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_dim.color = UiTheme.DIM
	_map_dim.visible = false
	add_child(_map_dim)
	_map_panel = CenterContainer.new()
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.visible = false
	add_child(_map_panel)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_map_panel.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := UiTheme.mk_title("Peta Kantor", 28, UiTheme.INK)
	vbox.add_child(title)
	var sub := UiTheme.mk_label("Denah ruangan - hanya bisa dibuka di ruang Gudang", 13, UiTheme.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(sub)
	_map_area = Control.new()
	_map_area.custom_minimum_size = MAP_AREA
	_map_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_map_area)
	_map_dot_self = ColorRect.new()
	_map_dot_self.color = UiTheme.GREEN
	_map_dot_self.size = Vector2(12, 12)
	_map_dot_self.visible = false
	_map_dot_self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_area.add_child(_map_dot_self)
	_map_dot_friend = ColorRect.new()
	_map_dot_friend.color = UiTheme.AMBER
	_map_dot_friend.size = Vector2(12, 12)
	_map_dot_friend.visible = false
	_map_dot_friend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_area.add_child(_map_dot_friend)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 6)
	vbox.add_child(legend)
	var dot_self := ColorRect.new()
	dot_self.color = UiTheme.GREEN
	dot_self.custom_minimum_size = Vector2(10, 10)
	dot_self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(dot_self)
	legend.add_child(UiTheme.mk_label("Kamu", 13, UiTheme.INK))
	var dot_friend := ColorRect.new()
	dot_friend.color = UiTheme.AMBER
	dot_friend.custom_minimum_size = Vector2(10, 10)
	dot_friend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(dot_friend)
	legend.add_child(UiTheme.mk_label("Teman", 13, UiTheme.INK))
	var hint := UiTheme.mk_label("M / ESC - Tutup peta", 13, UiTheme.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(hint)


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.position = Vector2(10, 10)
	panel.size = Vector2(320, 62)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	_tasks_label = _mk_label("Tugas: 0/0", 16, UiTheme.INK, Vector2.ZERO)
	vbox.add_child(_tasks_label)
	_timer_label = _mk_label("Waktu: 00:00", 16, UiTheme.AMBER, Vector2.ZERO)
	vbox.add_child(_timer_label)
	_status_label = _mk_label("", 14, UiTheme.INK, Vector2.ZERO)
	_status_label.anchor_left = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = -320
	_status_label.offset_right = -14
	_status_label.offset_top = 12
	_status_label.offset_bottom = 60
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status_label)
	var hint := _mk_label("WASD/Panah: Gerak  |  Shift: Lari (berisik!)  |  E: Interaksi  |  Esc: Batalkan tugas  |  TAB: Panduan", 12, UiTheme.MUTED, Vector2.ZERO)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 12
	hint.offset_right = 880
	hint.offset_top = -26
	hint.offset_bottom = -6
	add_child(hint)


func _build_prompt_and_message() -> void:
	var prompt_panel := PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_left = -320
	prompt_panel.offset_right = 320
	prompt_panel.offset_top = -58
	prompt_panel.offset_bottom = -30
	add_child(prompt_panel)
	var prompt_center := CenterContainer.new()
	prompt_panel.add_child(prompt_center)
	_prompt_label = _mk_label("", 16, UiTheme.INK, Vector2.ZERO)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_center.add_child(_prompt_label)
	_message_label = _mk_label("", 17, UiTheme.AMBER, Vector2.ZERO)
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.offset_left = -400
	_message_label.offset_right = 400
	_message_label.offset_top = 78
	_message_label.offset_bottom = 104
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)


func _build_result_panel() -> void:
	_result_dim = ColorRect.new()
	_result_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_dim.color = UiTheme.DIM
	_result_dim.visible = false
	_result_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_result_dim)
	_result_panel = CenterContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	add_child(_result_panel)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.custom_minimum_size = Vector2(640, 0)
	_result_panel.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)
	_result_title = UiTheme.mk_title("", 40, UiTheme.INK)
	vbox.add_child(_result_title)
	vbox.add_child(_spacer(14))
	vbox.add_child(UiTheme.hairline())
	vbox.add_child(_spacer(12))
	_result_stats = VBoxContainer.new()
	_result_stats.add_theme_constant_override("separation", 8)
	vbox.add_child(_result_stats)
	_stat_time = _stat_row("WAKTU")
	_stat_deaths = _stat_row("TERTANGKAP")
	_stat_tasks = _stat_row("TUGAS")
	vbox.add_child(_spacer(12))
	vbox.add_child(UiTheme.hairline())
	vbox.add_child(_spacer(12))
	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 10)
	vbox.add_child(rate_row)
	var rate_label := UiTheme.mk_label("PENILAIAN", 14, UiTheme.MUTED)
	rate_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_row.add_child(rate_label)
	_result_star_boxes.clear()
	for i in range(3):
		var star := UiTheme.StarIcon.new()
		star.custom_minimum_size = Vector2(20, 20)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rate_row.add_child(star)
		_result_star_boxes.append(star)
	_result_star_count = UiTheme.mk_label("0/3", 16, UiTheme.INK)
	_result_star_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_row.add_child(_result_star_count)
	vbox.add_child(_spacer(22))
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)
	var retry := Button.new()
	retry.text = "MAIN LAGI"
	retry.custom_minimum_size = Vector2(160, 44)
	UiTheme.style_button(retry)
	retry.pressed.connect(_on_retry_pressed)
	hbox.add_child(retry)
	var menu := Button.new()
	menu.text = "MENU UTAMA"
	menu.custom_minimum_size = Vector2(160, 44)
	UiTheme.style_button(menu)
	menu.pressed.connect(_on_menu_pressed)
	hbox.add_child(menu)


func _build_disconnect_panel() -> void:
	_disconnect_panel = CenterContainer.new()
	_disconnect_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_disconnect_panel.visible = false
	add_child(_disconnect_panel)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.custom_minimum_size = Vector2(480, 0)
	_disconnect_panel.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	_disconnect_label = UiTheme.mk_label("", 16, UiTheme.INK, null, HORIZONTAL_ALIGNMENT_CENTER)
	_disconnect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_disconnect_label)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	var menu := Button.new()
	menu.text = "MENU UTAMA"
	menu.custom_minimum_size = Vector2(160, 44)
	UiTheme.style_button(menu)
	menu.pressed.connect(_on_menu_pressed)
	hbox.add_child(menu)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _stat_row(label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := UiTheme.mk_label(label_text, 14, UiTheme.MUTED)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	var val := UiTheme.mk_label("", 16, UiTheme.INK, null, HORIZONTAL_ALIGNMENT_RIGHT)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	_result_stats.add_child(row)
	return val


func _set_star_box(box: UiTheme.StarIcon, filled: bool) -> void:
	box.filled = filled


func _mk_label(text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	# Label HUD: mono sistem. Outline tipis dipertahankan karena label
	# duduk langsung di atas scene game, bukan di dalam panel.
	var l := UiTheme.mk_label(text, font_size, color)
	l.position = pos
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _level() -> Node:
	return get_tree().get_first_node_in_group("LevelManager")


func _on_retry_pressed() -> void:
	var lv: Node = _level()
	if lv != null:
		lv.request_restart()


func _on_menu_pressed() -> void:
	var lv: Node = _level()
	if lv != null:
		lv.request_menu()
	else:
		NetworkManager.disconnect_all()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
