extends Node2D
## INTRO SINEMATIK (+-15 detik), layar pertama saat game dibuka.
##
## Bukan video: semuanya adegan sungguhan dari aset game. Ruangannya potongan
## ruang kantor Level 1 (TileMapLayer di intro.tscn), tokohnya sprite pemain
## dan sosok Level 1, cahayanya PointLight2D dengan tekstur dari kode
## (tekstur_cahaya.gd), dan semua tulisan digambar dari kode (GayaMenu).
## Kamera diam di satu sudut lalu pelan-pelan maju (zoom), plus guncangan
## saat sosok muncul, jadi terasa seperti potongan film.
##
## ALUR (detik):
##    0.0  layar terang, jam 20:59. "Akhirnya... jam pulang juga."
##    2.6  jam jadi 21:00, bunyi tik. 3.0 pemain menoleh ke kamera.
##    4.4  lampu berkedip 4 kali.
##    5.0  LISTRIK PADAM: ruangan gelap, senter menyala dan menyapu ruangan,
##         jam "--:--", baris terminal merah "PINTU KELUAR TERKUNCI".
##    6.6  bayangan sosok sekilas di pintu (cahaya merah).
##    8.0  potong ke hitam: pemain menyorot tumpukan berkas. "Siapa itu?!"
##   10.0  sosok bermata merah muncul di balik meja, layar memerah,
##         foto P1 dan P2 dicap TERJEBAK dan DIKURUNG.
##   11.2  "Mau ke mana? Tugasmu belum selesai."
##   13.2  "Selesaikan semuanya... sebelum pulang."
##   14.6  bunyi serangan, layar menghitam.
##   15.0  pindah ke main menu dalam mode "sambungan" (AlurLevel.dari_intro):
##         judul TERROR LEMBUR muncul dari gelap, kartu lembur keluar dari
##         mesin absen dan dicap BELUM BOLEH PULANG, baru tombol-tombolnya.
##
## Esc = lewati intro (langsung main menu biasa).
##
## Mengubah intro: geser angka waktu di _susun_acara(), ganti teks dialog di
## sana juga. Posisi tokoh dan kamera ada di konstanta di bawah ini.

const SCENE_MENU: String = "res://scenes/main_menu.tscn"
const TeksturCahaya := preload("res://scripts/level2/tekstur_cahaya.gd")
const DETAK: AudioStream = preload("res://assets/sfx/heartbeat/Heartbeat_Thump_DailySounds.mp3")

const T_SELESAI: float = 15.0
const HURUF_PER_DETIK: float = 38.0

# Posisi di dunia (koordinat Level 1, ruang kantor kiri bawah).
const POS_PEMAIN_MEJA := Vector2(399, 1128)
const POS_PEMAIN_ADEGAN3 := Vector2(511, 1196)
const POS_SOSOK_PINTU := Vector2(512, 992)
const POS_SOSOK_MEJA := Vector2(511, 1108)
const POS_TUMPUKAN := Vector2(509, 1126)
const PUSAT_KAMERA := Vector2(506, 1104)
const ZOOM_AWAL: float = 2.5
const ZOOM_AKHIR: float = 2.65

# Warna CanvasModulate (cahaya ruangan).
const TERANG := Color(0.93, 0.91, 0.87)
const PADAM := Color(0.11, 0.11, 0.15)
const MERAH_GELAP := Color(0.42, 0.07, 0.06)

const MERAH_TEKS := Color(0.886, 0.333, 0.247)  # #E2553F
const SUDUT_SAPU_AWAL: float = -165.0  # derajat, 0 = kanan, -90 = atas
const SUDUT_SAPU_AKHIR: float = -52.0

@onready var _pemain: AnimatedSprite2D = $Pemain
@onready var _sosok: AnimatedSprite2D = $Sosok
@onready var _kamera: Camera2D = $Kamera

var _gelap: CanvasModulate = null
var _cahaya_pemain: PointLight2D = null
var _senter: PointLight2D = null
var _cahaya_sosok: PointLight2D = null
var _mata: _MataSosok = null  # di LapisMata (CanvasLayer ikut kamera)
var _mata_aktif: bool = false
var _tumpukan: _TumpukanBerkas = null
var _detak: AudioStreamPlayer = null

