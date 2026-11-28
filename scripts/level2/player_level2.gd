extends CharacterBody2D
## Player KHUSUS LEVEL 2 (salinan scripts/player.gd; file aslinya tidak diubah).
## Bedanya dengan player.gd:
##  - batas kamera ikut ukuran map Level 2 (get_map_size_tiles(), 72 x 46)
##  - waktu sembunyi, tombol E tetap dibaca supaya bisa keluar lagi
##  - energi lari: Shift menghabiskan energi; habis = harus jalan dulu
##    sampai terisi 30% (bar kecil di atas kepala digambar HudMalam)
##  - anti nyangkut: kalau kaki pemain ternyata berada DI DALAM tembok /
##    furnitur (misal bangkit di posisi yang salah), pemain dipindah ke
##    lantai kosong terdekat (level_2.gd -> posisi_aman)
## Scene: scenes/level2/player_level2.tscn (z_index 8 = paling depan; collision
## lingkaran r 8 di bagian kaki, supaya badan boleh menutupi furnitur di atasnya).
##
## Player top-down (keyboard). Satu instance per peer, otoritas = peer pemilik.
##
## Otoritas lokal membaca input & bergerak; posisi/state dikirim ke peer lain
## via RPC unreliable 20 Hz, peer lain melakukan lerp. State gameplay
## (sembunyi/terkurung/bawa item) dimiliki host dan disebar via RPC reliable.
## Grup: "Player".

const WALK_SPEED: float = 170.0
const SPRINT_SPEED: float = 235.0
const SYNC_INTERVAL: float = 0.05
## Energi lari (0..1).
const ENERGI_LARI_DETIK: float = 4.0  # energi penuh cukup untuk lari 4 detik
const ENERGI_ISI_DETIK: float = 6.0  # kosong -> penuh lagi dalam 6 detik (jalan / diam)
const ENERGI_MIN_LARI: float = 0.3  # setelah habis, baru bisa lari lagi kalau sudah 30%

@export var player_index: int = 1

var peer_id: int = 1
var is_hidden: bool = false
var is_downed: bool = false
var carrying_revive: bool = false
var is_sprinting: bool = false
var iframes_left: float = 0.0
var interact_held: bool = false
var minigame_open: bool = false
var energi: float = 1.0
var energi_habis: bool = false  # true sejak energi 0 sampai terisi lagi 30%
var _cek_nyangkut_timer: float = 0.0
var _nyangkut_berapa: int = 0

var _sync_timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _bob_time: float = 0.0
var _trauma: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var light: PointLight2D = $Light
@onready var camera: Camera2D = $Camera2D

var _base_tint: Color = Color.WHITE
var _facing: String = "down"


## Lama host mengabaikan paket posisi dari teman setelah pemain di-spawn
## (milidetik). Lihat _sync_state.
const ABAIKAN_SYNC_AWAL_MS: int = 1500
var _lahir_ms: int = 0


func _ready() -> void:
	add_to_group("Player")
	peer_id = get_multiplayer_authority()
	_lahir_ms = Time.get_ticks_msec()
	if player_index == 2:
		_base_tint = Color(0.65, 0.8, 1.0)
		name_label.text = "P2"
	else:
		name_label.text = "P1"
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var is_local: bool = is_multiplayer_authority()
	camera.enabled = is_local
	if is_local:
		# Batas kamera ikut ukuran map level yang sedang dimainkan.
		# Level yang punya fungsi get_map_size_tiles() (Level 2) memberi
		# ukurannya sendiri; kalau tidak ada, pakai ukuran Level 1 (64 x 40).
		var ukuran_map: Vector2i = Vector2i(64, 40)
		var level: Node = get_tree().get_first_node_in_group("LevelManager")
		if level != null and level.has_method("get_map_size_tiles"):
			ukuran_map = level.get_map_size_tiles()
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = ukuran_map.x * 32
		camera.limit_bottom = ukuran_map.y * 32
		camera.make_current()
	_target_pos = global_position


