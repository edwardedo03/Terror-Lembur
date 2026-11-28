class_name GayaMenu
extends RefCounted
## Gaya layar menu Terror Lembur (mockup Opsi D): dipakai main menu,
## Pilih Level, dan Menunggu host.
##
## Kiri : judul besar condensed + tombol teks bergaris rambut.
## Kanan: mesin absen (jam LED + label Dymo berisi IP) dan kartu lembur
##        kertas yang mencatat progres Level 1 dan Level 2.
##
## SEMUA digambar dari kode (draw_*, Label, StyleBoxFlat, GradientTexture2D),
## tidak ada file gambar baru. Warna mengikuti UiTheme: gelap hangat,
## garis rambut, satu aksen amber.

# ----------------------------------------------------------------- warna ---
const LATAR := Color(0.031, 0.027, 0.043)
const INK := Color(0.925, 0.898, 0.847)
const SOFT := Color(0.788, 0.753, 0.678)
const MUTED := Color(0.604, 0.569, 0.502)
const REDUP := Color(0.541, 0.51, 0.459)
const AMBER := Color(0.91, 0.639, 0.239)
const HIJAU := Color(0.561, 0.71, 0.451)
const MERAH_AKSEN := Color(0.784, 0.216, 0.176)
const MERAH_PESAN := Color(0.82, 0.376, 0.247)
const BIRU_BAYANG := Color(0.353, 0.549, 0.784, 0.35)
const GARIS := Color(0.227, 0.204, 0.173)
const PANEL := Color(0.059, 0.051, 0.039)
const KEYCAP_ISI := Color(0.102, 0.09, 0.071)
const KEYCAP_GARIS := Color(0.361, 0.329, 0.282)
const KERTAS := Color(0.91, 0.871, 0.776)
const TINTA := Color(0.169, 0.141, 0.094)
const TINTA_PUDAR := Color(0.416, 0.365, 0.271)
const TINTA_ABU := Color(0.435, 0.392, 0.314)
const GARIS_KERTAS := Color(0.788, 0.737, 0.612)
const UNGU_STEMPEL := Color(0.29, 0.243, 0.549)
const MERAH_STEMPEL := Color(0.659, 0.157, 0.118)
const LED := Color(0.886, 0.333, 0.247)
const MESIN_ATAS := Color(0.235, 0.227, 0.208)
const MESIN_BAWAH := Color(0.165, 0.161, 0.145)
const LAMPU_HANGAT := Color(0.965, 0.839, 0.627)

# ------------------------------------------------------------------ font ---
const F_DISPLAY: Font = preload("res://assets/fonts/NotoSansDisplay-ExtraCondensedBold.ttf")
const F_MONO: Font = preload("res://assets/fonts/lmmono10-regular.otf")
const F_MONO_TEBAL: Font = preload("res://assets/fonts/lmmonolt10-bold.otf")

# --------------------------------------------------------- daftar kontrol ---
## Isi panel KONTROL: [judul kolom, [[tombol...], tahan?, keterangan], ...].
## Sama dengan mockup; kalau ada kontrol baru, cukup tambah baris di sini.
const KOLOM_KONTROL: Array = [
	["KEDUA LEVEL", [
		[["W", "A", "S", "D"], false, "Jalan, bisa juga pakai tombol panah"],
		[["Shift"], false, "Lari, berisik dan energinya terbatas"],
		[["E"], false, "Kerjakan tugas, sembunyi, ambil barang"],
		[["E"], true, "Selamatkan teman di kurungan"],
		[["Tab"], false, "Buka atau tutup papan tugas"],
		[["Esc"], false, "Batalkan tugas"],
	]],
	["LEVEL 1  LANTAI KANTOR", [
		[["M"], false, "Peta kantor, cuma bisa di Gudang"],
		[["E"], false, "Buka pintu kalau membawa kuncinya"],
		[["E"], false, "Aktifkan perangkap untuk memancing musuh"],
	]],
	["LEVEL 2  LOBI GELAP", [
		[["R"], false, "Senter HP, baterai cepat habis"],
		[["E"], false, "Colok HP di titik cas lalu diam 10 detik"],
		[["E"], false, "Nyalakan dan pakai komputer security"],
		[["M"], false, "Denah, saat ngecas di titik cas bertanda"],
		[["Esc"], false, "Berdiri dari komputer atau tutup denah"],
	]],
]

static var _varian: Dictionary = {}
static var _gaya_keycap: StyleBoxFlat = null


# ================================================================ helper ===
## Font dengan jarak antar huruf (spasi, px) dan penebalan (tebal) tambahan.
## Hasilnya di-cache supaya tidak membuat FontVariation baru tiap frame.
static func huruf(dasar: Font, spasi: int = 0, tebal: float = 0.0) -> Font:
	if spasi == 0 and is_zero_approx(tebal):
		return dasar
	var kunci: String = "%s|%d|%.2f" % [dasar.resource_path, spasi, tebal]
	if _varian.has(kunci):
		return _varian[kunci]
	var v := FontVariation.new()
	v.base_font = dasar
	v.spacing_glyph = spasi
	v.variation_embolden = tebal
	_varian[kunci] = v
	return v


## LM Mono regular yang sedikit ditebalkan. LM Mono aslinya tipis, jadi teks
## kecil di latar gelap (keterangan tombol, status) dibuat lebih terbaca.
static func mono(spasi: int = 0) -> Font:
	return huruf(F_MONO, spasi, 0.4)


static func label(teks: String, f: Font, ukuran: int, warna: Color) -> Label:
	var l := Label.new()
	l.text = teks
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", ukuran)
	l.add_theme_color_override("font_color", warna)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func garis_rambut() -> ColorRect:
	var r := ColorRect.new()
	r.color = GARIS
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Kedip 1 detik (0,5 detik nyala, 0,5 detik redup) yang sama untuk semua
## elemen, jadi titik dua jam LED dan lampu status berkedip bersamaan.
static func kedip_nyala() -> bool:
	return int(Time.get_ticks_msec() / 500.0) % 2 == 0