# UI
var _hitam: ColorRect = null
var _merah: ColorRect = null
var _dialog: Label = null
var _terminal: GayaMenu.PesanTerminal = null
var _mesin: GayaMenu.MesinAbsen = null
var _foto_p1: GayaMenu.Polaroid = null
var _foto_p2: GayaMenu.Polaroid = null

var _t: float = 0.0
var _acara: Array = []  # [[detik, Callable], ...] urut waktu
var _acara_ke: int = 0
var _ketik_dialog: float = 0.0
var _ketik_terminal: float = -1.0
var _mode_senter: String = "mati"  # "mati", "sapu", "sorot"
var _goyang: float = 0.0
var _goyang_kuat: float = 0.0
var _pindah: bool = false


func _ready() -> void:
	_kamera.position = PUSAT_KAMERA
	_kamera.zoom = Vector2(ZOOM_AWAL, ZOOM_AWAL)
	_kamera.make_current()
	_pasang_cahaya()
	_pasang_tokoh()
	_bangun_ui()
	_detak = AudioStreamPlayer.new()
	_detak.stream = DETAK
	_detak.volume_db = -9.0
	add_child(_detak)
	_susun_acara()


func _susun_acara() -> void:
	_acara = [
		[0.0, func() -> void: _pudar(_hitam, 0.0, 0.7)],
		[0.8, func() -> void: _ucap("Akhirnya... jam pulang juga.", GayaMenu.INK)],
		[2.6, _jam_pulang],
		[3.0, func() -> void: _pemain.play(&"idle_down")],
		[3.9, func() -> void: _ucap("", GayaMenu.INK)],
		[4.4, func() -> void: _kedip(true)],
		[4.55, func() -> void: _kedip(false)],
		[4.7, func() -> void: _kedip(true)],
		[4.85, func() -> void: _kedip(false)],
		[5.0, _padam],
		[5.3, func() -> void: SfxManager.play_local(&"keypad_beep")],
		[5.6, func() -> void: _ucap("Loh... kok mati lampu?", GayaMenu.INK)],
		[6.4, func() -> void: SfxManager.play_local(&"step")],
		[6.6, _sosok_di_pintu],
		[7.6, _sosok_hilang],
		[7.4, func() -> void: _ucap("", GayaMenu.INK)],
		[7.85, func() -> void: _pudar(_hitam, 1.0, 0.1)],
		[8.0, _adegan_tiga],
		[8.2, func() -> void: _detak.play()],
		[8.3, func() -> void: _ucap("Siapa itu?!", GayaMenu.INK)],
		[9.6, func() -> void: _ucap("", GayaMenu.INK)],
		[10.0, _sosok_muncul],
		[10.6, func() -> void: _cap_foto(_foto_p1, "TERJEBAK")],
		[11.0, func() -> void: _cap_foto(_foto_p2, "DIKURUNG")],
		[11.2, func() -> void: _ucap("Mau ke mana? Tugasmu belum selesai.", MERAH_TEKS)],
		[12.25, func() -> void: _detak.play()],
		[13.2, func() -> void: _ucap("Selesaikan semuanya... sebelum pulang.", MERAH_TEKS)],
		[14.6, _serangan],
		[T_SELESAI, func() -> void: _ke_menu(true)],
	]
	_acara.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _process(delta: float) -> void:
	if _pindah:
		return
	_t += delta
	while _acara_ke < _acara.size() and float(_acara[_acara_ke][0]) <= _t:
		var aksi: Callable = _acara[_acara_ke][1]
		_acara_ke += 1
		aksi.call()
		if _pindah:
			return
	# Kamera maju pelan sepanjang intro (+ guncangan).
	var maju: float = smoothstep(0.0, T_SELESAI, _t)
	var z: float = lerpf(ZOOM_AWAL, ZOOM_AKHIR, maju)
	_kamera.zoom = Vector2(z, z)
	if _goyang > 0.0:
		_goyang = maxf(0.0, _goyang - delta)
		var k: float = _goyang_kuat * minf(1.0, _goyang * 3.0)
		_kamera.offset = Vector2(randf_range(-k, k), randf_range(-k, k))
	else:
		_kamera.offset = Vector2.ZERO
	_perbarui_senter()
	_perbarui_ketikan(delta)
	# Mata ikut posisi dan pudarnya sosok.
	_mata.position = _sosok.position
	_mata.visible = _mata_aktif and _sosok.visible
	_mata.modulate.a = _sosok.modulate.a


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_ke_menu(false)


