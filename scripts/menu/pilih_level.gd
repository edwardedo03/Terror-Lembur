extends Control
## Layar PILIH LEVEL (khusus host; juga mode Solo tes dari editor).
##
## - Level baru bisa dipilih setelah teman tersambung, karena kedua level
##   punya tugas yang wajib dikerjakan berdua. Selama menunggu, kedua
##   tombol level diredupkan dan lampu status amber berkedip.
## - Level 2 terkunci sampai Level 1 pernah tamat di PC host (GameProgress).
##   Di mode Solo tes (editor) Level 2 tetap boleh dicoba walau terkunci.
## - Memilih level: AlurLevel.mulai_level() membawa host DAN teman ke level
##   itu (Level 1 diawali cerita, Level 2 langsung main).
## - KEMBALI KE MENU UTAMA memutus koneksi; teman ikut kembali ke main menu.

var _status: GayaMenu.StatusTitik = null
var _tombol_l1: GayaMenu.TombolMenu = null
var _tombol_l2: GayaMenu.TombolMenu = null
var _tombol_kembali: GayaMenu.TombolBawah = null
var _mesin: GayaMenu.MesinAbsen = null
var _kartu: GayaMenu.KartuLembur = null
var _sudah_memilih: bool = false
var _ada_teman_sebelumnya: bool = false


func _ready() -> void:
	MusicManager.play_menu()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if NetworkManager.mode == NetworkManager.Mode.CLIENT:
		# Teman tidak memilih level: arahkan ke layar Menunggu host.
		# (deferred: jangan ganti scene di tengah _ready scene ini)
		AlurLevel.call_deferred("ke_menunggu_host", AlurLevel.ip_host)
		return
	NetworkManager.peer_joined.connect(_on_peer_berubah)
	NetworkManager.peer_left.connect(_on_peer_berubah)
	_bangun_ui()
	_perbarui()
	_fokus_awal()


# ------------------------------------------------------------------- UI ---
func _bangun_ui() -> void:
	GayaMenu.pasang_latar(self)
	var peran: String = "MODE SOLO" if _solo() else "KAMU HOST"
	GayaMenu.baris_atas(self, Vector2(96, 80), PackedStringArray([peran, "LANTAI 1", "21.00"]))
	var judul := GayaMenu.JudulBesar.new()
	judul.baris = PackedStringArray(["PILIH LEVEL"])
	judul.ukuran = 104
	judul.baseline_pertama = 87.0
	judul.position = Vector2(96, 111)
	judul.size = Vector2(640, 110)
	add_child(judul)
	_status = GayaMenu.StatusTitik.new()
	_status.position = Vector2(96, 222)
	_status.size = Vector2(600, 80)
	_status.tengah_vertikal = false
	add_child(_status)
	_tombol_l1 = _tombol_level("LEVEL 1", "LANTAI KANTOR", Vector2(96, 304), true)
	_tombol_l1.pressed.connect(_pilih.bind("level_1"))
	_tombol_l2 = _tombol_level("LEVEL 2", "LOBI GELAP", Vector2(96, 388), false)
	_tombol_l2.pressed.connect(_pilih.bind("level_2"))
	_mesin = GayaMenu.MesinAbsen.new()
	_mesin.position = Vector2(760, 54)
	add_child(_mesin)
	var ip: String = NetworkManager.ip_utama()
	_mesin.atur_dymo("IP MESIN INI", ip if ip != "" else "TIDAK ADA")
	_kartu = GayaMenu.KartuLembur.new()
	_kartu.position = Vector2(816, 226)
	add_child(_kartu)
	_kartu.atur_progres(GameProgress.ringkasan())
	_tombol_kembali = GayaMenu.tombol_bawah("KEMBALI KE MENU UTAMA", "kembali")
	_tombol_kembali.position = Vector2(96, 654)
	_tombol_kembali.pressed.connect(_on_kembali)
	add_child(_tombol_kembali)
	GayaMenu.pasang_vinyet(self)


func _tombol_level(kode: String, nama: String, pos: Vector2, garis_atas: bool) -> GayaMenu.TombolMenu:
	var b := GayaMenu.TombolMenu.new()
	b.awalan = kode
	b.judul = nama
	b.ukuran_judul = 34
	b.baseline_judul = 46.0
	b.baseline_sub = 70.0
	b.garis_atas = garis_atas
	b.position = pos
	b.custom_minimum_size = Vector2(460, 84)
	b.size = b.custom_minimum_size
	add_child(b)
	return b


