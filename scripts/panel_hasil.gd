class_name PanelHasil
extends CanvasLayer
## Panel hasil akhir level, dipakai HUD Level 1 (hud.gd) dan HUD Level 2
## (hud_level2.gd) supaya tampilannya sama. Gayanya mengikuti menu (Opsi D):
##
## Kiri : baris kecil "LEVEL 1  LANTAI KANTOR  SELESAI", judul ending besar
##        dengan bayangan berwarna (hijau Happy, amber Bad, merah Gagal),
##        satu kalimat ringkasan, lalu daftar WAKTU, TERTANGKAP, TUGAS,
##        PENILAIAN (bintang).
## Kanan: kartu lembur yang "dicap". Isinya progres yang tersimpan
##        (GameProgress), cap bawah SUDAH PULANG (ungu) atau BELUM BOLEH
##        PULANG (merah), dan stiker amber LEVEL 2 TERBUKA saat Level 1
##        pertama kali tamat. Cap dan stiker muncul dengan animasi "dicap".
## Bawah: tombol teks. Host (dan solo tes): PILIH LEVEL, MAIN LAGI,
##        MENU UTAMA. Teman: MAIN LAGI dan MENU UTAMA, plus catatan bahwa
##        level berikutnya dipilih host.
##
## CanvasLayer sendiri (layer 25) supaya selalu di atas widget HUD lain
## (HudKantor layer 9, HUD layer 10, HudMalam layer 11, denah layer 12).

signal main_lagi
signal pilih_level
signal menu_utama

const LAYER_HASIL: int = 25
const WARNA_HAPPY := Color(0.561, 0.71, 0.451)
const WARNA_BAD := Color(0.91, 0.639, 0.239)
const WARNA_GAGAL := Color(0.784, 0.216, 0.176)
const UNGU := Color(0.29, 0.243, 0.549)

var _akar: Control = null
var _baris_atas: HBoxContainer = null
var _judul: GayaMenu.JudulBesar = null
var _kalimat: Label = null
var _daftar: _DaftarStat = null
var _kartu: GayaMenu.KartuLembur = null
var _tombol_main_lagi: GayaMenu.TombolMenu = null
var _tombol_pilih: GayaMenu.TombolMenu = null
var _tombol_menu: GayaMenu.TombolMenu = null
var _baris_tombol: HBoxContainer = null
var _catatan_teman: Label = null
var _level_label: String = "LEVEL 1  LANTAI KANTOR"
var _ada_level_baru: bool = false
var _tween: Tween = null


func _init() -> void:
	layer = LAYER_HASIL
	visible = false
	_bangun()


## Nama level di baris kecil kiri atas, misalnya "LEVEL 2  LOBI GELAP".
func atur_level(teks: String) -> void:
	_level_label = teks