# ------------------------------------------------------------- adegan ---
func _jam_pulang() -> void:
	_mesin.jam = "21:00"
	SfxManager.play_local(&"tick")


func _kedip(gelap: bool) -> void:
	_gelap.color = PADAM if gelap else TERANG
	SfxManager.play_local(&"keypad_click")


func _padam() -> void:
	_gelap.color = PADAM
	_cahaya_pemain.enabled = true
	_senter.enabled = true
	_mode_senter = "sapu"
	_mesin.jam = "--:--"
	_terminal.teks = "21.00  LISTRIK PADAM  PINTU KELUAR TERKUNCI"
	_terminal.huruf = 0
	_ketik_terminal = 0.0
	SfxManager.play_local(&"hide")


func _sosok_di_pintu() -> void:
	_sosok.position = POS_SOSOK_PINTU
	_sosok.play(&"idle_down")
	_mata_aktif = false
	_cahaya_sosok.enabled = true
	_cahaya_sosok.energy = 1.3
	_sosok.modulate.a = 0.0
	_sosok.visible = true
	_pudar(_sosok, 1.0, 0.3)


func _sosok_hilang() -> void:
	_pudar(_sosok, 0.0, 0.2)
	var tw := create_tween()
	tw.tween_property(_cahaya_sosok, "energy", 0.0, 0.2)


## Potong ke hitam sebentar, lalu pemain sudah berdiri di depan meja tengah
## menyorot tumpukan berkas.
func _adegan_tiga() -> void:
	_pemain.position = POS_PEMAIN_ADEGAN3
	_pemain.play(&"idle_up")
	_mode_senter = "sorot"
	_sosok.position = POS_SOSOK_MEJA
	_sosok.modulate.a = 0.0
	_sosok.visible = true
	_mata_aktif = true
	_cahaya_sosok.enabled = false
	_tumpukan.visible = true
	SfxManager.play_local(&"hide")
	_pudar(_hitam, 0.0, 0.35)


func _sosok_muncul() -> void:
	SfxManager.play_local(&"ghost_tp")
	_pudar(_sosok, 1.0, 0.5)
	_cahaya_sosok.enabled = true
	_cahaya_sosok.energy = 0.0
	var tw := create_tween()
	tw.tween_property(_cahaya_sosok, "energy", 0.9, 0.5)
	var tw2 := create_tween()
	tw2.tween_property(_gelap, "color", MERAH_GELAP, 0.6)
	_merah.modulate.a = 0.45
	_pudar(_merah, 0.12, 0.8)
	_goyang = 0.45
	_goyang_kuat = 3.0


func _cap_foto(foto: GayaMenu.Polaroid, cap: String) -> void:
	foto.cap = cap
	foto.skala_cap = 1.8
	var tw := create_tween()
	tw.tween_property(foto, "skala_cap", 1.0, 0.18).set_ease(Tween.EASE_IN)
	SfxManager.play_local(&"keypad_click")


func _serangan() -> void:
	SfxManager.play_local(&"ghost_attack")
	_goyang = 0.4
	_goyang_kuat = 4.0
	_pudar(_hitam, 1.0, 0.4)
	var tw := create_tween()
	tw.tween_property(_detak, "volume_db", -40.0, 0.4)


func _ke_menu(sambung: bool) -> void:
	if _pindah:
		return
	_pindah = true
	_detak.stop()
	AlurLevel.dari_intro = sambung
	get_tree().change_scene_to_file(SCENE_MENU)


# ------------------------------------------------------------- bantuan ---
func _pudar(n: CanvasItem, alpha: float, detik: float) -> void:
	var tw := create_tween()
	tw.tween_property(n, "modulate:a", alpha, detik)


func _ucap(teks: String, warna: Color) -> void:
	_dialog.text = teks
	_dialog.add_theme_color_override("font_color", warna)
	_dialog.visible_characters = 0
	_ketik_dialog = 0.0


func _perbarui_ketikan(delta: float) -> void:
	if _dialog.text != "" and _dialog.visible_characters >= 0 and _dialog.visible_characters < _dialog.text.length():
		_ketik_dialog += delta * HURUF_PER_DETIK
		_dialog.visible_characters = mini(int(_ketik_dialog), _dialog.text.length())
	if _ketik_terminal >= 0.0:
		_ketik_terminal += delta * HURUF_PER_DETIK * 1.4
		_terminal.huruf = int(_ketik_terminal)
		if _terminal.selesai_mengetik():
			_terminal.huruf = -1
			_ketik_terminal = -1.0


