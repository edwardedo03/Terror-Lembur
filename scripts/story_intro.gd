extends Control
## Cerita pembuka Level 1 (efek mesin ketik), gayanya sama dengan menu.
##
## CARA ISI CERITA (untuk Edward):
##   Ubah isi STORY_LINES di bawah dengan ceritamu sendiri.
##   Satu baris = satu paragraf yang diketik. Kalau mau cerita lebih
##   panjang atau pendek, tambah atau hapus baris saja. Penanda baris di
##   bawah paragraf (garis kecil) menyesuaikan sendiri.
##
## TAMPILAN (semua digambar dari kode, tanpa gambar):
##   pita hitam atas dan bawah, baris kecil "LEVEL 1  LANTAI KANTOR  21.00",
##   paragraf sebelumnya diredupkan, paragraf sekarang diketik dengan kursor
##   amber, penanda baris (sudah dibaca, sekarang, belum), dan petunjuk
##   tombol di kanan bawah.
##
## CARA MAIN: ketikan jalan sendiri (~30 huruf/detik).
##   - Spasi / tombol apa saja / klik: selesaikan baris yang sedang diketik.
##   - Tekan lagi: lanjut ke baris berikutnya.
##   - Esc: lewati semua cerita, langsung mulai game.
## Setelah baris terakhir: tekan tombol apa saja untuk mulai main.

const STORY_LINES: Array[String] = [
	"Malam Jumat, pukul 21.00. Kantor sudah sepi, hanya tersisa kami berdua.",
	"Lembur lagi. Laporan harus selesai sebelum pagi, dan lift sudah dimatikan sejak sore.",
	"Tapi malam ini ada yang berbeda. Lampu koridor berkedip sendiri. Dan langkah kaki itu... bukan langkah kami.",
	"Dia masih di sini. Penunggu kantor ini. Dan dia tidak suka ada yang lembur.",
	"Selesaikan semua tugas. Jangan sampai tertangkap. Dan kabur sebelum pagi.",
]
const CHARS_PER_SECOND: float = 30.0
const NEXT_SCENE: String = "res://scenes/level_1.tscn"

const KIRI: float = 200.0
const ATAS_PARAGRAF: float = 226.0
const JARAK_PARAGRAF: float = 26.0
const LEBAR_PARAGRAF: float = 880.0
const WARNA_LALU := Color(0.435, 0.404, 0.357)  # paragraf yang sudah dibaca
const TINGGI_PITA: float = 48.0

var _line: int = 0
var _shown: int = 0
var _char_accum: float = 0.0
var _waiting: bool = false  # baris sudah lengkap, menunggu input untuk lanjut
var _selesai: bool = false  # sudah pindah ke level (jangan dobel)

var _paragraf_lalu: GayaMenu.TeksKetik = null
var _paragraf_kini: GayaMenu.TeksKetik = null
var _penanda: _PenandaBaris = null
var _petunjuk: GayaMenu.PetunjukTombol = null


func _ready() -> void:
	GayaMenu.pasang_latar(self)
	# Cahaya lampu hangat dipindah ke tengah (di menu ada di atas mesin absen).
	var cahaya: Control = get_node_or_null("CahayaLampu") as Control
	if cahaya != null:
		cahaya.position = Vector2(640.0, 330.0) - cahaya.size * 0.5
		cahaya.modulate.a = 0.7
	_pasang_pita()
	GayaMenu.baris_atas(self, Vector2(KIRI, 112.0), PackedStringArray(["LEVEL 1", "LANTAI KANTOR", "21.00"]))

	_paragraf_lalu = _buat_paragraf(WARNA_LALU, false)
	_paragraf_lalu.visible = false
	_paragraf_kini = _buat_paragraf(GayaMenu.INK, true)

	_penanda = _PenandaBaris.new()
	_penanda.jumlah = STORY_LINES.size()
	_penanda.position = Vector2(KIRI, 560.0)
	_penanda.size = Vector2(400.0, 4.0)
	add_child(_penanda)

	_petunjuk = GayaMenu.PetunjukTombol.new()
	_petunjuk.isi = [["Spasi", "lanjut"], ["Esc", "lewati cerita"]]
	_petunjuk.position = Vector2(1280.0 - 96.0 - 600.0, 720.0 - 76.0 - 26.0)
	_petunjuk.size = Vector2(600.0, 26.0)
	add_child(_petunjuk)

	GayaMenu.pasang_vinyet(self)
	if STORY_LINES.is_empty():
		call_deferred("_start_game")
		return
	_tampilkan_baris()


