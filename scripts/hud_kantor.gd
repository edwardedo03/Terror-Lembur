extends CanvasLayer
## HUD "benda-benda kantor" untuk LEVEL 1 — gayanya disamakan dengan HUD
## Level 2 (scripts/level2/hud_malam.gd), tapi isinya khusus Level 1.
## Semua digambar dari KODE (tanpa file gambar).
##
## Dibuat oleh scripts/hud.gd (HUD Level 1). Isinya:
## - ID card P1/P2 (kiri atas): cap DIKURUNG / SEMBUNYI, tag kunci & item,
##   klip "BERDUA" saat sedang mengerjakan tugas 2 pemain bersama.
## - Papan tugas dropdown (kanan atas, Tab): daftar tugas + nama ruangan +
##   panduan singkat. Turun sendiri di awal level & saat ada tugas beres.
## - Label Dymo (bawah tengah): teks arahan "[E] ...".
## - Bar energi lari kecil di atas kepala pemain sendiri.
## - Busur hijau di sekitar pemain: arah Item Bangkit / kurungan teman.
## - DenahKertas: tampilan peta Gudang (dipakai hud.gd) gaya denah evakuasi.
##
## Data diambil dari level_1.gd lewat fungsi get_info_tugas(),
## get_info_pemain(), get_tujuan_bangkit(), get_level_time(),
## get_exit_open(), get_map_players(), get_local_player().

const F_MONO: Font = preload("res://assets/fonts/lmmono10-regular.otf")
const F_MONO_TEBAL: Font = preload("res://assets/fonts/lmmonolt10-bold.otf")

var hud: Node = null  # scripts/hud.gd (untuk teks arahan & status peta)
var f_mono: Font = F_MONO
var f_mono_tebal: Font = F_MONO_TEBAL

var _papan: Control = null


func _ready() -> void:
	# Di bawah HUD Level 1 (layer 10: alert musuh, peta, panel hasil) dan
	# di bawah minigame (layer 20).
	layer = 9
	_tambah(_KartuPemain.new(), "KartuPemain")
	_papan = _tambah(_PapanTugas.new(), "PapanTugas")
	_tambah(_LabelDymo.new(), "LabelDymo")
	_tambah(_PenandaBangkit.new(), "PenandaBangkit")
	_tambah(_BarEnergi.new(), "BarEnergi")


func _tambah(w: Control, nama: String) -> Control:
	w.name = nama
	w.set("kantor", self)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w)
	return w


# ------------------------------------------------------------ API untuk hud.gd
func toggle_papan() -> void:
	if _papan != null:
		_papan.toggle()


func is_papan_terbuka() -> bool:
	return _papan != null and _papan.is_terbuka()


func level() -> Node:
	return get_tree().get_first_node_in_group("LevelManager")


func teks_arahan() -> String:
	if hud != null and hud.has_method("get_prompt"):
		return str(hud.get_prompt())
	return ""


func peta_terbuka() -> bool:
	return hud != null and hud.has_method("is_map_open") and bool(hud.is_map_open())


# ======================================================== dasar widget
class _Widget extends Control:
	var kantor: Node = null

	func _process(_delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		queue_redraw()

	func _atur_posisi(_vp: Vector2) -> void:
		pass

	func lv() -> Node:
		return kantor.level() if kantor != null else null

	# Pemain di PC ini.
	func _pemain() -> Node:
		var l: Node = lv()
		return l.get_local_player() if l != null else null

	# true kalau peta / minigame sedang terbuka (penanda di sekitar pemain
	# tidak perlu tampil).
	func _ada_layar_penuh() -> bool:
		var l: Node = lv()
		if l != null and l.has_method("is_minigame_open") and bool(l.is_minigame_open()):
			return true
		return kantor != null and kantor.peta_terbuka()

	func kotak(r: Rect2, warna: Color, radius: float, tebal_garis: float = 0.0, warna_garis: Color = Color(0, 0, 0, 0)) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = warna
		sb.set_corner_radius_all(int(radius))
		if tebal_garis > 0.0:
			sb.set_border_width_all(int(tebal_garis))
			sb.border_color = warna_garis
		sb.anti_aliasing = true
		draw_style_box(sb, r)

	func teks(f: Font, pos: Vector2, s: String, ukuran: int, warna: Color) -> void:
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)

	func lebar_teks(f: Font, s: String, ukuran: int) -> float:
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x

	func teks_tengah(f: Font, pusat: Vector2, s: String, ukuran: int, warna: Color) -> void:
		var x: float = pusat.x - lebar_teks(f, s, ukuran) * 0.5
		draw_string(f, Vector2(x, pusat.y + f.get_ascent(ukuran) * 0.38), s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)

	func teks_kanan(f: Font, kanan: Vector2, s: String, ukuran: int, warna: Color) -> void:
		draw_string(f, Vector2(kanan.x - lebar_teks(f, s, ukuran), kanan.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)

	func pendekkan(f: Font, s: String, ukuran: int, lebar_maks: float) -> String:
		if lebar_teks(f, s, ukuran) <= lebar_maks:
			return s
		var t: String = s
		while t.length() > 1 and lebar_teks(f, t + "…", ukuran) > lebar_maks:
			t = t.substr(0, t.length() - 1)
		return t + "…"

	# Pecah kalimat jadi beberapa baris supaya muat selebar lebar_maks.
	func bungkus(f: Font, s: String, ukuran: int, lebar_maks: float) -> Array[String]:
		var hasil: Array[String] = []
		var baris: String = ""
		for kata: String in s.split(" ", false):
			var coba: String = kata if baris == "" else baris + " " + kata
			if baris != "" and lebar_teks(f, coba, ukuran) > lebar_maks:
				hasil.append(baris)
				baris = kata
			else:
				baris = coba
		if baris != "":
			hasil.append(baris)
		return hasil

	func goyang(titik: Array, warna: Color, tebal: float, benih: int) -> void:
		# Garis "tulisan tangan": tiap titik digeser sedikit (acak, tapi sama
		# tiap frame karena benihnya tetap).
		var rng := RandomNumberGenerator.new()
		rng.seed = benih
		var hasil := PackedVector2Array()
		for p: Vector2 in titik:
			hasil.append(p + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)))
		draw_polyline(hasil, warna, tebal, true)