## Arah senter: menyapu dari kiri ke pintu (adegan 2), lalu menyorot ke atas
## dengan tangan sedikit gemetar (adegan 3). Arah hadap pemain mengikuti.
func _perbarui_senter() -> void:
	if _mode_senter == "sapu":
		var p: float = smoothstep(5.2, 7.8, _t)
		var sudut: float = lerpf(SUDUT_SAPU_AWAL, SUDUT_SAPU_AKHIR, p)
		_senter.rotation = deg_to_rad(sudut)
		var anim: StringName = &"idle_left" if sudut < -135.0 else &"idle_up"
		if _pemain.animation != anim:
			_pemain.play(anim)
	elif _mode_senter == "sorot":
		var getar: float = sin(_t * 7.0) * 2.5 + sin(_t * 13.0) * 1.2
		_senter.rotation = deg_to_rad(-90.0 + getar)


# ------------------------------------------------------------- susunan ---
func _pasang_cahaya() -> void:
	_gelap = CanvasModulate.new()
	_gelap.name = "CahayaRuang"
	_gelap.color = TERANG
	add_child(_gelap)
	# Lingkaran cahaya di sekitar pemain dan senter: baru menyala saat padam.
	_cahaya_pemain = PointLight2D.new()
	_cahaya_pemain.name = "CahayaPemain"
	_cahaya_pemain.texture = TeksturCahaya.lingkaran()
	_cahaya_pemain.texture_scale = 0.45
	_cahaya_pemain.color = Color(1.0, 0.9, 0.75)
	_cahaya_pemain.energy = 0.7
	_cahaya_pemain.enabled = false
	_pemain.add_child(_cahaya_pemain)
	_senter = PointLight2D.new()
	_senter.name = "Senter"
	_senter.texture = TeksturCahaya.senter()
	_senter.texture_scale = 1.6
	_senter.color = Color(1.0, 0.95, 0.85)
	_senter.energy = 1.35
	_senter.enabled = false
	_senter.rotation = deg_to_rad(SUDUT_SAPU_AWAL)
	_pemain.add_child(_senter)


func _pasang_tokoh() -> void:
	_pemain.position = POS_PEMAIN_MEJA
	_pemain.play(&"idle_up")
	# Sosok: siluet gelap (tidak terkena cahaya) dengan mata merah menyala.
	var tanpa_cahaya := CanvasItemMaterial.new()
	tanpa_cahaya.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sosok.material = tanpa_cahaya
	_sosok.self_modulate = Color(0.05, 0.035, 0.05)
	_sosok.visible = false
	# Mata digambar di CanvasLayer sendiri yang ikut kamera
	# (follow_viewport), jadi tidak ikut digelapkan CanvasModulate dan
	# tetap merah menyala di ruangan yang padam.
	var lapis_mata := CanvasLayer.new()
	lapis_mata.name = "LapisMata"
	lapis_mata.layer = 1
	lapis_mata.follow_viewport_enabled = true
	add_child(lapis_mata)
	_mata = _MataSosok.new()
	_mata.name = "Mata"
	_mata.visible = false
	lapis_mata.add_child(_mata)
	_cahaya_sosok = PointLight2D.new()
	_cahaya_sosok.name = "CahayaMerah"
	_cahaya_sosok.texture = TeksturCahaya.lingkaran()
	_cahaya_sosok.texture_scale = 0.55
	_cahaya_sosok.color = Color(1.0, 0.18, 0.12)
	_cahaya_sosok.position = Vector2(0, -10)
	_cahaya_sosok.enabled = false
	_sosok.add_child(_cahaya_sosok)
	_tumpukan = _TumpukanBerkas.new()
	_tumpukan.name = "TumpukanBerkas"
	_tumpukan.position = POS_TUMPUKAN
	_tumpukan.z_index = 11
	_tumpukan.visible = false
	add_child(_tumpukan)


