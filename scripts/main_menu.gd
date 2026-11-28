extends Control
## Main Menu Terror Lembur (desain Opsi D), dibangun dari kode.
##
## Kiri : label shift, judul TERROR LEMBUR, BUAT GAME (host di PC 1) dan
##        GABUNG GAME (join dari PC 2) + kolom IP host.
## Kanan: mesin absen. IP PC ini muncul otomatis di label Dymo, jadi host
##        tidak perlu membuka cmd lalu ipconfig. Kartu lembur di bawahnya
##        mencatat progres Level 1 dan Level 2 (tetap tersimpan walau game
##        ditutup, lihat GameProgress).
## Bawah: KONTROL membuka panel semua tombol Level 1 dan Level 2.
##        MODE EDITOR (Solo tes dan Reset progres) hanya muncul kalau game
##        dijalankan dari editor Godot; di hasil export tidak ada.
##
## Sambungan dari intro: kalau dibuka langsung dari akhir intro sinematik
## (AlurLevel.dari_intro), layar mulai hitam lalu judul muncul dari gelap,
## kartu lembur keluar dari celah mesin absen dan dicap BELUM BOLEH PULANG,
## label Dymo berganti dari "SHIFT LEMBUR LT. 1" ke IP, baru tombol-tombol
## muncul. Tekan tombol apa saja atau klik untuk langsung ke akhir.
##
## Tidak ada mode solo untuk pemain karena kedua level punya tugas yang
## hanya bisa dikerjakan berdua. Setelah BUAT GAME host masuk ke layar
## Pilih Level; setelah GABUNG GAME teman masuk ke layar Menunggu host
## (lihat AlurLevel).

const BATAS_JOIN: float = 5.0

var _ip_edit: LineEdit = null
var _status: Label = null
var _mesin: GayaMenu.MesinAbsen = null
var _kartu: GayaMenu.KartuLembur = null
var _panel_kontrol: GayaMenu.PanelKontrol = null
var _tombol_buat: GayaMenu.TombolMenu = null
var _tombol_gabung: GayaMenu.TombolMenu = null
var _tombol_kontrol: GayaMenu.TombolBawah = null
var _joining: bool = false
var _join_timer: float = -1.0
var _ip_join: String = ""
var _baris_ip: HBoxContainer = null
var _baris_editor: HBoxContainer = null
# Mode sambungan dari intro
var _sambung: bool = false
var _hitam: ColorRect = null
var _tween_sambung: Tween = null


func _ready() -> void:
	# Backsound main menu (Ghost Story): fade-in, lalu loop crossfade
	# sendiri di MusicManager.
	MusicManager.play_menu()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Masuk main menu = sesi jaringan sebelumnya sudah selesai.
	NetworkManager.disconnect_all()
	AlurLevel.level_aktif = ""
	NetworkManager.connected_to_host.connect(_on_connected_to_host)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	_bangun_ui()
	var pesan: String = AlurLevel.ambil_pesan_menu()
	if pesan != "":
		_tulis_status(pesan, true)
	var dari_intro: bool = AlurLevel.dari_intro
	AlurLevel.dari_intro = false
	if dari_intro:
		_mulai_sambungan()
	else:
		_tombol_buat.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if _joining and _join_timer > 0.0:
		_join_timer -= delta
		if _join_timer <= 0.0:
			_joining = false
			NetworkManager.disconnect_all()
			_tulis_status("Tidak bisa terhubung. Cek IP host dan pastikan kedua PC di Wi-Fi atau LAN yang sama (UDP 7777).", true)