# ================================================= papan tugas (dropdown)
class _PapanTugas extends _Widget:
	const LEBAR: float = 262.0
	const TINGGI_KEPALA: float = 34.0
	const TINGGI_BARIS: float = 31.0
	const KERTAS := Color(0.957, 0.827, 0.369)
	const KERTAS_GELAP := Color(0.84, 0.7, 0.27)
	const MERAH_PENA := Color(0.78, 0.16, 0.14)
	const BIRU_PENA := Color(0.14, 0.27, 0.59)
	const TINTA_COKLAT := Color(0.4, 0.31, 0.13)
	const DETIK_AWAL: float = 6.0  # papan turun sendiri di awal level
	const DETIK_BERES: float = 4.0  # ... dan sebentar tiap ada tugas beres
	const PANDUAN: Array[String] = [
		"Beresin semua tugas, lalu kabur berdua lewat Lobby.",
		"Tugas BERDUA: kerjakan bareng di alatnya; selama itu kalian aman dari musuh.",
		"Satu alihkan musuh, satu kerjakan tugas.",
		"Peta cuma bisa dibuka di Gudang (M).",
		"WASD gerak · Shift lari (berisik!) · E interaksi · Esc batal tugas · Tab papan ini",
	]

	var _t: float = 0.0  # 0 = tergulung, 1 = terbuka penuh (bisa sedikit lebih karena pegas)
	var _kec: float = 0.0
	var _dipin: bool = false  # dibuka pakai Tab
	var _turun_sendiri: float = DETIK_AWAL
	var _beres_lama: Dictionary = {}
	var _waktu: float = 0.0

	func _ready() -> void:
		size = Vector2(LEBAR, 520)

	func _atur_posisi(vp: Vector2) -> void:
		position = Vector2(vp.x - LEBAR - 16.0, 10.0)

	func toggle() -> void:
		_dipin = not _dipin
		if not _dipin:
			_turun_sendiri = 0.0

	func is_terbuka() -> bool:
		return _dipin or _turun_sendiri > 0.0

	func _process(delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		_waktu += delta
		var l: Node = lv()
		if l != null and l.has_method("get_info_tugas"):
			for t: Dictionary in l.get_info_tugas():
				var kunci: String = str(t["id"])
				var beres: bool = str(t["status"]) == "beres"
				if beres and _beres_lama.has(kunci) and not bool(_beres_lama[kunci]):
					_turun_sendiri = maxf(_turun_sendiri, DETIK_BERES)
				_beres_lama[kunci] = beres
		_turun_sendiri = maxf(0.0, _turun_sendiri - delta)
		# pegas teredam: sedikit memantul saat terbuka / tertutup
		var target: float = 1.0 if is_terbuka() else 0.0
		_kec += ((target - _t) * 120.0 - _kec * 14.0) * delta
		_t = clampf(_t + _kec * delta, -0.02, 1.08)
		queue_redraw()

	func _baris_panduan() -> Array[String]:
		var hasil: Array[String] = []
		for kalimat: String in PANDUAN:
			var pecah: Array[String] = bungkus(kantor.f_mono, "- " + kalimat, 9, LEBAR - 40.0)
			for i: int in range(pecah.size()):
				hasil.append(pecah[i] if i == 0 else "  " + pecah[i])
		return hasil

	func _draw() -> void:
		var l: Node = lv()
		if l == null or not l.has_method("get_info_tugas"):
			return
		var daftar: Array = l.get_info_tugas()
		var jumlah_beres: int = 0
		for t: Dictionary in daftar:
			if str(t["status"]) == "beres":
				jumlah_beres += 1
		var pintu: bool = bool(l.get_exit_open()) if l.has_method("get_exit_open") else false
		var panduan: Array[String] = _baris_panduan()
		var w: float = LEBAR
		var atas: float = TINGGI_KEPALA - 6.0
		var tinggi_daftar: float = 14.0 + daftar.size() * TINGGI_BARIS + (22.0 if pintu else 0.0)
		var tinggi_penuh: float = tinggi_daftar + 22.0 + panduan.size() * 12.0 + 16.0
		var tinggi: float = maxf(0.0, tinggi_penuh * _t)
		var f: Font = kantor.f_mono
		var ft: Font = kantor.f_mono_tebal
		# --- kertas yang menggulung turun
		if tinggi > 2.0:
			var kiri: float = 10.0
			var kanan: float = w - 10.0
			var bawah: float = atas + tinggi
			var kertas := PackedVector2Array([Vector2(kiri, atas), Vector2(kanan, atas), Vector2(kanan, bawah - 3), Vector2(kiri + 1, bawah)])
			var bayang := PackedVector2Array()
			for p: Vector2 in kertas:
				bayang.append(p + Vector2(4, 5))
			draw_colored_polygon(bayang, Color(0, 0, 0, 0.35))
			draw_colored_polygon(kertas, KERTAS)
			var y: float = atas + 14.0
			var i: int = 0
			for t: Dictionary in daftar:
				if y + TINGGI_BARIS - 8.0 > bawah - 6.0:
					break  # baris ini belum "terbuka" oleh gulungan
				_baris(t, y, i)
				y += TINGGI_BARIS
				i += 1
			if pintu and y + 16.0 <= bawah - 6.0:
				teks(ft, Vector2(18, y + 8), "SEMUA BERES — KABUR LEWAT LOBBY!", 9, MERAH_PENA)
				goyang([Vector2(16, y + 12), Vector2(w - 18, y + 11)], MERAH_PENA, 1.4, 999)
				y += 22.0
			# panduan di bagian bawah kertas
			var y_pd: float = atas + tinggi_daftar + 8.0
			if y_pd + 10.0 <= bawah - 6.0:
				draw_line(Vector2(16, y_pd - 4), Vector2(w - 16, y_pd - 4), Color(0.84, 0.72, 0.31), 1.0)
				teks(ft, Vector2(18, y_pd + 9), "PANDUAN", 9, TINTA_COKLAT)
				var yy: float = y_pd + 22.0
				for baris: String in panduan:
					if yy > bawah - 8.0:
						break
					teks(f, Vector2(18, yy), baris, 9, Color(0.35, 0.27, 0.12))
					yy += 12.0
			# gulungan kertas di ujung bawah
			kotak(Rect2(kiri - 3, bawah - 4, kanan - kiri + 6, 9), KERTAS_GELAP, 4)
			draw_line(Vector2(kiri + 2, bawah - 2), Vector2(kanan - 2, bawah - 2), Color(1, 0.95, 0.75, 0.6), 1.0)
		else:
			# tergulung rapat di bawah papan
			kotak(Rect2(7, atas - 2, w - 14, 9), KERTAS_GELAP, 4)
			draw_line(Vector2(12, atas), Vector2(w - 12, atas), Color(1, 0.95, 0.75, 0.6), 1.0)
		# --- papan (clipboard) + penjepit
		kotak(Rect2(2, 4, w, TINGGI_KEPALA), Color(0, 0, 0, 0.35), 6)
		kotak(Rect2(0, 0, w, TINGGI_KEPALA), Color(0.42, 0.3, 0.17), 6, 1, Color(0.3, 0.2, 0.1))
		kotak(Rect2(w * 0.5 - 26, -5, 52, 13), Color(0.66, 0.67, 0.7), 4, 1, Color(0.45, 0.46, 0.5))
		kotak(Rect2(w * 0.5 - 9, -2, 18, 5), Color(0.42, 0.3, 0.17), 2)
		teks(ft, Vector2(12, 24), "TUGAS", 12, Color(0.98, 0.93, 0.8))
		# badge jumlah beres
		var label: String = "%d/%d" % [jumlah_beres, daftar.size()]
		var lb: float = lebar_teks(ft, label, 10) + 12.0
		var warna_badge: Color = Color(0.2, 0.55, 0.3) if pintu else MERAH_PENA
		kotak(Rect2(60, 11, lb, 16), warna_badge, 8)
		teks(ft, Vector2(66, 23), label, 10, Color(1, 0.95, 0.9))
		# waktu main (dipakai untuk bintang)
		var detik: int = int(l.get_level_time()) if l.has_method("get_level_time") else 0
		teks(ft, Vector2(66 + lb + 10, 23), "%02d:%02d" % [detik / 60, detik % 60], 10, Color(0.98, 0.93, 0.8, 0.85))
		teks_kanan(f, Vector2(w - 26, 23), "Tab", 10, Color(0.98, 0.93, 0.8, 0.55))
		# panah ▾ berputar mengikuti buka/tutup
		var pusat := Vector2(w - 14, 17)
		var sudut: float = PI * clampf(_t, 0.0, 1.0)
		var panah := PackedVector2Array()
		for p: Vector2 in [Vector2(-5, -2.5), Vector2(5, -2.5), Vector2(0, 3.5)]:
			panah.append(pusat + p.rotated(sudut))
		draw_colored_polygon(panah, Color(0.98, 0.93, 0.8))

	func _baris(t: Dictionary, y: float, i: int) -> void:
		var w: float = LEBAR
		var f: Font = kantor.f_mono
		var ft: Font = kantor.f_mono_tebal
		var st: String = str(t["status"])
		draw_line(Vector2(16, y + 20), Vector2(w - 16, y + 20), Color(0.84, 0.72, 0.31), 1.0)
		var x_nama: float = 36.0
		var lebar_maks: float = w - x_nama - 22.0
		teks(ft, Vector2(x_nama, y + 4), pendekkan(ft, str(t["nama"]), 11, lebar_maks), 11, Color(0.16, 0.125, 0.06))
		# baris kedua: ruangan (kiri) + keadaan (kanan)
		var kanan: String = ""
		var warna_ket: Color = TINTA_COKLAT
		if st == "beres":
			kanan = "beres"
			warna_ket = BIRU_PENA
		elif st == "jalan":
			kanan = "%d%%" % int(float(t["progres"]) * 100.0)
		if bool(t["berdua"]) and st != "beres":
			kanan = ("BERDUA · " + kanan) if kanan != "" else "BERDUA"
			warna_ket = MERAH_PENA if st != "jalan" else warna_ket
		var lebar_kanan: float = lebar_teks(ft, kanan, 9) if kanan != "" else 0.0
		if kanan != "":
			teks_kanan(ft, Vector2(w - 16.0, y + 15), kanan, 9, warna_ket)
		var ruang: String = pendekkan(f, str(t["ruang"]), 9, w - 16.0 - lebar_kanan - 8.0 - x_nama)
		teks(f, Vector2(x_nama, y + 15), ruang, 9, TINTA_COKLAT)
		# kotak centang tulisan tangan di kiri
		var bx: float = 16.0
		goyang([Vector2(bx, y - 5), Vector2(bx + 11, y - 5.5), Vector2(bx + 11.5, y + 6), Vector2(bx, y + 6.5), Vector2(bx, y - 5)], Color(0.24, 0.18, 0.08), 1.3, 100 + i)
		if st == "beres":
			goyang([Vector2(bx + 1, y), Vector2(bx + 5, y + 5), Vector2(bx + 15, y - 9)], BIRU_PENA, 2.2, 300 + i)
			goyang([Vector2(x_nama - 2, y + 1), Vector2(x_nama + minf(lebar_teks(ft, str(t["nama"]), 11), lebar_maks) + 2, y)], Color(BIRU_PENA, 0.55), 1.2, 400 + i)
		elif st == "jalan":
			# setrip pensil kecil = sedang dikerjakan
			goyang([Vector2(bx + 2, y + 1), Vector2(bx + 9, y)], Color(0.24, 0.18, 0.08), 1.6, 500 + i)


# =========================================================== ID card
class _KartuPemain extends _Widget:
	func _ready() -> void:
		size = Vector2(220, 130)

	func _atur_posisi(_vp: Vector2) -> void:
		position = Vector2.ZERO

	func _draw() -> void:
		var l: Node = lv()
		if l == null or not l.has_method("get_info_pemain"):
			return
		var info: Array = l.get_info_pemain()
		var i: int = 0
		for p: Dictionary in info:
			var cx: float = 40.0 + i * 62.0
			var pusat := Vector2(cx, 64)
			var sudut: float = deg_to_rad(-4.0 if i == 0 else 3.0)
			var tali := Color(0.16, 0.16, 0.19)
			draw_line(Vector2(cx - 10, 0), pusat + Vector2(0, -33).rotated(sudut), tali, 3.0, true)
			draw_line(Vector2(cx + 10, 0), pusat + Vector2(0, -33).rotated(sudut), tali, 3.0, true)
			draw_set_transform(pusat, sudut, Vector2.ONE)
			_kartu(p, i)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var status: String = str(p["status"])
			if status == "kurung" or status == "sembunyi":
				# Cap stempel miring di atas foto.
				var warna_cap: Color = Color(0.78, 0.16, 0.14, 0.92) if status == "kurung" else Color(0.3, 0.4, 0.6, 0.9)
				var kata: String = "DIKURUNG" if status == "kurung" else "SEMBUNYI"
				draw_set_transform(pusat + Vector2(0, -3).rotated(sudut), sudut - 0.3, Vector2.ONE)
				var lebar: float = lebar_teks(kantor.f_mono_tebal, kata, 9) + 8.0
				draw_rect(Rect2(-lebar * 0.5, -8, lebar, 16), warna_cap, false, 1.6)
				teks_tengah(kantor.f_mono_tebal, Vector2.ZERO, kata, 9, warna_cap)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# tag kecil di bawah kartu: kunci yang dibawa / Item Bangkit
			var tag: Array[String] = []
			if str(p["kunci"]) != "":
				tag.append("KUNCI " + str(p["kunci"]))
			if bool(p["item"]):
				tag.append("+ITEM")
			var ty: float = pusat.y + 46.0
			for s: String in tag:
				var lt: float = lebar_teks(kantor.f_mono_tebal, s, 8) + 8.0
				kotak(Rect2(cx - lt * 0.5, ty - 7, lt, 13), Color(0.086, 0.086, 0.1, 0.9), 3)
				teks_tengah(kantor.f_mono_tebal, Vector2(cx, ty - 0.5), s, 8, Color(0.98, 0.86, 0.5))
				ty += 15.0
			i += 1
		if info.size() >= 2 and bool(info[0].get("aman", false)) and bool(info[1].get("aman", false)):
			_klip(Vector2(71, 44))

	func _klip(c: Vector2) -> void:
		# Klip kertas yang menjepit dua ID card = sedang berdua di tugas
		# 2 pemain, aman dari musuh.
		var logam := Color(0.78, 0.8, 0.84)
		var tebal: float = 1.8
		draw_arc(c + Vector2(-13, 0), 5.0, PI * 0.5, PI * 1.5, 12, logam, tebal, true)
		draw_arc(c + Vector2(14, 0), 5.0, -PI * 0.5, PI * 0.5, 12, logam, tebal, true)
		draw_line(c + Vector2(-13, -5), c + Vector2(14, -5), logam, tebal, true)
		draw_line(c + Vector2(-13, 5), c + Vector2(10, 5), logam, tebal, true)
		draw_arc(c + Vector2(10, 1.5), 3.5, PI * 0.5, PI * 1.5, 10, logam, tebal, true)
		draw_line(c + Vector2(10, -2), c + Vector2(-8, -2), logam, tebal, true)
		teks_tengah(kantor.f_mono_tebal, c + Vector2(0, 15), "BERDUA", 8, Color(0.85, 0.9, 1.0, 0.85))

	func _kartu(p: Dictionary, i: int) -> void:
		var w: float = 54.0
		var h: float = 70.0
		var o := Vector2(-w * 0.5, -h * 0.5)
		var warna: Color = Color(0.31, 0.75, 0.67) if i == 0 else Color(0.43, 0.59, 0.94)
		var redup: float = 0.55 if str(p["status"]) == "sembunyi" else 1.0
		kotak(Rect2(o + Vector2(3, 4), Vector2(w, h)), Color(0, 0, 0, 0.4), 5)
		kotak(Rect2(o, Vector2(w, h)), Color(0.91 * redup, 0.9 * redup, 0.87 * redup), 5)
		draw_rect(Rect2(o + Vector2(0, 6), Vector2(w, 11)), Color(warna.r * redup, warna.g * redup, warna.b * redup))
		kotak(Rect2(o + Vector2(w * 0.5 - 7, 2), Vector2(14, 4)), Color(0.24, 0.24, 0.26), 2)
		var abu := Color(0.59 * redup, 0.59 * redup, 0.62 * redup)
		draw_circle(o + Vector2(w * 0.5, 28), 7.0, abu)
		draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.5 - 13, 50), o + Vector2(w * 0.5 - 10, 40), o + Vector2(w * 0.5, 37),
			o + Vector2(w * 0.5 + 10, 40), o + Vector2(w * 0.5 + 13, 50)]), abu)
		teks_tengah(kantor.f_mono_tebal, o + Vector2(w * 0.5, 58), str(p["nama"]), 9, Color(0.16, 0.16, 0.18))
		draw_rect(Rect2(o + Vector2(6, 63), Vector2(w - 12, 2.5)), Color(warna.r * redup, warna.g * redup, warna.b * redup))


