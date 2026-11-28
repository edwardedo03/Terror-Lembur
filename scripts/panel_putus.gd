class_name PanelPutus
extends CanvasLayer
## Panel "KONEKSI PUTUS", dipakai HUD Level 1 dan Level 2.
##
## Jenis:
## - "host_keluar": host menekan MENU UTAMA setelah level selesai.
## - "host_putus" : koneksi ke host hilang di tengah permainan.
## - "teman_putus": di PC host, teman terputus. Game dijeda; kalau teman
##                  join lagi, game langsung lanjut (panel disembunyikan).
## Kalau `detik` > 0, bar amber berjalan mundur menuju kembali ke menu
## utama (perpindahannya sendiri tetap diatur level, _disconnect_timer).
##
## CanvasLayer sendiri (layer 26) supaya di atas panel hasil (layer 25).

signal menu_utama

const LAYER_PUTUS: int = 26
const MERAH := Color(0.82, 0.376, 0.247)

var _akar: Control = null
var _judul: Label = null
var _kalimat: Label = null
var _bar_latar: ColorRect = null
var _bar_isi: ColorRect = null
var _baris_tunggu: GayaMenu.StatusTitik = null
var _tombol: GayaMenu.TombolBawah = null
var _sisa: float = 0.0
var _total: float = 0.0


func _init() -> void:
	layer = LAYER_PUTUS
	visible = false
	_bangun()


func tampilkan(jenis: String, detik: float = 0.0) -> void:
	match jenis:
		"host_keluar":
			_judul.text = "HOST KELUAR DARI GAME"
			_kalimat.text = "Kamu kembali ke menu utama sebentar lagi."
			_tombol.judul = "KE MENU UTAMA SEKARANG"
		"host_putus":
			_judul.text = "KONEKSI KE HOST HILANG"
			_kalimat.text = "Kamu kembali ke menu utama sebentar lagi."
			_tombol.judul = "KE MENU UTAMA SEKARANG"
		_:
			_judul.text = "TEMAN TERPUTUS"
			_kalimat.text = "Game dijeda. Kalau temanmu join lagi, game langsung lanjut."
			_tombol.judul = "KEMBALI KE MENU UTAMA"
	_tombol.custom_minimum_size = Vector2(_tombol.lebar_pas(), 44.0)
	_tombol.queue_redraw()
	_total = detik
	_sisa = detik
	_bar_latar.visible = detik > 0.0
	_baris_tunggu.visible = jenis == "teman_putus"
	visible = true
	_tombol.call_deferred("grab_focus")


func sembunyikan() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible or _total <= 0.0:
		return
	_sisa = maxf(0.0, _sisa - delta)
	_bar_isi.size.x = _bar_latar.size.x * (_sisa / _total)


func _bangun() -> void:
	_akar = Control.new()
	_akar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_akar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_akar)
	var redup := ColorRect.new()
	redup.set_anchors_preset(Control.PRESET_FULL_RECT)
	redup.color = Color(0.024, 0.02, 0.031, 0.78)
	redup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_akar.add_child(redup)
	var tengah := CenterContainer.new()
	tengah.set_anchors_preset(Control.PRESET_FULL_RECT)
	tengah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_akar.add_child(tengah)
	var kotak := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = GayaMenu.PANEL
	sb.border_color = GayaMenu.GARIS
	sb.set_border_width_all(1)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 30
	sb.content_margin_bottom = 22
	kotak.add_theme_stylebox_override("panel", sb)
	kotak.custom_minimum_size = Vector2(560, 0)
	tengah.add_child(kotak)
	var isi := VBoxContainer.new()
	isi.add_theme_constant_override("separation", 14)
	kotak.add_child(isi)
	var kepala := GayaMenu.StatusTitik.new()
	kepala.warna_titik = MERAH
	kepala.kedip = true
	kepala.teks = ""
	kepala.custom_minimum_size = Vector2(480, 20)
	kepala.tengah_vertikal = false
	isi.add_child(kepala)
	var label_kepala: Label = GayaMenu.label("KONEKSI PUTUS", GayaMenu.huruf(GayaMenu.F_MONO_TEBAL, 3), 13, MERAH)
	label_kepala.position = Vector2(24, 0)
	kepala.add_child(label_kepala)
	_judul = GayaMenu.label("", GayaMenu.huruf(GayaMenu.F_DISPLAY, 1, 0.6), 46, GayaMenu.INK)
	_judul.add_theme_color_override("font_shadow_color", GayaMenu.MERAH_AKSEN)
	_judul.add_theme_constant_override("shadow_offset_x", 3)
	_judul.add_theme_constant_override("shadow_offset_y", 0)
	isi.add_child(_judul)
	_kalimat = GayaMenu.label("", GayaMenu.mono(), 15, GayaMenu.SOFT)
	_kalimat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kalimat.custom_minimum_size = Vector2(480, 0)
	isi.add_child(_kalimat)
	_bar_latar = ColorRect.new()
	_bar_latar.color = Color(0.141, 0.125, 0.102)
	_bar_latar.custom_minimum_size = Vector2(480, 4)
	isi.add_child(_bar_latar)
	_bar_isi = ColorRect.new()
	_bar_isi.color = GayaMenu.AMBER
	_bar_isi.size = Vector2(480, 4)
	_bar_latar.add_child(_bar_isi)
	_baris_tunggu = GayaMenu.StatusTitik.new()
	_baris_tunggu.warna_titik = GayaMenu.AMBER
	_baris_tunggu.kedip = true
	_baris_tunggu.teks = "Menunggu teman join lagi"
	_baris_tunggu.tengah_vertikal = false
	_baris_tunggu.custom_minimum_size = Vector2(480, 22)
	isi.add_child(_baris_tunggu)
	isi.add_child(GayaMenu.garis_rambut())
	_tombol = GayaMenu.tombol_bawah("KE MENU UTAMA SEKARANG", "kembali")
	_tombol.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tombol.pressed.connect(func() -> void: menu_utama.emit())
	isi.add_child(_tombol)
	GayaMenu.pasang_vinyet(_akar)
