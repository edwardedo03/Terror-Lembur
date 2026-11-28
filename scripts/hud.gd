extends CanvasLayer
## HUD Level 1 — dibangun dari kode supaya mudah diubah tanpa mengotak-atik
## file .tscn. Menampilkan tugas, waktu, status pemain, prompt interaksi,
## pesan tengah layar, panel hasil (ending + penilaian), dan panel putus koneksi.
## Gaya visual: UiTheme (kantor lembur: gelap hangat, garis rambut, mono,
## satu aksen amber).
##
## Penyesuaian supaya mirip HUD Level 2 (lihat scripts/hud_kantor.gd):
## bar Tugas/Waktu, status, bar STAMINA, panduan, dan kotak prompt lama
## diganti ID card, papan tugas dropdown (Tab), label Dymo, bar energi di
## atas kepala, dan busur hijau Item Bangkit. Peta Gudang kini bergaya
## denah evakuasi. Fungsi lama (update_tasks, set_stamina, dst.) tetap ada
## supaya level_1.gd tidak perlu diubah banyak; isinya diabaikan kalau
## elemen lamanya tidak dibangun.

const HUD_KANTOR := preload("res://scripts/hud_kantor.gd")

var _tasks_label: Label = null
var _timer_label: Label = null
var _status_label: Label = null
var _prompt_label: Label = null
var _pesan: GayaMenu.PesanTerminal = null  # pesan atas tengah bergaya terminal
var _pesan_ketik: float = 0.0  # jumlah huruf yang sudah "diketik" (pecahan)
var _flash_rect: ColorRect = null
var _hasil: PanelHasil = null  # panel hasil akhir (scripts/panel_hasil.gd)
var _putus: PanelPutus = null  # panel koneksi putus (scripts/panel_putus.gd)
var _message_timer: float = 0.0
var _flash_alpha: float = 0.0
var _task_total: int = 0
const PESAN_LAMA: float = 3.5  # detik pesan tampil
const PESAN_PUDAR: float = 0.5  # detik memudar di ujung
const PESAN_KETIK_PER_DETIK: float = 70.0
const MERAH_PESAN := Color(0.886, 0.333, 0.247)  # #E2553F, sama dengan mockup
const KATA_BAHAYA: Array[String] = ["padam", "sosok", "musuh", "berisik", "tertangkap", "terkunci", "perangkap", "mendekat"]
var _kantor: CanvasLayer = null  # HUD gaya Level 2 (scripts/hud_kantor.gd)
var _prompt_teks: String = ""  # teks arahan untuk label Dymo
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
var _map_panel: Control = null  # DenahKertas (hud_kantor.gd)
var _map_area: Control = null
var _map_rooms: Array = []
var _map_available: bool = false
var _map_open: bool = false
var _map_scale: float = 0.0
var _map_dot_self: ColorRect = null
var _map_dot_friend: ColorRect = null


func _ready() -> void:
	layer = 10
	# HUD gaya Level 2: ID card, papan tugas, label Dymo, bar energi, busur
	# Item Bangkit. (Dulu: _build_top_bar, _build_stamina_bar, _build_guide.)
	_kantor = HUD_KANTOR.new()
	_kantor.name = "HudKantor"
	_kantor.hud = self
	add_child(_kantor)
	_build_prompt_and_message()
	_build_result_panel()
	_build_disconnect_panel()
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0, 0, 0, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	_build_enemy_alert()
	_build_map()
	# Panel hasil (layer 25) dan panel koneksi putus (layer 26) punya
	# CanvasLayer sendiri, jadi selalu di atas elemen HUD lain.