# =========================================================== label Dymo
class _LabelDymo extends _Widget:
	var _teks: String = ""

	func _atur_posisi(vp: Vector2) -> void:
		var t: String = kantor.teks_arahan().to_upper() if kantor != null else ""
		_teks = t
		visible = t != ""
		var w: float = lebar_teks(kantor.f_mono_tebal, t, 13) + 38.0
		size = Vector2(w, 32)
		pivot_offset = size * 0.5
		rotation = deg_to_rad(-1.2)
		position = Vector2(vp.x * 0.5 - w * 0.5, vp.y - 66.0)

	func _draw() -> void:
		if _teks == "":
			return
		var w: float = size.x
		var h: float = size.y
		var pita := PackedVector2Array([Vector2(6, 0), Vector2(w - 6, 0), Vector2(w, h * 0.5), Vector2(w - 6, h), Vector2(6, h), Vector2(0, h * 0.5)])
		var bayang := PackedVector2Array()
		for p: Vector2 in pita:
			bayang.append(p + Vector2(2, 4))
		draw_colored_polygon(bayang, Color(0, 0, 0, 0.5))
		draw_colored_polygon(pita, Color(0.086, 0.086, 0.1))
		teks_tengah(kantor.f_mono_tebal, Vector2(w * 0.5 + 1, h * 0.5 + 1), _teks, 13, Color(0, 0, 0))
		teks_tengah(kantor.f_mono_tebal, Vector2(w * 0.5, h * 0.5), _teks, 13, Color(0.93, 0.93, 0.94))


