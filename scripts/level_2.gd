extends Node2D
## Level 2 — Lobi Kantor "Gelap Gulita" (TileMap 72 x 46).
##
## Mode bertahan: dua pemain harus selamat dari jam 21.00 sampai 05.00
## (1 jam game = 90 detik) di lobi yang gelap total, lalu kabur lewat
## pintu kaca. Dasarnya tetap level_1.gd (minigame tugas, sembunyi,
## kurungan + item bangkit, pintu keluar, bintang). Yang baru di Level 2:
## - Pandangan selalu lingkaran kecil 1,5 tile. Mau melihat lebih jauh =
##   nyalakan senter HP (R): kerucut 7 tile, baterai cepat habis.
## - Baterai HP mulai 0%. Selama baterai > 0% HP hidup (tersambung WiFi
##   kantor) -> posisi pemain terlihat di denah operator; baterai turun pelan.
## - Titik cas: diam 10 detik di colokan; setelah dipakai korslet 1 jam
##   game. Cas pertama membangunkan musuh.
## - Komputer security: dinyalakan sekali -> jam mulai jalan. Operator
##   melihat denah, posisi teman (kalau HP-nya menyala), laporan, titik cas.
##   Error 3x (23.30, 01.30, 03.30): jam berhenti sampai kabel disambung.
## - 7 laporan gangguan muncul per jam dengan batas waktu.
## - 05.00: lampu menyala, pintu kaca terbuka kalau kunci cadangan &
##   pintu kaca (berdua) sudah beres.
## Semua state Level 2 dimiliki host lalu disebar ke client tiap 0,2 detik.
## Belum ada (tahap berikutnya): Satpam baru + Mantan Bos, hukuman
## laporan terlambat (selain genset), minigame keypad & tahan E.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const LEVEL_ID: String = "level_2"
const PAR_TIME: float = 720.0
const TASK_RANGE: float = 62.0
const HIDE_RANGE: float = 50.0
const REVIVE_RANGE: float = 52.0
const CAGE_RANGE: float = 68.0
const EXIT_RADIUS: float = 72.0
const EXIT_HOLD: float = 1.5
const RESCUE_TIME: float = 2.0
const SOLO_REVIVE_DELAY: float = 12.0
## Lobi hampir gelap total: di luar cahaya, benda masih terlihat SEDIKIT
## sekali (3,5% terang). Ubah ke Color(0, 0, 0) kalau mau hitam pekat.
const BASE_MODULATE: Color = Color(0.035, 0.035, 0.05)
const BLACKOUT_MODULATE: Color = Color(0.01, 0.01, 0.015)
## Warna lobi saat lampu menyala lagi jam 05.00.
const SUBUH_MODULATE: Color = Color(0.3, 0.3, 0.38)
const MAP_SIZE_TILES: Vector2i = Vector2i(72, 46)
## Zoom kamera Level 2 (bawaan Camera2D = 1). Makin besar = makin dekat.
const CAMERA_ZOOM: float = 4.5

# --- baterai HP, pandangan & senter (angka dari dokumen desain)
## Lingkaran pandang bergradasi (tekstur lingkaran_pandang.png, 256 px).
## Skala 0.55 = cahaya sampai ±2,2 tile, makin ke tepi makin redup; batas
## yang masih jelas terlihat ±1,5 tile. Tidak ikut baterai.
const SKALA_LINGKARAN: float = 0.55
const SENTER_PANJANG: float = 7.0  # panjang kerucut senter (tile)
const BATERAI_TURUN_LAYAR: float = 0.5  # % per detik (1% per 2 detik) selama HP hidup
const BATERAI_TURUN_SENTER: float = 15.0  # % per detik (penuh habis ±6,7 detik)
const CAS_PER_DETIK: float = 10.0  # 0 -> 100% dalam 10 detik
const KORSLET_DETIK: float = 90.0  # colokan mati 1 jam game setelah dipakai
const CAS_MIN_KORSLET: float = 5.0  # dapat < 5% (cuma sebentar) = colokan tidak korslet
const CAS_RANGE: float = 40.0
const KOMPUTER_RANGE: float = 48.0
const KABEL_RANGE: float = 44.0

# --- jam (21.00 -> 05.00, 1 jam game = 90 detik nyata)
const DETIK_PER_JAM_GAME: float = 90.0
const MENIT_SUBUH: float = 480.0  # 8 jam setelah 21.00 = 05.00
const MENIT_ERROR: Array[float] = [150.0, 270.0, 390.0]  # 23.30, 01.30, 03.30
const NAMA_FASE: Array[String] = ["-", "Sunyi", "Gelisah", "Jam Mati", "Subuh"]
## Jam muncul laporan kalau metadata "jam_laporan" belum diisi di node tugas.
const JAM_LAPORAN_CADANGAN: Dictionary = {
	&"speaker": 22, &"genset": 23, &"tv_rapat": 0, &"fotokopi": 1,
	&"lift": 2, &"kunci_cadangan": 3, &"pintu_kaca": 4,
}

const F_MONO: Font = preload("res://assets/fonts/lmmono10-regular.otf")
const F_MONO_TEBAL: Font = preload("res://assets/fonts/lmmonolt10-bold.otf")

# --- Isi panduan (dropdown TAB) khusus Level 2 ---
# Menimpa isi default Level 1 di HUD (peta M tidak ada di Level 2).
const GUIDE_LINES_L2: Array[String] = [
	"Bertahanlah dari jam 21.00 sampai 05.00.",
	"Senter HP (R) butuh baterai - isi daya di titik pengisian.",
	"Laporkan gangguan di komputer sekuriti, lalu kabur lewat pintu kaca jam 05.00.",
	"Tekan TAB untuk membuka / menutup panduan ini.",
]
const PENANDA_LAPORAN: GDScript = preload("res://scripts/level2/penanda_laporan.gd")
## Nama singkat laporan untuk sticky note di HUD.
const NAMA_PENDEK: Dictionary = {
	&"speaker": "speaker", &"genset": "genset", &"tv_rapat": "TV rapat", &"fotokopi": "fotokopi",
	&"lift": "lift", &"kunci_cadangan": "kunci", &"pintu_kaca": "pintu kaca",
}
const TEX_PANDANG: Texture2D = preload("res://assets/sprites/lingkaran_pandang.png")
const TEX_SENTER: Texture2D = preload("res://assets/sprites/senter_kerucut.png")
const HUD_MALAM: GDScript = preload("res://scripts/level2/hud_malam.gd")
const LAYAR_KOMPUTER: GDScript = preload("res://scripts/level2/layar_komputer.gd")
## Sprite Satpam = karakter "Manager" bubbabba, dipakai apa adanya (tidak diedit).
const SATPAM_FRAMES: SpriteFrames = preload("res://assets/characters/satpam/satpam_frames.tres")
## Frame Manager 32x64: kakinya ada di bawah frame. Digeser 16 px ke atas
## supaya kaki pas di titik collision (sama seperti pemain).
const SATPAM_OFFSET: Vector2 = Vector2(0, -16)
## z_index pemain & Satpam di Level 2. Harus SAMA dengan layer Props &
## props_atas (5) supaya Y-Sort jalan: di depan furnitur kalau berdiri di
## bawahnya, di belakang furnitur kalau berdiri di atasnya.
const Z_KARAKTER: int = 5

var _level_active: bool = false
var _level_ended: bool = false
var _paused_for_disconnect: bool = false
var _level_time: float = 0.0
var _deaths_total: int = 0
var _exit_open: bool = false
var _exit_progress: float = 0.0
var _rescue_progress: float = 0.0
var _cage_peer: int = -1
var _revive_carrier: int = -1
var _revive_visible: bool = false
var _solo_revive_timer: float = -1.0
var _wipe_timer: float = -1.0
var _blackout_timer: float = 0.0
var _disconnect_timer: float = -1.0
var _progress_broadcast_timer: float = 0.0
var _flicker_time: float = 0.0

var _players: Dictionary = {}  # peer_id -> Player
var _holding: Dictionary = {}  # peer_id -> bool
var _tasks: Dictionary = {}  # StringName -> Dictionary node/progress/completed/game_type/requires_two
var _doors: Dictionary = {}  # String -> LockedDoor
var _spots: Array[Node2D] = []
var _lights: Array[PointLight2D] = []
var _light_base: Array[float] = []
var _light_phase: Array[float] = []
var _pathfinder: GridPathfinder = null
var _server_parts: Dictionary = {}  # peer_id -> true (bagian server selesai)
var minigame_layer: MinigameLayer = null

# =====================================================================
# MENU DEBUG — pilih node Level2 di Scene Tree, lalu lihat Inspector >
# "Debug (khusus tes)". Semua pilihan hanya berlaku kalau Debug Aktif
# dicentang. MATIKAN lagi sebelum game dikumpulkan / dimainkan serius.
# =====================================================================
@export_group("Debug (khusus tes)")
## Saklar utama. Kalau tidak dicentang, semua pilihan debug di bawah diabaikan.
@export var debug_aktif: bool = false
## Mulai dari jam berapa (menit setelah 21.00). 60 = 22.00, 150 = 23.30, 300 = 02.00, 420 = 04.00.
@export_range(0, 479, 15) var debug_mulai_menit: int = 0
## Komputer security langsung menyala, jadi jam langsung berjalan.
@export var debug_komputer_nyala: bool = false
## Baterai awal semua pemain (%).
@export_range(0, 100, 5) var debug_baterai_awal: int = 0
## Baterai tidak pernah berkurang.
@export var debug_baterai_tak_habis: bool = false
## Kecepatan jam. 1 = normal (1 jam game = 90 detik), 6 = semalam kira-kira 2 menit.
@export_range(1.0, 20.0, 0.5) var debug_kecepatan_jam: float = 1.0
## Satpam tidak pernah aktif.
@export var debug_tanpa_satpam: bool = false
## Pemain tidak bisa tertangkap.
@export var debug_kebal: bool = false
## Lobi terang (gelap dimatikan) supaya map mudah dilihat. F9 saat main juga bisa.
@export var debug_terang: bool = false
## Lewati error kabel jam 23.30 / 01.30 / 03.30.
@export var debug_tanpa_error_kabel: bool = false
## Tampilkan nama ruangan & garis rute Satpam saat main.
@export var debug_tampilkan_panduan: bool = false
## Kotak info debug di kanan bawah layar (F1 untuk sembunyikan / munculkan).
@export var debug_kotak_info: bool = true
## Tombol cepat saat main: F1 info, F2 +30 menit, F3 baterai 100%, F4 picu / perbaiki error kabel, F9 terang, F10 lompat ke 04.59. (F5–F8 sengaja tidak dipakai karena dipakai editor Godot.)
@export var debug_tombol_cepat: bool = true
@export_group("")

var _terang: bool = false
var _info_debug_tampil: bool = true
var _penanda: Dictionary = {}  # task_id -> penanda_laporan (bentuk di lantai)

