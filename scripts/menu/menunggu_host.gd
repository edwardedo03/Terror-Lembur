extends Control
## Layar MENUNGGU HOST (PC teman / P2).
##
## Menampilkan IP host yang tersambung dan apa yang sedang dilakukan host.
## Begitu host memilih level, tulisan berganti jadi "Host memilih LEVEL ...,
## Memuat level", lalu AlurLevel membawa teman ke level itu. Kalau host
## sudah berada di dalam level saat teman join, teman langsung dibawa
## masuk. Kalau host keluar, kembali ke main menu dengan pesan.
##
## Kartu lembur di kanan menampilkan progres HOST (dikirim lewat jaringan),
## karena host yang menentukan Level 2 sudah terbuka atau belum.

var _baris_host: GayaMenu.StatusTitik = null
var _baris_status: GayaMenu.StatusTitik = null
var _mesin: GayaMenu.MesinAbsen = null
var _kartu: GayaMenu.KartuLembur = null
var _tombol_keluar: GayaMenu.TombolBawah = null
var _status_diterima: bool = false
var _tanya_timer: float = 0.0


func _ready() -> void:
	MusicManager.play_menu()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if NetworkManager.mode != NetworkManager.Mode.CLIENT:
		# Layar ini khusus PC teman (deferred: jangan ganti scene di _ready).
		AlurLevel.call_deferred("ke_menu_utama", "")
		return
	NetworkManager.host_disconnected.connect(_on_host_putus)
	AlurLevel.status_host_diterima.connect(_on_status_host)
	AlurLevel.level_dipilih_host.connect(_on_level_dipilih)
	_bangun_ui()
	_tampil_menunggu()
	AlurLevel.minta_status()
	_tanya_timer = 1.0
	_tombol_keluar.call_deferred("grab_focus")


func _process(delta: float) -> void:
	# Tanya status host tiap detik sampai dijawab.
	if _status_diterima:
		return
	_tanya_timer -= delta
	if _tanya_timer <= 0.0:
		_tanya_timer = 1.0
		AlurLevel.minta_status()


# ------------------------------------------------------------------- UI ---
func _bangun_ui() -> void:
	GayaMenu.pasang_latar(self)
	GayaMenu.baris_atas(self, Vector2(96, 80), PackedStringArray(["KAMU P2", "LANTAI 1", "21.00"]))
	var judul := GayaMenu.JudulBesar.new()
	judul.baris = PackedStringArray(["MENUNGGU", "HOST"])
	judul.ukuran = 112
	judul.baseline_pertama = 93.0
	judul.jarak_baris = 98.5
	judul.position = Vector2(96, 111)
	judul.size = Vector2(640, 210)
	add_child(judul)
	var ip: String = AlurLevel.ip_host if AlurLevel.ip_host != "" else "-"
	_baris_host = GayaMenu.StatusTitik.new()
	_baris_host.position = Vector2(96, 342)
	_baris_host.size = Vector2(460, 62)
	_baris_host.garis_atas = true
	_baris_host.garis_bawah = true
	_baris_host.warna_titik = GayaMenu.HIJAU
	_baris_host.teks = "Tersambung ke host"
	_baris_host.teks_kanan = ip
	add_child(_baris_host)
	_baris_status = GayaMenu.StatusTitik.new()
	_baris_status.position = Vector2(96, 404)
	_baris_status.size = Vector2(460, 78)
	_baris_status.garis_bawah = true
	add_child(_baris_status)
	_mesin = GayaMenu.MesinAbsen.new()
	_mesin.position = Vector2(760, 54)
	add_child(_mesin)
	_mesin.atur_dymo("HOST", ip)
	_kartu = GayaMenu.KartuLembur.new()
	_kartu.position = Vector2(816, 226)
	add_child(_kartu)
	_kartu.atur_progres(AlurLevel.progres_tampil())
	_tombol_keluar = GayaMenu.tombol_bawah("KELUAR KE MENU UTAMA", "kembali")
	_tombol_keluar.position = Vector2(96, 654)
	_tombol_keluar.pressed.connect(_on_keluar)
	add_child(_tombol_keluar)
	GayaMenu.pasang_vinyet(self)


func _tampil_menunggu() -> void:
	_baris_status.bentuk = "titik"
	_baris_status.warna_titik = GayaMenu.AMBER
	_baris_status.kedip = true
	_baris_status.teks = "Host sedang memilih level"
	_baris_status.teks_sorot = ""
	_baris_status.sub_baris = PackedStringArray(["Game mulai otomatis begitu host memilih"])
	_baris_status.queue_redraw()


func _tampil_level(level_id: String, sedang_main: bool) -> void:
	_baris_status.bentuk = "segitiga"
	_baris_status.warna_titik = GayaMenu.AMBER
	_baris_status.kedip = false
	_baris_status.teks = "Host sedang main" if sedang_main else "Host memilih"
	_baris_status.teks_sorot = AlurLevel.nama_level(level_id)
	_baris_status.sub_baris = PackedStringArray(["Masuk menyusul ke level" if sedang_main else "Memuat level"])
	_baris_status.queue_redraw()


# ------------------------------------------------------------- jaringan ---
func _on_status_host(level_id: String) -> void:
	_status_diterima = true
	_kartu.atur_progres(AlurLevel.progres_tampil())
	if level_id != "":
		_tampil_level(level_id, true)


func _on_level_dipilih(level_id: String) -> void:
	_tampil_level(level_id, false)


func _on_host_putus() -> void:
	AlurLevel.ke_menu_utama("Host keluar dari game.")


func _on_keluar() -> void:
	AlurLevel.ke_menu_utama()