func _physics_process(delta: float) -> void:
	if iframes_left > 0.0:
		iframes_left = maxf(0.0, iframes_left - delta)
	if not is_multiplayer_authority():
		return
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	var level_running: bool = level == null or level.is_level_running()
	if is_downed or is_hidden or minigame_open or not level_running:
		velocity = Vector2.ZERO
		move_and_slide()
		_tick_energi(delta, false, level)
		# Saat sembunyi, tombol E tetap dibaca supaya pemain bisa keluar lagi.
		# (Dulu fungsi ini langsung return sebelum membaca E, jadi tidak bisa keluar.)
		if is_hidden and not is_downed and not minigame_open and level_running and Input.is_action_just_pressed("interact"):
			if level != null:
				level.notify_interact_pressed(peer_id)
		_sync_tick(delta)
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_tick_energi(delta, Input.is_action_pressed("sprint") and dir.length() > 0.1, level)
	var speed: float = SPRINT_SPEED if is_sprinting else WALK_SPEED
	velocity = dir.normalized() * speed if dir.length() > 0.1 else Vector2.ZERO
	move_and_slide()
	_cek_nyangkut(delta, level)
	# Interact: tekan/lepas diteruskan ke Level (host yang memutuskan efeknya).
	if Input.is_action_just_pressed("interact"):
		interact_held = true
		if level != null:
			level.notify_interact_pressed(peer_id)
	if Input.is_action_just_released("interact"):
		interact_held = false
		if level != null:
			level.notify_interact_released(peer_id)
	_sync_tick(delta)


# Anti nyangkut: tiap 0,2 detik dicek apakah kaki pemain masuk ke tembok /
# furnitur (pakai lingkaran sedikit lebih kecil, jadi menempel tembok biasa
# TIDAK dihitung). Kalau 2x berturut-turut masuk, pindah ke posisi aman.
func _cek_nyangkut(delta: float, level: Node) -> void:
	if level == null or not level.has_method("bebas_tabrakan"):
		return
	_cek_nyangkut_timer -= delta
	if _cek_nyangkut_timer > 0.0:
		return
	_cek_nyangkut_timer = 0.2
	if level.bebas_tabrakan(global_position, 5.0):
		_nyangkut_berapa = 0
		return
	_nyangkut_berapa += 1
	if _nyangkut_berapa >= 2:
		_nyangkut_berapa = 0
		var tujuan: Vector2 = level.posisi_aman(global_position)
		print("[Level 2] P%d nyangkut di %s -> dipindah ke %s" % [player_index, str(global_position), str(tujuan)])
		global_position = tujuan
		velocity = Vector2.ZERO


# Energi lari. mau_lari = Shift ditekan sambil bergerak. Mengatur is_sprinting.
# Dipisah jadi fungsi sendiri supaya bisa dites di smoke test.
func _tick_energi(delta: float, mau_lari: bool, level: Node) -> void:
	var tak_habis: bool = level != null and level.has_method("is_energi_tak_habis") and level.is_energi_tak_habis()
	if energi_habis and energi >= ENERGI_MIN_LARI:
		energi_habis = false
	is_sprinting = mau_lari and not energi_habis
	if is_sprinting:
		if not tak_habis:
			energi = maxf(0.0, energi - delta / ENERGI_LARI_DETIK)
		if energi <= 0.0:
			energi_habis = true
			is_sprinting = false
	else:
		energi = minf(1.0, energi + delta / ENERGI_ISI_DETIK)