# --- state Level 2 (dimiliki host, disebar ke client tiap 0,2 detik)
var _baterai: Dictionary = {}  # peer_id -> 0..100 (%)
var _senter: Dictionary = {}  # peer_id -> bool
var _cas_dipakai: Dictionary = {}  # peer_id -> nama node titik cas ("" = tidak ngecas)
var _cas_mulai: Dictionary = {}  # peer_id -> baterai saat mulai ngecas
var _cas_korslet: Dictionary = {}  # nama titik cas -> sisa detik korslet
var _jam_menit: float = 0.0  # menit sejak 21.00
var _komputer_pernah: bool = false
var _komputer_nyala: bool = false
var _error_ke: int = 0
var _kabel_rusak: String = ""  # nama node titik kabel yang putus ("" = tidak error)
var _musuh_aktif: bool = false
var _subuh: bool = false
var _genset_mati: bool = false
var _state_timer: float = 0.0
var _lampu_faktor: float = 0.0
var _cas_nodes: Dictionary = {}  # nama -> node titik cas
var _kabel_nodes: Dictionary = {}  # nama -> node titik kabel
var _glow_laporan: Dictionary = {}  # task_id -> PointLight2D kedip di alat yang rusak
var hud_malam: CanvasLayer = null
var layar_komputer: CanvasLayer = null

@onready var floor_layer: TileMapLayer = get_node_or_null("Lantai")
@onready var walls_layer: TileMapLayer = get_node_or_null("Dinding")
@onready var props_layer: TileMapLayer = get_node_or_null("Props")
@onready var canvas_modulate: CanvasModulate = get_node_or_null("CanvasModulate")
@onready var players_container: Node2D = get_node_or_null("Pemain")
@onready var tasks_container: Node2D = get_node_or_null("Tugas")
@onready var spots_container: Node2D = get_node_or_null("TempatSembunyi")
@onready var doors_container: Node2D = get_node_or_null("Pintu")  # Level 2 tidak punya pintu terkunci (boleh kosong)
@onready var spawns_container: Node2D = get_node_or_null("Spawn")
@onready var lights_container: Node2D = get_node_or_null("Lampu")
@onready var enemy: CharacterBody2D = get_node_or_null("Satpam")
@onready var exit_door: Node2D = get_node_or_null("PintuKeluar")
@onready var cage: Node2D = get_node_or_null("Kurungan")
@onready var revive_item: Node2D = get_node_or_null("ItemBangkit")
@onready var hud: CanvasLayer = get_node_or_null("HUD")
@onready var komputer: Node2D = get_node_or_null("KomputerSecurity")
@onready var cas_container: Node = get_node_or_null("TitikCas")
@onready var kabel_container: Node = get_node_or_null("TitikKabel")


func _ready() -> void:
	add_to_group("LevelManager")
	randomize()
	_collect_level_nodes()
	_setup_pathfinder()
	_setup_enemy()
	_setup_lights()
	_sembunyikan_panduan_editor()
	_setup_malam()
	_terapkan_debug()
	_laporan_node()
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)
	_level_active = true
	if NetworkManager.is_server_authority():
		_spawn_player(NetworkManager.local_peer_id(), 0, true)
		var idx: int = 1
		for pid: int in NetworkManager.connected_ids:
			_spawn_player(pid, idx, true)
			idx += 1
	elif NetworkManager.mode == NetworkManager.Mode.CLIENT:
		rpc_id(1, "request_sync_rpc")
	minigame_layer = MinigameLayer.new()
	minigame_layer.name = "MinigameLayer"
	add_child(minigame_layer)
	# Popup tugas Level 2 memakai gaya standar (sama seperti Level 1).
	# Gaya "monitor CCTV" dari proyek asal tidak dipakai di sini karena
	# MinigameLayer upstream sudah memakai gaya UiTheme yang berbeda.
	_update_hud_static()
	if hud != null:
		hud.set_guide_lines(GUIDE_LINES_L2)


func is_level_running() -> bool:
	return _level_active and not _level_ended and not _paused_for_disconnect


func is_minigame_open() -> bool:
	# Dipakai HUD: tombol TAB tidak boleh menumpuk panduan di atas minigame.
	return minigame_layer != null and minigame_layer.is_open()


func _collect_level_nodes() -> void:
	# Isi Tugas / TempatSembunyi boleh dikelompokkan dalam Node2D lain,
	# jadi dicari rekursif. Node yang bukan tugas (misal Marker2D catatan)
	# dilewati karena tidak punya properti task_id.
	for st: Node in _semua_anak(tasks_container):
		if not ("task_id" in st):
			continue
		# Jam muncul laporan diambil dari Metadata node (Inspector > Metadata).
		var jam: int = int(st.get_meta("jam_laporan", JAM_LAPORAN_CADANGAN.get(st.task_id, 22)))
		var muncul: float = float(((jam - 21 + 24) % 24) * 60)
		_tasks[st.task_id] = {
			"node": st,
			"progress": 0.0,
			"completed": false,
			"game_type": st.game_type,
			"requires_two": st.requires_two,
			"jam": jam,
			"muncul": muncul,
			# Batas waktu: 1,5 jam game di fase 1, lalu 1 jam game.
			"batas": muncul + (90.0 if muncul < 120.0 else 60.0),
			"aktif": false,
			"terlambat": false,
			"wajib": bool(st.get_meta("wajib", false)),
			"area": str(st.get_meta("area", "")),
		}
	for d: Node in _semua_anak(doors_container):
		if "door_id" in d:
			_doors[d.door_id] = d
	for s: Node in _semua_anak(spots_container):
		if s.has_method("set_occupied"):
			_spots.append(s)


func _semua_anak(root: Node) -> Array[Node]:
	# Semua turunan sebuah node (anak, cucu, dst).
	var out: Array[Node] = []
	if root == null:
		return out
	for c: Node in root.get_children():
		out.append(c)
		out.append_array(_semua_anak(c))
	return out


func _sembunyikan_panduan_editor() -> void:
	if _debug(debug_tampilkan_panduan):
		return
	# NamaRuangan & JalurSatpam cuma panduan saat menyusun map di editor.
	# Saat game jalan disembunyikan supaya pemain tidak dapat "contekan".
	for nama: String in ["NamaRuangan", "JalurSatpam"]:
		var n: Node = get_node_or_null(nama)
		if n is CanvasItem:
			(n as CanvasItem).visible = false


func _laporan_node() -> void:
	# Cek cepat di panel Output: kalau angkanya 0, berarti ada node yang
	# namanya berubah / pindah folder.
	var rute: int = enemy.patrol_points.size() if enemy != null else 0
	print("[Level 2] tugas: %d | tempat sembunyi: %d | lampu: %d | titik cas: %d | titik kabel: %d | titik rute satpam: %d | komputer: %s" % [
		_tasks.size(), _spots.size(), _lights.size(), _cas_nodes.size(), _kabel_nodes.size(), rute, "ada" if komputer != null else "TIDAK ADA"])


func _hitung_marker(nama_grup: String) -> int:
	var n: int = 0
	for c: Node in _semua_anak(get_node_or_null(nama_grup)):
		if c is Marker2D:
			n += 1
	return n


func _setup_pathfinder() -> void:
	if floor_layer == null or walls_layer == null:
		push_warning("Level 2: TileMapLayer Lantai/Dinding tidak ditemukan; pathfinding Satpam nonaktif.")
		return
	var blocked: Dictionary = {}
	for d: Node in _doors.values():
		for cell: Vector2i in d.door_cells:
			blocked[cell] = true
	_pathfinder = GridPathfinder.new()
	_pathfinder.setup(floor_layer, walls_layer, props_layer, blocked)


func _setup_enemy() -> void:
	if enemy == null:
		return
	enemy.pathfinder = _pathfinder
	enemy.patrol_points = _rute_satpam("Fase1")
	enemy.spawn_points = _marker_positions("EnemySpawn", 8, [Vector2i(57, 21), Vector2i(66, 8), Vector2i(8, 35), Vector2i(25, 41), Vector2i(40, 39), Vector2i(64, 38), Vector2i(16, 14), Vector2i(50, 34)])
	var start: Vector2 = _marker_pos("EnemySpawn1", Vector2i(57, 21))
	enemy.global_position = start
	_pasang_sprite_satpam()
	# Musuh belum aktif sampai ada pemain yang ngecas HP pertama kali.
	_set_musuh_aktif(false)


func _pasang_sprite_satpam() -> void:
	# enemy.tscn dipakai bareng Level 1, jadi sprite-nya diganti dari sini saja.
	var spr: AnimatedSprite2D = enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr != null:
		spr.sprite_frames = SATPAM_FRAMES
		spr.offset = SATPAM_OFFSET
		spr.play("idle_down")
	# Level 1 memberi warna keunguan ke musuh. Satpam pakai warna asli sprite.
	if "_base_tint" in enemy:
		enemy.set("_base_tint", Color.WHITE)
	enemy.z_index = Z_KARAKTER
	# Tanda "?"/"!" di atas kepala dinaikkan karena Satpam lebih tinggi.
	var tanda: Control = enemy.get_node_or_null("StateLabel") as Control
	if tanda != null:
		tanda.position.y = -56.0


func _rute_satpam(nama_fase: String) -> Array[Vector2]:
	# Rute patroli digambar pakai Line2D di JalurSatpam, jadi bisa digeser
	# langsung di editor. Kalau Line2D-nya tidak ketemu, pakai rute cadangan.
	var out: Array[Vector2] = []
	var jalur: Node = get_node_or_null("JalurSatpam")
	var line: Line2D = null
	if jalur != null:
		line = jalur.get_node_or_null(nama_fase) as Line2D
	if line != null:
		for pt: Vector2 in line.points:
			out.append(line.to_global(pt))
	if out.size() < 2:
		out.clear()
		for cell: Vector2i in [Vector2i(2, 22), Vector2i(12, 22), Vector2i(21, 24), Vector2i(23, 29), Vector2i(41, 29), Vector2i(52, 29), Vector2i(57, 25), Vector2i(57, 21), Vector2i(52, 16), Vector2i(43, 16), Vector2i(32, 15), Vector2i(23, 15)]:
			out.append(Vector2(cell) * 32.0 + Vector2(16, 16))
	return out


func _setup_lights() -> void:
	# Lampu dikelompokkan per area (Lampu/Atrium, Lampu/kafe, ...), jadi rekursif.
	for l: Node in _semua_anak(lights_container):
		if l is PointLight2D:
			_lights.append(l)
			_light_base.append(l.energy)
			_light_phase.append(randf() * TAU)


func _marker_pos(marker_name: String, fallback_cell: Vector2i) -> Vector2:
	if spawns_container != null:
		# find_child: marker boleh ada di dalam folder (misal Spawn/musuh).
		var m: Node2D = spawns_container.find_child(marker_name, true, false) as Node2D
		if m != null:
			return m.global_position
	return Vector2(fallback_cell) * 32.0 + Vector2(16, 16)