# ------------------------------------------------------------- keadaan ---
func _solo() -> bool:
	return NetworkManager.mode == NetworkManager.Mode.SOLO


func _ada_teman() -> bool:
	return _solo() or not NetworkManager.connected_ids.is_empty()


func _perbarui() -> void:
	var solo: bool = _solo()
	var ada_teman: bool = _ada_teman()
	# Status teman.
	_status.sub_baris = PackedStringArray()
	if solo:
		_status.bentuk = "titik"
		_status.warna_titik = GayaMenu.AMBER
		_status.kedip = false
		_status.teks = "Mode solo, hanya untuk tes di editor"
		_status.sub_baris = PackedStringArray(["Tugas berdua bisa dikerjakan sendiri di mode ini."])
	elif ada_teman:
		_status.bentuk = "titik"
		_status.warna_titik = GayaMenu.HIJAU
		_status.kedip = false
		_status.teks = "Teman tersambung sebagai P2"
	else:
		_status.bentuk = "titik"
		_status.warna_titik = GayaMenu.AMBER
		_status.kedip = true
		_status.teks = "Menunggu teman join"
		_status.sub_baris = PackedStringArray([
			"Level bisa dipilih setelah teman tersambung,",
			"karena ada tugas yang harus dikerjakan berdua",
		])
	_status.queue_redraw()
	# Level 1.
	if GameProgress.sudah_tamat("level_1"):
		_tombol_l1.bintang = GameProgress.get_stars("level_1")
		_tombol_l1.sub = "terbaik " + GayaMenu.format_waktu(GameProgress.get_best_time("level_1"))
	else:
		_tombol_l1.bintang = -1
		_tombol_l1.sub = "Belum pernah tamat"
	_tombol_l1.atur_aktif(ada_teman and not _sudah_memilih, 0.35)
	# Level 2.
	var terbuka2: bool = GameProgress.level_terbuka("level_2")
	var editor_solo: bool = solo and OS.has_feature("editor")
	_tombol_l2.ikon_kunci = not terbuka2
	if GameProgress.sudah_tamat("level_2"):
		_tombol_l2.bintang = GameProgress.get_stars("level_2")
		_tombol_l2.sub = "terbaik " + GayaMenu.format_waktu(GameProgress.get_best_time("level_2"))
	elif terbuka2:
		_tombol_l2.bintang = -1
		_tombol_l2.sub = "Terbuka, belum pernah tamat"
	else:
		_tombol_l2.bintang = -1
		_tombol_l2.sub = "Terkunci, mode editor tetap boleh mencoba" if editor_solo else "Terkunci, tamatkan Level 1 dulu"
	var bisa2: bool = ada_teman and (terbuka2 or editor_solo) and not _sudah_memilih
	var redup2: float = 0.55
	if not ada_teman:
		redup2 = 0.35 * (1.0 if terbuka2 else 0.55)
	_tombol_l2.atur_aktif(bisa2, redup2)
	_kartu.atur_progres(GameProgress.ringkasan())


## Fokus awal: level yang paling mungkin dipilih (Level 2 kalau sudah
## terbuka tapi belum tamat, selain itu Level 1). Tanpa teman, fokus di
## tombol KEMBALI supaya keyboard tetap bisa dipakai.
func _fokus_awal() -> void:
	var target: Control = _tombol_kembali
	if _ada_teman():
		target = _tombol_l1
		if not _tombol_l2.disabled and not GameProgress.sudah_tamat("level_2"):
			target = _tombol_l2
	_ada_teman_sebelumnya = _ada_teman()
	target.call_deferred("grab_focus")


func _on_peer_berubah(_peer_id: int) -> void:
	_perbarui()
	# Teman baru saja masuk: pindahkan fokus ke tombol level.
	if _ada_teman() and not _ada_teman_sebelumnya:
		_fokus_awal()
	_ada_teman_sebelumnya = _ada_teman()


# ---------------------------------------------------------------- aksi ---
func _pilih(level_id: String) -> void:
	if _sudah_memilih or not _ada_teman():
		return
	_sudah_memilih = true
	_perbarui()
	AlurLevel.mulai_level(level_id)


func _on_kembali() -> void:
	AlurLevel.ke_menu_utama()