## Tampilkan hasil. level_baru = id level yang baru terbuka ("" = tidak ada).
func tampilkan(success: bool, stars: int, ending: String, time_sec: float, deaths: int, done: int, total: int, level_baru: String = "") -> void:
	var teman: bool = NetworkManager.mode == NetworkManager.Mode.CLIENT
	var warna: Color = WARNA_GAGAL
	var kalimat: String = "Kedua pemain tertangkap sebelum sempat kabur."
	if success and ending == "Happy Ending":
		warna = WARNA_HAPPY
		kalimat = "Kalian kabur berdua tanpa ada yang tertangkap."
	elif success:
		warna = WARNA_BAD
		kalimat = "Kalian berhasil kabur, tapi sempat tertangkap %d kali." % deaths
	# Baris atas: nama level + status (warna sesuai ending).
	for anak: Node in _baris_atas.get_children():
		anak.queue_free()
	var bagian: PackedStringArray = PackedStringArray(_level_label.split("  "))
	bagian.append("SELESAI" if success else "GAGAL")
	var f_kecil: Font = GayaMenu.mono(2)
	for i in range(bagian.size()):
		var w: Color = warna if i == bagian.size() - 1 else GayaMenu.MUTED
		_baris_atas.add_child(GayaMenu.label(bagian[i], f_kecil, 14, w))
	_judul.baris = PackedStringArray([(ending if success else "GAGAL").to_upper()])
	_judul.warna_bayang = warna
	_judul.queue_redraw()
	_kalimat.text = kalimat
	_daftar.waktu = GayaMenu.format_waktu(time_sec)
	_daftar.tertangkap = "%d kali" % deaths
	_daftar.tugas = "%d dari %d" % [done, total]
	_daftar.bintang = stars
	_daftar.queue_redraw()
	# Kartu lembur: progres tersimpan (hasil level ini sudah dicatat
	# GameProgress sebelum panel ini muncul), lalu cap dan stiker.
	_kartu.atur_progres(GameProgress.ringkasan())
	_ada_level_baru = level_baru != ""
	if success:
		_kartu.cap_bawah = PackedStringArray(["SUDAH", "PULANG"])
		_kartu.warna_cap_bawah = Color(UNGU, 0.85)
	else:
		_kartu.cap_bawah = PackedStringArray(["BELUM BOLEH", "PULANG"])
		_kartu.warna_cap_bawah = Color(GayaMenu.MERAH_STEMPEL, 0.85)
	_kartu.stiker = PackedStringArray(["LEVEL 2", "TERBUKA"]) if _ada_level_baru else PackedStringArray()
	# Tombol sesuai peran.
	_tombol_pilih.visible = not teman
	_catatan_teman.visible = teman
	visible = true
	_animasi_masuk()
	var fokus: Control = _tombol_pilih if (_ada_level_baru and not teman) else _tombol_main_lagi
	fokus.call_deferred("grab_focus")


func sembunyikan() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false


func is_tampil() -> bool:
	return visible


## Untuk smoke test: apakah stiker LEVEL 2 TERBUKA dipasang.
func ada_cap_level_baru() -> bool:
	return _ada_level_baru