func _marker_positions(prefix: String, count: int, fallbacks: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in range(count):
		out.append(_marker_pos(prefix + str(i + 1), fallbacks[i]))
	return out


func _revive_points() -> Array[Vector2]:
	return _marker_positions("Revive", 8, [Vector2i(13, 9), Vector2i(44, 10), Vector2i(58, 10), Vector2i(2, 15), Vector2i(30, 20), Vector2i(66, 24), Vector2i(13, 38), Vector2i(52, 42)])


# ---------------------------------------------------------------- spawn ---
func _spawn_player(peer_id: int, index: int, broadcast: bool) -> void:
	if _players.has(peer_id):
		return
	if players_container == null:
		return
	var p: CharacterBody2D = PLAYER_SCENE.instantiate()
	p.name = "Player_%d" % peer_id
	p.z_index = Z_KARAKTER  # player.tscn pakai 10 (Level 1); di sini ikut Y-Sort
	p.set_multiplayer_authority(peer_id)
	p.player_index = index + 1
	p.position = _marker_pos("PlayerSpawn%d" % (index + 1), Vector2i(3, 10) if index == 0 else Vector2i(5, 10))
	players_container.add_child(p)
	_pasang_lampu_pemain(p)
	if not _baterai.has(peer_id):
		_baterai[peer_id] = float(debug_baterai_awal) if debug_aktif else 0.0
		_senter[peer_id] = false
		_cas_dipakai[peer_id] = ""
	_players[peer_id] = p
	_holding[peer_id] = false
	if broadcast and NetworkManager.is_networked() and NetworkManager.is_server_authority():
		rpc("_spawn_player_rpc", peer_id, index)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_rpc(peer_id: int, index: int) -> void:
	_spawn_player(peer_id, index, false)


func _on_peer_joined(peer_id: int) -> void:
	if not NetworkManager.is_server_authority() or _level_ended:
		return
	var index: int = 1 if _players.size() >= 1 else 0
	_spawn_player(peer_id, index, true)


func _on_peer_left(_peer_id: int) -> void:
	if _level_ended:
		return
	_paused_for_disconnect = true
	if hud != null:
		hud.show_disconnect("Partner terputus. Kembali ke menu untuk main lagi.")


func _on_host_disconnected() -> void:
	if _level_ended:
		return
	_paused_for_disconnect = true
	_disconnect_timer = 4.0
	if hud != null:
		hud.show_disconnect("Host terputus. Kembali ke menu...")


# ------------------------------------------------------------- sync RPC ---
@rpc("any_peer", "call_remote", "reliable")
func request_sync_rpc() -> void:
	if not NetworkManager.is_server_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var players_data: Array = []
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		players_data.append([pid, p.player_index - 1, p.global_position])
	var tasks_data: Dictionary = {}
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		tasks_data[tid] = [t["progress"], t["completed"]]
	var doors_data: Dictionary = {}
	for did: String in _doors.keys():
		doors_data[did] = _doors[did].is_open
	var data: Dictionary = {
		"players": players_data,
		"tasks": tasks_data,
		"doors": doors_data,
		"enemy_pos": enemy.global_position if enemy != null else Vector2.ZERO,
		"enemy_state": enemy.state if enemy != null else 0,
		"time": _level_time,
		"deaths": _deaths_total,
		"exit_open": _exit_open,
		"cage_peer": _cage_peer,
		"cage_pos": cage.global_position if cage != null else Vector2.ZERO,
		"revive_visible": _revive_visible,
		"revive_pos": revive_item.global_position if revive_item != null else Vector2.ZERO,
		"carrier": _revive_carrier,
	}
	rpc_id(sender, "_full_state_rpc", data)


@rpc("authority", "call_remote", "reliable")
func _full_state_rpc(data: Dictionary) -> void:
	for row: Array in data["players"]:
		_spawn_player(int(row[0]), int(row[1]), false)
		var p: Node = _players.get(int(row[0]))
		if p != null:
			p.global_position = row[2]
	var tasks_data: Dictionary = data["tasks"]
	for tid: String in tasks_data.keys():
		var key := StringName(tid)
		if _tasks.has(key):
			var t: Dictionary = _tasks[key]
			t["progress"] = float(tasks_data[tid][0])
			t["completed"] = bool(tasks_data[tid][1])
			t["node"].set_progress(t["progress"])
			if t["completed"]:
				t["node"].set_completed()
	var doors_data: Dictionary = data["doors"]
	for did: String in doors_data.keys():
		if bool(doors_data[did]) and _doors.has(did):
			_apply_door_open(did)
	if enemy != null:
		enemy.global_position = data["enemy_pos"]
		enemy.state = int(data["enemy_state"])
	_level_time = float(data["time"])
	_deaths_total = int(data["deaths"])
	_exit_open = bool(data["exit_open"])
	if _exit_open and exit_door != null:
		exit_door.set_locked(false)
	_cage_peer = int(data["cage_peer"])
	_revive_carrier = int(data["carrier"])
	_revive_visible = bool(data["revive_visible"])
	if _cage_peer != -1 and cage != null:
		cage.show_at(data["cage_pos"])
	if _revive_visible and revive_item != null:
		revive_item.show_at(data["revive_pos"])
	_update_hud_static()


# ------------------------------------------------------------ interaksi ---
func notify_interact_pressed(peer_id: int) -> void:
	if NetworkManager.is_server_authority():
		_handle_press(peer_id)
	else:
		rpc_id(1, "request_press_rpc", peer_id)


func notify_interact_released(peer_id: int) -> void:
	if NetworkManager.is_server_authority():
		_holding[peer_id] = false
	else:
		rpc_id(1, "request_release_rpc", peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_press_rpc(peer_id: int) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_press(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_release_rpc(peer_id: int) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_holding[peer_id] = false


func _handle_press(peer_id: int) -> void:
	if not is_level_running():
		return
	var p: Node = _players.get(peer_id)
	if p == null or p.is_downed:
		return
	if p.is_hidden:
		_set_player_hidden(p, false)
		return
	# 1) Selamatkan teman (butuh item; hold ditangani _physics_process).
	if _cage_peer != -1 and _revive_carrier == peer_id and p.global_position.distance_to(cage.global_position) <= CAGE_RANGE:
		_holding[peer_id] = true
		return
	# 2) Ambil item bangkit.
	if _revive_visible and revive_item != null and p.global_position.distance_to(revive_item.global_position) <= REVIVE_RANGE:
		_revive_visible = false
		_revive_carrier = peer_id
		revive_item.hide_item()
		p.apply_local_state(false, false, true)
		p.broadcast_state()
		if NetworkManager.is_networked():
			rpc("_revive_taken_rpc", peer_id)
		_show_message("Item Bangkit didapat! Selamatkan temanmu di kurungan.")
		return
	# 2b) Sedang ngecas: tekan E lagi = cabut HP.
	if str(_cas_dipakai.get(peer_id, "")) != "":
		_hentikan_cas(peer_id)
		return
	# 2c) Komputer security (nyalakan / duduk jadi operator).
	if komputer != null and p.global_position.distance_to(komputer.global_position) <= KOMPUTER_RANGE:
		_pakai_komputer(peer_id)
		return
	# 2d) Kabel putus saat komputer error.
	if _kabel_rusak != "" and _kabel_nodes.has(_kabel_rusak) and p.global_position.distance_to((_kabel_nodes[_kabel_rusak] as Node2D).global_position) <= KABEL_RANGE:
		_buka_minigame_untuk(peer_id, StringName("kabel_" + _kabel_rusak))
		return
	# 2e) Titik cas HP.
	var cas_nama: String = _cas_terdekat(p.global_position)
	if cas_nama != "":
		_mulai_cas(peer_id, cas_nama)
		return
	# 3) Kerjakan tugas (buka minigame di layar pemain itu).
	var tid: StringName = _nearest_task(p.global_position)
	if tid != StringName(""):
		_try_open_minigame(peer_id, tid)
		return
	# 4) Sembunyi.
	if _nearest_spot(p.global_position) != null:
		_set_player_hidden(p, true)
		return


@rpc("authority", "call_remote", "reliable")
func _revive_taken_rpc(peer_id: int) -> void:
	_revive_visible = false
	_revive_carrier = peer_id
	if revive_item != null:
		revive_item.hide_item()


func _set_player_hidden(p: Node, hidden: bool) -> void:
	p.apply_local_state(p.is_downed, hidden, p.carrying_revive)
	p.broadcast_state()
	if hidden and NetworkManager.is_server_authority():
		# Sembunyi = senter mati & HP dicabut dari colokan.
		var pid: int = p.peer_id
		_senter[pid] = false
		_hentikan_cas(pid)


func _nearest_task(pos: Vector2) -> StringName:
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if t["completed"] or not bool(t["aktif"]):
			continue
		if pos.distance_to((t["node"] as Node2D).global_position) <= TASK_RANGE:
			return tid
	return StringName("")


func _nearest_spot(pos: Vector2) -> Node2D:
	for s: Node2D in _spots:
		if pos.distance_to(s.global_position) <= HIDE_RANGE:
			return s
	return null


# ------------------------------------------------------------ minigame ---
func get_local_player() -> Node:
	return _players.get(NetworkManager.local_peer_id())


func task_position(tid: StringName) -> Vector2:
	var kabel: String = _nama_kabel_dari_tid(tid)
	if kabel != "" and _kabel_nodes.has(kabel):
		return (_kabel_nodes[kabel] as Node2D).global_position
	if _tasks.has(tid):
		return (_tasks[tid]["node"] as Node2D).global_position
	return Vector2.ZERO


func is_task_completed(tid: StringName) -> bool:
	var kabel: String = _nama_kabel_dari_tid(tid)
	if kabel != "":
		return _kabel_rusak != kabel
	return _tasks.has(tid) and bool(_tasks[tid]["completed"])


func set_local_minigame_open(open: bool) -> void:
	var p: Node = get_local_player()
	if p == null:
		return
	p.minigame_open = open
	if open:
		p.velocity = Vector2.ZERO
		p.interact_held = false


func open_minigame_for_local(tid: StringName) -> void:
	if minigame_layer == null:
		return
	if _nama_kabel_dari_tid(tid) != "":
		minigame_layer.open_minigame(tid, &"kabel")
		return
	if not _tasks.has(tid):
		return
	minigame_layer.open_minigame(tid, _tasks[tid]["game_type"])


func _try_open_minigame(peer_id: int, tid: StringName) -> void:
	var t: Dictionary = _tasks[tid]
	if t["requires_two"] and _server_needed() > 1:
		var in_range: int = 0
		for pid: int in _players.keys():
			var p: Node = _players[pid]
			if p.is_downed or p.is_hidden:
				continue
			if p.global_position.distance_to((t["node"] as Node2D).global_position) <= TASK_RANGE:
				in_range += 1
		if in_range < 2:
			_notice_to(peer_id, "Butuh 2 pemain di dekat server untuk mulai!")
			return
	if peer_id == NetworkManager.local_peer_id():
		open_minigame_for_local(tid)
	elif NetworkManager.is_networked():
		rpc_id(peer_id, "_open_minigame_rpc", String(tid))


@rpc("authority", "call_remote", "reliable")
func _open_minigame_rpc(tid: String) -> void:
	open_minigame_for_local(StringName(tid))


func submit_minigame_result(tid: StringName) -> void:
	if NetworkManager.is_server_authority():
		_handle_minigame_result(NetworkManager.local_peer_id(), tid)
	elif NetworkManager.is_networked():
		rpc_id(1, "request_minigame_result_rpc", NetworkManager.local_peer_id(), String(tid))


# -------------------------------------------------- suara kesalahan task ---
func report_mistake_noise() -> void:
	# Kesalahan di minigame lokal: Satpam mendengar suara dari posisi
	# pemain lokal. Server memproses langsung; klien kirim ke host.
	# Dipanggil MinigameLayer saat minigame meng-emit mistake_made.
	# Satpam yang belum aktif (belum ada yang ngecas HP pertama kali)
	# tidak dibangunkan oleh suara ini.
	if NetworkManager.is_server_authority():
		_noise_at_player(NetworkManager.local_peer_id())
	elif NetworkManager.is_networked():
		rpc_id(1, "report_mistake_rpc", NetworkManager.local_peer_id())


@rpc("any_peer", "call_remote", "unreliable")
func report_mistake_rpc(peer_id: int) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_noise_at_player(peer_id)


func _noise_at_player(peer_id: int) -> void:
	var p: Node = _players.get(peer_id)
	if p == null or enemy == null or not _musuh_aktif:
		return
	if enemy.hear_noise(p.global_position):
		_show_message("Berisik! Satpam mendekat...")


@rpc("any_peer", "call_remote", "reliable")
func request_minigame_result_rpc(peer_id: int, tid: String) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_minigame_result(peer_id, StringName(tid))


func _handle_minigame_result(peer_id: int, tid: StringName) -> void:
	var kabel: String = _nama_kabel_dari_tid(tid)
	if kabel != "":
		var pk: Node = _players.get(peer_id)
		if pk != null and not pk.is_downed and kabel == _kabel_rusak and pk.global_position.distance_to(task_position(tid)) <= KABEL_RANGE + 60.0:
			_perbaiki_kabel()
		return
	if not _tasks.has(tid) or bool(_tasks[tid]["completed"]):
		return
	var p: Node = _players.get(peer_id)
	if p == null or p.is_downed or p.is_hidden:
		return
	if p.global_position.distance_to((_tasks[tid]["node"] as Node2D).global_position) > TASK_RANGE + 30.0:
		return
	if not bool(_tasks[tid]["requires_two"]):
		_complete_task(tid)
		return
	# Tugas co-op: bank bagian pemain ini, selesaikan kalau semua
	# bagian terkumpul DAN semua pemain berada di dekat stasiun.
	_server_parts[peer_id] = true
	if _server_parts_ready(tid):
		_complete_task(tid)
	else:
		_notice_to(peer_id, "Bagianmu selesai! Menunggu partner menyelesaikan bagiannya.")


func _server_needed() -> int:
	# Solo: 1 pemain cukup (kalau tidak, game tidak bisa tamat solo).
	return 1 if not NetworkManager.is_networked() else 2


func _server_parts_ready(tid: StringName) -> bool:
	if _server_parts.size() < _server_needed():
		return false
	var station_pos: Vector2 = (_tasks[tid]["node"] as Node2D).global_position
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		if p.is_downed or p.is_hidden:
			return false
		if p.global_position.distance_to(station_pos) > TASK_RANGE + 30.0:
			return false
	return true


func report_minigame_progress(tid: StringName, progress: float) -> void:
	if NetworkManager.is_server_authority():
		_apply_task_progress(tid, progress)
	elif NetworkManager.is_networked():
		rpc_id(1, "report_minigame_progress_rpc", String(tid), progress)


@rpc("any_peer", "call_remote", "unreliable")
func report_minigame_progress_rpc(tid: String, progress: float) -> void:
	if not NetworkManager.is_server_authority():
		return
	_apply_task_progress(StringName(tid), progress)


func _apply_task_progress(tid: StringName, progress: float) -> void:
	if not _tasks.has(tid) or bool(_tasks[tid]["completed"]):
		return
	var t: Dictionary = _tasks[tid]
	t["progress"] = clampf(progress, 0.0, 1.0)
	t["node"].set_progress(t["progress"])


func _notice_to(peer_id: int, text: String) -> void:
	if peer_id == NetworkManager.local_peer_id():
		_show_message(text)
	elif NetworkManager.is_networked():
		rpc_id(peer_id, "_notice_rpc", text)


@rpc("authority", "call_remote", "reliable")
func _notice_rpc(text: String) -> void:
	_show_message(text)


# -------------------------------------------------------------- physics ---
func _physics_process(delta: float) -> void:
	if _level_active and not _level_ended:
		_level_time += delta
	if _disconnect_timer > 0.0:
		_disconnect_timer -= delta
		if _disconnect_timer <= 0.0:
			_go_to_menu()
			return
	if not NetworkManager.is_server_authority():
		return
	if not is_level_running():
		return
	_tick_tasks(delta)
	_tick_rescue(delta)
	_tick_exit(delta)
	_tick_revive_timers(delta)
	_tick_malam(delta)
	_progress_broadcast_timer -= delta
	if _progress_broadcast_timer <= 0.0:
		_progress_broadcast_timer = 0.25
		_broadcast_progress()


func _tick_tasks(_delta: float) -> void:
	# Tugas biasa selesai lewat minigame (submit_minigame_result).
	# Di sini hanya menyelesaikan tugas co-op yang bagiannya sudah
	# terkumpul begitu semua pemain kembali berkumpul di stasiun.
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if t["completed"] or not bool(t["requires_two"]):
			continue
		if _server_parts_ready(tid):
			_complete_task(tid)


func _complete_task(tid: StringName) -> void:
	var t: Dictionary = _tasks[tid]
	t["completed"] = true
	t["progress"] = 1.0
	t["node"].set_completed()
	if NetworkManager.is_networked():
		rpc("_task_completed_rpc", String(tid))
	_kabar("beres", str(t["node"].title), "%d/%d laporan beres" % [_completed_count(), _tasks.size()])
	if tid == &"genset" and _genset_mati:
		_genset_mati = false
		_kabar("info", "Genset menyala lagi", "titik cas berfungsi kembali")
	# Pintu kaca baru terbuka jam 05.00 (dan kalau tugas wajibnya beres).
	_cek_pintu_kaca()


@rpc("authority", "call_remote", "reliable")
func _task_completed_rpc(tid: String) -> void:
	var key := StringName(tid)
	if _tasks.has(key):
		var t: Dictionary = _tasks[key]
		t["completed"] = true
		t["progress"] = 1.0
		t["node"].set_completed()


@rpc("authority", "call_remote", "reliable")
func _exit_opened_rpc() -> void:
	_exit_open = true
	if exit_door != null:
		exit_door.set_locked(false)


func _broadcast_progress() -> void:
	if not NetworkManager.is_networked():
		return
	var data: Dictionary = {}
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if not t["completed"] and float(t["progress"]) > 0.0:
			data[String(tid)] = float(t["progress"])
	rpc("_tasks_progress_rpc", data, _exit_progress, _rescue_progress)


@rpc("authority", "call_remote", "unreliable")
func _tasks_progress_rpc(data: Dictionary, exit_progress: float, rescue_progress: float) -> void:
	for tid: String in data.keys():
		var key := StringName(tid)
		if _tasks.has(key):
			var t: Dictionary = _tasks[key]
			t["progress"] = float(data[tid])
			t["node"].set_progress(t["progress"])
	_exit_progress = exit_progress
	_rescue_progress = rescue_progress
	if exit_door != null:
		exit_door.set_progress(_exit_progress)
	if cage != null and cage.visible:
		cage.set_rescue_progress(_rescue_progress)


func _tick_rescue(delta: float) -> void:
	if _cage_peer == -1 or _revive_carrier == -1:
		_rescue_progress = 0.0
		return
	var carrier: Node = _players.get(_revive_carrier)
	if carrier == null or carrier.is_downed or carrier.is_hidden:
		_rescue_progress = maxf(0.0, _rescue_progress - delta * 0.5)
		return
	if bool(_holding.get(_revive_carrier, false)) and carrier.global_position.distance_to(cage.global_position) <= CAGE_RANGE:
		_rescue_progress += delta / RESCUE_TIME
		if cage != null:
			cage.set_rescue_progress(_rescue_progress)
		if _rescue_progress >= 1.0:
			_revive_player(_cage_peer)
	else:
		_rescue_progress = maxf(0.0, _rescue_progress - delta * 0.5)
		if cage != null:
			cage.set_rescue_progress(_rescue_progress)


func _tick_exit(delta: float) -> void:
	if not _exit_open or exit_door == null:
		return
	var expected: int = 2 if NetworkManager.is_networked() else 1
	var inside: int = 0
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		if p.is_downed:
			continue
		if p.global_position.distance_to(exit_door.global_position) <= EXIT_RADIUS:
			inside += 1
	if inside >= expected:
		_exit_progress += delta / EXIT_HOLD
	else:
		_exit_progress = maxf(0.0, _exit_progress - delta)
	exit_door.set_progress(_exit_progress)
	if _exit_progress >= 1.0:
		_finish_level(true)


func _tick_revive_timers(delta: float) -> void:
	if _solo_revive_timer > 0.0:
		_solo_revive_timer -= delta
		if _solo_revive_timer <= 0.0 and _cage_peer != -1:
			_show_message("Kamu berhasil keluar dari kurungan (mode solo).")
			_revive_player(_cage_peer)
	if _wipe_timer > 0.0:
		_wipe_timer -= delta
		if _wipe_timer <= 0.0:
			_finish_level(false)


# --------------------------------------------------------- pintu & cage ---
func _open_door(door_id: String) -> void:
	if not _doors.has(door_id) or _doors[door_id].is_open:
		return
	_apply_door_open(door_id)
	if NetworkManager.is_networked():
		rpc("_door_opened_rpc", door_id)
	_show_message("Pintu %s terbuka!" % door_id)


func _apply_door_open(door_id: String) -> void:
	var d: Node = _doors[door_id]
	d.open_door()
	if _pathfinder != null:
		for cell: Vector2i in d.door_cells:
			_pathfinder.set_door_blocked(cell, false)


@rpc("authority", "call_remote", "reliable")
func _door_opened_rpc(door_id: String) -> void:
	if _doors.has(door_id):
		_apply_door_open(door_id)


func on_player_caught(peer_id: int) -> void:
	if not NetworkManager.is_server_authority() or _level_ended:
		return
	if _debug(debug_kebal):
		return
	var p: Node = _players.get(peer_id)
	if p == null or p.is_downed:
		return
	_senter[peer_id] = false
	_hentikan_cas(peer_id)
	_deaths_total += 1
	p.apply_local_state(true, false, false)
	p.grant_iframes(0.0)
	p.broadcast_state()
	_cage_peer = peer_id
	_rescue_progress = 0.0
	if cage != null:
		cage.show_at(p.global_position)
	var revive_pos: Vector2 = Vector2.ZERO
	if not _revive_visible and _revive_carrier == -1 and revive_item != null:
		var pts: Array[Vector2] = _revive_points()
		revive_pos = pts[randi() % pts.size()]
		_revive_visible = true
		revive_item.show_at(revive_pos)
	if NetworkManager.is_networked():
		rpc("_player_downed_rpc", peer_id, p.global_position, revive_pos, _revive_visible)
	_kabar_lokal("bahaya", "P%d tertangkap!" % p.player_index, "Cari Item Bangkit lalu bebaskan")
	if _all_players_downed():
		if NetworkManager.mode == NetworkManager.Mode.SOLO:
			_solo_revive_timer = SOLO_REVIVE_DELAY
		else:
			_wipe_timer = 1.5


@rpc("authority", "call_remote", "reliable")
func _player_downed_rpc(peer_id: int, cage_pos: Vector2, revive_pos: Vector2, revive_visible: bool) -> void:
	_cage_peer = peer_id
	_rescue_progress = 0.0
	if cage != null:
		cage.show_at(cage_pos)
	_revive_visible = revive_visible
	if revive_visible and revive_item != null:
		revive_item.show_at(revive_pos)
	var p: Node = _players.get(peer_id)
	if p != null:
		_kabar_lokal("bahaya", "P%d tertangkap!" % p.player_index, "Cari Item Bangkit lalu bebaskan")


func _revive_player(peer_id: int) -> void:
	var p: Node = _players.get(peer_id)
	if p == null:
		return
	var pos: Vector2 = cage.global_position if cage != null else p.global_position
	p.global_position = pos + Vector2(20, 0)
	p.velocity = Vector2.ZERO
	p.apply_local_state(false, false, false)
	p.grant_iframes(2.0)
	p.broadcast_state()
	if _revive_carrier != -1:
		var carrier: Node = _players.get(_revive_carrier)
		if carrier != null and carrier != p:
			carrier.apply_local_state(carrier.is_downed, carrier.is_hidden, false)
			carrier.broadcast_state()
	_revive_carrier = -1
	_revive_visible = false
	_cage_peer = -1
	_rescue_progress = 0.0
	_solo_revive_timer = -1.0
	if cage != null:
		cage.hide_cage()
	if revive_item != null:
		revive_item.hide_item()
	if NetworkManager.is_networked():
		rpc("_player_revived_rpc", peer_id, p.global_position)
	_kabar_lokal("info", "P%d bebas dari kurungan" % p.player_index)


@rpc("authority", "call_remote", "reliable")
func _player_revived_rpc(peer_id: int, pos: Vector2) -> void:
	var p: Node = _players.get(peer_id)
	if p != null:
		p.global_position = pos
		p.velocity = Vector2.ZERO
		_kabar_lokal("info", "P%d bebas dari kurungan" % p.player_index)
	_revive_carrier = -1
	_revive_visible = false
	_cage_peer = -1
	_rescue_progress = 0.0
	if cage != null:
		cage.hide_cage()
	if revive_item != null:
		revive_item.hide_item()


func _all_players_downed() -> bool:
	if _players.is_empty():
		return false
	for pid: int in _players.keys():
		if not _players[pid].is_downed:
			return false
	return true


# -------------------------------------------------------------- blackout ---
func trigger_blackout_pulse() -> void:
	_apply_blackout_local()
	if NetworkManager.is_networked():
		rpc("_blackout_rpc")


@rpc("authority", "call_remote", "reliable")
func _blackout_rpc() -> void:
	_apply_blackout_local()


func _apply_blackout_local() -> void:
	_blackout_timer = 1.6
	if hud != null:
		hud.flash_blackout()
	var local_p: Node = _players.get(NetworkManager.local_peer_id())
	if local_p != null:
		local_p.add_trauma(0.55)
	_show_message("Lampu darurat padam sesaat... langkah Satpam tidak terdengar lagi.")


# ---------------------------------------------------------------- ending ---
func _finish_level(success: bool) -> void:
	if _level_ended:
		return
	_level_ended = true
	var stars: int = 0
	var ending: String = "GAGAL"
	if success:
		ending = "Happy Ending" if _deaths_total == 0 else "Bad Ending"
		# Bintang Level 2: laporan yang beres TEPAT WAKTU + jumlah tertangkap.
		var tepat: int = _laporan_tepat_waktu()
		if tepat >= 6 and _deaths_total == 0:
			stars = 3
		elif tepat >= 4 and _deaths_total <= 1:
			stars = 2
		else:
			stars = 1
	_apply_finished(success, stars, ending)
	if NetworkManager.is_networked():
		rpc("_level_finished_rpc", success, stars, ending, _level_time, _deaths_total)


@rpc("authority", "call_remote", "reliable")
func _level_finished_rpc(success: bool, stars: int, ending: String, time_sec: float, deaths: int) -> void:
	_level_time = time_sec
	_deaths_total = deaths
	_level_ended = true
	_apply_finished(success, stars, ending)


func _apply_finished(success: bool, stars: int, ending: String) -> void:
	if minigame_layer != null:
		minigame_layer.force_close()
	GameProgress.record_level_result(LEVEL_ID, stars, _level_time, ending, success)
	if hud != null:
		hud.show_result(success, stars, ending, _level_time, _deaths_total, _completed_count(), _tasks.size())


func request_restart() -> void:
	if NetworkManager.is_server_authority():
		if NetworkManager.is_networked():
			rpc("_restart_rpc")
		_do_restart()
	else:
		rpc_id(1, "request_restart_rpc")


@rpc("any_peer", "call_remote", "reliable")
func request_restart_rpc() -> void:
	if NetworkManager.is_server_authority():
		request_restart()


@rpc("authority", "call_remote", "reliable")
func _restart_rpc() -> void:
	_do_restart()


func _do_restart() -> void:
	get_tree().reload_current_scene()


func request_menu() -> void:
	_go_to_menu()


func _go_to_menu() -> void:
	NetworkManager.disconnect_all()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- visuals ---
func _process(delta: float) -> void:
	_flicker_time += delta
	if _blackout_timer > 0.0:
		_blackout_timer -= delta
	# Lampu lobi mati sepanjang malam; jam 05.00 menyala bertahap (6 detik).
	_lampu_faktor = move_toward(_lampu_faktor, 1.0 if _subuh else 0.0, delta / 6.0)
	if canvas_modulate != null:
		var target: Color = BASE_MODULATE.lerp(SUBUH_MODULATE, _lampu_faktor)
		if _terang:
			target = Color(0.8, 0.8, 0.85)
		if _blackout_timer > 0.0:
			target = BLACKOUT_MODULATE
		canvas_modulate.color = canvas_modulate.color.lerp(target, minf(1.0, delta * 6.0))
	var blackout_mult: float = 0.15 if _blackout_timer > 0.0 else 1.0
	for i: int in range(_lights.size()):
		var flicker: float = 0.88 + 0.12 * sin(_flicker_time * 7.0 + _light_phase[i])
		if randf() < 0.003:
			flicker *= 0.35
		_lights[i].energy = _light_base[i] * flicker * blackout_mult * _lampu_faktor
	# Visual tempat sembunyi = turunan dari posisi pemain yang sembunyi.
	for s: Node2D in _spots:
		var occ: bool = false
		for pid: int in _players.keys():
			var p: Node = _players[pid]
			if p.is_hidden and p.global_position.distance_to(s.global_position) <= HIDE_RANGE:
				occ = true
				break
		s.set_occupied(occ)
	_perbarui_visual_malam(delta)
	_update_hud_frame()


func _completed_count() -> int:
	var n: int = 0
	for tid: StringName in _tasks.keys():
		if bool(_tasks[tid]["completed"]):
			n += 1
	return n


func _update_hud_static() -> void:
	if hud == null:
		return
	hud.set_task_total(_tasks.size())


func _update_hud_frame() -> void:
	if hud == null:
		return
	hud.set_timer_text(_teks_jam_hud())
	hud.set_tasks_text(_teks_laporan_hud())
	var status_lines: Array[String] = []
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var st: String = "TERKURUNG" if p.is_downed else ("SEMBUNYI" if p.is_hidden else "AKTIF")
		status_lines.append("P%d: %s  HP %d%%%s" % [p.player_index, st, int(ceil(get_baterai(pid))), " [+ITEM]" if p.carrying_revive else ""])
	hud.update_status(status_lines)
	if hud_malam != null:
		hud_malam.set_prompt(_compute_prompt())
		if _debug(debug_kotak_info) and _info_debug_tampil:
			hud_malam.set_debug(_teks_debug(), true)
		else:
			hud_malam.set_debug("", debug_aktif)
	else:
		hud.show_prompt(_compute_prompt())


func _compute_prompt() -> String:
	var local_p: Node = _players.get(NetworkManager.local_peer_id())
	if local_p == null or local_p.is_downed or _level_ended:
		return ""
	if local_p.minigame_open:
		return ""
	if local_p.is_hidden:
		return "[E] Keluar dari persembunyian"
	if _cage_peer != -1 and _revive_carrier == NetworkManager.local_peer_id() and cage != null and local_p.global_position.distance_to(cage.global_position) <= CAGE_RANGE:
		return "[Tahan E] Selamatkan teman dari kurungan"
	if _revive_visible and revive_item != null and local_p.global_position.distance_to(revive_item.global_position) <= REVIVE_RANGE:
		return "[E] Ambil Item Bangkit"
	var pid_lokal: int = NetworkManager.local_peer_id()
	if str(_cas_dipakai.get(pid_lokal, "")) != "":
		return "[E] Cabut HP · ngecas %d%%" % int(get_baterai(pid_lokal))
	if komputer != null and local_p.global_position.distance_to(komputer.global_position) <= KOMPUTER_RANGE:
		if not _komputer_pernah:
			return "[E] Nyalakan komputer security"
		return "[E] Duduk di komputer"
	if _kabel_rusak != "" and _kabel_nodes.has(_kabel_rusak) and local_p.global_position.distance_to((_kabel_nodes[_kabel_rusak] as Node2D).global_position) <= KABEL_RANGE:
		return "[E] Sambung kabel yang putus"
	var cas_dekat: String = _cas_terdekat(local_p.global_position)
	if cas_dekat != "":
		var alasan: String = _alasan_cas_tidak_bisa(cas_dekat, pid_lokal)
		if alasan != "":
			return alasan
		return "[E] Colok HP · diam 10 detik"
	var tid: StringName = _nearest_task(local_p.global_position)
	if tid != StringName(""):
		var t: Dictionary = _tasks[tid]
		if t["requires_two"] and _server_needed() > 1:
			return "[E] %s — BUTUH 2 PEMAIN!" % t["node"].title
		return "[E] Kerjakan: %s" % t["node"].title
	if _nearest_spot(local_p.global_position) != null:
		return "[E] Sembunyi"
	if _exit_open and exit_door != null and local_p.global_position.distance_to(exit_door.global_position) <= EXIT_RADIUS + 40.0:
		return "Berdiri berdua di pintu keluar untuk kabur!"
	if not _exit_open and exit_door != null and local_p.global_position.distance_to(exit_door.global_position) <= EXIT_RADIUS:
		return "Pintu kaca terkunci — baru bisa dibuka jam 05.00"
	return ""


func get_map_size_tiles() -> Vector2i:
	# Dibaca player.gd untuk batas kamera (map Level 2 lebih besar dari Level 1).
	return MAP_SIZE_TILES


func _show_message(text: String) -> void:
	# Pesan pribadi (dari kode dasar Level 1 & notice host): muncul di HP.
	if hud_malam != null:
		hud_malam.kabar("pribadi", text)
	elif hud != null:
		hud.show_message(text)


# =====================================================================
# SISTEM MALAM LEVEL 2: baterai, senter, titik cas, komputer, jam, laporan
# =====================================================================

# ------------------------------------------------------------ setup ---
func _setup_malam() -> void:
	if canvas_modulate != null:
		canvas_modulate.color = BASE_MODULATE
	for n: Node in _semua_anak(cas_container):
		if n.has_method("set_status") and "aktif_saat_subuh" in n:
			_cas_nodes[String(n.name)] = n
			_cas_korslet[String(n.name)] = 0.0
	for n: Node in _semua_anak(kabel_container):
		if n.has_method("set_rusak"):
			_kabel_nodes[String(n.name)] = n
	# Alat laporan disembunyikan sampai jamnya tiba. Alat yang sedang rusak
	# diberi cahaya kedip kecil supaya terlihat kalau pemain sudah dekat.
	for tid: StringName in _tasks.keys():
		var node: Node2D = _tasks[tid]["node"]
		node.visible = false
		# Kotak & label bawaan task_station disembunyikan, diganti penanda
		# bentuk sederhana (titik + gelombang bunyi) khusus Level 2.
		for c: Node in node.get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = false
		var pen: Node2D = PENANDA_LAPORAN.new()
		pen.name = "PenandaLaporan"
		pen.set("warna", node.accent if "accent" in node else Color(1, 0.8, 0.3))
		node.add_child(pen)
		_penanda[tid] = pen
		var glow := PointLight2D.new()
		glow.name = "GlowLaporan"
		glow.texture = TEX_PANDANG
		glow.texture_scale = 0.3
		glow.color = node.accent if "accent" in node else Color(1, 0.85, 0.4)
		glow.energy = 0.0
		node.add_child(glow)
		_glow_laporan[tid] = glow
	hud_malam = HUD_MALAM.new()
	hud_malam.name = "HudMalam"
	hud_malam.level = self
	add_child(hud_malam)
	layar_komputer = LAYAR_KOMPUTER.new()
	layar_komputer.name = "LayarKomputer"
	layar_komputer.level = self
	layar_komputer.font_mono = F_MONO
	layar_komputer.font_mono_tebal = F_MONO_TEBAL
	add_child(layar_komputer)
	if hud != null and hud.has_method("mode_minimal"):
		hud.mode_minimal()
	_kabar_lokal("info", "WASD gerak · Shift lari · E interaksi · R senter")


func _pasang_lampu_pemain(p: Node) -> void:
	# Light bawaan player.tscn dijadikan "lingkaran pandang", ditambah
	# PointLight2D Senter berbentuk kerucut (mati sampai tombol R).
	var lampu_hp: PointLight2D = p.get_node_or_null("Light") as PointLight2D
	if lampu_hp != null:
		lampu_hp.texture = TEX_PANDANG
		lampu_hp.texture_scale = SKALA_LINGKARAN
		lampu_hp.color = Color(0.8, 0.85, 1.0)
	if p.get_node_or_null("Senter") == null:
		var senter := PointLight2D.new()
		senter.name = "Senter"
		senter.texture = TEX_SENTER
		senter.texture_scale = SENTER_PANJANG * 32.0 / 256.0
		senter.color = Color(1, 0.95, 0.8)
		senter.energy = 1.4
		senter.enabled = false
		p.add_child(senter)
	if p.is_multiplayer_authority():
		var cam: Camera2D = p.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)


func _set_musuh_aktif(aktif: bool) -> void:
	# Sementara (tahap ini) yang aktif adalah Satpam dengan AI musuh Level 1.
	_musuh_aktif = aktif
	if enemy == null:
		return
	enemy.visible = aktif
	enemy.process_mode = Node.PROCESS_MODE_INHERIT if aktif else Node.PROCESS_MODE_DISABLED
	var col: CollisionShape2D = enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", not aktif)


# ------------------------------------------------------ tick (host) ---
func _tick_malam(delta: float) -> void:
	_tick_baterai(delta)
	for nama: String in _cas_korslet.keys():
		if float(_cas_korslet[nama]) > 0.0:
			_cas_korslet[nama] = maxf(0.0, float(_cas_korslet[nama]) - delta * _kecepatan_jam())
	# Jam hanya berjalan saat komputer security menyala.
	if _komputer_nyala and not _subuh:
		_jam_menit = minf(MENIT_SUBUH, _jam_menit + delta * 60.0 / DETIK_PER_JAM_GAME * _kecepatan_jam())
		_tick_laporan()
		if _error_ke < MENIT_ERROR.size() and _jam_menit >= MENIT_ERROR[_error_ke]:
			if _debug(debug_tanpa_error_kabel):
				_error_ke += 1
			else:
				_mulai_error()
		elif _jam_menit >= MENIT_SUBUH:
			_mulai_subuh()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = 0.2
		_kirim_state_malam()


func _tick_baterai(delta: float) -> void:
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var b: float = float(_baterai.get(pid, 0.0))
		var cas: String = str(_cas_dipakai.get(pid, ""))
		if cas != "":
			var bergerak: bool = p.velocity.length() > 12.0
			if bergerak or p.is_downed or p.is_hidden or _alasan_cas_tidak_bisa(cas, pid) != "":
				_hentikan_cas(pid)
				if bergerak:
					_notice_to(pid, "Kamu bergerak — HP tercabut dari colokan.")
				continue
			b = minf(100.0, b + CAS_PER_DETIK * delta)
			_baterai[pid] = b
			if b >= 100.0:
				_hentikan_cas(pid)
			continue
		if p.is_downed or p.is_hidden:
			_senter[pid] = false
		if p.is_downed:
			continue
		var turun: float = BATERAI_TURUN_LAYAR if b > 0.0 else 0.0
		if bool(_senter.get(pid, false)):
			turun += BATERAI_TURUN_SENTER
		if _debug(debug_baterai_tak_habis):
			turun = 0.0
		b = maxf(0.0, b - turun * delta)
		if b <= 0.0 and bool(_senter.get(pid, false)):
			_senter[pid] = false
			_notice_to(pid, "Baterai habis! Senter mati, pandangan menyempit.")
		_baterai[pid] = b


func _tick_laporan() -> void:
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if bool(t["completed"]):
			continue
		if not bool(t["aktif"]):
			if _jam_menit >= float(t["muncul"]):
				t["aktif"] = true
				_kabar("laporan", str(t["node"].title), "%s · batas %s" % [str(t["area"]), _format_jam(float(t["batas"]))])
		elif not bool(t["terlambat"]) and _jam_menit >= float(t["batas"]):
			t["terlambat"] = true
			_hukuman_laporan(tid)


func _hukuman_laporan(tid: StringName) -> void:
	var t: Dictionary = _tasks[tid]
	var judul: String = t["node"].title
	if bool(t["wajib"]):
		_kabar("bahaya", "%s lewat batas" % judul, "tetap wajib beres sebelum 05.00")
		return
	if tid == &"genset":
		_genset_mati = true
		_kabar("bahaya", "Genset mati", "semua titik cas padam")
		return
	# Hukuman lain (Satpam/Bos mendatangi area) dibuat bersama AI musuh baru.
	_kabar("bahaya", "Terlambat: " + judul, "ada yang mendekat ke " + str(t["area"]))


# ------------------------------------------------------ baterai & cas ---
func _cas_terdekat(pos: Vector2) -> String:
	var terbaik: String = ""
	var jarak_min: float = CAS_RANGE
	for nama: String in _cas_nodes.keys():
		var d: float = pos.distance_to((_cas_nodes[nama] as Node2D).global_position)
		if d <= jarak_min:
			jarak_min = d
			terbaik = nama
	return terbaik


func _alasan_cas_tidak_bisa(nama: String, peer_id: int) -> String:
	# "" = colokan bisa dipakai pemain ini.
	if not _cas_nodes.has(nama):
		return "Titik cas tidak ditemukan."
	if _genset_mati:
		return "Listrik mati (genset). Titik cas padam sampai genset diperbaiki."
	if fase_sekarang() == 4 and not bool(_cas_nodes[nama].aktif_saat_subuh):
		return "Colokan ini mati menjelang subuh. Cari titik cas lain."
	var sisa: float = float(_cas_korslet.get(nama, 0.0))
	if sisa > 0.0:
		return "Colokan korslet — bisa dipakai lagi %d detik lagi." % int(ceil(sisa))
	for lain: int in _cas_dipakai.keys():
		if lain != peer_id and str(_cas_dipakai[lain]) == nama:
			return "Colokan ini sedang dipakai temanmu."
	return ""


func _mulai_cas(peer_id: int, nama: String) -> void:
	var p: Node = _players.get(peer_id)
	if p == null:
		return
	var alasan: String = _alasan_cas_tidak_bisa(nama, peer_id)
	if alasan != "":
		_notice_to(peer_id, alasan)
		return
	if get_baterai(peer_id) >= 99.5:
		_notice_to(peer_id, "Baterai HP masih penuh.")
		return
	if p.velocity.length() > 12.0:
		_notice_to(peer_id, "Berhenti dulu, baru colok HP.")
		return
	_cas_dipakai[peer_id] = nama
	_cas_mulai[peer_id] = get_baterai(peer_id)
	_senter[peer_id] = false
	_notice_to(peer_id, "Ngecas di %s... diam 10 detik. [E] untuk cabut." % _nama_area_cas(nama))
	if not _musuh_aktif and not _subuh and not _debug(debug_tanpa_satpam):
		_set_musuh_aktif(true)
		_kabar("info", "Terdengar langkah kaki & bunyi HT", "satpam mulai berpatroli")


func _hentikan_cas(peer_id: int) -> void:
	var nama: String = str(_cas_dipakai.get(peer_id, ""))
	if nama == "":
		return
	_cas_dipakai[peer_id] = ""
	var dapat: float = get_baterai(peer_id) - float(_cas_mulai.get(peer_id, 0.0))
	if dapat >= CAS_MIN_KORSLET:
		_cas_korslet[nama] = KORSLET_DETIK
		_notice_to(peer_id, "HP terisi %d%%. Colokan %s korslet (1 jam game)." % [int(get_baterai(peer_id)), _nama_area_cas(nama)])
	else:
		_notice_to(peer_id, "HP dicabut (baterai %d%%)." % int(get_baterai(peer_id)))


func _status_cas(nama: String) -> int:
	# 0 siap, 1 dipakai, 2 korslet, 3 mati (sama dengan enum di titik_cas.gd)
	if not _cas_nodes.has(nama):
		return 3
	if _genset_mati:
		return 3
	if fase_sekarang() == 4 and not bool(_cas_nodes[nama].aktif_saat_subuh):
		return 3
	for pid: int in _cas_dipakai.keys():
		if str(_cas_dipakai[pid]) == nama:
			return 1
	if float(_cas_korslet.get(nama, 0.0)) > 0.0:
		return 2
	return 0


# ---------------------------------------------------------------- senter ---
func _unhandled_input(event: InputEvent) -> void:
	if _debug(debug_tombol_cepat) and event is InputEventKey and event.pressed and not event.echo:
		if _tombol_debug(event.physical_keycode):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		var p: Node = get_local_player()
		if p == null or p.minigame_open or not is_level_running():
			return
		notify_senter_pressed(NetworkManager.local_peer_id())
		get_viewport().set_input_as_handled()


func notify_senter_pressed(peer_id: int) -> void:
	if NetworkManager.is_server_authority():
		_toggle_senter(peer_id)
	elif NetworkManager.is_networked():
		rpc_id(1, "request_senter_rpc", peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_senter_rpc(peer_id: int) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_toggle_senter(peer_id)


func _toggle_senter(peer_id: int) -> void:
	var p: Node = _players.get(peer_id)
	if p == null or p.is_downed or p.is_hidden:
		return
	if bool(_senter.get(peer_id, false)):
		_senter[peer_id] = false
		return
	if str(_cas_dipakai.get(peer_id, "")) != "":
		_notice_to(peer_id, "Lagi ngecas, senter tidak bisa dinyalakan.")
		return
	if get_baterai(peer_id) <= 0.0:
		_notice_to(peer_id, "Baterai 0% — senter tidak bisa menyala. Cari titik cas!")
		return
	_senter[peer_id] = true
	# Tahap berikutnya: senter yang menyala memanggil Mantan Bos.


func _sudut_hadap(arah: String) -> float:
	match arah:
		"right":
			return 0.0
		"left":
			return PI
		"up":
			return -PI * 0.5
	return PI * 0.5  # down


# ------------------------------------------------------ komputer & error ---
func _pakai_komputer(peer_id: int) -> void:
	if not _komputer_pernah:
		_komputer_pernah = true
		_komputer_nyala = true
		_kabar("info", "Komputer security menyala", "bertahan sampai 05.00")
		_kirim_state_malam()
	_buka_layar_untuk(peer_id)


func _buka_layar_untuk(peer_id: int) -> void:
	if peer_id == NetworkManager.local_peer_id():
		buka_layar_komputer()
	elif NetworkManager.is_networked():
		rpc_id(peer_id, "_buka_layar_rpc")


@rpc("authority", "call_remote", "reliable")
func _buka_layar_rpc() -> void:
	buka_layar_komputer()


func buka_layar_komputer() -> void:
	if layar_komputer != null:
		layar_komputer.buka()


func tutup_layar_komputer() -> void:
	if layar_komputer != null:
		layar_komputer.tutup()


func _mulai_error() -> void:
	_error_ke += 1
	var nama_list: Array = _kabel_nodes.keys()
	if nama_list.is_empty():
		return  # tidak ada titik kabel di scene: error dilewati
	_komputer_nyala = false
	_kabel_rusak = str(nama_list[randi() % nama_list.size()])
	_kabar("bahaya", "Koneksi terputus", "kabel " + _nama_area_kabel(_kabel_rusak))
	_kirim_state_malam()


func _perbaiki_kabel() -> void:
	if _kabel_rusak == "":
		return
	var area: String = _nama_area_kabel(_kabel_rusak)
	_kabel_rusak = ""
	_komputer_nyala = true
	_kabar("info", "Kabel %s tersambung" % area, "komputer & jam jalan lagi")
	_kirim_state_malam()


func _buka_minigame_untuk(peer_id: int, tid: StringName) -> void:
	if peer_id == NetworkManager.local_peer_id():
		open_minigame_for_local(tid)
	elif NetworkManager.is_networked():
		rpc_id(peer_id, "_open_minigame_rpc", String(tid))


func _nama_kabel_dari_tid(tid: StringName) -> String:
	var s: String = String(tid)
	if s.begins_with("kabel_"):
		return s.substr(6)
	return ""


# --------------------------------------------------------- subuh & pintu ---
func _mulai_subuh() -> void:
	if _subuh:
		return
	_subuh = true
	_jam_menit = MENIT_SUBUH
	_set_musuh_aktif(false)
	_kabar("info", "Subuh — lampu lobi menyala", "lari ke pintu kaca")
	_cek_pintu_kaca()
	_kirim_state_malam()


func _cek_pintu_kaca() -> void:
	if not _subuh or _exit_open:
		return
	var kurang := PackedStringArray()
	for tid: StringName in [&"kunci_cadangan", &"pintu_kaca"]:
		if _tasks.has(tid) and not bool(_tasks[tid]["completed"]):
			kurang.append(str(_tasks[tid]["node"].title))
	if not kurang.is_empty():
		_kabar("bahaya", "Pintu kaca masih terkunci", "selesaikan: " + ", ".join(kurang))
		return
	_exit_open = true
	if exit_door != null:
		exit_door.set_locked(false)
	if NetworkManager.is_networked():
		rpc("_exit_opened_rpc")
	_kabar("info", "Pintu kaca terbuka", "lari berdua ke vestibul")


func _laporan_tepat_waktu() -> int:
	var n: int = 0
	for tid: StringName in _tasks.keys():
		if bool(_tasks[tid]["completed"]) and not bool(_tasks[tid]["terlambat"]):
			n += 1
	return n


# ------------------------------------------------------ sinkron (host) ---
func _kirim_state_malam() -> void:
	if not NetworkManager.is_networked() or not NetworkManager.is_server_authority():
		return
	var lap: Dictionary = {}
	for tid: StringName in _tasks.keys():
		lap[String(tid)] = [bool(_tasks[tid]["aktif"]), bool(_tasks[tid]["terlambat"])]
	rpc("_state_malam_rpc", {
		"b": _baterai, "s": _senter, "c": _cas_dipakai, "k": _cas_korslet,
		"j": _jam_menit, "on": _komputer_nyala, "pernah": _komputer_pernah,
		"kr": _kabel_rusak, "m": _musuh_aktif, "sb": _subuh, "gm": _genset_mati, "lap": lap,
	})


@rpc("authority", "call_remote", "unreliable_ordered")
func _state_malam_rpc(data: Dictionary) -> void:
	_baterai = data["b"]
	_senter = data["s"]
	_cas_dipakai = data["c"]
	_cas_korslet = data["k"]
	_jam_menit = float(data["j"])
	_komputer_nyala = bool(data["on"])
	_komputer_pernah = bool(data["pernah"])
	_kabel_rusak = str(data["kr"])
	_subuh = bool(data["sb"])
	_genset_mati = bool(data["gm"])
	if bool(data["m"]) != _musuh_aktif:
		_set_musuh_aktif(bool(data["m"]))
	var lap: Dictionary = data["lap"]
	for k: String in lap.keys():
		var key := StringName(k)
		if _tasks.has(key):
			_tasks[key]["aktif"] = bool(lap[k][0])
			_tasks[key]["terlambat"] = bool(lap[k][1])


func _umumkan(text: String) -> void:
	_kabar("info", text)


func _kabar(jenis: String, judul: String, isi: String = "") -> void:
	# Kabar untuk SEMUA pemain (host menampilkan + mengirim ke client).
	# jenis: "laporan" / "beres" / "bahaya" -> notifikasi HP (bahaya juga baris
	# log merah), "info" -> baris log di atas layar.
	_kabar_lokal(jenis, judul, isi)
	if NetworkManager.is_networked() and NetworkManager.is_server_authority():
		rpc("_kabar_rpc", jenis, judul, isi)


@rpc("authority", "call_remote", "reliable")
func _kabar_rpc(jenis: String, judul: String, isi: String) -> void:
	_kabar_lokal(jenis, judul, isi)


func _kabar_lokal(jenis: String, judul: String, isi: String = "") -> void:
	if hud_malam != null:
		hud_malam.kabar(jenis, judul, isi)
	elif hud != null:
		hud.show_message(judul + ("  —  " + isi if isi != "" else ""))


# ------------------------------------------------- visual (semua PC) ---
func _perbarui_visual_malam(_delta: float) -> void:
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var lampu_hp: PointLight2D = p.get_node_or_null("Light") as PointLight2D
		if lampu_hp != null:
			# Lingkaran pandang tetap 1,5 tile; baterai tidak mengubahnya.
			lampu_hp.texture_scale = SKALA_LINGKARAN
		var senter: PointLight2D = p.get_node_or_null("Senter") as PointLight2D
		if senter != null:
			var nyala: bool = is_senter_nyala(pid) and not p.is_downed and not p.is_hidden
			senter.enabled = nyala
			if nyala:
				senter.rotation = _sudut_hadap(str(p.get("_facing")))
				senter.energy = 1.3 + 0.1 * sin(_flicker_time * 23.0)
	for nama: String in _cas_nodes.keys():
		_cas_nodes[nama].set_status(_status_cas(nama))
	if komputer != null and komputer.has_method("set_status"):
		komputer.set_status(2 if _kabel_rusak != "" else (1 if _komputer_nyala or _subuh else 0))
	for nama: String in _kabel_nodes.keys():
		_kabel_nodes[nama].set_rusak(nama == _kabel_rusak)
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		var node: Node2D = t["node"]
		node.visible = bool(t["aktif"]) or bool(t["completed"])
		var pen: Node = _penanda.get(tid)
		if pen != null:
			pen.set_keadaan(float(t["progress"]), bool(t["completed"]), bool(t["terlambat"]))
		var glow: PointLight2D = _glow_laporan.get(tid)
		if glow != null:
			glow.energy = 0.0 if bool(t["completed"]) else 0.7 + 0.3 * sin(_flicker_time * 5.0 + float(t["muncul"]))


# ------------------------------------- getter (HUD & layar komputer) ---
func get_baterai(peer_id: int) -> float:
	return float(_baterai.get(peer_id, 0.0))


func is_senter_nyala(peer_id: int) -> bool:
	return bool(_senter.get(peer_id, false))


func get_area_cas(peer_id: int) -> String:
	var nama: String = str(_cas_dipakai.get(peer_id, ""))
	return _nama_area_cas(nama) if nama != "" else ""


func get_jam_menit() -> float:
	return _jam_menit


func is_jam_berjalan() -> bool:
	return _komputer_nyala and not _subuh and _kabel_rusak == ""


func is_komputer_pernah() -> bool:
	return _komputer_pernah


func get_teks_sub_hp() -> String:
	# Baris kecil di bawah jam pada layar HP.
	if _subuh:
		return "Subuh · lampu lobi menyala"
	if _kabel_rusak != "":
		return "jam berhenti — komputer error"
	if not _komputer_pernah:
		return "nyalakan komputer security"
	return "Kamis malam · %s" % get_nama_fase()


func get_info_laporan_semua() -> Array:
	# Semua 7 laporan urut jam, untuk sticky note di HUD.
	var daftar: Array = []
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		var st: String = "belum"
		if bool(t["completed"]):
			st = "beres"
		elif bool(t["terlambat"]):
			st = "telat"
		elif bool(t["aktif"]):
			st = "aktif"
		daftar.append({
			"muncul": float(t["muncul"]),
			"jam": _format_jam(float(t["muncul"])),
			"nama": str(NAMA_PENDEK.get(tid, String(tid))),
			"status": st,
			"wajib": bool(t["wajib"]),
		})
	daftar.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["muncul"]) < float(b["muncul"]))
	return daftar


func get_info_pemain() -> Array:
	# Untuk ID card di HUD: urut P1, P2.
	var daftar: Array = []
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var st: String = "aktif"
		if p.is_downed:
			st = "kurung"
		elif p.is_hidden:
			st = "sembunyi"
		daftar.append({"nomor": int(p.player_index), "nama": "P%d" % p.player_index, "status": st, "baterai": get_baterai(pid)})
	daftar.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["nomor"]) < int(b["nomor"]))
	return daftar