# =============================================== bar energi di atas kepala
class _BarEnergi extends _Widget:
	# Bar energi lari kecil di atas kepala pemain sendiri (sama dengan Level 2):
	# kuning-amber + garis tepi gelap, pucat saat mengisi, merah berdenyut
	# saat habis (+ garis putih di batas boleh lari lagi).
	const LEBAR: float = 34.0
	const TINGGI: float = 4.0
	const DI_ATAS_KEPALA: float = -25.0  # titik di dunia game (px) relatif ke pemain
	const AMBER: Color = Color(1.0, 0.78, 0.18)
	const AMBER_ISI: Color = Color(1.0, 0.86, 0.45)
	const MERAH_HABIS: Color = Color(1.0, 0.27, 0.2)
	const TEPI: Color = Color(0.05, 0.04, 0.03)
	const BATAS_LARI: float = 0.25  # = STAMINA_MIN_TO_SPRINT / STAMINA_MAX di player.gd
	var _alpha: float = 0.0
	var _kedip: float = 0.0

	func _atur_posisi(vp: Vector2) -> void:
		size = vp
		position = Vector2.ZERO

	func _process(delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		queue_redraw()
		_kedip += delta
		var p: Node = _pemain()
		var perlu: bool = p != null and not p.is_hidden and not p.is_downed and not p.minigame_open \
			and not _ada_layar_penuh() and (p.is_sprinting or p.get_stamina_ratio() < 0.999)
		# muncul cepat, hilang pelan setelah penuh
		_alpha = move_toward(_alpha, 1.0 if perlu else 0.0, delta * (6.0 if perlu else 1.5))

	func _draw() -> void:
		var p: Node2D = _pemain() as Node2D
		if p == null or _alpha <= 0.01:
			return
		var habis: bool = bool(p.get("_sprint_locked"))
		var titik: Vector2 = p.get_global_transform_with_canvas() * Vector2(0, DI_ATAS_KEPALA)
		var r := Rect2(titik.x - LEBAR * 0.5, titik.y - TINGGI, LEBAR, TINGGI)
		kotak(r.grow(1.0), Color(TEPI, 0.8 * _alpha), 3)
		var jalur: Color = Color(0.4, 0.09, 0.07) if habis else Color(0.27, 0.24, 0.2)
		kotak(r, Color(jalur, 0.9 * _alpha), 2)
		var warna: Color
		if habis:
			warna = Color(MERAH_HABIS, 0.75 + 0.25 * sin(_kedip * 9.0))
		elif p.is_sprinting:
			warna = Color(AMBER, 1.0)
		else:
			warna = Color(AMBER_ISI, 0.85)
		var isi: float = LEBAR * clampf(p.get_stamina_ratio(), 0.0, 1.0)
		if isi >= 1.0:
			kotak(Rect2(r.position, Vector2(isi, TINGGI)), Color(warna.r, warna.g, warna.b, warna.a * _alpha), 2)
		if habis:
			var x: float = r.position.x + LEBAR * BATAS_LARI
			draw_line(Vector2(x, r.position.y - 1.0), Vector2(x, r.end.y + 1.0), Color(1, 1, 1, 0.8 * _alpha), 1.0)


# ======================================================= busur Item Bangkit
class _PenandaBangkit extends _Widget:
	# Garis busur tipis hijau (seperti radar) yang menunjuk ke Item Bangkit;
	# setelah item diambil, menunjuk ke kurungan teman. Sama dengan Level 2:
	# tembus tembok, makin dekat makin panjang & terang, berdenyut pelan.
	# Hanya untuk pemain yang bebas (tujuan dari level.get_tujuan_bangkit()).
	const HIJAU_BUSUR: Color = Color(0.27, 1.0, 0.47)
	const RADIUS_DUNIA: float = 50.0  # px dunia dari tengah pemain (±1,6 tile)
	const JARAK_PENUH: float = 48.0  # <= 1,5 tile: busur paling panjang & terang
	const JARAK_JAUH: float = 512.0  # >= 16 tile: busur paling pendek & tipis
	const KEKUATAN_MIN: float = 0.3  # walau jauh tetap kelihatan sedikit
	const TEBAL: float = 5.0  # px layar
	var _waktu: float = 0.0
	var _alpha: float = 0.0
	var _kekuatan: float = 0.0
	var _sudut: float = 0.0

	func _atur_posisi(vp: Vector2) -> void:
		size = vp
		position = Vector2.ZERO

	func _process(delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		queue_redraw()
		_waktu += delta
		var p: Node2D = _pemain() as Node2D
		var tujuan: Dictionary = {}
		var l: Node = lv()
		if l != null and l.has_method("get_tujuan_bangkit"):
			tujuan = l.get_tujuan_bangkit()
		var tampil: bool = p != null and bool(tujuan.get("ada", false)) and not p.is_hidden \
			and not p.minigame_open and not _ada_layar_penuh()
		if tampil:
			var arah: Vector2 = (tujuan["pos"] as Vector2) - p.global_position
			var t: float = clampf(1.0 - (arah.length() - JARAK_PENUH) / (JARAK_JAUH - JARAK_PENUH), 0.0, 1.0)
			_kekuatan = KEKUATAN_MIN + (1.0 - KEKUATAN_MIN) * pow(t, 1.2)
			if arah.length() > 1.0:
				if _alpha <= 0.01:
					_sudut = arah.angle()
				else:
					_sudut = lerp_angle(_sudut, arah.angle(), minf(1.0, delta * 10.0))
		_alpha = move_toward(_alpha, 1.0 if tampil else 0.0, delta * 3.0)

	func get_kekuatan() -> float:
		# Untuk smoke test & debug (0 = tidak tampil).
		return _kekuatan * _alpha

	func _draw() -> void:
		var p: Node2D = _pemain() as Node2D
		if p == null or _alpha <= 0.01:
			return
		var xf: Transform2D = p.get_global_transform_with_canvas()
		var pusat: Vector2 = xf.origin
		var r: float = RADIUS_DUNIA * xf.get_scale().x
		var setengah: float = deg_to_rad(10.0 + 22.0 * _kekuatan)
		var napas: float = 0.82 + 0.18 * sin(_waktu * 2.5)
		var a: float = (0.3 + 0.7 * _kekuatan) * napas * _alpha
		var mulai: float = _sudut - setengah
		var akhir: float = _sudut + setengah
		draw_arc(pusat, r, mulai, akhir, 32, Color(0, 0, 0, 0.6 * a), TEBAL * 2.0, true)
		draw_arc(pusat, r, mulai, akhir, 32, Color(HIJAU_BUSUR, a), TEBAL, true)
		for ujung: float in [mulai, akhir]:
			draw_circle(pusat + Vector2.from_angle(ujung) * r, TEBAL * 0.5, Color(HIJAU_BUSUR, a))


# ================================================ peta Gudang: denah kertas
class DenahKertas extends Control:
	# Peta Level 1 (dibuka di Gudang dengan M) bergaya denah evakuasi seperti
	# denah Level 2. Aturannya tetap aturan Level 1: semua ruangan terlihat,
	# ada posisi kamu & teman. Dipakai oleh scripts/hud.gd.
	const KERTAS := Color(0.93, 0.91, 0.85)
	const TINTA := Color(0.18, 0.22, 0.2)
	const HIJAU_EVAKUASI := Color(0.13, 0.47, 0.3)
	const MERAH := Color(0.82, 0.16, 0.12)
	const BIRU := Color(0.2, 0.36, 0.72)
	const UKURAN_MAP := Vector2(64, 40)  # Level 1 = 64 x 40 sel

	var rooms: Array = []  # [{"name": String, "rect": Rect2i}] dari level_1.gd (MAP_ROOMS)
	var font: Font = null
	var font_tipis: Font = null
	var _waktu: float = 0.0
	var _muncul: float = 0.0  # animasi kertas "diangkat" saat dibuka

	func mulai() -> void:
		_muncul = 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_waktu += delta
		_muncul = minf(1.0, _muncul + delta * 5.0)
		queue_redraw()

	func _goyang(titik: Array, warna: Color, tebal: float, benih: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = benih
		var hasil := PackedVector2Array()
		for p: Vector2 in titik:
			hasil.append(p + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8)))
		draw_polyline(hasil, warna, tebal, true)

	func _draw() -> void:
		var lv: Node = get_tree().get_first_node_in_group("LevelManager")
		if lv == null or font == null:
			return
		var vp: Vector2 = size
		var s: float = minf(vp.x * 0.76 / UKURAN_MAP.x, vp.y * 0.64 / UKURAN_MAP.y)
		var isi: Vector2 = UKURAN_MAP * s
		var kertas_ukuran: Vector2 = isi + Vector2(44, 98)
		var ease: float = 1.0 - pow(1.0 - _muncul, 3.0)
		var pusat: Vector2 = vp * 0.5 + Vector2(0, 30.0 * (1.0 - ease))
		draw_set_transform(pusat, deg_to_rad(-1.2), Vector2.ONE * (0.96 + 0.04 * ease))
		var o: Vector2 = -kertas_ukuran * 0.5
		# kertas + bayangan + selotip
		draw_rect(Rect2(o + Vector2(6, 8), kertas_ukuran), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(o, kertas_ukuran), KERTAS)
		for x: float in [o.x + 30.0, o.x + kertas_ukuran.x - 90.0]:
			draw_rect(Rect2(Vector2(x, o.y - 8), Vector2(60, 16)), Color(0.95, 0.93, 0.84, 0.75))
		# kepala kertas hijau ala denah evakuasi
		draw_rect(Rect2(o, Vector2(kertas_ukuran.x, 40)), HIJAU_EVAKUASI)
		draw_string(font, o + Vector2(18, 26), "DENAH KANTOR  ·  LANTAI 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
		draw_string(font, o + Vector2(kertas_ukuran.x - 18 - 220, 26), "%d ruangan" % rooms.size(), HORIZONTAL_ALIGNMENT_RIGHT, 220, 13, Color(1, 1, 1, 0.85))
		var asal: Vector2 = o + Vector2(22, 56)
		# garis luar gedung (putus-putus)
		var luar := Rect2(asal, isi)
		draw_dashed_line(luar.position, Vector2(luar.end.x, luar.position.y), Color(TINTA, 0.25), 1.0, 6.0)
		draw_dashed_line(Vector2(luar.end.x, luar.position.y), luar.end, Color(TINTA, 0.25), 1.0, 6.0)
		draw_dashed_line(luar.end, Vector2(luar.position.x, luar.end.y), Color(TINTA, 0.25), 1.0, 6.0)
		draw_dashed_line(Vector2(luar.position.x, luar.end.y), luar.position, Color(TINTA, 0.25), 1.0, 6.0)
		# ruangan (ruangan tempat kamu berdiri diberi warna kuning)
		var p_lokal: Node2D = lv.get_local_player() as Node2D
		var sel_lokal := Vector2i(-99, -99)
		if p_lokal != null:
			sel_lokal = Vector2i((p_lokal.global_position / 32.0).floor())
		var i: int = 0
		for r: Dictionary in rooms:
			i += 1
			var k: Rect2i = r["rect"]
			var rect := Rect2(asal + Vector2(k.position) * s, Vector2(k.size) * s).grow(-1.5)
			var di_sini: bool = k.has_point(sel_lokal)
			draw_rect(rect, Color(0.99, 0.93, 0.7) if di_sini else Color(0.84, 0.88, 0.82))
			_goyang([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position], TINTA, 1.8, 500 + i)
			var ukuran_huruf: int = int(clampf(s * 1.05, 9.0, 13.0))
			var nama: String = str(r["name"])
			if font.get_string_size(nama, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran_huruf).x > rect.size.x - 4.0:
				ukuran_huruf = 9
			draw_string(font, Vector2(rect.position.x, rect.get_center().y + ukuran_huruf * 0.35), nama, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, ukuran_huruf, TINTA)
		# posisi teman (biru) lalu kamu (merah + label)
		for row: Dictionary in lv.get_map_players():
			if bool(row["local"]):
				continue
			var t_teman: Vector2 = asal + (row["pos"] as Vector2) / 32.0 * s
			draw_circle(t_teman, 3.5, BIRU)
			draw_string(font, t_teman + Vector2(6, 4), "TEMAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BIRU)
		if p_lokal != null:
			var titik: Vector2 = asal + p_lokal.global_position / 32.0 * s
			draw_circle(titik, 4.5 + 1.5 * sin(_waktu * 6.0), Color(MERAH, 0.35))
			draw_circle(titik, 3.5, MERAH)
			var lebar_label: float = font.get_string_size("KAMU DI SINI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var alas := Rect2(titik + Vector2(7, -16), Vector2(lebar_label + 8, 14))
			draw_rect(alas, Color(1, 1, 1, 0.92))
			draw_rect(alas, MERAH, false, 1.0)
			draw_string(font, alas.position + Vector2(4, 11), "KAMU DI SINI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MERAH)
		# kaki kertas
		var y_kaki: float = o.y + kertas_ukuran.y - 14
		var tipis: Font = font_tipis if font_tipis != null else font
		draw_string(tipis, Vector2(o.x + 22, y_kaki), "Denah ini cuma bisa dilihat dari Gudang.   merah = kamu   biru = teman", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(TINTA, 0.75))
		draw_string(tipis, Vector2(o.x + kertas_ukuran.x - 22 - 200, y_kaki), "[M] / [Esc] tutup", HORIZONTAL_ALIGNMENT_RIGHT, 200, 11, Color(TINTA, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