func _process(delta: float) -> void:
	# Remote: kejar posisi terakhir yang diterima.
	if not is_multiplayer_authority() and _has_target:
		global_position = global_position.lerp(_target_pos, minf(1.0, delta * 14.0))
	# Bob kecil saat bergerak + kedip saat i-frame.
	var moving: bool = velocity.length() > 10.0
	_bob_time += delta * (10.0 if moving else 2.0)
	sprite.position.y = -4.0 + sin(_bob_time) * (1.2 if moving else 0.4)
	_update_animation(moving)
	if iframes_left > 0.0:
		var blink_a: float = 0.45 + 0.4 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
		sprite.modulate = Color(_base_tint.r, _base_tint.g, _base_tint.b, blink_a)
	elif is_downed:
		sprite.modulate = Color(0.55, 0.55, 0.6, 0.9) * _base_tint
	elif is_hidden:
		sprite.modulate = Color(1, 1, 1, 0.35) * _base_tint
	else:
		sprite.modulate = _base_tint
	light.energy = 0.0 if is_downed else (0.18 if is_hidden else 1.1)
	# Camera shake (trauma) hanya untuk pemain lokal.
	if is_multiplayer_authority() and camera.enabled:
		if _trauma > 0.0:
			_trauma = maxf(0.0, _trauma - delta * 1.6)
			var s: float = _trauma * _trauma * 14.0
			camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		else:
			camera.offset = Vector2.ZERO


func _update_animation(moving: bool) -> void:
	if moving:
		_facing = _dir_name(velocity)
		_play_anim("walk_" + _facing)
	else:
		_play_anim("idle_" + _facing)


func _dir_name(dir_vec: Vector2) -> String:
	if absf(dir_vec.x) > absf(dir_vec.y):
		return "right" if dir_vec.x > 0.0 else "left"
	return "down" if dir_vec.y > 0.0 else "up"


func _play_anim(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func grant_iframes(seconds: float) -> void:
	iframes_left = maxf(iframes_left, seconds)


# --- Dipanggil host (lokal) lalu disebar ke peer lain via apply_net_state. ---
func apply_local_state(downed: bool, hidden: bool, carrying: bool) -> void:
	is_downed = downed
	is_hidden = hidden
	carrying_revive = carrying
	if downed:
		velocity = Vector2.ZERO
		interact_held = false


func broadcast_state() -> void:
	if NetworkManager.is_networked():
		rpc("apply_net_state", is_downed, is_hidden, carrying_revive, iframes_left > 0.0)


@rpc("any_peer", "call_remote", "reliable")
func apply_net_state(downed: bool, hidden: bool, carrying: bool, has_iframes: bool) -> void:
	apply_local_state(downed, hidden, carrying)
	if has_iframes and iframes_left <= 0.0:
		iframes_left = 1.0


func _sync_tick(delta: float) -> void:
	if not NetworkManager.is_networked():
		return
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		rpc("_sync_state", global_position, velocity, is_hidden, is_downed, carrying_revive, is_sprinting, iframes_left > 0.0)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_state(pos: Vector2, vel: Vector2, hidden: bool, downed: bool, carrying: bool, sprinting: bool, has_iframes: bool) -> void:
	# Setelah MAIN LAGI, PC teman masih sempat mengirim posisi dari level
	# yang lama sebelum ikut memuat ulang. Paket basi itu dulu memindahkan
	# pemain teman di level baru milik host ke tempat lamanya, lalu ikut
	# terkirim balik ke teman lewat sinkron awal, sehingga teman muncul di
	# tempat lain, bukan di titik spawn. Jadi host mengabaikan paket posisi
	# dari teman sebentar setelah pemain itu di-spawn.
	if NetworkManager.is_server_authority() and Time.get_ticks_msec() - _lahir_ms < ABAIKAN_SYNC_AWAL_MS:
		return
	_target_pos = pos
	_has_target = true
	velocity = vel
	# Sembunyi / tertangkap / bawa item diputuskan HOST (lewat apply_net_state
	# yang reliable). Paket posisi dari client ini unreliable dan bisa datang
	# telat membawa nilai lama -> dulu bisa menimpa keputusan host sesaat
	# (mis. baru disembunyikan host, lalu tertimpa "tidak sembunyi" dan
	# langsung tertangkap). Jadi di host ketiga nilai itu diabaikan.
	if not NetworkManager.is_server_authority():
		is_hidden = hidden
		is_downed = downed
		carrying_revive = carrying
	is_sprinting = sprinting
	if has_iframes and iframes_left <= 0.0:
		iframes_left = 0.6
	# Koreksi keras kalau meleset jauh (mis. teleport revive).
	if global_position.distance_to(pos) > 120.0:
		global_position = pos