## Waktu detik -> "06:41".
static func format_waktu(detik: float) -> String:
	var t: int = int(round(detik))
	return "%02d:%02d" % [t / 60, t % 60]


## Buang semua gaya bawaan Button supaya yang tampil hanya gambar _draw().
static func kosongkan_gaya(b: Button) -> void:
	b.flat = true
	b.text = ""
	for nama: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(nama, StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _tekstur_radial(titik: PackedFloat32Array, warna: PackedColorArray, ujung: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = titik
	g.colors = warna
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = ujung
	t.width = 256
	t.height = 256
	return t


## Latar layar menu: warna dasar + cahaya lampu hangat di atas mesin absen.
static func pasang_latar(induk: Control) -> void:
	var dasar := ColorRect.new()
	dasar.name = "LatarDasar"
	dasar.color = LATAR
	dasar.set_anchors_preset(Control.PRESET_FULL_RECT)
	dasar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	induk.add_child(dasar)
	var cahaya := TextureRect.new()
	cahaya.name = "CahayaLampu"
	cahaya.texture = _tekstur_radial(
		PackedFloat32Array([0.0, 0.52, 1.0]),
		PackedColorArray([Color(LAMPU_HANGAT, 0.15), Color(LAMPU_HANGAT, 0.05), Color(LAMPU_HANGAT, 0.0)]),
		Vector2(1.0, 0.5))
	cahaya.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cahaya.stretch_mode = TextureRect.STRETCH_SCALE
	cahaya.position = Vector2(930.0 - 460.0, 110.0 - 460.0)
	cahaya.size = Vector2(920.0, 920.0)
	cahaya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	induk.add_child(cahaya)


## Vinyet gelap di tepi layar (dipasang setelah isi, sebelum panel dialog).
static func pasang_vinyet(induk: Control) -> void:
	var v := TextureRect.new()
	v.name = "Vinyet"
	v.texture = _tekstur_radial(
		PackedFloat32Array([0.0, 0.58, 1.0]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)]),
		Vector2(1.207, 0.5))
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	induk.add_child(v)


## Baris kecil di atas judul, misalnya "SHIFT MALAM  LANTAI 1  21.00".
## Bagian terakhir berwarna amber.
static func baris_atas(induk: Control, pos: Vector2, bagian: PackedStringArray, warna_akhir: Color = AMBER) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.position = pos
	h.add_theme_constant_override("separation", 22)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Font = mono(2)
	for i in range(bagian.size()):
		var warna: Color = warna_akhir if i == bagian.size() - 1 else MUTED
		h.add_child(label(bagian[i], f, 14, warna))
	induk.add_child(h)
	return h


static func tombol_bawah(judul: String, ikon: String, ukuran: int = 24) -> TombolBawah:
	var b := TombolBawah.new()
	b.judul = judul
	b.ikon = ikon
	b.ukuran_judul = ukuran
	b.custom_minimum_size = Vector2(b.lebar_pas(), 44.0)
	b.size = b.custom_minimum_size
	return b