func fase_sekarang() -> int:
	if _jam_menit < 120.0:
		return 1  # 21.00–23.00 Sunyi
	if _jam_menit < 300.0:
		return 2  # 23.00–02.00 Gelisah
	if _jam_menit < 420.0:
		return 3  # 02.00–04.00 Jam Mati
	return 4  # 04.00–05.00 Subuh


func get_nama_fase() -> String:
	return NAMA_FASE[fase_sekarang()]


func get_teks_jam() -> String:
	return _format_jam(_jam_menit) if _komputer_pernah else "--.--"


func get_teks_error() -> String:
	if _kabel_rusak == "":
		return ""
	return "KOMPUTER ERROR — kabel putus di %s. Jam berhenti!" % _nama_area_kabel(_kabel_rusak)


func get_posisi_komputer() -> Vector2:
	return komputer.global_position if komputer != null else Vector2.ZERO


func get_info_titik_cas() -> Array:
	var out: Array = []
	for nama: String in _cas_nodes.keys():
		out.append({
			"pos": (_cas_nodes[nama] as Node2D).global_position,
			"status": _status_cas(nama),
			"sisa": float(_cas_korslet.get(nama, 0.0)),
			"area": _nama_area_cas(nama),
		})
	return out


func get_info_titik_kabel() -> Array:
	var out: Array = []
	for nama: String in _kabel_nodes.keys():
		out.append({
			"pos": (_kabel_nodes[nama] as Node2D).global_position,
			"rusak": nama == _kabel_rusak,
			"area": _nama_area_kabel(nama),
		})
	return out