func _bangun_ui() -> void:
	var lapis := CanvasLayer.new()
	lapis.name = "UI"
	lapis.layer = 10
	add_child(lapis)
	var akar := Control.new()
	akar.set_anchors_preset(Control.PRESET_FULL_RECT)
	akar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lapis.add_child(akar)

	_merah = ColorRect.new()
	_merah.set_anchors_preset(Control.PRESET_FULL_RECT)
	_merah.color = Color(0.6, 0.05, 0.04, 1.0)
	_merah.modulate.a = 0.0
	_merah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	akar.add_child(_merah)
	GayaMenu.pasang_vinyet(akar)

	# Baris terminal merah saat listrik padam.
	_terminal = GayaMenu.PesanTerminal.new()
	_terminal.latar = false
	_terminal.warna = MERAH_TEKS
	_terminal.ukuran = 16
	_terminal.anchor_right = 1.0
	_terminal.offset_top = 60.0
	_terminal.offset_bottom = 92.0
	akar.add_child(_terminal)

	# Foto P1 dan P2 di kiri atas, mesin absen kecil di kanan atas.
	_foto_p1 = GayaMenu.Polaroid.new()
	_foto_p1.label = "P1"
	_foto_p1.derajat = -5.0
	_foto_p1.position = Vector2(30, 64)
	akar.add_child(_foto_p1)
	_foto_p2 = GayaMenu.Polaroid.new()
	_foto_p2.label = "P2"
	_foto_p2.derajat = 4.0
	_foto_p2.position = Vector2(108, 64)
	akar.add_child(_foto_p2)
	_mesin = GayaMenu.MesinAbsen.new()
	_mesin.scale = Vector2(0.5, 0.5)
	_mesin.position = Vector2(1280.0 - 30.0 - 170.0, 60.0)
	_mesin.jam = "20:59"
	_mesin.atur_dymo("SHIFT LEMBUR", "LT. 1")
	akar.add_child(_mesin)

	# Dialog bawah (diketik huruf demi huruf).
	_dialog = GayaMenu.label("", GayaMenu.mono(), 21, GayaMenu.INK)
	_dialog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Posisi teks dihitung dari kalimat penuh, jadi tidak bergeser saat diketik.
	_dialog.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_dialog.position = Vector2(0, 598)
	_dialog.size = Vector2(1280, 36)
	_dialog.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_dialog.add_theme_constant_override("shadow_offset_x", 0)
	_dialog.add_theme_constant_override("shadow_offset_y", 2)
	_dialog.add_theme_constant_override("shadow_outline_size", 6)
	akar.add_child(_dialog)

	# Pita hitam (letterbox) dan petunjuk Esc.
	for atas: bool in [true, false]:
		var pita := ColorRect.new()
		pita.color = Color(0, 0, 0, 1)
		pita.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pita.position = Vector2(0, 0 if atas else 720 - 44)
		pita.size = Vector2(1280, 44)
		akar.add_child(pita)
	var petunjuk := GayaMenu.PetunjukTombol.new()
	petunjuk.isi = [["Esc", "lewati intro"]]
	petunjuk.position = Vector2(1280.0 - 30.0 - 300.0, 720.0 - 22.0 - 13.0)
	petunjuk.size = Vector2(300, 26)
	akar.add_child(petunjuk)

	_hitam = ColorRect.new()
	_hitam.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hitam.color = Color(0, 0, 0, 1)
	_hitam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	akar.add_child(_hitam)


## Dua mata merah menyala di wajah sosok. Titik (0, 0) = tengah sprite sosok.
class _MataSosok extends Node2D:
	func _draw() -> void:
		for x: float in [-2.5, 4.5]:
			draw_circle(Vector2(x, -7.0), 2.6, Color(1.0, 0.2, 0.15, 0.35))
			draw_rect(Rect2(x - 1.0, -8.0, 2.0, 2.0), Color(1.0, 0.25, 0.18))


## Tumpukan berkas di meja tengah (tugas yang belum selesai), digambar dari
## kode: lembar kertas putih bertumpuk dengan penanda merah di ujungnya.
class _TumpukanBerkas extends Node2D:
	const GESER: Array[int] = [0, 1, -1, 0, 1, 0, -1, 1]

	func _draw() -> void:
		for i in range(GESER.size()):
			var y: float = float(i) * 4.0
			var x: float = -15.0 + float(GESER[i])
			draw_rect(Rect2(x, y, 30.0, 3.0), Color(0.92, 0.9, 0.86))
			draw_rect(Rect2(x, y + 3.0, 30.0, 1.0), Color(0.45, 0.43, 0.4))
			draw_rect(Rect2(x + 27.0, y + 1.0, 3.0, 1.0), Color(0.75, 0.12, 0.1))