# ============================================================ gambar kecil ===
static func titik_kotak_bulat(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad: float = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pusat: Array[Vector2] = [
		Vector2(r.end.x - rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.position.y + rad),
	]
	var sudut_awal: Array[float] = [-PI / 2.0, 0.0, PI / 2.0, PI]
	for k in range(4):
		for j in range(7):
			var a: float = sudut_awal[k] + (PI / 2.0) * float(j) / 6.0
			pts.append(pusat[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func bintang(ci: CanvasItem, pusat: Vector2, r: float, isi: bool, warna: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a: float = -PI / 2.0 + float(i) * PI / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(pusat + Vector2(cos(a), sin(a)) * rr)
	if isi:
		ci.draw_colored_polygon(pts, warna)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, warna, 1.2, true)


static func gembok(ci: CanvasItem, pusat: Vector2, warna: Color) -> void:
	ci.draw_rect(Rect2(pusat.x - 5.0, pusat.y - 1.0, 10.0, 7.0), warna)
	var busur := PackedVector2Array()
	for i in range(9):
		var a: float = PI + PI * float(i) / 8.0
		busur.append(Vector2(pusat.x, pusat.y - 2.0) + Vector2(cos(a), sin(a)) * 3.2)
	ci.draw_polyline(busur, warna, 1.6, true)
	ci.draw_line(Vector2(pusat.x - 3.2, pusat.y - 2.0), Vector2(pusat.x - 3.2, pusat.y - 1.0), warna, 1.6)
	ci.draw_line(Vector2(pusat.x + 3.2, pusat.y - 2.0), Vector2(pusat.x + 3.2, pusat.y - 1.0), warna, 1.6)


static func lebar_keycap(teks: String) -> float:
	return maxf(26.0, F_MONO_TEBAL.get_string_size(teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)


static func keycap(ci: CanvasItem, r: Rect2, teks: String) -> void:
	if _gaya_keycap == null:
		_gaya_keycap = StyleBoxFlat.new()
		_gaya_keycap.bg_color = KEYCAP_ISI
		_gaya_keycap.border_color = KEYCAP_GARIS
		_gaya_keycap.set_border_width_all(1)
		_gaya_keycap.border_width_bottom = 3
		_gaya_keycap.set_corner_radius_all(4)
	ci.draw_style_box(_gaya_keycap, r)
	ci.draw_string(F_MONO_TEBAL, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 3.0), teks, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, INK)


## Stempel kotak miring (cap "TAMAT 06:41", cap "BELUM BOLEH PULANG").
## skala > 1 dipakai animasi "dicap": stempel mulai besar lalu mengecil
## ke ukuran asli sambil makin pekat.
static func stempel(ci: CanvasItem, pusat: Vector2, derajat: float, baris: PackedStringArray, warna: Color, ukuran: int, tebal_garis: float, skala: float = 1.0) -> float:
	var f: Font = huruf(F_MONO_TEBAL, 1)
	var lebar: float = 0.0
	for b: String in baris:
		lebar = maxf(lebar, f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x)
	var tinggi_baris: float = float(ukuran) * 1.25
	var kotak := Vector2(lebar + 14.0, tinggi_baris * baris.size() + 5.0)
	if skala <= 0.01:
		return kotak.x
	# makin besar (awal animasi) makin pudar
	warna = Color(warna, warna.a * clampf(1.0 - (skala - 1.0) * 1.2, 0.0, 1.0))
	ci.draw_set_transform(pusat, deg_to_rad(derajat), Vector2(skala, skala))
	ci.draw_rect(Rect2(-kotak * 0.5, kotak), warna, false, tebal_garis)
	for i in range(baris.size()):
		var y: float = -kotak.y * 0.5 + 2.5 + tinggi_baris * float(i + 1) - float(ukuran) * 0.28
		ci.draw_string(f, Vector2(-kotak.x * 0.5, y), baris[i], HORIZONTAL_ALIGNMENT_CENTER, kotak.x, ukuran, warna)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return kotak.x


# ============================================================ judul besar ===
## Judul condensed besar dengan bayangan merah (dan sedikit biru) bergeser,
## seperti salah cetak. Tiap baris digambar di baseline yang ditentukan
## supaya jarak barisnya rapat seperti di mockup.
class JudulBesar extends Control:
	var baris: PackedStringArray = PackedStringArray()
	var ukuran: int = 128
	var baseline_pertama: float = 105.0
	var jarak_baris: float = 110.0
	var warna_bayang: Color = GayaMenu.MERAH_AKSEN

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 2, 0.6)
		for i in range(baris.size()):
			var pos := Vector2(0.0, baseline_pertama + jarak_baris * float(i))
			draw_string(f, pos + Vector2(-2.0, 0.0), baris[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, GayaMenu.BIRU_BAYANG)
			draw_string(f, pos + Vector2(4.0, 0.0), baris[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna_bayang)
			draw_string(f, pos, baris[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, GayaMenu.INK)


# ============================================================ mesin absen ===
class MesinAbsen extends Control:
	var label_dymo: String = "IP MESIN INI"
	var isi_dymo: String = "-"
	## Jam di layar LED, format "21:00" (atau "--:--" saat listrik padam).
	## Titik dua di tengah berkedip.
	var jam: String = "21:00":
		set(v):
			jam = v
			queue_redraw()
	var _nyala: bool = true
	var _gaya_badan: StyleBoxFlat = null
	var _gaya_layar: StyleBoxFlat = null
	var _gaya_celah: StyleBoxFlat = null

	func _init() -> void:
		size = Vector2(340, 188)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gaya_badan = StyleBoxFlat.new()
		_gaya_badan.bg_color = GayaMenu.MESIN_BAWAH
		_gaya_badan.set_corner_radius_all(12)
		_gaya_badan.shadow_color = Color(0, 0, 0, 0.55)
		_gaya_badan.shadow_size = 18
		_gaya_badan.shadow_offset = Vector2(0, 14)
		_gaya_layar = StyleBoxFlat.new()
		_gaya_layar.bg_color = Color(0.039, 0.035, 0.027)
		_gaya_layar.set_corner_radius_all(4)
		_gaya_celah = StyleBoxFlat.new()
		_gaya_celah.bg_color = Color(0.02, 0.02, 0.016)
		_gaya_celah.set_corner_radius_all(3)

	func atur_dymo(kiri: String, kanan: String) -> void:
		label_dymo = kiri
		isi_dymo = kanan
		queue_redraw()

	func _process(_delta: float) -> void:
		var n: bool = GayaMenu.kedip_nyala()
		if n != _nyala:
			_nyala = n
			queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var badan := Rect2(Vector2.ZERO, size)
		# Badan mesin: bayangan dari StyleBoxFlat, lalu gradasi atas-bawah.
		draw_style_box(_gaya_badan, badan)
		var pts: PackedVector2Array = GayaMenu.titik_kotak_bulat(badan, 12.0)
		var warna_titik := PackedColorArray()
		for p: Vector2 in pts:
			warna_titik.append(GayaMenu.MESIN_ATAS.lerp(GayaMenu.MESIN_BAWAH, clampf(p.y / size.y, 0.0, 1.0)))
		draw_polygon(pts, warna_titik)
		draw_line(Vector2(12.0, 1.0), Vector2(w - 12.0, 1.0), Color(1, 1, 1, 0.08), 1.0)
		draw_string(GayaMenu.mono(5), Vector2(0.0, 25.0), "MESIN ABSEN", HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(0.561, 0.545, 0.506))
		# Layar LED + jam 21:00 (titik dua berkedip).
		var layar := Rect2(32.0, 34.0, 276.0, 70.0)
		draw_style_box(_gaya_layar, layar)
		draw_rect(Rect2(layar.position.x + 1.0, layar.position.y + 1.0, layar.size.x - 2.0, 4.0), Color(0, 0, 0, 0.45))
		var f: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 8, 0.3)
		var uk: int = 58
		var bagian_jam: PackedStringArray = jam.split(":")
		var kiri: String = bagian_jam[0] if bagian_jam.size() > 0 else "--"
		var kanan: String = bagian_jam[1] if bagian_jam.size() > 1 else "--"
		var lebar_semua: float = f.get_string_size(kiri + ":" + kanan, HORIZONTAL_ALIGNMENT_LEFT, -1, uk).x
		var x0: float = layar.position.x + (layar.size.x - lebar_semua) * 0.5 + 4.0
		var y: float = 90.0
		var x_titik: float = x0 + f.get_string_size(kiri, HORIZONTAL_ALIGNMENT_LEFT, -1, uk).x
		var x_kanan: float = x0 + f.get_string_size(kiri + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, uk).x
		var warna_titik_dua: Color = GayaMenu.LED if _nyala else Color(GayaMenu.LED, 0.12)
		for bagian: Array in [[kiri, x0, GayaMenu.LED], [":", x_titik, warna_titik_dua], [kanan, x_kanan, GayaMenu.LED]]:
			var teks: String = String(bagian[0])
			var px: float = float(bagian[1])
			var warna: Color = bagian[2]
			draw_string_outline(f, Vector2(px, y), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, uk, 12, Color(warna, warna.a * 0.10))
			draw_string_outline(f, Vector2(px, y), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, uk, 6, Color(warna, warna.a * 0.18))
			draw_string(f, Vector2(px, y), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, uk, warna)
		_gambar_dymo(w)
		draw_style_box(_gaya_celah, Rect2(50.0, 164.0, 240.0, 8.0))

	func _gambar_dymo(w: float) -> void:
		# Label Dymo: pita hitam bersudut runcing, sedikit miring.
		var fd: Font = GayaMenu.huruf(GayaMenu.F_MONO_TEBAL, 1)
		var w1: float = fd.get_string_size(label_dymo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var w2: float = fd.get_string_size(isi_dymo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var lebar: float = w1 + 14.0 + w2 + 36.0
		var tinggi: float = 26.0
		var pusat := Vector2(w * 0.5, 116.0 + tinggi * 0.5)
		draw_set_transform(pusat, deg_to_rad(-1.2), Vector2.ONE)
		var o := Vector2(-lebar * 0.5, -tinggi * 0.5)
		var bentuk := PackedVector2Array([
			o + Vector2(6.0, 0.0), o + Vector2(lebar - 6.0, 0.0), o + Vector2(lebar, tinggi * 0.5),
			o + Vector2(lebar - 6.0, tinggi), o + Vector2(6.0, tinggi), o + Vector2(0.0, tinggi * 0.5),
		])
		draw_colored_polygon(bentuk, Color(0.075, 0.075, 0.094))
		var warna := Color(0.929, 0.929, 0.941)
		draw_string(fd, o + Vector2(18.0, 17.5), label_dymo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, warna)
		draw_string(fd, o + Vector2(18.0 + w1 + 14.0, 17.5), isi_dymo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, warna)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =========================================================== kartu lembur ===
## Kartu absen kertas yang keluar dari celah mesin. Isinya progres:
##   { "level_1": {"tamat", "bintang", "waktu", "terbuka"}, "level_2": {...} }
## (lihat GameProgress.ringkasan()).
class KartuLembur extends Control:
	var progres: Dictionary = {}
	## Cap merah di bawah kartu. Panel hasil memakai "SUDAH PULANG" (ungu).
	var cap_bawah: PackedStringArray = PackedStringArray(["BELUM BOLEH", "PULANG"])
	var warna_cap_bawah: Color = Color(GayaMenu.MERAH_STEMPEL, 0.82)
	## Stiker amber miring di baris LV 2, misalnya "LEVEL 2" / "TERBUKA".
	var stiker: PackedStringArray = PackedStringArray()
	## Skala untuk animasi "dicap" (1 = ukuran asli, 0 = belum tampil).
	var skala_cap_bawah: float = 1.0:
		set(v):
			skala_cap_bawah = v
			queue_redraw()
	var skala_stiker: float = 1.0:
		set(v):
			skala_stiker = v
			queue_redraw()

	func _init() -> void:
		size = Vector2(228, 404)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func atur_progres(p: Dictionary) -> void:
		progres = p
		queue_redraw()

	func _info(lid: String) -> Dictionary:
		var v: Variant = progres.get(lid, {})
		if v is Dictionary:
			return v
		return {}

	func _draw() -> void:
		var w: float = size.x
		draw_rect(Rect2(Vector2(-12.0, 16.0), size), Color(0, 0, 0, 0.38))
		draw_rect(Rect2(Vector2.ZERO, size), GayaMenu.KERTAS)
		# Bayangan dari celah mesin di ujung atas kartu.
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 22), Vector2(0, 22)]),
			PackedColorArray([Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		var kiri: float = 16.0
		var lebar_isi: float = w - 32.0
		draw_string(GayaMenu.huruf(GayaMenu.F_MONO_TEBAL, 3), Vector2(kiri, 37.0), "KARTU LEMBUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GayaMenu.TINTA)
		draw_string(GayaMenu.huruf(GayaMenu.F_MONO, 1), Vector2(kiri, 53.0), "LANTAI KANTOR DAN LOBI", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GayaMenu.TINTA_PUDAR)
		var f_kecil: Font = GayaMenu.huruf(GayaMenu.F_MONO, 2)
		draw_string(f_kecil, Vector2(kiri, 76.0), "SHIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GayaMenu.TINTA_PUDAR)
		draw_string(f_kecil, Vector2(kiri, 76.0), "ABSEN", HORIZONTAL_ALIGNMENT_RIGHT, lebar_isi, 10, GayaMenu.TINTA_PUDAR)
		draw_line(Vector2(kiri, 82.0), Vector2(kiri + lebar_isi, 82.0), GayaMenu.TINTA, 1.5)
		_baris_level(82.0, kiri, lebar_isi, "LV 1", "LANTAI KANTOR", _info("level_1"), true)
		_baris_level(142.0, kiri, lebar_isi, "LV 2", "LOBI GELAP", _info("level_2"), false)
		draw_line(Vector2(kiri, 233.0), Vector2(kiri + lebar_isi, 233.0), GayaMenu.GARIS_KERTAS, 1.0)
		draw_line(Vector2(kiri, 264.0), Vector2(kiri + lebar_isi, 264.0), GayaMenu.GARIS_KERTAS, 1.0)
		if not cap_bawah.is_empty():
			GayaMenu.stempel(self, Vector2(152.0, 322.0), -7.0, cap_bawah, warna_cap_bawah, 14, 2.0, skala_cap_bawah)
		if not stiker.is_empty():
			# stiker amber di baris LV 2 (contoh: LEVEL 2 TERBUKA)
			GayaMenu.stempel(self, Vector2(166.0, 171.0), -9.0, stiker, Color(0.78, 0.5, 0.08), 14, 2.5, skala_stiker)

	func _baris_level(atas: float, kiri: float, lebar_isi: float, kode: String, nama: String, info: Dictionary, level_satu: bool) -> void:
		var tamat: bool = bool(info.get("tamat", false))
		var terbuka: bool = bool(info.get("terbuka", level_satu))
		var f: Font = GayaMenu.F_MONO_TEBAL
		var warna_judul: Color = GayaMenu.TINTA if (level_satu or tamat) else GayaMenu.TINTA_ABU
		draw_string(f, Vector2(kiri, atas + 22.0), kode, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, warna_judul)
		var x_nama: float = kiri + f.get_string_size(kode, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		draw_string(f, Vector2(x_nama, atas + 22.0), nama, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, warna_judul)
		if tamat:
			var teks_cap: String = "TAMAT " + GayaMenu.format_waktu(float(info.get("waktu", 0.0)))
			var fc: Font = GayaMenu.huruf(GayaMenu.F_MONO_TEBAL, 1)
			var lebar_cap: float = fc.get_string_size(teks_cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
			GayaMenu.stempel(self, Vector2(kiri + lebar_cap * 0.5, atas + 41.0), -3.0, PackedStringArray([teks_cap]), GayaMenu.UNGU_STEMPEL, 12, 1.5)
			var jumlah: int = int(info.get("bintang", 0))
			for i in range(3):
				GayaMenu.bintang(self, Vector2(kiri + lebar_cap + 16.0 + 15.0 * float(i), atas + 41.0), 6.0, i < jumlah, GayaMenu.UNGU_STEMPEL)
		else:
			var teks: String = "belum tamat"
			if not level_satu:
				teks = "siap absen" if terbuka else "tamatkan LV 1 dulu"
			draw_string(GayaMenu.F_MONO, Vector2(kiri, atas + 45.0), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GayaMenu.TINTA_ABU)
		draw_line(Vector2(kiri, atas + 60.0), Vector2(kiri + lebar_isi, atas + 60.0), GayaMenu.GARIS_KERTAS, 1.0)


# ============================================================ tombol menu ===
## Tombol teks besar bergaris rambut (BUAT GAME, GABUNG GAME, LEVEL 1, ...).
## Segitiga amber + judul amber muncul saat tombol disorot (mouse / keyboard).
## Mouse yang masuk ke tombol ikut memindahkan fokus keyboard ke tombol itu,
## jadi hanya satu tombol yang tersorot.
class TombolMenu extends Button:
	var judul: String = ""
	var sub: String = ""
	var awalan: String = ""  # teks kecil di depan judul, misalnya "LEVEL 1"
	var ukuran_judul: int = 30
	var baseline_judul: float = 33.0
	var baseline_sub: float = 56.0
	var ikon_kunci: bool = false
	var bintang: int = -1  # -1 = bintang tidak ditampilkan
	var garis_atas: bool = false
	var garis_bawah: bool = true

	func _init() -> void:
		GayaMenu.kosongkan_gaya(self)
		mouse_entered.connect(_on_mouse_masuk)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _on_mouse_masuk() -> void:
		# Jangan rebut fokus dari kolom IP yang sedang diketik.
		var pemilik: Control = get_viewport().gui_get_focus_owner()
		if not disabled and focus_mode != Control.FOCUS_NONE and not (pemilik is LineEdit):
			grab_focus()
		queue_redraw()

	## Aktif = bisa diklik. alpha = keredupan saat tidak aktif.
	func atur_aktif(aktif: bool, alpha: float = 0.35) -> void:
		disabled = not aktif
		focus_mode = Control.FOCUS_ALL if aktif else Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if aktif else Control.CURSOR_ARROW
		modulate = Color(1, 1, 1, 1.0 if aktif else alpha)
		if not aktif and has_focus():
			release_focus()
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if garis_atas:
			draw_line(Vector2(0.0, 0.5), Vector2(w, 0.5), GayaMenu.GARIS, 1.0)
		if garis_bawah:
			draw_line(Vector2(0.0, h - 0.5), Vector2(w, h - 0.5), GayaMenu.GARIS, 1.0)
		var sorot: bool = not disabled and (has_focus() or is_hovered())
		var cy: float = h * 0.5
		if sorot:
			draw_colored_polygon(PackedVector2Array([Vector2(5.0, cy - 8.0), Vector2(17.0, cy), Vector2(5.0, cy + 8.0)]), GayaMenu.AMBER)
		var x: float = 34.0
		if awalan != "":
			var fa: Font = GayaMenu.mono(2)
			draw_string(fa, Vector2(x, baseline_judul), awalan, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GayaMenu.AMBER if sorot else GayaMenu.MUTED)
			x += fa.get_string_size(awalan, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
		var fj: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.3)
		draw_string(fj, Vector2(x, baseline_judul), judul, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran_judul, GayaMenu.AMBER if sorot else GayaMenu.INK)
		var xs: float = 34.0
		var cy_sub: float = baseline_sub - 4.5
		if ikon_kunci:
			GayaMenu.gembok(self, Vector2(xs + 5.0, cy_sub), GayaMenu.MUTED)
			xs += 18.0
		if bintang >= 0:
			for i in range(3):
				var isi: bool = i < bintang
				GayaMenu.bintang(self, Vector2(xs + 7.0 + 16.0 * float(i), cy_sub), 6.5, isi, GayaMenu.AMBER if isi else GayaMenu.MUTED)
			xs += 56.0
		if sub != "":
			draw_string(GayaMenu.mono(), Vector2(xs, baseline_sub), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GayaMenu.MUTED)


## Tombol kecil di baris bawah: KONTROL (ikon keyboard), KEMBALI / KELUAR
## (segitiga kiri), TUTUP (keycap Esc).
class TombolBawah extends Button:
	var judul: String = ""
	var ikon: String = ""  # "keyboard", "kembali", "esc", atau ""
	var ukuran_judul: int = 24
	var warna_judul: Color = GayaMenu.INK

	func _init() -> void:
		GayaMenu.kosongkan_gaya(self)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _lebar_ikon() -> float:
		match ikon:
			"keyboard":
				return 30.0 + 12.0
			"kembali":
				return 12.0 + 12.0
			"esc":
				return GayaMenu.lebar_keycap("Esc") + 10.0
		return 0.0

	func lebar_pas() -> float:
		var f: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.3)
		return _lebar_ikon() + f.get_string_size(judul, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran_judul).x + 6.0

	func _draw() -> void:
		var cy: float = size.y * 0.5
		var abu: Color = GayaMenu.MUTED
		match ikon:
			"keyboard":
				draw_rect(Rect2(1.0, cy - 9.0, 28.0, 18.0), abu, false, 1.5)
				for baris_y: float in [cy - 3.5, cy + 0.5]:
					for kx: float in [6.0, 11.0, 16.0, 21.0]:
						draw_line(Vector2(kx, baris_y), Vector2(kx + 2.0, baris_y), abu, 1.6)
				draw_line(Vector2(9.0, cy + 4.5), Vector2(21.0, cy + 4.5), abu, 1.6)
			"kembali":
				draw_colored_polygon(PackedVector2Array([Vector2(11.0, cy - 7.0), Vector2(1.0, cy), Vector2(11.0, cy + 7.0)]), abu)
			"esc":
				var lw: float = GayaMenu.lebar_keycap("Esc")
				GayaMenu.keycap(self, Rect2(0.0, cy - 13.0, lw, 26.0), "Esc")
		var sorot: bool = not disabled and (has_focus() or is_hovered())
		var warna: Color = GayaMenu.AMBER if sorot else warna_judul
		var f: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.3)
		draw_string(f, Vector2(_lebar_ikon(), cy + float(ukuran_judul) * 0.36), judul, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran_judul, warna)


## Tombol bergaris putus-putus untuk MODE EDITOR (Solo tes, Reset progres).
class TombolDebug extends Button:
	var teks: String = ""

	func _init() -> void:
		GayaMenu.kosongkan_gaya(self)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func atur_teks(t: String) -> void:
		teks = t
		var lebar: float = GayaMenu.mono().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0
		custom_minimum_size = Vector2(lebar, 30.0)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var sorot: bool = has_focus() or is_hovered()
		var warna: Color = GayaMenu.AMBER if sorot else GayaMenu.KEYCAP_GARIS
		draw_dashed_line(Vector2(0.0, 0.5), Vector2(w, 0.5), warna, 1.0, 4.0)
		draw_dashed_line(Vector2(0.0, h - 0.5), Vector2(w, h - 0.5), warna, 1.0, 4.0)
		draw_dashed_line(Vector2(0.5, 0.0), Vector2(0.5, h), warna, 1.0, 4.0)
		draw_dashed_line(Vector2(w - 0.5, 0.0), Vector2(w - 0.5, h), warna, 1.0, 4.0)
		draw_string(GayaMenu.mono(), Vector2(0.0, h * 0.5 + 4.5), teks, HORIZONTAL_ALIGNMENT_CENTER, w, 13, GayaMenu.SOFT)


# ========================================================== status titik ===
## Baris status dengan titik (hijau = tersambung, amber berkedip = menunggu)
## atau segitiga amber. Bisa ada teks kanan (IP) dan baris keterangan kecil.
class StatusTitik extends Control:
	var bentuk: String = "titik"  # "titik" atau "segitiga"
	var warna_titik: Color = GayaMenu.HIJAU
	var kedip: bool = false
	var teks: String = ""
	var teks_sorot: String = ""  # disambung setelah teks, warna amber
	var teks_kanan: String = ""
	var sub_baris: PackedStringArray = PackedStringArray()
	var garis_atas: bool = false
	var garis_bawah: bool = false
	var tengah_vertikal: bool = true
	var _nyala: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if not kedip:
			return
		var n: bool = GayaMenu.kedip_nyala()
		if n != _nyala:
			_nyala = n
			queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if garis_atas:
			draw_line(Vector2(0.0, 0.5), Vector2(w, 0.5), GayaMenu.GARIS, 1.0)
		if garis_bawah:
			draw_line(Vector2(0.0, h - 0.5), Vector2(w, h - 0.5), GayaMenu.GARIS, 1.0)
		var tinggi_isi: float = 19.0 + 19.0 * float(sub_baris.size())
		var atas: float = (h - tinggi_isi) * 0.5 if tengah_vertikal else 0.0
		var base1: float = atas + 15.0
		var cy: float = base1 - 5.0
		var warna: Color = warna_titik if (not kedip or _nyala) else Color(warna_titik, 0.12)
		if bentuk == "segitiga":
			draw_colored_polygon(PackedVector2Array([Vector2(1.0, cy - 6.0), Vector2(11.0, cy), Vector2(1.0, cy + 6.0)]), warna)
		else:
			draw_circle(Vector2(5.0, cy), 5.0, warna)
		var x: float = 24.0
		draw_string(GayaMenu.mono(), Vector2(x, base1), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GayaMenu.SOFT)
		if teks_sorot != "":
			x += GayaMenu.mono().get_string_size(teks + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(GayaMenu.mono(), Vector2(x, base1), teks_sorot, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GayaMenu.AMBER)
		if teks_kanan != "":
			draw_string(GayaMenu.mono(), Vector2(0.0, base1), teks_kanan, HORIZONTAL_ALIGNMENT_RIGHT, w, 16, GayaMenu.INK)
		for i in range(sub_baris.size()):
			draw_string(GayaMenu.mono(), Vector2(24.0, base1 + 21.0 + 18.0 * float(i)), sub_baris[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GayaMenu.MUTED)


# ========================================================== panel kontrol ===
## Deret keycap di kolom kiri panel kontrol (rata tengah dalam 118 px).
class DeretTombol extends Control:
	var tombol: PackedStringArray = PackedStringArray()
	var tahan: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(118, 26)

	func _draw() -> void:
		var jarak: float = 4.0
		var lebar: Array[float] = []
		var total: float = 0.0
		for t: String in tombol:
			var lw: float = GayaMenu.lebar_keycap(t)
			lebar.append(lw)
			total += lw
		total += jarak * float(maxi(0, tombol.size() - 1))
		var lebar_tahan: float = 0.0
		if tahan:
			lebar_tahan = GayaMenu.mono().get_string_size("tahan", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			total += 6.0 + lebar_tahan
		var x: float = (size.x - total) * 0.5
		for i in range(tombol.size()):
			GayaMenu.keycap(self, Rect2(x, 0.0, lebar[i], 26.0), tombol[i])
			x += lebar[i] + jarak
		if tahan:
			draw_string(GayaMenu.mono(), Vector2(x + 2.0, 17.0), "tahan", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GayaMenu.MUTED)


## Panel KONTROL: semua kontrol Level 1 dan Level 2 dalam tiga kolom.
## Ditutup dengan tombol TUTUP, Esc, atau klik di luar kotak.
class PanelKontrol extends Control:
	signal ditutup

	var _tombol_tutup: Button = null

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		var redup := ColorRect.new()
		redup.color = Color(0.02, 0.016, 0.027, 0.88)
		redup.set_anchors_preset(Control.PRESET_FULL_RECT)
		redup.mouse_filter = Control.MOUSE_FILTER_STOP
		redup.gui_input.connect(_on_redup_input)
		add_child(redup)
		var tengah := CenterContainer.new()
		tengah.set_anchors_preset(Control.PRESET_FULL_RECT)
		tengah.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tengah)
		var kotak := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = GayaMenu.PANEL
		sb.border_color = GayaMenu.GARIS
		sb.set_border_width_all(1)
		sb.content_margin_left = 40
		sb.content_margin_right = 40
		sb.content_margin_top = 30
		sb.content_margin_bottom = 36
		kotak.add_theme_stylebox_override("panel", sb)
		kotak.custom_minimum_size = Vector2(1000, 0)
		kotak.mouse_filter = Control.MOUSE_FILTER_STOP
		tengah.add_child(kotak)
		var isi := VBoxContainer.new()
		isi.add_theme_constant_override("separation", 28)
		kotak.add_child(isi)
		var kepala := HBoxContainer.new()
		isi.add_child(kepala)
		var judul: Label = GayaMenu.label("KONTROL", GayaMenu.huruf(GayaMenu.F_DISPLAY, 2, 0.6), 48, GayaMenu.INK)
		judul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kepala.add_child(judul)
		var tutup: TombolBawah = GayaMenu.tombol_bawah("TUTUP", "esc", 22)
		tutup.warna_judul = GayaMenu.AMBER
		tutup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tutup.pressed.connect(tutup_panel)
		kepala.add_child(tutup)
		_tombol_tutup = tutup
		var deret := HBoxContainer.new()
		deret.add_theme_constant_override("separation", 32)
		isi.add_child(deret)
		for kolom: Array in GayaMenu.KOLOM_KONTROL:
			deret.add_child(_bangun_kolom(kolom))

	func _bangun_kolom(kolom: Array) -> Control:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		v.custom_minimum_size = Vector2(285, 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kepala := VBoxContainer.new()
		kepala.add_theme_constant_override("separation", 8)
		kepala.add_child(GayaMenu.label(String(kolom[0]), GayaMenu.huruf(GayaMenu.F_MONO_TEBAL, 2), 13, GayaMenu.AMBER))
		kepala.add_child(GayaMenu.garis_rambut())
		v.add_child(kepala)
		var daftar: Array = kolom[1]
		for baris: Array in daftar:
			v.add_child(_bangun_baris(baris))
		return v

	func _bangun_baris(baris: Array) -> Control:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var deret := DeretTombol.new()
		deret.tombol = PackedStringArray(baris[0])
		deret.tahan = bool(baris[1])
		deret.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(deret)
		var teks: Label = GayaMenu.label(String(baris[2]), GayaMenu.mono(), 14, GayaMenu.SOFT)
		teks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		teks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		teks.custom_minimum_size = Vector2(150, 0)
		h.add_child(teks)
		return h

	func buka() -> void:
		visible = true
		if _tombol_tutup != null:
			_tombol_tutup.grab_focus()

	func tutup_panel() -> void:
		if not visible:
			return
		visible = false
		ditutup.emit()

	func _on_redup_input(event: InputEvent) -> void:
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			tutup_panel()

	func _unhandled_input(event: InputEvent) -> void:
		if visible and event.is_action_pressed("ui_cancel"):
			tutup_panel()
			get_viewport().set_input_as_handled()


# ========================================================= pesan terminal ===
## Satu baris pesan bergaya terminal: "> TEKS" + kursor kotak berkedip.
## Dipakai baris merah "LISTRIK PADAM" di intro dan pesan di layar saat
## main di Level 1 (merah = bahaya, amber = info). Teks bisa muncul seperti
## diketik lewat `huruf` (jumlah huruf yang sudah tampil, -1 = semua).
## Kotak latar dibuat selebar teks penuh supaya tidak melebar saat mengetik.
class PesanTerminal extends Control:
	var teks: String = "":
		set(v):
			teks = v
			queue_redraw()
	var warna: Color = GayaMenu.LED
	var latar: bool = true
	var huruf: int = -1:
		set(v):
			huruf = v
			queue_redraw()
	var kursor: bool = true
	var ukuran: int = 17
	var _nyala: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		var n: bool = GayaMenu.kedip_nyala()
		if n != _nyala:
			_nyala = n
			queue_redraw()

	func selesai_mengetik() -> bool:
		return huruf < 0 or huruf >= ("> " + teks).length()

	func _draw() -> void:
		if teks == "":
			return
		var f: Font = GayaMenu.huruf(GayaMenu.F_MONO_TEBAL, 1)
		var penuh: String = "> " + teks
		var tampil: String = penuh if huruf < 0 else penuh.substr(0, clampi(huruf, 0, penuh.length()))
		var lebar_penuh: float = f.get_string_size(penuh, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x
		var lebar_kotak: float = lebar_penuh + (14.0 + 10.0 + 9.0 + 18.0 if latar else 9.0 + 10.0)
		var tinggi: float = float(ukuran) + 18.0
		var x0: float = (size.x - lebar_kotak) * 0.5
		var y_tengah: float = size.y * 0.5
		var x_teks: float = x0
		if latar:
			var kotak := Rect2(x0, y_tengah - tinggi * 0.5, lebar_kotak, tinggi)
			draw_rect(kotak, Color(0.031, 0.027, 0.024, 0.86))
			draw_rect(kotak, Color(warna.r * 0.45, warna.g * 0.4, warna.b * 0.38, 0.9), false, 1.0)
			draw_rect(Rect2(x0 + 14.0, y_tengah - 9.0, 3.0, 18.0), warna)
			x_teks = x0 + 14.0 + 3.0 + 10.0
		var baseline: float = y_tengah + float(ukuran) * 0.36
		draw_string(f, Vector2(x_teks + 1.0, baseline + 1.0), tampil, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(x_teks, baseline), tampil, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)
		if kursor and _nyala:
			var x_kursor: float = x_teks + f.get_string_size(tampil, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x + 4.0
			draw_rect(Rect2(x_kursor, baseline - float(ukuran) * 0.78, 9.0, float(ukuran)), warna)


# ============================================================ teks diketik ===
## Paragraf yang muncul huruf demi huruf, dibungkus otomatis selebar
## `lebar_maks`, dengan kursor kotak amber berkedip di ujung teks.
## Dipakai cerita pembuka Level 1.
class TeksKetik extends Control:
	var teks: String = "":
		set(v):
			teks = v
			queue_redraw()
	var huruf: int = -1:
		set(v):
			huruf = v
			queue_redraw()
	var ukuran: int = 24
	var warna: Color = GayaMenu.INK
	var kursor: bool = true
	var lebar_maks: float = 880.0
	var jarak_baris: float = 36.0
	var _nyala: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		var n: bool = GayaMenu.kedip_nyala()
		if n != _nyala and kursor:
			_nyala = n
			queue_redraw()

	## Pecah teks jadi baris-baris yang muat dalam lebar_maks (per kata).
	func _baris(f: Font, isi: String) -> PackedStringArray:
		var hasil := PackedStringArray()
		var sekarang: String = ""
		for kata: String in isi.split(" ", false):
			var coba: String = kata if sekarang == "" else sekarang + " " + kata
			if f.get_string_size(coba, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x > lebar_maks and sekarang != "":
				hasil.append(sekarang)
				sekarang = kata
			else:
				sekarang = coba
		if sekarang != "":
			hasil.append(sekarang)
		return hasil

	## Tinggi paragraf penuh (untuk menata paragraf berikutnya).
	func tinggi_penuh() -> float:
		var n: int = maxi(1, _baris(GayaMenu.mono(), teks).size())
		return jarak_baris * float(n)

	func _draw() -> void:
		var f: Font = GayaMenu.mono()
		var semua: PackedStringArray = _baris(f, teks)
		var sisa: int = teks.length() if huruf < 0 else huruf
		var y: float = float(ukuran)
		var x_akhir: float = 0.0
		var y_akhir: float = y
		for b: String in semua:
			if sisa <= 0:
				break
			var potong: String = b.substr(0, mini(sisa, b.length()))
			draw_string(f, Vector2(0.0, y), potong, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)
			x_akhir = f.get_string_size(potong, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x
			y_akhir = y
			sisa -= b.length() + 1
			y += jarak_baris
		if kursor and _nyala:
			draw_rect(Rect2(x_akhir + 5.0, y_akhir - float(ukuran) * 0.8, 12.0, float(ukuran)), GayaMenu.AMBER)


# ========================================================= petunjuk tombol ===
## Deret petunjuk "[Spasi] lanjut  [Esc] lewati", rata kanan.
class PetunjukTombol extends Control:
	var isi: Array = [["Spasi", "lanjut"], ["Esc", "lewati"]]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f: Font = GayaMenu.mono()
		var x: float = size.x
		var cy: float = size.y * 0.5
		for i in range(isi.size() - 1, -1, -1):
			var pasangan: Array = isi[i]
			var tombol: String = String(pasangan[0])
			var arti: String = String(pasangan[1])
			var w_arti: float = f.get_string_size(arti, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			x -= w_arti
			draw_string(f, Vector2(x, cy + 4.5), arti, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GayaMenu.MUTED)
			var w_tombol: float = GayaMenu.lebar_keycap(tombol)
			x -= 8.0 + w_tombol
			GayaMenu.keycap(self, Rect2(x, cy - 13.0, w_tombol, 26.0), tombol)
			x -= 22.0


# ================================================================ polaroid ===
## Foto P1 / P2 yang ditempel selotip (intro). Bisa diberi cap merah
## (TERJEBAK, DIKURUNG) dengan animasi lewat `skala_cap`.
class Polaroid extends Control:
	var label: String = "P1"
	var derajat: float = -5.0
	var cap: String = ""
	var skala_cap: float = 0.0:
		set(v):
			skala_cap = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(66, 82)

	func _draw() -> void:
		var pusat: Vector2 = size * 0.5
		draw_set_transform(pusat, deg_to_rad(derajat), Vector2.ONE)
		var o: Vector2 = -size * 0.5
		draw_rect(Rect2(o + Vector2(2.0, 5.0), size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(o, size), Color(0.929, 0.906, 0.855))
		draw_rect(Rect2(o + Vector2(5.0, 5.0), Vector2(size.x - 10.0, 52.0)), Color(0.176, 0.173, 0.2))
		var fd: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.4)
		draw_string(fd, o + Vector2(0.0, 41.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.541, 0.51, 0.459))
		draw_string(GayaMenu.F_MONO_TEBAL, o + Vector2(0.0, 74.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, GayaMenu.TINTA)
		# selotip
		draw_rect(Rect2(o + Vector2(20.0, -7.0), Vector2(26.0, 11.0)), Color(0.925, 0.886, 0.769, 0.65))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if cap != "" and skala_cap > 0.01:
			GayaMenu.stempel(self, pusat + Vector2(0.0, -6.0), -14.0, PackedStringArray([cap]), Color(0.722, 0.161, 0.118), 10, 2.0, skala_cap)