# ------------------------------------------------------------------- UI ---
func _bangun_ui() -> void:
	GayaMenu.pasang_latar(self)
	GayaMenu.baris_atas(self, Vector2(96, 72), PackedStringArray(["SHIFT MALAM", "LANTAI 1", "21.00"]))
	var judul := GayaMenu.JudulBesar.new()
	judul.baris = PackedStringArray(["TERROR", "LEMBUR"])
	judul.ukuran = 128
	judul.baseline_pertama = 105.0
	judul.jarak_baris = 110.0
	judul.position = Vector2(96, 103)
	judul.size = Vector2(600, 230)
	add_child(judul)
	var tagline: Label = GayaMenu.label("Selesaikan tugas lembur. Hindari sosok itu.\nKabur berdua.", GayaMenu.mono(), 17, GayaMenu.SOFT)
	tagline.add_theme_constant_override("line_spacing", 5)
	tagline.position = Vector2(96, 341)
	add_child(tagline)
	_tombol_buat = _tombol_menu("BUAT GAME", "Host di PC 1, kamu yang memilih level", Vector2(96, 426))
	_tombol_buat.pressed.connect(_on_host_pressed)
	_tombol_gabung = _tombol_menu("GABUNG GAME", "Join dari PC 2, masukkan IP host", Vector2(96, 492))
	_tombol_gabung.pressed.connect(_on_join_pressed)
	_bangun_kolom_ip()
	_status = GayaMenu.label("", GayaMenu.mono(), 13, GayaMenu.MUTED)
	_status.position = Vector2(130, 606)
	_status.size = Vector2(560, 40)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	# Kanan: mesin absen + kartu lembur (kartu digambar di atas celah mesin).
	_mesin = GayaMenu.MesinAbsen.new()
	_mesin.position = Vector2(760, 54)
	add_child(_mesin)
	_isi_ip_mesin()
	# Kartu di dalam "celah" yang memotong gambar (clip_contents), supaya
	# saat sambungan dari intro kartu bisa meluncur keluar dari mesin.
	var celah := Control.new()
	celah.name = "CelahKartu"
	celah.position = Vector2(796, 226)
	celah.size = Vector2(260, 430)
	celah.clip_contents = true
	celah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celah)
	_kartu = GayaMenu.KartuLembur.new()
	_kartu.position = Vector2(20, 0)
	celah.add_child(_kartu)
	_kartu.atur_progres(GameProgress.ringkasan())
	# Bawah: KONTROL dan MODE EDITOR.
	_tombol_kontrol = GayaMenu.tombol_bawah("KONTROL", "keyboard")
	_tombol_kontrol.position = Vector2(96, 654)
	_tombol_kontrol.pressed.connect(_buka_kontrol)
	add_child(_tombol_kontrol)
	if OS.has_feature("editor"):
		_bangun_mode_editor()
	GayaMenu.pasang_vinyet(self)
	_panel_kontrol = GayaMenu.PanelKontrol.new()
	_panel_kontrol.name = "PanelKontrol"
	add_child(_panel_kontrol)
	_panel_kontrol.ditutup.connect(_on_kontrol_ditutup)


func _tombol_menu(judul: String, sub: String, pos: Vector2) -> GayaMenu.TombolMenu:
	var b := GayaMenu.TombolMenu.new()
	b.judul = judul
	b.sub = sub
	b.ukuran_judul = 30
	b.baseline_judul = 33.0
	b.baseline_sub = 55.0
	b.position = pos
	b.custom_minimum_size = Vector2(400, 60)
	b.size = b.custom_minimum_size
	add_child(b)
	return b


func _bangun_kolom_ip() -> void:
	var baris := HBoxContainer.new()
	baris.position = Vector2(130, 562)
	baris.add_theme_constant_override("separation", 12)
	add_child(baris)
	_baris_ip = baris
	var lbl: Label = GayaMenu.label("IP HOST", GayaMenu.mono(1), 13, GayaMenu.MUTED)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baris.add_child(lbl)
	_ip_edit = LineEdit.new()
	_ip_edit.custom_minimum_size = Vector2(170, 34)
	_ip_edit.placeholder_text = "192.168.x.x"
	_ip_edit.text = GameProgress.ip_terakhir()
	_ip_edit.add_theme_font_override("font", GayaMenu.mono())
	_ip_edit.add_theme_font_size_override("font_size", 16)
	_ip_edit.add_theme_color_override("font_color", GayaMenu.INK)
	_ip_edit.add_theme_color_override("font_placeholder_color", GayaMenu.REDUP)
	_ip_edit.add_theme_color_override("caret_color", GayaMenu.AMBER)
	_ip_edit.add_theme_stylebox_override("normal", _gaya_kolom(GayaMenu.GARIS, true))
	_ip_edit.add_theme_stylebox_override("focus", _gaya_kolom(GayaMenu.AMBER, false))
	_ip_edit.text_submitted.connect(_on_ip_submitted)
	baris.add_child(_ip_edit)


