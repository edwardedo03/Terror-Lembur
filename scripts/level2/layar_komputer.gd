class_name LayarKomputer
extends CanvasLayer
## Layar komputer security (operator) — Level 2. Berjalan LOKAL di PC pemain
## yang sedang duduk di komputer. Menampilkan denah lobi satu layar penuh:
## posisi teman (kalau baterai HP-nya > 0%), laporan gangguan + batas
## waktunya, status titik cas, titik kabel, jam & fase. Satpam dan Bos
## TIDAK ditampilkan. Saat komputer error, denah mati dan hanya muncul
## pesan kabel mana yang putus. Tutup dengan E atau Esc.
## Nama ruangan di denah baru muncul setelah ruangan itu didatangi pemain
## SATUNYA (bukan yang sedang duduk di komputer). Mode solo: pemain sendiri.

var level: Node = null
var font_mono: Font = null  # diisi level_2.gd (huruf mesin ketik)
var font_mono_tebal: Font = null

var _peta: Control = null  # instance kelas _Peta (di bawah)
var _terbuka: bool = false


func _ready() -> void:
	layer = 9
	_peta = _Peta.new()
	_peta.layar = self
	_peta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_peta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peta.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_peta)
	visible = false


func is_terbuka() -> bool:
	return _terbuka


func buka() -> void:
	if _terbuka or level == null:
		return
	if _peta.tex_denah == null:
		_peta.siapkan_denah(level)
	_terbuka = true
	visible = true
	level.set_local_minigame_open(true)


func tutup() -> void:
	if not _terbuka:
		return
	_terbuka = false
	visible = false
	if level != null:
		# Jeda sebentar supaya tombol E yang dipakai menutup layar tidak
		# langsung terbaca lagi sebagai "interaksi" oleh pemain.
		var lv: Node = level
		get_tree().create_timer(0.2).timeout.connect(func() -> void: lv.set_local_minigame_open(false))


func _input(event: InputEvent) -> void:
	if not _terbuka:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("interact"):
			tutup()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _terbuka:
		return
	var p: Node = level.get_local_player() if level != null else null
	if p == null or p.is_downed or not level.is_level_running():
		tutup()
		return
	_peta.queue_redraw()