# ---------------------------------------------------------------- animasi ---
func _animasi_masuk() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_akar.modulate.a = 0.0
	_kartu.position = Vector2(900.0, 92.0)
	_kartu.skala_cap_bawah = 0.0
	_kartu.skala_stiker = 0.0
	_tween = create_tween()
	_tween.tween_property(_akar, "modulate:a", 1.0, 0.35)
	_tween.parallel().tween_property(_kartu, "position", Vector2(846.0, 92.0), 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.15)
	_tween.tween_callback(_bunyi_cap)
	_tween.tween_property(_kartu, "skala_cap_bawah", 1.0, 0.18).from(1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _ada_level_baru:
		_tween.tween_interval(0.25)
		_tween.tween_callback(_bunyi_cap)
		_tween.tween_property(_kartu, "skala_stiker", 1.0, 0.2).from(1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _bunyi_cap() -> void:
	SfxManager.play_local(&"keypad_click")


# ---------------------------------------------------------------- bangun ---
func _bangun() -> void:
	_akar = Control.new()
	_akar.name = "PanelHasil"
	_akar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_akar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_akar)
	var redup := ColorRect.new()
	redup.set_anchors_preset(Control.PRESET_FULL_RECT)
	redup.color = Color(0.024, 0.02, 0.031, 0.86)
	redup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_akar.add_child(redup)
	# Kiri: baris kecil, judul, kalimat, daftar angka.
	_baris_atas = HBoxContainer.new()
	_baris_atas.position = Vector2(96, 78)
	_baris_atas.add_theme_constant_override("separation", 22)
	_baris_atas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_akar.add_child(_baris_atas)
	_judul = GayaMenu.JudulBesar.new()
	_judul.ukuran = 100
	_judul.baseline_pertama = 84.0
	_judul.position = Vector2(96, 109)
	_judul.size = Vector2(700, 110)
	_akar.add_child(_judul)
	_kalimat = GayaMenu.label("", GayaMenu.mono(), 16, GayaMenu.SOFT)
	_kalimat.position = Vector2(96, 214)
	_kalimat.size = Vector2(620, 24)
	_akar.add_child(_kalimat)
	_daftar = _DaftarStat.new()
	_daftar.position = Vector2(96, 260)
	_daftar.size = Vector2(460, 4 * 46 + 1)
	_akar.add_child(_daftar)
	# Bawah: tombol teks.
	_baris_tombol = HBoxContainer.new()
	_baris_tombol.position = Vector2(96, 534)
	_baris_tombol.add_theme_constant_override("separation", 22)
	_akar.add_child(_baris_tombol)
	_tombol_pilih = _tombol("PILIH LEVEL")
	_tombol_pilih.pressed.connect(func() -> void: pilih_level.emit())
	_tombol_main_lagi = _tombol("MAIN LAGI")
	_tombol_main_lagi.pressed.connect(func() -> void: main_lagi.emit())
	_tombol_menu = _tombol("MENU UTAMA")
	_tombol_menu.pressed.connect(func() -> void: menu_utama.emit())
	_catatan_teman = GayaMenu.label("Level berikutnya dipilih host. Kamu ikut pindah otomatis.", GayaMenu.mono(), 13, GayaMenu.MUTED)
	_catatan_teman.position = Vector2(130, 592)
	_catatan_teman.visible = false
	_akar.add_child(_catatan_teman)
	# Kanan: kartu lembur yang dicap (sedikit miring).
	_kartu = GayaMenu.KartuLembur.new()
	_kartu.position = Vector2(846, 92)
	_kartu.pivot_offset = _kartu.size * 0.5
	_kartu.rotation = deg_to_rad(2.0)
	_akar.add_child(_kartu)
	GayaMenu.pasang_vinyet(_akar)


func _tombol(teks: String) -> GayaMenu.TombolMenu:
	var b := GayaMenu.TombolMenu.new()
	b.judul = teks
	b.ukuran_judul = 30
	b.baseline_judul = 34.0
	b.garis_bawah = false
	var lebar: float = GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.3).get_string_size(teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	b.custom_minimum_size = Vector2(34.0 + lebar + 8.0, 48.0)
	_baris_tombol.add_child(b)
	return b


## Daftar WAKTU / TERTANGKAP / TUGAS / PENILAIAN dengan garis rambut.
class _DaftarStat extends Control:
	var waktu: String = "00:00"
	var tertangkap: String = "0 kali"
	var tugas: String = "0 dari 0"
	var bintang: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var tinggi: float = 46.0
		var f_label: Font = GayaMenu.mono(2)
		var f_nilai: Font = GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.3)
		draw_line(Vector2(0.0, 0.5), Vector2(w, 0.5), GayaMenu.GARIS, 1.0)
		var baris: Array = [["WAKTU", waktu], ["TERTANGKAP", tertangkap], ["TUGAS", tugas], ["PENILAIAN", ""]]
		for i in range(baris.size()):
			var atas: float = tinggi * float(i)
			var bl: float = atas + 32.0
			draw_string(f_label, Vector2(0.0, bl), String(baris[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GayaMenu.MUTED)
			if i < 3:
				draw_string(f_nilai, Vector2(0.0, bl + 1.0), String(baris[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, w, 28, GayaMenu.INK)
			else:
				var teks: String = "%d/3" % bintang
				var lebar_teks: float = f_nilai.get_string_size(teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
				draw_string(f_nilai, Vector2(w - lebar_teks, bl + 1.0), teks, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, GayaMenu.INK)
				var x: float = w - lebar_teks - 14.0 - 3.0 * 24.0
				for k in range(3):
					var isi: bool = k < bintang
					GayaMenu.bintang(self, Vector2(x + 10.0 + 24.0 * float(k), bl - 9.0), 9.5, isi, GayaMenu.AMBER if isi else GayaMenu.MUTED)
			draw_line(Vector2(0.0, atas + tinggi - 0.5), Vector2(w, atas + tinggi - 0.5), GayaMenu.GARIS, 1.0)