func _process(delta: float) -> void:
	if _waiting or _line >= STORY_LINES.size():
		return
	_char_accum += delta * CHARS_PER_SECOND
	var target: int = int(_char_accum)
	if target > _shown:
		_shown = mini(target, STORY_LINES[_line].length())
		_paragraf_kini.huruf = _shown
		if _shown >= STORY_LINES[_line].length():
			_baris_lengkap()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			_start_game()
			return
		_advance()
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		if m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			_advance()


func _advance() -> void:
	if _line >= STORY_LINES.size():
		_start_game()
		return
	if not _waiting:
		# Baris masih diketik: selesaikan langsung.
		_shown = STORY_LINES[_line].length()
		_paragraf_kini.huruf = -1
		_baris_lengkap()
		return
	_line += 1
	if _line >= STORY_LINES.size():
		_start_game()
		return
	_tampilkan_baris()


## Siapkan paragraf baris ke-_line: paragraf sebelumnya diredupkan di atas,
## paragraf baru mulai diketik dari huruf pertama di bawahnya.
func _tampilkan_baris() -> void:
	_shown = 0
	_char_accum = 0.0
	_waiting = false
	var y: float = ATAS_PARAGRAF
	if _line > 0:
		_paragraf_lalu.teks = STORY_LINES[_line - 1]
		_paragraf_lalu.huruf = -1
		_paragraf_lalu.visible = true
		y += _paragraf_lalu.tinggi_penuh() + JARAK_PARAGRAF
	_paragraf_kini.position = Vector2(KIRI, y)
	_paragraf_kini.teks = STORY_LINES[_line]
	_paragraf_kini.huruf = 0
	_penanda.sekarang = _line
	_penanda.queue_redraw()
	_atur_petunjuk(false)


func _baris_lengkap() -> void:
	_waiting = true
	_atur_petunjuk(true)


func _atur_petunjuk(lengkap: bool) -> void:
	var terakhir: bool = _line >= STORY_LINES.size() - 1
	var arti: String = "mulai main" if (lengkap and terakhir) else "lanjut"
	_petunjuk.isi = [["Spasi", arti], ["Esc", "lewati cerita"]]
	_petunjuk.queue_redraw()


func _buat_paragraf(warna: Color, kursor: bool) -> GayaMenu.TeksKetik:
	var p := GayaMenu.TeksKetik.new()
	p.ukuran = 24
	p.jarak_baris = 36.0
	p.lebar_maks = LEBAR_PARAGRAF
	p.warna = warna
	p.kursor = kursor
	p.position = Vector2(KIRI, ATAS_PARAGRAF)
	p.size = Vector2(LEBAR_PARAGRAF + 40.0, 120.0)
	add_child(p)
	return p


func _pasang_pita() -> void:
	for atas: bool in [true, false]:
		var pita := ColorRect.new()
		pita.color = Color(0, 0, 0, 1)
		pita.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pita.anchor_right = 1.0
		if atas:
			pita.offset_bottom = TINGGI_PITA
		else:
			pita.anchor_top = 1.0
			pita.anchor_bottom = 1.0
			pita.offset_top = -TINGGI_PITA
		add_child(pita)


func _start_game() -> void:
	if _selesai:
		return
	_selesai = true
	get_tree().change_scene_to_file(NEXT_SCENE)


## Penanda baris: garis kecil per paragraf. Sudah dibaca = abu, sekarang =
## amber, belum = gelap.
class _PenandaBaris extends Control:
	var jumlah: int = 5
	var sekarang: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in range(jumlah):
			var warna: Color = GayaMenu.GARIS
			if i < sekarang:
				warna = GayaMenu.MUTED
			elif i == sekarang:
				warna = GayaMenu.AMBER
			draw_rect(Rect2(float(i) * 34.0, 0.0, 26.0, 3.0), warna)