# ------------------------------------------------------------------ gambar
class _Peta extends Control:

	const SEL_MAKS: float = 12.0
	const LOG_HOROR: Array[String] = [
		"> log 21:04  sinyal WiFi: 2 HP karyawan terdeteksi",
		"> log 22:47  petugas jaga malam: TIDAK TERDAFTAR sejak 2019",
		"> log 00:13  HT channel 3 aktif... tidak ada yang menjawab",
		"> log 02:02  pintu lift terbuka di lantai L (tidak ada penumpang)",
		"> log 03:58  kartu akses 'P. SUTARNO (alm.)' dipakai di R. Security",
	]

	var layar: Node = null
	var tex_denah: ImageTexture = null
	var ukuran_map: Vector2i = Vector2i(72, 46)
	var _waktu: float = 0.0

	func siapkan_denah(lv: Node) -> void:
		ukuran_map = lv.get_map_size_tiles()
		var img := Image.create_empty(ukuran_map.x, ukuran_map.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var lantai: TileMapLayer = lv.floor_layer
		var dinding: TileMapLayer = lv.walls_layer
		var props: TileMapLayer = lv.props_layer
		for y: int in range(ukuran_map.y):
			for x: int in range(ukuran_map.x):
				var c := Vector2i(x, y)
				if dinding != null and dinding.get_cell_source_id(c) != -1:
					img.set_pixel(x, y, Color(0.42, 0.78, 0.86))
				elif props != null and props.get_cell_source_id(c) != -1:
					img.set_pixel(x, y, Color(0.1, 0.27, 0.3))
				elif lantai != null and lantai.get_cell_source_id(c) != -1:
					img.set_pixel(x, y, Color(0.04, 0.13, 0.16))
		tex_denah = ImageTexture.create_from_image(img)

	func _process(delta: float) -> void:
		_waktu += delta

	func _draw() -> void:
		var lv: Node = layar.level if layar != null else null
		if lv == null:
			return
		var font: Font = ThemeDB.fallback_font
		if layar.font_mono_tebal != null:
			font = layar.font_mono_tebal
		var vp: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.016, 0.03, 0.03, 0.98))
		# --- header
		var jam: String = lv.get_teks_jam()
		var fase: String = lv.get_nama_fase()
		draw_string(font, Vector2(30, 40), "SECURA  ·  MONITOR KEAMANAN — LOBI", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.78, 0.91, 0.77))
		draw_string(font, Vector2(vp.x - 370, 40), "%s   FASE %s" % [jam, fase.to_upper()], HORIZONTAL_ALIGNMENT_RIGHT, 336, 19, Color(1.0, 0.69, 0.27))
		var err: String = lv.get_teks_error()
		if err != "":
			# Error: denah mati.
			var kedip: float = 0.6 + 0.4 * absf(sin(_waktu * 4.0))
			draw_string(font, Vector2(0, vp.y * 0.45), "KONEKSI TERPUTUS", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 40, Color(1, 0.3, 0.25, kedip))
			draw_string(font, Vector2(0, vp.y * 0.45 + 44), err, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, Color(1, 0.85, 0.8))
			draw_string(font, Vector2(0, vp.y * 0.45 + 74), "Jam berhenti sampai kabel disambung lagi.", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 15, Color(1, 1, 1, 0.7))
			draw_string(font, Vector2(30, vp.y - 26), "[E] / [Esc] Berdiri dari komputer", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.45, 0.56, 0.44))
			_bingkai(vp)
			return
		# --- denah
		var area := Rect2(Vector2(30, 62), Vector2(vp.x - 310, vp.y - 132))
		var sel: float = minf(SEL_MAKS, minf(area.size.x / ukuran_map.x, area.size.y / ukuran_map.y))
		var asal: Vector2 = area.position + (area.size - Vector2(ukuran_map) * sel) * 0.5
		var skala: float = sel / 32.0
		if tex_denah != null:
			draw_texture_rect(tex_denah, Rect2(asal, Vector2(ukuran_map) * sel), false)
		# nama ruangan: muncul kalau ruangan itu sudah didatangi pemain satunya
		for r: Dictionary in lv.get_info_ruangan():
			var k: Rect2i = r["kotak"]
			var pos: Vector2 = asal + (Vector2(k.position) + Vector2(k.size) * 0.5) * sel
			if bool(r["nama_ok"]):
				draw_string(font, pos + Vector2(-70, 4), str(r["nama"]), HORIZONTAL_ALIGNMENT_CENTER, 140, 10, Color(0.6, 0.85, 0.9, 0.8))
			else:
				draw_string(font, pos + Vector2(-20, 4), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(0.6, 0.85, 0.9, 0.3))
		var kedip_cepat: bool = fmod(_waktu, 0.6) < 0.4
		# komputer (lokasi operator)
		var kp: Vector2 = lv.get_posisi_komputer()
		draw_rect(Rect2(asal + kp * skala - Vector2(5, 5), Vector2(10, 10)), Color(0.75, 0.5, 1.0))
		draw_string(font, asal + kp * skala + Vector2(8, 4), "KAMU", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.7, 1))
		# titik cas
		for c: Dictionary in lv.get_info_titik_cas():
			var pc: Vector2 = c["pos"]
			var p: Vector2 = asal + pc * skala
			var w: Color = Color(0.35, 1, 0.45)
			var teks: String = ""
			match int(c["status"]):
				1:
					w = Color(1, 0.85, 0.25)
					teks = "dipakai"
				2:
					w = Color(1, 0.3, 0.25)
					teks = "korslet %ds" % int(c["sisa"])
				3:
					w = Color(0.4, 0.4, 0.4)
					teks = "mati"
			draw_circle(p, 4.5, w)
			draw_string(font, p + Vector2(-20, -7), "CAS", HORIZONTAL_ALIGNMENT_CENTER, 40, 9, w)
			if teks != "":
				draw_string(font, p + Vector2(-40, 15), teks, HORIZONTAL_ALIGNMENT_CENTER, 80, 9, w)
		# titik kabel
		for k: Dictionary in lv.get_info_titik_kabel():
			var pk: Vector2 = k["pos"]
			var p: Vector2 = asal + pk * skala
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.55, 0.55, 0.6))
		# laporan gangguan
		for t: Dictionary in lv.get_info_laporan():
			var pt: Vector2 = t["pos"]
			var p: Vector2 = asal + pt * skala
			if bool(t["selesai"]):
				draw_string(font, p + Vector2(-6, 4), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 1, 0.5))
				continue
			var w: Color = Color(1, 0.35, 0.3) if bool(t["terlambat"]) else Color(1, 0.85, 0.2)
			if kedip_cepat or bool(t["terlambat"]):
				draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), w, false, 2.0)
			draw_string(font, p + Vector2(9, -2), str(t["judul"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, w)
			draw_string(font, p + Vector2(9, 10), str(t["keterangan"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, w)
		# teman (hanya kalau HP-nya menyala)
		var y_info: float = 80.0
		var x_info: float = vp.x - 260.0
		draw_string(font, Vector2(x_info, y_info), "SINYAL HP KARYAWAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.85, 0.95))
		y_info += 22.0
		var ada_teman: bool = false
		for info: Dictionary in lv.get_info_teman():
			ada_teman = true
			var nama: String = str(info["nama"])
			if bool(info["terlihat"]):
				var pi: Vector2 = info["pos"]
				var p: Vector2 = asal + pi * skala
				draw_circle(p, 5.0, Color(0.3, 1, 0.5))
				draw_arc(p, 9.0 + 3.0 * sin(_waktu * 5.0), 0.0, TAU, 20, Color(0.3, 1, 0.5, 0.6), 1.5)
				draw_string(font, p + Vector2(8, -6), nama, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 1, 0.7))
			draw_string(font, Vector2(x_info, y_info), "%s: %s" % [nama, str(info["status"])], HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color(0.85, 0.95, 1))
			y_info += 18.0
		if not ada_teman:
			draw_string(font, Vector2(x_info, y_info), "(mode uji solo: tidak ada teman)", HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color(1, 1, 1, 0.6))
			y_info += 18.0
		# daftar laporan
		y_info += 14.0
		draw_string(font, Vector2(x_info, y_info), "LAPORAN GANGGUAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.85, 0.95))
		y_info += 20.0
		var ada_laporan: bool = false
		for t: Dictionary in lv.get_info_laporan():
			ada_laporan = true
			var w: Color = Color(0.45, 1, 0.5) if bool(t["selesai"]) else (Color(1, 0.4, 0.35) if bool(t["terlambat"]) else Color(1, 0.9, 0.5))
			draw_string(font, Vector2(x_info, y_info), "%s %s" % [str(t["jam"]), str(t["judul"])], HORIZONTAL_ALIGNMENT_LEFT, 250, 11, w)
			y_info += 15.0
			draw_string(font, Vector2(x_info + 12, y_info), "%s — %s" % [str(t["area"]), str(t["keterangan"])], HORIZONTAL_ALIGNMENT_LEFT, 240, 10, Color(w, 0.75))
			y_info += 18.0
		if not ada_laporan:
			draw_string(font, Vector2(x_info, y_info), "Belum ada laporan.", HORIZONTAL_ALIGNMENT_LEFT, 250, 11, Color(1, 1, 1, 0.6))
		# --- footer
		var idx: int = clampi(int(lv.get_jam_menit() / 100.0), 0, LOG_HOROR.size() - 1)
		draw_string(font, Vector2(30, vp.y - 46), LOG_HOROR[idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1, 0.5, 0.7))
		draw_string(font, Vector2(30, vp.y - 26), "[E] / [Esc] Berdiri dari komputer   |   Satpam tidak terlihat di layar ini", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.56, 0.44))
		_bingkai(vp)

	func _bingkai(vp: Vector2) -> void:
		# Garis scanline tipis + bingkai monitor di tepi layar.
		var y: float = 0.0
		while y < vp.y:
			draw_line(Vector2(0, y), Vector2(vp.x, y), Color(0, 0, 0, 0.14), 1.0)
			y += 3.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(0.18, 0.18, 0.2)
		sb.set_border_width_all(14)
		sb.set_corner_radius_all(26)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2(-4, -4), vp + Vector2(8, 8)))