func _gaya_kolom(garis: Color, isi: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GayaMenu.PANEL
	sb.draw_center = isi
	sb.border_color = garis
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


func _isi_ip_mesin() -> void:
	var daftar: Array[Dictionary] = NetworkManager.daftar_ip_lan()
	if daftar.is_empty():
		_mesin.atur_dymo("IP MESIN INI", "TIDAK ADA")
		_mesin.tooltip_text = "Tidak ada jaringan. Sambungkan PC ke Wi-Fi atau LAN dulu."
	else:
		_mesin.atur_dymo("IP MESIN INI", String(daftar[0]["ip"]))
		var baris: PackedStringArray = PackedStringArray()
		for isi: Dictionary in daftar:
			var adapter: String = String(isi["adapter"])
			baris.append("%s  %s" % [String(isi["ip"]), adapter if adapter != "" else "adapter"])
		_mesin.tooltip_text = "IP yang bisa dipakai teman:\n" + "\n".join(baris)
	# Tooltip butuh mouse_filter selain IGNORE.
	_mesin.mouse_filter = Control.MOUSE_FILTER_PASS


func _bangun_mode_editor() -> void:
	var baris := HBoxContainer.new()
	baris.name = "ModeEditor"
	baris.alignment = BoxContainer.ALIGNMENT_END
	baris.add_theme_constant_override("separation", 10)
	baris.anchor_left = 1.0
	baris.anchor_right = 1.0
	baris.anchor_top = 1.0
	baris.anchor_bottom = 1.0
	baris.offset_left = -700.0
	baris.offset_right = -96.0
	baris.offset_top = -66.0
	baris.offset_bottom = -22.0
	baris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(baris)
	_baris_editor = baris
	var lbl: Label = GayaMenu.label("MODE EDITOR", GayaMenu.mono(1), 12, GayaMenu.REDUP)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baris.add_child(lbl)
	var solo := GayaMenu.TombolDebug.new()
	solo.atur_teks("Solo (tes)")
	solo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	solo.tooltip_text = "Tes sendiri tanpa teman. Hanya ada saat dijalankan dari editor."
	solo.pressed.connect(_on_solo_pressed)
	baris.add_child(solo)
	var reset := GayaMenu.TombolDebug.new()
	reset.atur_teks("Reset progres")
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.tooltip_text = "Hapus progres Level 1 dan Level 2 di PC ini (Level 2 terkunci lagi)."
	reset.pressed.connect(_on_reset_pressed)
	baris.add_child(reset)


# ------------------------------------------------- sambungan dari intro ---
func _input(event: InputEvent) -> void:
	if not _sambung:
		return
	var tekan: bool = false
	if event is InputEventKey:
		var k: InputEventKey = event
		tekan = k.pressed and not k.echo
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		tekan = m.pressed
	if tekan:
		# Tombol yang ditekan hanya untuk melewati animasi, jangan sampai
		# ikut menekan BUAT GAME.
		get_viewport().set_input_as_handled()
		_selesaikan_sambungan(true)


func _elemen_bawah() -> Array[Control]:
	var daftar: Array[Control] = [_tombol_buat, _tombol_gabung, _baris_ip, _status, _tombol_kontrol]
	if _baris_editor != null:
		daftar.append(_baris_editor)
	return daftar


func _mulai_sambungan() -> void:
	_sambung = true
	_mesin.atur_dymo("SHIFT LEMBUR", "LT. 1")
	_kartu.position.y = -430.0
	_kartu.skala_cap_bawah = 0.0
	for n: Control in _elemen_bawah():
		n.visible = false
		n.modulate.a = 0.0
	_hitam = ColorRect.new()
	_hitam.name = "HitamIntro"
	_hitam.color = Color(0, 0, 0, 1)
	_hitam.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hitam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hitam)
	# Urutan: gelap memudar (judul tampil), kartu meluncur keluar dari mesin,
	# cap BELUM BOLEH PULANG, lalu tombol muncul dan Dymo berganti ke IP.
	_tween_sambung = create_tween()
	_tween_sambung.tween_property(_hitam, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	_tween_sambung.tween_callback(func() -> void: SfxManager.play_local(&"hide"))
	_tween_sambung.tween_property(_kartu, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_sambung.tween_interval(0.3)
	_tween_sambung.tween_callback(func() -> void: SfxManager.play_local(&"keypad_click"))
	_tween_sambung.tween_property(_kartu, "skala_cap_bawah", 1.0, 0.18).from(1.7).set_ease(Tween.EASE_IN)
	_tween_sambung.tween_interval(0.7)
	_tween_sambung.tween_callback(_selesaikan_sambungan.bind(false))


## Akhir sambungan. langsung = true kalau pemain menekan tombol untuk
## melewati animasi (semua langsung tampil tanpa memudar).
func _selesaikan_sambungan(langsung: bool) -> void:
	if not _sambung:
		return
	_sambung = false
	if _tween_sambung != null:
		_tween_sambung.kill()
		_tween_sambung = null
	if _hitam != null:
		_hitam.queue_free()
		_hitam = null
	_kartu.position.y = 0.0
	_kartu.skala_cap_bawah = 1.0
	_isi_ip_mesin()
	for n: Control in _elemen_bawah():
		n.visible = true
		if langsung:
			n.modulate.a = 1.0
		else:
			var tw := create_tween()
			tw.tween_property(n, "modulate:a", 1.0, 0.45)
	if not langsung:
		SfxManager.play_local(&"tick")
	_tombol_buat.grab_focus()


func _tulis_status(teks: String, galat: bool) -> void:
	if _status == null:
		return
	_status.text = teks
	_status.add_theme_color_override("font_color", GayaMenu.MERAH_PESAN if galat else GayaMenu.MUTED)


# ---------------------------------------------------------------- aksi ---
func _on_host_pressed() -> void:
	if _joining:
		return
	var err: Error = NetworkManager.host_game()
	if err != OK:
		_tulis_status("Gagal membuat game. Port 7777 mungkin sedang dipakai, tutup game lain lalu coba lagi.", true)
		return
	AlurLevel.ke_pilih_level()


func _on_ip_submitted(_teks: String) -> void:
	_on_join_pressed()


func _on_join_pressed() -> void:
	if _joining:
		return
	var ip: String = _ip_edit.text.strip_edges()
	if ip == "":
		_tulis_status("Isi dulu IP host. IP-nya tertulis di label mesin absen pada layar PC host.", true)
		_ip_edit.grab_focus()
		return
	_joining = true
	_join_timer = BATAS_JOIN
	_ip_join = ip
	_tulis_status("Menghubungi host %s ..." % ip, false)
	var err: Error = NetworkManager.join_game(ip)
	if err != OK:
		_joining = false
		_tulis_status("Gagal memulai koneksi. Cek lagi IP yang dimasukkan.", true)


func _on_connected_to_host() -> void:
	if not _joining:
		return
	_joining = false
	GameProgress.simpan_ip_terakhir(_ip_join)
	AlurLevel.ke_menunggu_host(_ip_join)


func _on_connection_failed() -> void:
	_joining = false
	NetworkManager.disconnect_all()
	_tulis_status("Koneksi gagal. Pastikan host sudah menekan BUAT GAME dan IP-nya benar.", true)


func _on_solo_pressed() -> void:
	NetworkManager.start_solo()
	AlurLevel.ke_pilih_level()


func _on_reset_pressed() -> void:
	GameProgress.reset_progres()
	_kartu.atur_progres(GameProgress.ringkasan())
	_tulis_status("Progres Level 1 dan Level 2 di PC ini sudah dihapus.", false)


func _buka_kontrol() -> void:
	_panel_kontrol.buka()


func _on_kontrol_ditutup() -> void:
	_tombol_kontrol.grab_focus()