func get_info_laporan() -> Array:
	var out: Array = []
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if not bool(t["aktif"]) and not bool(t["completed"]):
			continue
		var ket: String = "batas %s" % _format_jam(float(t["batas"]))
		if bool(t["completed"]):
			ket = "selesai"
		elif bool(t["terlambat"]):
			ket = "TERLAMBAT" + (" (wajib)" if bool(t["wajib"]) else "")
		out.append({
			"pos": (t["node"] as Node2D).global_position,
			"judul": str(t["node"].title),
			"area": str(t["area"]),
			"jam": _format_jam(float(t["muncul"])),
			"selesai": bool(t["completed"]),
			"terlambat": bool(t["terlambat"]),
			"keterangan": ket,
		})
	return out


func get_info_teman() -> Array:
	# Teman = semua pemain selain diri sendiri. Posisinya hanya tampil di
	# denah kalau baterai HP-nya > 0% (dilacak lewat WiFi kantor).
	var out: Array = []
	var lokal: int = NetworkManager.local_peer_id()
	for pid: int in _players.keys():
		if pid == lokal:
			continue
		var p: Node2D = _players[pid]
		var b: float = get_baterai(pid)
		var status: String = "sinyal hilang (baterai 0%)"
		if p.is_downed:
			status = "TERKURUNG"
		elif b > 0.0:
			status = "baterai %d%%" % int(ceil(b))
		out.append({
			"nama": "P%d" % p.player_index,
			"pos": p.global_position,
			"terlihat": b > 0.0 and not p.is_downed,
			"status": status,
		})
	return out


