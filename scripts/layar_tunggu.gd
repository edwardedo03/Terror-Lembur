class_name LayarTunggu
extends CanvasLayer
## Layar tunggu di PC teman (P2) sampai state penuh pertama dari host tiba.
## Menutupi map supaya teman tidak sempat melihat seluruh peta tanpa kamera
## pemain. Gayanya sama dengan menu (judul besar, baris status berkedip).
##
## - Level 1: "MENUNGGU HOST", karena host masih membaca cerita pembuka.
## - Level 2: "MEMUAT LOBI GELAP", tinggal menunggu data dari host.
##
## Pakai: var l := LayarTunggu.new(); l.level_satu = false; add_child(l)
## lalu l.tutup() saat state pertama diterima (memudar 0.35 detik).

const LAYER_TUNGGU: int = 100
const TINGGI_PITA: float = 48.0

var level_satu: bool = true

var _akar: Control = null
var _status: GayaMenu.StatusTitik = null
var _waktu: float = 0.0
var _jumlah_titik: int = -1


func _ready() -> void:
	layer = LAYER_TUNGGU
	_bangun()


func _process(delta: float) -> void:
	# Titik tiga di ujung status bertambah satu per satu: ".", "..", "...".
	_waktu += delta
	var n: int = (int(_waktu / 0.4) % 3) + 1
	if n != _jumlah_titik and _status != null:
		_jumlah_titik = n
		_status.teks_sorot = ".".repeat(n)
		_status.queue_redraw()


## Tutup layar tunggu dengan memudar, lalu hapus dirinya.
func tutup() -> void:
	if _akar == null or not is_inside_tree():
		queue_free()
		return
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_akar, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _bangun() -> void:
	_akar = Control.new()
	_akar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_akar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_akar)
	GayaMenu.pasang_latar(_akar)

	# Pita hitam atas dan bawah (seperti layar bioskop, sama dengan intro).
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
		_akar.add_child(pita)

	var label_level: String = "LEVEL 1  LANTAI KANTOR" if level_satu else "LEVEL 2  LOBI GELAP"
	GayaMenu.baris_atas(_akar, Vector2(96, 150), PackedStringArray(["KAMU P2", label_level, "21.00"]))

	var judul := GayaMenu.JudulBesar.new()
	judul.baris = PackedStringArray(["MENUNGGU", "HOST"]) if level_satu else PackedStringArray(["MEMUAT", "LOBI GELAP"])
	judul.ukuran = 104
	judul.baseline_pertama = 86.0
	judul.jarak_baris = 92.0
	judul.position = Vector2(96, 178)
	judul.size = Vector2(900, 200)
	_akar.add_child(judul)

	_status = GayaMenu.StatusTitik.new()
	_status.warna_titik = GayaMenu.AMBER
	_status.kedip = true
	_status.tengah_vertikal = false
	_status.teks = "Host masih membaca cerita" if level_satu else "Mengambil data dari host"
	_status.sub_baris = PackedStringArray([
		"Game mulai begitu host masuk ke lantai kantor" if level_satu else "Lobi gelap siap dalam beberapa detik"
	])
	_status.position = Vector2(96, 398)
	_status.size = Vector2(700, 48)
	_akar.add_child(_status)

	GayaMenu.pasang_vinyet(_akar)