func _process(delta: float) -> void:
	_update_pesan(delta)
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 0.8)
		_flash_rect.color = Color(0, 0, 0, _flash_alpha)
	_update_enemy_alert(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	# TAB = papan tugas (+ panduan), M = peta (hanya kalau tersedia),
	# ESC = tutup peta.
	# Saat minigame terbuka semua tombol ini dimatikan: minigame punya
	# input sendiri (termasuk ESC untuk batal), dan panduan/peta tidak
	# boleh menumpuk di atasnya.
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _minigame_open():
		return
	if k.keycode == KEY_TAB:
		if _kantor != null:
			_kantor.toggle_papan()
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
	if _map_panel != null:
		_map_panel.set("rooms", rooms)
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
		if _map_panel.has_method("mulai"):
			_map_panel.mulai()
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
	# Teks arahan sekarang tampil sebagai label Dymo (hud_kantor.gd).
	_prompt_teks = text
	if _prompt_label != null:
		_prompt_label.text = text


func get_prompt() -> String:
	return _prompt_teks

func set_stamina(ratio: float) -> void:
	if _stamina_bar == null:
		return
	_stamina_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	if _stamina_fill != null:
		_stamina_fill.bg_color = UiTheme.RED if ratio < 0.25 else UiTheme.GREEN


## Pesan atas tengah (gaya baris terminal, sama dengan intro):
## teks diketik cepat, merah kalau berisi kata bahaya, amber kalau info
## biasa, lalu memudar setelah PESAN_LAMA detik.
func show_message(text: String) -> void:
	if _pesan == null:
		return
	_pesan.teks = _rapikan_pesan(text)
	_pesan.warna = MERAH_PESAN if _pesan_bahaya(text) else GayaMenu.AMBER
	_pesan_ketik = 0.0
	_pesan.huruf = 0
	_pesan.modulate.a = 1.0
	_message_timer = PESAN_LAMA


func _update_pesan(delta: float) -> void:
	if _pesan == null or _message_timer <= 0.0:
		return
	if not _pesan.selesai_mengetik():
		_pesan_ketik += delta * PESAN_KETIK_PER_DETIK
		_pesan.huruf = int(_pesan_ketik)
		if _pesan.selesai_mengetik():
			_pesan.huruf = -1
	_message_timer -= delta
	_pesan.modulate.a = clampf(_message_timer / PESAN_PUDAR, 0.0, 1.0)
	if _message_timer <= 0.0:
		_pesan.teks = ""


## Pesan bahaya (musuh, perangkap, lampu padam, tertangkap) tampil merah.
static func _pesan_bahaya(text: String) -> bool:
	var t: String = text.to_lower()
	for kata: String in KATA_BAHAYA:
		if t.contains(kata):
			return true
	return false


## Rapikan teks pesan lama untuk baris terminal: tanpa titik tiga, tanpa
## tanda pisah, tanpa titik penutup, huruf kapital semua.
static func _rapikan_pesan(text: String) -> String:
	var t: String = text.strip_edges()
	t = t.replace(" — ", ", ").replace("—", ", ")
	t = t.replace("... ", "  ").replace("...", "")
	if t.ends_with("."):
		t = t.substr(0, t.length() - 1)
	return t.to_upper()


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


func show_result(success: bool, stars: int, ending: String, time_sec: float, deaths: int, done: int, total: int, level_baru: String = "") -> void:
	# level_baru: id level yang baru terbuka karena level ini pertama kali
	# tamat ("level_2" saat Level 1 pertama tamat), "" kalau tidak ada.
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


## Dipanggil saat teman yang sempat terputus bergabung lagi (game lanjut).
func hide_disconnect() -> void:
	if _putus == null:
		return
	_putus.sembunyikan()


func _fit_guide_panel() -> void:
	# Tinggi panel mengikuti isi (header saja saat tertutup, + isi saat
	# terbuka) supaya teks tidak keluar dari kotak panel. Panel menempel
	# di kanan bawah: offset_bottom tetap, offset_top yang bergerak,
	# jadi panel tumbuh ke atas saat dibuka.
	if _guide_panel == null:
		return
	var h: float = _guide_panel.get_combined_minimum_size().y
	_guide_panel.offset_top = _guide_panel.offset_bottom - h


func _build_map() -> void:
	# Peta Gudang bergaya denah evakuasi (sama dengan denah Level 2),
	# digambar dari kode di hud_kantor.gd -> DenahKertas. Aturannya tetap:
	# semua ruangan terlihat, hanya bisa dibuka di Gudang, ada titik teman.
	var kertas := HUD_KANTOR.DenahKertas.new()
	kertas.name = "DenahKertas"
	kertas.font = HUD_KANTOR.F_MONO_TEBAL
	kertas.font_tipis = HUD_KANTOR.F_MONO
	kertas.set_anchors_preset(Control.PRESET_FULL_RECT)
	kertas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kertas.visible = false
	add_child(kertas)
	_map_panel = kertas


func _build_prompt_and_message() -> void:
	# Kotak prompt lama di bawah tengah diganti label Dymo (hud_kantor.gd);
	# yang dibangun di sini tinggal pesan atas tengah: baris terminal
	# "> TEKS" + kursor (GayaMenu.PesanTerminal), lebarnya mengikuti teks.
	_pesan = GayaMenu.PesanTerminal.new()
	_pesan.name = "PesanTerminal"
	_pesan.anchor_left = 0.5
	_pesan.anchor_right = 0.5
	_pesan.offset_left = -560
	_pesan.offset_right = 560
	_pesan.offset_top = 64
	_pesan.offset_bottom = 100
	_pesan.ukuran = 17
	add_child(_pesan)


func _build_result_panel() -> void:
	# Panel hasil sama untuk Level 1 dan Level 2 (scripts/panel_hasil.gd):
	# MAIN LAGI, PILIH LEVEL (host), MENU UTAMA, plus cap "LEVEL 2 TERBUKA".
	_hasil = PanelHasil.new()
	_hasil.name = "PanelHasil"
	_hasil.main_lagi.connect(_on_retry_pressed)
	_hasil.pilih_level.connect(_on_pilih_level_pressed)
	_hasil.menu_utama.connect(_on_menu_pressed)
	_hasil.atur_level("LEVEL 1  LANTAI KANTOR")
	add_child(_hasil)


func _build_disconnect_panel() -> void:
	# Panel koneksi putus sama untuk Level 1 dan Level 2 (scripts/panel_putus.gd).
	_putus = PanelPutus.new()
	_putus.name = "PanelPutus"
	_putus.menu_utama.connect(_on_menu_pressed)
	add_child(_putus)


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