func _format_jam(menit: float) -> String:
	var total: int = int(menit)
	var jam: int = (21 + int(total / 60.0)) % 24
	return "%02d.%02d" % [jam, total % 60]


func _teks_jam_hud() -> String:
	if not _komputer_pernah:
		return "Jam --.--  (nyalakan komputer)"
	var teks: String = "Jam %s  ·  Fase %s" % [_format_jam(_jam_menit), get_nama_fase()]
	if _kabel_rusak != "":
		teks += "  ·  BERHENTI"
	return teks


func _teks_laporan_hud() -> String:
	var aktif: int = 0
	for tid: StringName in _tasks.keys():
		if bool(_tasks[tid]["aktif"]) and not bool(_tasks[tid]["completed"]):
			aktif += 1
	return "Laporan beres: %d/%d  |  menunggu: %d" % [_completed_count(), _tasks.size(), aktif]


func _nama_area_cas(nama: String) -> String:
	if _cas_nodes.has(nama):
		return str(_cas_nodes[nama].nama_area)
	return nama


func _nama_area_kabel(nama: String) -> String:
	if _kabel_nodes.has(nama):
		return str(_kabel_nodes[nama].nama_area)
	return nama


# =====================================================================
# DEBUG (lihat Inspector node Level2 > "Debug (khusus tes)")
# =====================================================================
func _debug(pilihan: bool) -> bool:
	return debug_aktif and pilihan


func _kecepatan_jam() -> float:
	return debug_kecepatan_jam if debug_aktif else 1.0


func _terapkan_debug() -> void:
	_terang = _debug(debug_terang)
	_info_debug_tampil = true
	if not debug_aktif:
		return
	push_warning("Level 2: MODE DEBUG AKTIF — matikan 'Debug Aktif' di node Level2 sebelum game dikumpulkan.")
	if not NetworkManager.is_server_authority():
		return
	if debug_mulai_menit > 0:
		_jam_menit = float(debug_mulai_menit)
		# Error yang jamnya sudah lewat dianggap sudah terjadi.
		while _error_ke < MENIT_ERROR.size() and MENIT_ERROR[_error_ke] <= _jam_menit:
			_error_ke += 1
		# Laporan yang jamnya sudah lewat langsung aktif, batasnya diberi 1 jam lagi.
		for tid: StringName in _tasks.keys():
			var t: Dictionary = _tasks[tid]
			if float(t["muncul"]) <= _jam_menit:
				t["aktif"] = true
				t["batas"] = maxf(float(t["batas"]), _jam_menit + 60.0)
	if debug_komputer_nyala:
		_komputer_pernah = true
		_komputer_nyala = true
	if debug_tanpa_satpam:
		_set_musuh_aktif(false)


func _tombol_debug(tombol: int) -> bool:
	# true = tombolnya dipakai debug.
	var host: bool = NetworkManager.is_server_authority()
	match tombol:
		KEY_F1:
			_info_debug_tampil = not _info_debug_tampil
		KEY_F9:
			_terang = not _terang
			_kabar_lokal("info", "Debug: lobi " + ("terang" if _terang else "gelap"))
		KEY_F2:
			if host:
				_komputer_pernah = true
				_jam_menit = minf(MENIT_SUBUH - 0.5, _jam_menit + 30.0)
				_kabar_lokal("info", "Debug: jam maju 30 menit")
		KEY_F3:
			if host:
				_baterai[NetworkManager.local_peer_id()] = 100.0
				_kabar_lokal("info", "Debug: baterai 100%")
		KEY_F4:
			if host:
				if _kabel_rusak == "":
					_picu_error_paksa()
				else:
					_perbaiki_kabel()
		KEY_F10:
			if host:
				_error_ke = MENIT_ERROR.size()
				_kabel_rusak = ""
				_komputer_pernah = true
				_komputer_nyala = true
				_jam_menit = MENIT_SUBUH - 0.5
				_kabar_lokal("info", "Debug: lompat ke 04.59")
		_:
			return false
	if not host and tombol in [KEY_F2, KEY_F3, KEY_F4, KEY_F10]:
		_kabar_lokal("info", "Debug: tombol ini hanya bisa di PC host")
	return true


func _picu_error_paksa() -> void:
	var nama_list: Array = _kabel_nodes.keys()
	if nama_list.is_empty():
		return
	_komputer_pernah = true
	_komputer_nyala = false
	_kabel_rusak = str(nama_list[randi() % nama_list.size()])
	_kabar("bahaya", "Koneksi terputus", "kabel " + _nama_area_kabel(_kabel_rusak))
	_kirim_state_malam()


func _teks_debug() -> String:
	var b: PackedStringArray = PackedStringArray()
	var berikut: String = _format_jam(MENIT_ERROR[_error_ke]) if _error_ke < MENIT_ERROR.size() else "-"
	b.append("JAM %s  (menit %.1f, x%.1f)  FASE %s" % [_format_jam(_jam_menit), _jam_menit, _kecepatan_jam(), get_nama_fase()])
	b.append("KOMPUTER %s  KABEL PUTUS %s  ERROR BERIKUT %s" % ["nyala" if _komputer_nyala else "mati", _kabel_rusak if _kabel_rusak != "" else "-", berikut])
	b.append("SATPAM %s  SUBUH %s  GENSET %s  PINTU %s" % ["aktif" if _musuh_aktif else "tidur", "ya" if _subuh else "tidak", "MATI" if _genset_mati else "ok", "terbuka" if _exit_open else "terkunci"])
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var cas: String = str(_cas_dipakai.get(pid, ""))
		b.append("P%d  HP %d%%  senter %s  cas %s" % [p.player_index, int(get_baterai(pid)), "nyala" if is_senter_nyala(pid) else "mati", cas if cas != "" else "-"])
	var cas_teks: PackedStringArray = PackedStringArray()
	for nama: String in _cas_nodes.keys():
		var st: int = _status_cas(nama)
		var label: String = ["siap", "dipakai", "korslet %ds" % int(ceil(float(_cas_korslet.get(nama, 0.0)))), "mati"][st]
		cas_teks.append("%s:%s" % [nama.trim_prefix("Cas"), label])
	b.append("CAS  " + "  ".join(cas_teks))
	for l: Dictionary in get_info_laporan_semua():
		if str(l["status"]) != "belum":
			b.append("LAPORAN %s %s: %s" % [str(l["jam"]), str(l["nama"]), str(l["status"])])
	b.append("FPS %d" % Engine.get_frames_per_second())
	if debug_tombol_cepat:
		b.append("F1 info  F2 +30mnt  F3 baterai  F4 error  F9 terang  F10 04.59")
	return "\n".join(b)
