extends Node2D
## Level 1 — Lantai Kantor, Sayap Utama (TileMap).
##
## Pemilik state gameplay (host/solo): tugas, pintu terkunci, kurungan,
## item bangkit, pintu keluar, ending & bintang. Client mengirim niat
## (tekan/lepas E) ke host, host memvalidasi lalu menyebar hasilnya via RPC.
## Interaksi dihitung dari jarak (tanpa Area2D) supaya deterministik
## di jaringan. Peta tile ada di scenes/level_1.tscn; sumber grid-nya
## levels/level_1_grid.txt (generator: tools/build_level_1.gd).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const LEVEL_ID: String = "level_1"
const PAR_TIME: float = 480.0
const TASK_RANGE: float = 62.0
const HIDE_RANGE: float = 50.0
const REVIVE_RANGE: float = 52.0
const KEY_RANGE: float = 52.0
const KEY_CONSUMED: int = -2  # kunci sudah dipakai untuk membuka pintunya
const DOOR_RANGE: float = 56.0
const TRAP_STEP_RADIUS: float = 20.0
const TRAP_USE_RANGE: float = 64.0
const VISION_RADIUS: float = 150.0
const LAMP_RADIUS: float = 192.0
const CAGE_RANGE: float = 68.0
const EXIT_RADIUS: float = 72.0
const EXIT_HOLD: float = 1.5
const EXIT_WALKOUT_TIME: float = 2.5  # durasi maks jalan keluar otomatis (pengaman)
const EXIT_WALKOUT_OFFSET: Vector2 = Vector2(0, 48)  # arah keluar: ke bawah, melewati pintu (pintu di tepi bawah peta)
const RESCUE_TIME: float = 2.0
const SOLO_REVIVE_DELAY: float = 12.0
const SHARED_COOP_TYPES: Array[StringName] = [&"lan", &"backup", &"rapat"]
# Berdua = aman (disamakan dengan Level 2, versi "sebagian"): kedua pemain
# aman dari musuh HANYA selama sama-sama berada di alat tugas 2 pemain
# yang belum beres. Jaraknya sama dengan syarat kumpul di _server_parts_ready.
const JARAK_TUGAS_BERDUA: float = TASK_RANGE + 30.0
# Huruf mesin ketik untuk popup tugas bergaya monitor (sama dengan Level 2).
const F_MONO: Font = preload("res://assets/fonts/lmmono10-regular.otf")
const F_MONO_TEBAL: Font = preload("res://assets/fonts/lmmonolt10-bold.otf")
# Kegelapan dasar peta. Disesuaikan supaya suasananya lebih dekat ke
# Level 2: ±20% lebih gelap dari semula Color(0.077, 0.077, 0.112).
# Naikkan angkanya kalau terlalu gelap, turunkan kalau masih terlalu terang.
const BASE_MODULATE: Color = Color(0.062, 0.062, 0.09, 1.0)
const BLACKOUT_MODULATE: Color = Color(0.032, 0.032, 0.052, 1.0)

# --- Peta kantor: kotak ruangan saja (tanpa koridor, tanpa props) ---
# Kotak diturunkan dari Walls layer scenes/level_1.tscn (audit headless
# 27 Nov 2026): tiap kotak 0 sel dinding di dalamnya, label ruangan di
# scene ada di dalam kotaknya, antar kotak tidak bertumpukan. Lorong
# Timur sengaja tidak digambar (koridor). Rect2i dalam SEL (32 px).
const MAP_ROOMS: Array = [
	{"name": "Gudang", "rect": Rect2i(1, 6, 8, 9)},
	{"name": "Toilet", "rect": Rect2i(1, 17, 8, 5)},
	{"name": "R. Arsip", "rect": Rect2i(1, 24, 8, 15)},
	{"name": "Pantry", "rect": Rect2i(10, 4, 11, 7)},
	{"name": "R. Istirahat", "rect": Rect2i(22, 4, 10, 7)},
	{"name": "R. Rapat", "rect": Rect2i(33, 2, 13, 9)},
	{"name": "R. Manager", "rect": Rect2i(47, 4, 7, 7)},
	{"name": "R. Keuangan", "rect": Rect2i(55, 2, 8, 9)},
	{"name": "Area Kerja", "rect": Rect2i(10, 13, 27, 17)},
	{"name": "R. IT", "rect": Rect2i(38, 19, 6, 8)},
	{"name": "R. Fotokopi", "rect": Rect2i(45, 19, 6, 8)},
	{"name": "R. HR", "rect": Rect2i(52, 19, 4, 8)},
	{"name": "R. Serbaguna", "rect": Rect2i(10, 33, 12, 6)},
	{"name": "R. Server", "rect": Rect2i(23, 33, 10, 6)},
	{"name": "Lobby", "rect": Rect2i(34, 33, 13, 6)},
	{"name": "Resepsionis", "rect": Rect2i(48, 33, 15, 6)},
]
# Ruang Gudang (pojok kiri atas): satu-satunya tempat peta bisa dibuka.
const GUDANG_RECT := Rect2(32.0, 192.0, 256.0, 288.0)

var _level_active: bool = false
var _level_ended: bool = false
var _paused_for_disconnect: bool = false
var _level_time: float = 0.0
var _deaths_total: int = 0
var _exit_open: bool = false
var _exit_progress: float = 0.0
var _exiting: bool = false  # transisi selesai level: pemain sedang jalan keluar otomatis
var _exit_walkout_timer: float = 0.0
var _exit_target: Vector2 = Vector2.ZERO  # titik di balik pintu keluar yang dituju saat walkout
var _rescue_progress: float = 0.0
var _cage_peer: int = -1
var _revive_carrier: int = -1
var _key_carriers: Dictionary = {"A": -1, "B": -1, "C": -1, "D": -1, "E": -1}
var _revive_visible: bool = false
var _solo_revive_timer: float = -1.0
var _wipe_timer: float = -1.0
var _blackout_timer: float = 0.0
var _disconnect_timer: float = -1.0
var _pesan_menu: String = ""  # pesan untuk main menu saat kembali karena host putus
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
var _server_parts: Dictionary = {}  # tid -> {peer_id -> true} (bagian co-op, per tugas)
var _task_busy: Dictionary = {}  # tid -> peer_id (tugas SOLO sedang dikerjakan siapa)
var _local_task: StringName = StringName("")  # tugas yang sedang dibuka pemain lokal
var _sync_received: bool = false  # klien sudah menerima state penuh dari host?
var _sync_retry: float = 0.0  # timer ulang request_sync (klien saja)
var _coop_sessions: Dictionary = {}  # tid -> {"game": MinigameBase, "players": Array[int]} (task co-op bersama)
var _coop_last_key_peer: int = -1  # pemain terakhir yang menekan tombol di puzzle bersama
var _coop_broadcast_timer: float = 0.0
var _wait_overlay: LayarTunggu = null  # layar "MENUNGGU HOST" untuk klien yang masuk duluan
var _traps: Array[Node] = []
var _trap_by_id: Dictionary = {}  # trap_id -> Trap
var _vision_timer: float = 0.0
var minigame_layer: MinigameLayer = null

@onready var floor_layer: TileMapLayer = get_node_or_null("Floor")
@onready var walls_layer: TileMapLayer = get_node_or_null("Walls")
@onready var props_layer: TileMapLayer = get_node_or_null("Props")
@onready var props0_layer: TileMapLayer = get_node_or_null("Props0")
@onready var props1_layer: TileMapLayer = get_node_or_null("Props1")
@onready var canvas_modulate: CanvasModulate = get_node_or_null("CanvasModulate")
@onready var players_container: Node2D = get_node_or_null("Players")
@onready var tasks_container: Node2D = get_node_or_null("Tasks")
@onready var spots_container: Node2D = get_node_or_null("HidingSpots")
@onready var doors_container: Node2D = get_node_or_null("Doors")
@onready var traps_container: Node2D = get_node_or_null("Traps")
@onready var spawns_container: Node2D = get_node_or_null("Spawns")
@onready var lights_container: Node2D = get_node_or_null("Lights")
@onready var enemy: CharacterBody2D = get_node_or_null("Enemy")
@onready var exit_door: Node2D = get_node_or_null("ExitDoor")
@onready var cage: Node2D = get_node_or_null("Cage")
@onready var revive_item: Node2D = get_node_or_null("ReviveItem")
@onready var hud: CanvasLayer = get_node_or_null("HUD")


func _ready() -> void:
	# Backsound Level 1 (The Leaves) — crossfade dari lagu menu /
	# cerita ke lagu level, lalu loop crossfade sendiri di MusicManager.
	MusicManager.play_level()
	add_to_group("LevelManager")
	randomize()
	_collect_level_nodes()
	_setup_pathfinder()
	_setup_enemy()
	_setup_lights()
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
	# Popup tugas bergaya monitor (seperti Level 2), pelat versi kantor.
	minigame_layer.pakai_gaya_monitor(F_MONO, F_MONO_TEBAL, "PC LEMBUR  ·  LT. 1")
	if NetworkManager.mode == NetworkManager.Mode.CLIENT:
		_build_join_wait_overlay()
	_update_hud_static()
	if hud != null:
		hud.setup_map(MAP_ROOMS)


func is_level_running() -> bool:
	return _level_active and not _level_ended and not _paused_for_disconnect


func _collect_level_nodes() -> void:
	if tasks_container != null:
		for st: Node in tasks_container.get_children():
			_tasks[st.task_id] = {
				"node": st,
				"progress": 0.0,
				"completed": false,
				"game_type": st.game_type,
				"requires_two": st.requires_two,
				"ruang": _nama_ruang_di((st as Node2D).global_position),  # untuk papan tugas di HUD
			}
	if doors_container != null:
		for d: Node in doors_container.get_children():
			_doors[d.door_id] = d
	if traps_container != null:
		for tr: Node in traps_container.get_children():
			_traps.append(tr)
			_trap_by_id[tr.trap_id] = tr
	if spots_container != null:
		for s: Node in spots_container.get_children():
			_spots.append(s)


func _door_cells(d: Node) -> Array[Vector2i]:
	# Sel yang ditempati sebuah pintu terkunci: gabungan door_cells yang
	# diisi di scene + 2 sel yang dihitung dari posisi pintu. Pintu
	# vertikal 32x64: 2 selnya = kolom posisi, baris (y-16)/32 dan
	# (y+16)/32. Pintu HORIZONTAL (export `horizontal` di locked_door.gd,
	# atau node yang terlanjur diputar 90° di editor): 2 selnya = baris
	# posisi, kolom (x-16)/32 dan (x+16)/32. Pengaman ini penting:
	# door_cells diisi manual di editor dan gampang salah salin — DoorC
	# sempat berisi sel DoorA (9,26),(9,27), jadi sel asli Pintu C
	# (9,35),(9,36) tetap walkable dan musuh jalan menembus pintu yang
	# terkunci. Dengan helper ini, sel dari posisi selalu ikut terblokir
	# walau data scene salah. Tanpa cabang horizontal, pintu yang diputar
	# 90° memblokir 2 sel vertikal yang salah dan musuh menembus pintunya.
	var cells: Array[Vector2i] = []
	for cell: Vector2i in d.door_cells:
		if not cells.has(cell):
			cells.append(cell)
	var pos: Vector2 = (d as Node2D).global_position
	var is_horiz: bool = bool(d.get("horizontal")) or absf(sin((d as Node2D).rotation)) > 0.7
	if is_horiz:
		var row: int = floori(pos.y / 32.0)
		for col: int in [floori((pos.x - 16.0) / 32.0), floori((pos.x + 16.0) / 32.0)]:
			var c := Vector2i(col, row)
			if not cells.has(c):
				cells.append(c)
	else:
		var col: int = floori(pos.x / 32.0)
		for row: int in [floori((pos.y - 16.0) / 32.0), floori((pos.y + 16.0) / 32.0)]:
			var c := Vector2i(col, row)
			if not cells.has(c):
				cells.append(c)
	return cells


func _setup_pathfinder() -> void:
	if floor_layer == null or walls_layer == null:
		push_warning("Level 1: TileMapLayer Floor/Walls tidak ditemukan; pathfinding enemy nonaktif.")
		return
	var blocked: Dictionary = {}
	for d: Node in _doors.values():
		for cell: Vector2i in _door_cells(d):
			blocked[cell] = true
	_pathfinder = GridPathfinder.new()
	# Props0/Props1 ikut jadi penghalang: objek di kedua layer itu
	# ber-collision tapi sebelumnya tidak dikenal pathfinder, jadi musuh
	# disuruh jalan menabraknya. DekorDinding/DekorKecil tidak ikut
	# (tile-nya tidak punya collision, cuma hiasan).
	_pathfinder.setup(floor_layer, walls_layer, props_layer, blocked, [props0_layer, props1_layer])
	# Sel perangkap ikut diblokir: musuh tidak boleh menginjak trap
	# (hanya pemain yang bisa memicunya). Jalur A* musuh memutar
	# melewati trap; saat dipancing ke trap, musuh berhenti di
	# sebelahnya, bukan di atasnya.
	for tr: Node in _traps:
		_pathfinder.set_trap_blocked(_pathfinder.world_to_cell(tr.global_position), true)


func _setup_enemy() -> void:
	if enemy == null:
		return
	enemy.pathfinder = _pathfinder
	enemy.patrol_points = _marker_positions("Patrol", 27, [Vector2i(11, 14), Vector2i(35, 14), Vector2i(58, 16), Vector2i(58, 29), Vector2i(35, 29), Vector2i(11, 29), Vector2i(11, 21), Vector2i(58, 22), Vector2i(59, 7), Vector2i(62, 22), Vector2i(55, 35), Vector2i(40, 35), Vector2i(28, 36), Vector2i(15, 33), Vector2i(5, 18), Vector2i(16, 7), Vector2i(27, 7), Vector2i(39, 7), Vector2i(50, 7), Vector2i(4, 32), Vector2i(5, 8), Vector2i(18, 18), Vector2i(33, 20), Vector2i(17, 25), Vector2i(39, 23), Vector2i(47, 21), Vector2i(52, 24)])
	enemy.spawn_points = _marker_positions("EnemySpawn", 13, [Vector2i(4, 8), Vector2i(59, 8), Vector2i(4, 30), Vector2i(28, 34), Vector2i(62, 23), Vector2i(39, 8), Vector2i(13, 37), Vector2i(54, 35), Vector2i(47, 22), Vector2i(24, 21), Vector2i(46, 14), Vector2i(1, 20), Vector2i(21, 6)])
	var start: Vector2 = enemy.spawn_points[randi() % enemy.spawn_points.size()]
	enemy.global_position = start
	if _pathfinder != null:
		for i: int in range(enemy.patrol_points.size()):
			var c: Vector2i = _pathfinder.world_to_cell(enemy.patrol_points[i])
			if _pathfinder.is_cell_blocked(c):
				push_warning("Patrol%d di cell %s yang tidak bisa dilalui — geser markernya di editor." % [i + 1, str(c)])
		for i: int in range(enemy.spawn_points.size()):
			var c2: Vector2i = _pathfinder.world_to_cell(enemy.spawn_points[i])
			if _pathfinder.is_cell_blocked(c2):
				push_warning("EnemySpawn%d di cell %s yang tidak bisa dilalui — geser markernya di editor." % [i + 1, str(c2)])


func _setup_lights() -> void:
	if lights_container == null:
		return
	for l: Node in lights_container.get_children():
		if l is PointLight2D:
			_lights.append(l)
			_light_base.append(l.energy)
			_light_phase.append(randf() * TAU)


func _marker_pos(marker_name: String, fallback_cell: Vector2i) -> Vector2:
	if spawns_container != null:
		var m: Node2D = spawns_container.get_node_or_null(marker_name)
		if m != null:
			return m.global_position
	return Vector2(fallback_cell) * 32.0 + Vector2(16, 16)


func _marker_positions(prefix: String, count: int, fallbacks: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in range(count):
		out.append(_marker_pos(prefix + str(i + 1), fallbacks[i]))
	return out


func _revive_points() -> Array[Vector2]:
	return _marker_positions("Revive", 8, [Vector2i(5, 6), Vector2i(58, 7), Vector2i(11, 35), Vector2i(57, 33), Vector2i(25, 12), Vector2i(49, 27), Vector2i(33, 7), Vector2i(4, 16)])


# ---------------------------------------------------------------- spawn ---
func _spawn_player(peer_id: int, index: int, broadcast: bool) -> void:
	if _players.has(peer_id):
		return
	if players_container == null:
		return
	var p: CharacterBody2D = PLAYER_SCENE.instantiate()
	p.name = "Player_%d" % peer_id
	p.set_multiplayer_authority(peer_id)
	p.player_index = index + 1
	p.position = _marker_pos("PlayerSpawn%d" % (index + 1), Vector2i(35, 34) if index == 0 else Vector2i(37, 34))
	players_container.add_child(p)
	_players[peer_id] = p
	_holding[peer_id] = false
	if broadcast and NetworkManager.is_networked() and NetworkManager.is_server_authority():
		rpc("_spawn_player_rpc", peer_id, index)


@rpc("authority", "call_remote", "reliable")
func _spawn_player_rpc(peer_id: int, index: int) -> void:
	_spawn_player(peer_id, index, false)
	if peer_id == NetworkManager.local_peer_id():
		# Host sudah spawn pemain lokal -> kamera sudah ada. Overlay
		# boleh hilang di sini (pengaman kalau _full_state_rpc
		# terlambat); state penuh menyusul lewat _full_state_rpc.
		_hide_join_wait_overlay()


func _on_peer_joined(peer_id: int) -> void:
	if not NetworkManager.is_server_authority() or _level_ended:
		return
	# Kalau ada yang kembali bergabung setelah sempat terputus,
	# LANJUTKAN game. BUG LAMA: _paused_for_disconnect tidak pernah
	# dibersihkan — sekali P2 terputus (walau cuma sebentar, lalu join
	# lagi), is_level_running() jadi false SELAMANYA di host: musuh
	# membeku di satu tempat (physics_process-nya return duluan),
	# trap & mistake tidak memanggil musuh, dan P1 pun tidak bisa
	# jalan. Sementara P2 yang join lagi tetap bisa jalan-jalan dan
	# melihat musuh diam di situ terus. _spawn_player di bawah
	# return duluan kalau pemain lama masih ada (itu benar), tapi
	# jeda-nya harus tetap dibersihkan di sini.
	if _paused_for_disconnect:
		_paused_for_disconnect = false
		if hud != null:
			hud.hide_disconnect()
	var index: int = 1 if _players.size() >= 1 else 0
	_spawn_player(peer_id, index, true)


func _on_peer_left(_peer_id: int) -> void:
	if _level_ended:
		return
	_paused_for_disconnect = true
	if hud != null:
		hud.show_putus("teman_putus")


func _on_host_disconnected() -> void:
	_hide_join_wait_overlay()
	_disconnect_timer = 4.0
	if _level_ended:
		# Host menekan MENU UTAMA di panel hasil: teman ikut kembali.
		_pesan_menu = "Host keluar dari game."
		if hud != null:
			hud.show_putus("host_keluar", _disconnect_timer)
		return
	_paused_for_disconnect = true
	_pesan_menu = "Host terputus dari game."
	if hud != null:
		hud.show_putus("host_putus", _disconnect_timer)


# ------------------------------------------------------- overlay tunggu ---
func _build_join_wait_overlay() -> void:
	# Klien yang masuk duluan belum punya kamera pemain sampai host
	# men-spawn dia (host masih menonton cerita). Tanpa layar ini, layarnya
	# menampilkan seluruh map mentah. Layar "MENUNGGU HOST" (layar_tunggu.gd)
	# menutupi map sampai state penuh pertama diterima dari host.
	var layar := LayarTunggu.new()
	layar.name = "JoinWaitOverlay"
	layar.level_satu = true
	add_child(layar)
	_wait_overlay = layar


func _hide_join_wait_overlay() -> void:
	if _wait_overlay != null:
		_wait_overlay.tutup()
		_wait_overlay = null


# ------------------------------------------------------------- sync RPC ---
@rpc("any_peer", "call_remote", "reliable")
func _trap_states() -> Dictionary:
	var out: Dictionary = {}
	for tr: Node in _traps:
		out[tr.trap_id] = bool(tr.armed)
	return out


@rpc("any_peer", "call_remote", "reliable")
func request_sync_rpc() -> void:
	# NOTE: fungsi ini WAJIB punya @rpc di atas — tanpa itu, panggilan
	# rpc_id(1, "request_sync_rpc") dari klien dibuang Godot diam-diam,
	# _full_state_rpc tidak pernah dikirim, dan overlay "MENUNGGU HOST"
	# tidak pernah hilang. (Itulah bug yang terjadi 26 Nov: anotasi ini
	# memang tidak pernah ada sejak awal, tapi sebelum ada overlay,
	# rusaknya sync awal tidak kelihatan karena game baru mulai dari
	# state default semua.)
	if not NetworkManager.is_server_authority():
		return
	# Jangan jawab sync dari game yang SUDAH BERAKHIR: snapshot-nya basi
	# (posisi pemain di kurungan, task sudah selesai, dsb.). Klien yang
	# minta sync akan mengulang tiap 1 detik (lihat _process) dan mendapat
	# jawaban segar begitu host restart. Tanpa penjaga ini, klien yang
	# reload saat restart bisa menerima snapshot pra-restart dan pemain
	# yang tadinya terkurung malah "respawn" di posisi kurungan, bukan di
	# tempat awal — karena _full_state_rpc memasang posisi dari host.
	if _level_ended:
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
		"keys": _key_carriers.duplicate(),
		"traps": _trap_states(),
		"ended": _level_ended,
	}
	rpc_id(sender, "_full_state_rpc", data)


@rpc("authority", "call_remote", "reliable")
func _full_state_rpc(data: Dictionary) -> void:
	# Abaikan snapshot dari game yang sudah berakhir (basi — mis. terkirim
	# sesaat sebelum host restart). Kalau diterima, pemain yang tadinya
	# terkurung akan dipasang di posisi kurungan, bukan di spawn awal.
	# _sync_received sengaja TIDAK di-set, jadi loop retry di _process
	# akan meminta sync lagi dan mendapat snapshot segar pasca-restart.
	if bool(data.get("ended", false)):
		return
	_sync_received = true
	_hide_join_wait_overlay()
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
	if data.has("keys"):
		var keys_data: Dictionary = data["keys"]
		for kid: String in keys_data.keys():
			_key_carriers[kid] = int(keys_data[kid])
			if int(keys_data[kid]) != -1:
				var kitem: Node = _key_item_node(kid)
				if kitem != null:
					kitem.hide_item()
	if data.has("traps"):
		var traps_data: Dictionary = data["traps"]
		for tid: String in traps_data.keys():
			var tr: Node = _trap_by_id.get(tid)
			if tr != null and not bool(traps_data[tid]):
				tr.set_spent()
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
		SfxManager.play_for(peer_id, &"pick")
		_show_message("Item Bangkit didapat! Selamatkan temanmu di kurungan.")
		return
	# 3) Ambil kunci pintu.
	for kid: String in _key_carriers.keys():
		var kitem: Node = _key_item_node(kid)
		if kitem != null and int(_key_carriers.get(kid, -1)) == -1 and p.global_position.distance_to(kitem.global_position) <= KEY_RANGE:
			_key_carriers[kid] = peer_id
			kitem.hide_item()
			if NetworkManager.is_networked():
				rpc("_key_taken_rpc", kid, peer_id)
			SfxManager.play_for(peer_id, &"pick")
			_show_message("Kunci %s didapat! Cari Pintu %s." % [kid, kid])
			return
	# 4) Buka pintu terkunci (butuh kunci yang cocok).
	var door: Node = _nearest_door(p.global_position)
	if door != null and not door.is_open:
		if _key_carriers.get(door.door_id, -1) == peer_id:
			_key_carriers[door.door_id] = KEY_CONSUMED
			var kitem: Node = _key_item_node(door.door_id)
			if kitem != null:
				kitem.hide_item()
			_open_door(door.door_id)
		else:
			_show_message("Pintu %s terkunci, cari Kunci %s dulu" % [door.door_id, door.door_id])
		return
	# 5) Kerjakan tugas (buka minigame di layar pemain itu).
	var tid: StringName = _nearest_task(p.global_position)
	if tid != StringName(""):
		_try_open_minigame(peer_id, tid)
		return
	# 6) Aktifkan perangkap (sengaja) — musuh dipancing ke posisi trap.
	var trap: Node = _nearest_trap(p.global_position, TRAP_USE_RANGE)
	if trap != null and _can_see_from(p.global_position, trap.global_position):
		_trigger_trap(trap.trap_id, peer_id, true)
		return
	# 7) Sembunyi.
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
	if hidden:
		SfxManager.play_for(p.peer_id, &"hide")
	p.apply_local_state(p.is_downed, hidden, p.carrying_revive)
	p.broadcast_state()


func _nearest_task(pos: Vector2) -> StringName:
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if t["completed"]:
			continue
		if pos.distance_to((t["node"] as Node2D).global_position) <= TASK_RANGE:
			return tid
	return StringName("")


func _nearest_spot(pos: Vector2) -> Node2D:
	for s: Node2D in _spots:
		if pos.distance_to(s.global_position) <= HIDE_RANGE:
			return s
	return null


func _nearest_door(pos: Vector2) -> Node:
	for d: Node in _doors.values():
		if pos.distance_to(d.global_position) <= DOOR_RANGE:
			return d
	return null


func _key_item_node(kid: String) -> Node:
	# Cari kunci berdasarkan hurufnya — generik untuk A, B, C, D, E,
	# dst. (bukan match per huruf lagi). Urutan: nama node dulu
	# ("KeyItemD"), lalu properti key_id node-nya, supaya tetap ketemu
	# walau Edward hanya mengganti salah satu dari keduanya saat
	# menduplikasi di editor.
	var by_name: Node = get_node_or_null("KeyItem" + kid)
	if by_name != null:
		return by_name
	for c: Node in get_children():
		if c.get("key_id") != null and str(c.get("key_id")) == kid:
			return c
	return null


@rpc("authority", "call_remote", "reliable")
func _key_taken_rpc(key_id: String, peer_id: int) -> void:
	_key_carriers[key_id] = peer_id
	var kitem: Node = _key_item_node(key_id)
	if kitem != null:
		kitem.hide_item()


# ------------------------------------------------------------ visibilitas ---
func _can_see_from(from_pos: Vector2, target_pos: Vector2) -> bool:
	# Garis pandang: ada tembok/pintu tertutup di antara = tidak kelihatan.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from_pos, target_pos, 1)
	if not space.intersect_ray(query).is_empty():
		return false
	# Cahaya: kena cahaya pemain, atau kena lampu ruangan.
	if from_pos.distance_to(target_pos) <= VISION_RADIUS:
		return true
	for lamp: PointLight2D in _lights:
		if target_pos.distance_to(lamp.global_position) <= LAMP_RADIUS:
			return true
	return false


func _can_see(target_pos: Vector2) -> bool:
	var lp: Node = _players.get(NetworkManager.local_peer_id())
	if lp == null:
		return true
	return _can_see_from(lp.global_position, target_pos)


func _update_vision() -> void:
	var lp: Node = _players.get(NetworkManager.local_peer_id())
	if lp == null:
		return
	var from_pos: Vector2 = lp.global_position
	for kid: String in _key_carriers.keys():
		var kitem: Node = _key_item_node(kid)
		if kitem != null:
			kitem.visible = int(_key_carriers[kid]) == -1 and _can_see_from(from_pos, kitem.global_position)
	if revive_item != null:
		# Revive adalah suar penyelamat: selalu terlihat saat muncul,
		# supaya partner bisa menemukannya dari mana pun (bukan disembunyikan vision).
		revive_item.visible = _revive_visible
	for tr: Node in _traps:
		tr.visible = _can_see_from(from_pos, tr.global_position)


# ------------------------------------------------------------ perangkap ---
func _nearest_trap(pos: Vector2, max_dist: float) -> Node:
	var best: Node = null
	var best_d: float = max_dist
	for tr: Node in _traps:
		if not bool(tr.armed):
			continue
		var d: float = pos.distance_to(tr.global_position)
		if d <= best_d:
			best_d = d
			best = tr
	return best


func _trap_message(peer_id: int, deliberate: bool) -> String:
	if deliberate:
		return "Perangkap diaktifkan! Sesuatu mendekat ke sana..."
	if peer_id == NetworkManager.local_peer_id():
		return "Kamu menginjak perangkap! Sesuatu mendekat..."
	return "Ada yang menginjak perangkap! Sesuatu mendekat..."


func _trigger_trap(trap_id: String, peer_id: int, deliberate: bool) -> void:
	var tr: Node = _trap_by_id.get(trap_id)
	if tr == null or not bool(tr.armed):
		return
	tr.set_spent()
	SfxManager.play_shared(&"alarm")
	if enemy != null:
		enemy.investigate(tr.global_position)
	_show_message(_trap_message(peer_id, deliberate))
	if NetworkManager.is_networked():
		rpc("_trap_triggered_rpc", trap_id, peer_id, deliberate)


@rpc("authority", "call_remote", "reliable")
func _trap_triggered_rpc(trap_id: String, peer_id: int, deliberate: bool) -> void:
	var tr: Node = _trap_by_id.get(trap_id)
	if tr != null:
		tr.set_spent()
	_show_message(_trap_message(peer_id, deliberate))


func _tick_traps() -> void:
	for tr: Node in _traps:
		if not bool(tr.armed):
			continue
		for pid: int in _players.keys():
			var p: Node = _players[pid]
			if p.is_downed or p.is_hidden:
				continue
			if p.global_position.distance_to(tr.global_position) <= TRAP_STEP_RADIUS:
				_trigger_trap(tr.trap_id, pid, false)
				break


# ------------------------------------------------------------ minigame ---
func get_local_player() -> Node:
	return _players.get(NetworkManager.local_peer_id())


func task_position(tid: StringName) -> Vector2:
	if _tasks.has(tid):
		return (_tasks[tid]["node"] as Node2D).global_position
	return Vector2.ZERO


func is_task_completed(tid: StringName) -> bool:
	return _tasks.has(tid) and bool(_tasks[tid]["completed"])


func set_local_minigame_open(open: bool) -> void:
	var p: Node = get_local_player()
	if p == null:
		return
	p.minigame_open = open
	if open:
		p.velocity = Vector2.ZERO
		p.interact_held = false
	elif _local_task != StringName(""):
		# Minigame ditutup -> lepas kunci tugas solo milik pemain lokal.
		_release_task_lock(_local_task)
		_local_task = StringName("")


func is_minigame_open() -> bool:
	return minigame_layer != null and minigame_layer.is_open()


func set_local_map_open(open: bool) -> void:
	# Dipanggil HUD saat peta dibuka/ditutup: bekukan gerak + interaksi
	# pemain lokal seperti saat minigame terbuka (player.gd).
	var p: Node = get_local_player()
	if p == null:
		return
	p.map_open = open
	if open:
		p.velocity = Vector2.ZERO
		p.interact_held = false


func get_map_players() -> Array:
	# Dipakai HUD untuk titik pemain di peta (lokal + teman).
	var out: Array = []
	var local_id: int = NetworkManager.local_peer_id()
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		out.append({"pos": (p as Node2D).global_position, "local": pid == local_id})
	return out


func _is_local_in_gudang() -> bool:
	var p: Node = get_local_player()
	if p == null:
		return false
	return GUDANG_RECT.has_point((p as Node2D).global_position)


func _release_task_lock(tid: StringName) -> void:
	if NetworkManager.is_server_authority():
		if _task_busy.has(tid) and int(_task_busy[tid]) == NetworkManager.local_peer_id():
			_task_busy.erase(tid)
	elif NetworkManager.is_networked():
		rpc_id(1, "request_release_task_rpc", NetworkManager.local_peer_id(), String(tid))


@rpc("any_peer", "call_remote", "reliable")
func request_release_task_rpc(peer_id: int, tid: String) -> void:
	# Klien melepas kunci tugas solo-nya saat minigame ditutup.
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	var key := StringName(tid)
	if _task_busy.has(key) and int(_task_busy[key]) == peer_id:
		_task_busy.erase(key)


func open_minigame_for_local(tid: StringName) -> void:
	if minigame_layer == null or not _tasks.has(tid):
		return
	_local_task = tid
	minigame_layer.open_minigame(tid, _tasks[tid]["game_type"])


func _try_open_minigame(peer_id: int, tid: StringName) -> void:
	var t: Dictionary = _tasks[tid]
	# Tugas solo dikunci untuk 1 pemain; tugas co-op bebas dibuka berdua.
	if not bool(t["requires_two"]):
		if _task_busy.has(tid) and int(_task_busy[tid]) != peer_id:
			_notice_to(peer_id, "Tugas ini sedang dikerjakan pemain lain!")
			return
		_task_busy[tid] = peer_id
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
	# Task co-op bersama: satu puzzle di server, kedua pemain mirror.
	if _is_shared_coop(tid):
		_ensure_coop_session(tid)
		if peer_id == NetworkManager.local_peer_id():
			_open_shared_for_local(tid)
		elif NetworkManager.is_networked():
			_add_coop_player(tid, peer_id)
			rpc_id(peer_id, "_open_shared_minigame_rpc", String(tid), _coop_snapshot(tid))
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


@rpc("any_peer", "call_remote", "reliable")
func request_minigame_result_rpc(peer_id: int, tid: String) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_handle_minigame_result(peer_id, StringName(tid))


func _handle_minigame_result(peer_id: int, tid: StringName) -> void:
	if not _tasks.has(tid) or bool(_tasks[tid]["completed"]):
		return
	# Task co-op bersama TIDAK lewat jalur ini — otoritas server
	# menyelesaikannya langsung saat puzzle bersama selesai.
	if _is_shared_coop(tid):
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
	if not _server_parts.has(tid):
		_server_parts[tid] = {}
	_server_parts[tid][peer_id] = true
	if _server_parts_ready(tid):
		_complete_task(tid)
	else:
		_notice_to(peer_id, "Bagianmu selesai! Menunggu partner menyelesaikan bagiannya.")


func _server_needed() -> int:
	# Solo: 1 pemain cukup (kalau tidak, game tidak bisa tamat solo).
	return 1 if not NetworkManager.is_networked() else 2


func _server_parts_ready(tid: StringName) -> bool:
	var parts: Dictionary = _server_parts.get(tid, {})
	if parts.size() < _server_needed():
		return false
	var station_pos: Vector2 = (_tasks[tid]["node"] as Node2D).global_position
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		if p.is_downed or p.is_hidden:
			return false
		if p.global_position.distance_to(station_pos) > TASK_RANGE + 30.0:
			return false
	return true


# --------------------------------------------------- task co-op bersama ---
# Tiga task co-op (lan/backup/rapat) dikerjakan BERDUA dalam SATU puzzle:
# otoritas (game tersembunyi di server) yang menjalankan logika; kedua
# pemain membuka "mirror" yang hanya menampilkan state server dan
# meneruskan tombol ke server. Solo tetap pakai jalur lama (paralel),
# begitu juga task "server" (keypad) yang tidak masuk SHARED_COOP_TYPES.
func _is_shared_coop(tid: StringName) -> bool:
	if not _tasks.has(tid):
		return false
	var t: Dictionary = _tasks[tid]
	return bool(t["requires_two"]) and _server_needed() > 1 and SHARED_COOP_TYPES.has(t["game_type"])


func _ensure_coop_session(tid: StringName) -> void:
	if _coop_sessions.has(tid):
		return
	var t: Dictionary = _tasks[tid]
	var script: GDScript = load(MinigameLayer.GAME_SCRIPTS[t["game_type"]])
	var game: MinigameBase = script.new() as MinigameBase
	if game == null:
		return
	add_child(game)
	game.visible = false  # otoritas tersembunyi; pemain melihat mirror-nya
	game.setup()
	game.finished.connect(_on_coop_authority_finished.bind(tid))
	game.mistake_made.connect(_on_coop_authority_mistake.bind(tid))
	_coop_sessions[tid] = {"game": game, "players": []}
	_coop_last_key_peer = -1


func _coop_snapshot(tid: StringName) -> Dictionary:
	if not _coop_sessions.has(tid):
		return {}
	var game: MinigameBase = _coop_sessions[tid]["game"]
	if game == null:
		return {}
	return game.get_shared_state()


func _open_shared_for_local(tid: StringName) -> void:
	if minigame_layer == null or not _tasks.has(tid):
		return
	if minigame_layer.open_minigame(tid, _tasks[tid]["game_type"], true, _coop_snapshot(tid)):
		_local_task = tid
		_add_coop_player(tid, NetworkManager.local_peer_id())


@rpc("authority", "call_remote", "reliable")
func _open_shared_minigame_rpc(tid: String, snapshot: Dictionary) -> void:
	var key := StringName(tid)
	if minigame_layer == null or not _tasks.has(key):
		return
	if minigame_layer.open_minigame(key, _tasks[key]["game_type"], true, snapshot):
		_local_task = key
	else:
		# Gagal buka (mis. minigame lain sedang terbuka): keluar dari sesi
		# supaya otoritas tidak jalan sendiri tanpa pemain.
		leave_coop_session(key)


func _add_coop_player(tid: StringName, peer_id: int) -> void:
	if not _coop_sessions.has(tid):
		return
	var players: Array = _coop_sessions[tid]["players"]
	if not players.has(peer_id):
		players.append(peer_id)


func leave_coop_session(tid: StringName) -> void:
	# Dipanggil layer saat mirror ditutup (ESC / selesai / tertangkap).
	if NetworkManager.is_server_authority():
		_remove_coop_player(tid, NetworkManager.local_peer_id())
	elif NetworkManager.is_networked():
		rpc_id(1, "leave_coop_session_rpc", NetworkManager.local_peer_id(), String(tid))


@rpc("any_peer", "call_remote", "reliable")
func leave_coop_session_rpc(peer_id: int, tid: String) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_remove_coop_player(StringName(tid), peer_id)


func _remove_coop_player(tid: StringName, peer_id: int) -> void:
	if not _coop_sessions.has(tid):
		return
	var players: Array = _coop_sessions[tid]["players"]
	players.erase(peer_id)
	if players.is_empty():
		_cleanup_coop_session(tid)


func submit_coop_key(tid: StringName, keycode: int) -> void:
	# Dipanggil layer saat pemain menekan tombol di mirror co-op.
	if NetworkManager.is_server_authority():
		_apply_coop_key(NetworkManager.local_peer_id(), tid, keycode)
	elif NetworkManager.is_networked():
		rpc_id(1, "submit_coop_key_rpc", NetworkManager.local_peer_id(), String(tid), keycode)


@rpc("any_peer", "call_remote", "reliable")
func submit_coop_key_rpc(peer_id: int, tid: String, keycode: int) -> void:
	if not NetworkManager.is_server_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_apply_coop_key(peer_id, StringName(tid), keycode)


func _apply_coop_key(peer_id: int, tid: StringName, keycode: int) -> void:
	if not _coop_sessions.has(tid):
		return
	var players: Array = _coop_sessions[tid]["players"]
	if not players.has(peer_id):
		return
	var game: MinigameBase = _coop_sessions[tid]["game"]
	if game == null:
		return
	_coop_last_key_peer = peer_id
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = keycode
	game.handle_key(ev)
	# Kirim snapshot segar ke semua pemain di sesi supaya tampilan
	# langsung sinkron (tanpa menunggu tick 0,1 dtk).
	if _coop_sessions.has(tid):
		_broadcast_coop_snapshot(tid)


func _tick_coop_sessions(delta: float) -> void:
	_coop_broadcast_timer += delta
	var do_broadcast: bool = _coop_broadcast_timer >= 0.1
	if do_broadcast:
		_coop_broadcast_timer = 0.0
	for tid: StringName in _coop_sessions.keys():
		var session: Dictionary = _coop_sessions[tid]
		var game: MinigameBase = session["game"]
		if game == null:
			continue
		var players: Array = session["players"]
		if players.is_empty():
			continue
		game.tick(delta)
		# tick() bisa menyelesaikan game (Backup 100%) — _finish()
		# memanggil _on_coop_authority_finished -> _complete_task ->
		# _cleanup_coop_session di tengah loop; cek ulang sebelum lanjut.
		if not _coop_sessions.has(tid):
			continue
		_apply_task_progress(tid, game.get_progress())
		if do_broadcast:
			_broadcast_coop_snapshot(tid)


func _broadcast_coop_snapshot(tid: StringName) -> void:
	if not _coop_sessions.has(tid):
		return
	var snap: Dictionary = _coop_snapshot(tid)
	if snap.is_empty():
		return
	if NetworkManager.is_networked():
		rpc("_coop_state_rpc", String(tid), snap)
	# Pemain lokal (host) juga mirror: terapkan langsung.
	if minigame_layer != null:
		minigame_layer.apply_coop_snapshot(tid, snap)


@rpc("authority", "call_remote", "unreliable")
func _coop_state_rpc(tid: String, snapshot: Dictionary) -> void:
	if minigame_layer != null:
		minigame_layer.apply_coop_snapshot(StringName(tid), snapshot)


func _on_coop_authority_finished(tid: StringName) -> void:
	_complete_task(tid)


func _on_coop_authority_mistake(tid: StringName) -> void:
	# Kesalahan di puzzle bersama: musuh mendengar dari posisi pemain
	# yang terakhir menekan tombol (atau pemain pertama di sesi kalau
	# kesalahannya dari timer, mis. sektor backup terlewat).
	var pid: int = _coop_last_key_peer
	if (pid == -1 or not _players.has(pid)) and _coop_sessions.has(tid):
		var players: Array = _coop_sessions[tid]["players"]
		if not players.is_empty():
			pid = int(players[0])
	if pid != -1 and _players.has(pid):
		_noise_at_player(pid)


func _cleanup_coop_session(tid: StringName) -> void:
	if not _coop_sessions.has(tid):
		return
	var game: MinigameBase = _coop_sessions[tid]["game"]
	_coop_sessions.erase(tid)
	if game != null:
		game.queue_free()


# -------------------------------------------------- suara kesalahan task ---
func report_mistake_noise() -> void:
	# Kesalahan di minigame lokal: musuh mendengar suara dari posisi
	# pemain lokal. Server memproses langsung; klien kirim ke host.
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
	if p == null or enemy == null:
		return
	if enemy.hear_noise(p.global_position):
		_show_message("Berisik! Musuh mendekat")


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
	_tick_coop_sessions(delta)
	_tick_traps()
	_tick_rescue(delta)
	_tick_exit(delta)
	_tick_revive_timers(delta)
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
		if _is_shared_coop(tid):
			continue
		if _server_parts_ready(tid):
			_complete_task(tid)


func _complete_task(tid: StringName) -> void:
	var t: Dictionary = _tasks[tid]
	_task_busy.erase(tid)
	_cleanup_coop_session(tid)
	t["completed"] = true
	t["progress"] = 1.0
	t["node"].set_completed()
	SfxManager.play_shared(&"complete")
	if NetworkManager.is_networked():
		rpc("_task_completed_rpc", String(tid))
	_show_message("Tugas %s beres  %d dari %d" % [t["node"].title, _completed_count(), _tasks.size()])
	if _completed_count() >= _tasks.size() and not _exit_open:
		_exit_open = true
		if exit_door != null:
			exit_door.set_locked(false)
		if NetworkManager.is_networked():
			rpc("_exit_opened_rpc")
		_show_message("Semua tugas selesai! Kabur berdua lewat Lobby!")


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
	_show_message("Semua tugas selesai! Kabur berdua lewat Lobby!")


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
	# Transisi selesai level sedang berjalan: jangan hitung progres
	# keluar lagi, tapi majukan walkout-nya.
	if _exiting:
		_tick_exit_walkout(delta)
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
		_start_exit_walkout()


# Transisi selesai level: begitu semua pemain berkumpul di pintu
# keluar, input dikunci dan tiap pemain otomatis berjalan keluar
# melewati pintu (bukan langsung loncat ke layar hasil). Musuh tidak
# bisa menangkap selama walkout (iframes). Host yang memutuskan kapan
# walkout selesai (semua pemain sampai di titik keluar / timeout),
# lalu _finish_level(true) menampilkan layar hasil.
func _start_exit_walkout() -> void:
	if _exiting or exit_door == null:
		return
	_exiting = true
	_exit_walkout_timer = 0.0
	_exit_target = exit_door.global_position + EXIT_WALKOUT_OFFSET
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		if p.is_downed:
			continue
		# Kebal selama jalan keluar, dan jalan otomatis ke titik keluar.
		p.grant_iframes(EXIT_WALKOUT_TIME + 1.0)
		if pid == NetworkManager.local_peer_id():
			p.auto_walk_target = _exit_target
	if NetworkManager.is_networked():
		rpc("_exit_walkout_rpc", _exit_target)
	_show_message("KABUR!")


@rpc("authority", "call_remote", "reliable")
func _exit_walkout_rpc(exit_target: Vector2) -> void:
	if _exiting:
		return
	_exiting = true
	_exit_walkout_timer = 0.0
	_exit_target = exit_target
	var p: Node = get_local_player()
	if p != null and not p.is_downed:
		p.auto_walk_target = _exit_target
	_show_message("KABUR!")


func _tick_exit_walkout(delta: float) -> void:
	_exit_walkout_timer += delta
	# Selesai kalau semua pemain yang hidup sudah sampai di titik
	# keluar, atau kalau waktunya habis (pengaman kalau ada yang
	# nyangkut di tembok / jalurnya buntu).
	var arrived: bool = true
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		if p.is_downed:
			continue
		if p.global_position.distance_to(_exit_target) > 20.0:
			arrived = false
			break
	if arrived or _exit_walkout_timer >= EXIT_WALKOUT_TIME:
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
	SfxManager.play_shared(&"door")
	if NetworkManager.is_networked():
		rpc("_door_opened_rpc", door_id)
	_show_message("Pintu %s terbuka!" % door_id)


func _apply_door_open(door_id: String) -> void:
	var d: Node = _doors[door_id]
	d.open_door()
	# Kunci pintu ini sudah terpakai: tandai supaya tidak muncul lagi
	# di _update_vision dan tidak bisa diambil ulang. Dijalankan di host
	# (via _open_door), di klien (via _door_opened_rpc), dan saat load
	# state untuk pintu yang sudah terbuka.
	_key_carriers[door_id] = KEY_CONSUMED
	var kitem: Node = _key_item_node(door_id)
	if kitem != null:
		kitem.hide_item()
	if _pathfinder != null:
		for cell: Vector2i in _door_cells(d):
			_pathfinder.set_door_blocked(cell, false)


@rpc("authority", "call_remote", "reliable")
func _door_opened_rpc(door_id: String) -> void:
	if _doors.has(door_id):
		_apply_door_open(door_id)


func on_player_caught(peer_id: int) -> void:
	if not NetworkManager.is_server_authority() or _level_ended:
		return
	var p: Node = _players.get(peer_id)
	if p == null or p.is_downed:
		return
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
	_show_message("P%d tertangkap! Cari Item Bangkit lalu selamatkan dia!" % p.player_index)
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
		_show_message("P%d tertangkap! Cari Item Bangkit lalu selamatkan dia!" % p.player_index)


func _revive_player(peer_id: int) -> void:
	var p: Node = _players.get(peer_id)
	if p == null:
		return
	var pos: Vector2 = cage.global_position if cage != null else p.global_position
	# Dulu: selalu digeser 20 px ke kanan -> kalau tertangkap di samping
	# tembok/furnitur, pemain bangkit DI DALAM tembok dan nyangkut.
	# Sekarang dicek dulu; kalau tidak muat, cari lantai kosong terdekat.
	var tujuan: Vector2 = pos + Vector2(20, 0)
	if not bebas_tabrakan(tujuan):
		tujuan = posisi_aman(pos)
	p.global_position = tujuan
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
	_show_message("P%d bebas dari kurungan!" % p.player_index)


@rpc("authority", "call_remote", "reliable")
func _player_revived_rpc(peer_id: int, pos: Vector2) -> void:
	var p: Node = _players.get(peer_id)
	if p != null:
		p.global_position = pos
		p.velocity = Vector2.ZERO
		_show_message("P%d bebas dari kurungan!" % p.player_index)
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
	_show_message("Listrik padam sesaat  sosok itu berpindah tempat")


# ---------------------------------------------------------------- ending ---
func _finish_level(success: bool) -> void:
	if _level_ended:
		return
	_level_ended = true
	var stars: int = 0
	var ending: String = "GAGAL"
	if success:
		ending = "Happy Ending" if _deaths_total == 0 else "Bad Ending"
		if _level_time <= PAR_TIME and _deaths_total == 0:
			stars = 3
		elif _level_time <= PAR_TIME * 1.5 or _deaths_total <= 1:
			stars = 2
		else:
			stars = 1
	# Level 2 terbuka saat Level 1 PERTAMA KALI tamat di PC host. Dicek
	# sebelum progres dicatat; hasilnya ikut dikirim ke teman supaya cap
	# "LEVEL 2 TERBUKA" di panel hasil sama di kedua PC.
	var level_baru: String = "level_2" if (success and not GameProgress.sudah_tamat(LEVEL_ID)) else ""
	_apply_finished(success, stars, ending, level_baru)
	if NetworkManager.is_networked():
		rpc("_level_finished_rpc", success, stars, ending, _level_time, _deaths_total, level_baru)


@rpc("authority", "call_remote", "reliable")
func _level_finished_rpc(success: bool, stars: int, ending: String, time_sec: float, deaths: int, level_baru: String) -> void:
	_level_time = time_sec
	_deaths_total = deaths
	_level_ended = true
	_apply_finished(success, stars, ending, level_baru)


func _apply_finished(success: bool, stars: int, ending: String, level_baru: String = "") -> void:
	if minigame_layer != null:
		minigame_layer.force_close()
	GameProgress.record_level_result(LEVEL_ID, stars, _level_time, ending, success)
	if hud != null:
		hud.show_result(success, stars, ending, _level_time, _deaths_total, _completed_count(), _tasks.size(), level_baru)


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


## Tombol PILIH LEVEL di panel hasil (host / solo tes). Teman ikut dibawa
## ke layar Menunggu host oleh AlurLevel; koneksi tidak diputus.
func request_pilih_level() -> void:
	if NetworkManager.mode == NetworkManager.Mode.CLIENT:
		return
	AlurLevel.kembali_ke_pilih_level()


func request_menu() -> void:
	_go_to_menu()


func _go_to_menu() -> void:
	# Putus koneksi lalu ke main menu. _pesan_menu (kalau ada) ditampilkan
	# sekali di main menu, misalnya "Host terputus dari game."
	AlurLevel.ke_menu_utama(_pesan_menu)


# ---------------------------------------------------------------- visuals ---
func _process(delta: float) -> void:
	# Klien mengulang request_sync sampai state penuh pertama tiba
	# (host bisa saja masih menonton cerita saat request pertama dikirim).
	if NetworkManager.mode == NetworkManager.Mode.CLIENT and not _sync_received:
		_sync_retry -= delta
		if _sync_retry <= 0.0:
			_sync_retry = 1.0
			rpc_id(1, "request_sync_rpc")
	_flicker_time += delta
	if _blackout_timer > 0.0:
		_blackout_timer -= delta
	if canvas_modulate != null:
		var target: Color = BLACKOUT_MODULATE if _blackout_timer > 0.0 else BASE_MODULATE
		canvas_modulate.color = canvas_modulate.color.lerp(target, minf(1.0, delta * 6.0))
	var blackout_mult: float = 0.15 if _blackout_timer > 0.0 else 1.0
	for i: int in range(_lights.size()):
		var flicker: float = 0.88 + 0.12 * sin(_flicker_time * 7.0 + _light_phase[i])
		if randf() < 0.003:
			flicker *= 0.35
		_lights[i].energy = _light_base[i] * flicker * blackout_mult
	# Visual tempat sembunyi = turunan dari posisi pemain yang sembunyi.
	for s: Node2D in _spots:
		var occ: bool = false
		for pid: int in _players.keys():
			var p: Node = _players[pid]
			if p.is_hidden and p.global_position.distance_to(s.global_position) <= HIDE_RANGE:
				occ = true
				break
		s.set_occupied(occ)
	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = 0.12
		_update_vision()
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
	hud.update_timer(_level_time)
	hud.update_tasks(_completed_count(), _tasks.size(), _exit_open)
	var status_lines: Array[String] = []
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var st: String = "TERKURUNG" if p.is_downed else ("SEMBUNYI" if p.is_hidden else "AKTIF")
		status_lines.append("P%d: %s%s" % [p.player_index, st, " [+ITEM]" if p.carrying_revive else ""])
	hud.update_status(status_lines)
	hud.show_prompt(_compute_prompt())
	var local_p: Node = _players.get(NetworkManager.local_peer_id())
	if local_p != null:
		hud.set_stamina(local_p.get_stamina_ratio())
		# Peta hanya tersedia saat pemain lokal di ruang Gudang, level
		# jalan, dan tidak ada minigame terbuka; pemain yang terkurung
		# atau sembunyi tidak bisa membuka peta. Peta yang sedang
		# terbuka langsung ditutup begitu syaratnya tidak terpenuhi.
		var map_ok: bool = _is_local_in_gudang() and is_level_running() and not is_minigame_open() and not local_p.is_downed and not local_p.is_hidden
		hud.set_map_available(map_ok)
		if hud.is_map_open() and not map_ok:
			hud.close_map()


func _compute_prompt() -> String:
	var local_p: Node = _players.get(NetworkManager.local_peer_id())
	if local_p == null or local_p.is_downed or _level_ended:
		return ""
	if local_p.is_hidden:
		return "[E] Keluar dari persembunyian"
	if _cage_peer != -1 and _revive_carrier == NetworkManager.local_peer_id() and cage != null and local_p.global_position.distance_to(cage.global_position) <= CAGE_RANGE:
		return "[Tahan E] Selamatkan teman dari kurungan"
	if _revive_visible and revive_item != null and local_p.global_position.distance_to(revive_item.global_position) <= REVIVE_RANGE:
		return "[E] Ambil Item Bangkit"
	for kid: String in _key_carriers.keys():
		var kitem: Node = _key_item_node(kid)
		if kitem != null and int(_key_carriers.get(kid, -1)) == -1 and local_p.global_position.distance_to(kitem.global_position) <= KEY_RANGE:
			return "[E] Ambil Kunci " + kid
	var door: Node = _nearest_door(local_p.global_position)
	if door != null and not door.is_open:
		if _key_carriers.get(door.door_id, -1) == NetworkManager.local_peer_id():
			return "[E] Buka Pintu " + door.door_id
		return "Pintu " + door.door_id + " terkunci, cari Kunci " + door.door_id
	var tid: StringName = _nearest_task(local_p.global_position)
	if tid != StringName(""):
		var t: Dictionary = _tasks[tid]
		if t["requires_two"] and _server_needed() > 1:
			return "[E] %s  BUTUH 2 PEMAIN!" % t["node"].title
		return "[E] Kerjakan: %s" % t["node"].title
	var trap: Node = _nearest_trap(local_p.global_position, TRAP_USE_RANGE)
	if trap != null and _can_see(trap.global_position):
		return "[E] Aktifkan Perangkap"
	if _nearest_spot(local_p.global_position) != null:
		return "[E] Sembunyi"
	if _exit_open and exit_door != null and local_p.global_position.distance_to(exit_door.global_position) <= EXIT_RADIUS + 40.0:
		return "Berdiri berdua di pintu keluar untuk kabur!"
	if _is_local_in_gudang():
		return "[M] Lihat Peta Kantor"
	return ""


func _show_message(text: String) -> void:
	if hud != null:
		hud.show_message(text)


# ============================================ info untuk HUD (gaya Level 2)
# Dibaca scripts/hud_kantor.gd (ID card, papan tugas, busur Item Bangkit).
func get_level_time() -> float:
	return _level_time


func get_exit_open() -> bool:
	return _exit_open


## Nama ruangan untuk posisi ini: kotak MAP_ROOMS yang berisi titiknya.
## Di luar kotak (lorong): label ruangan terdekat di scene (mis. "Lorong
## Timur"); kalau yang terdekat itu ruangan, jadi "Lorong dekat <ruangan>".
func _nama_ruang_di(pos: Vector2) -> String:
	var sel := Vector2i((pos / 32.0).floor())
	var nama_ruang: Array[String] = []
	for r: Dictionary in MAP_ROOMS:
		nama_ruang.append(str(r["name"]))
		if (r["rect"] as Rect2i).has_point(sel):
			return str(r["name"])
	var terdekat: String = ""
	var jarak_terdekat: float = INF
	var labels: Node = get_node_or_null("Labels")
	if labels != null:
		for l: Node in labels.get_children():
			if l is Label:
				var lab := l as Label
				var d: float = (lab.global_position + lab.size * 0.5).distance_to(pos)
				if d < jarak_terdekat:
					jarak_terdekat = d
					terdekat = lab.text
	if terdekat == "":
		return "Lorong"
	if terdekat in nama_ruang:
		return "Lorong dekat " + terdekat
	return terdekat


func get_info_tugas() -> Array:
	# Urutan sama dengan urutan node di Tasks.
	var daftar: Array = []
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		var st: String = "belum"
		if bool(t["completed"]):
			st = "beres"
		elif float(t["progress"]) > 0.001:
			st = "jalan"
		daftar.append({
			"id": String(tid),
			"nama": str(t["node"].title),
			"ruang": str(t.get("ruang", "")),
			"status": st,
			"progres": float(t["progress"]),
			"berdua": bool(t["requires_two"]) and _server_needed() > 1,
		})
	return daftar


func get_info_pemain() -> Array:
	# Untuk ID card: urut P1, P2.
	var daftar: Array = []
	for pid: int in _players.keys():
		var p: Node = _players[pid]
		var st: String = "aktif"
		if p.is_downed:
			st = "kurung"
		elif p.is_hidden:
			st = "sembunyi"
		var kunci: String = ""
		for kid: String in _key_carriers.keys():
			if int(_key_carriers[kid]) == pid:
				kunci = kid if kunci == "" else kunci + "," + kid
		daftar.append({"nomor": int(p.player_index), "nama": "P%d" % p.player_index, "status": st,
			"kunci": kunci, "item": bool(p.carrying_revive), "aman": is_pemain_aman(pid)})
	daftar.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["nomor"]) < int(b["nomor"]))
	return daftar


## Berdua = aman (versi sebagian): true kalau pemain ini dan temannya
## sama-sama berdiri di alat tugas 2 pemain yang belum beres (Server, LAN,
## Backup, Rapat). Dibaca enemy.gd (host) dan HUD (klip "BERDUA").
## Mode solo / pemain sendirian = tidak pernah aman.
func is_pemain_aman(peer_id: int) -> bool:
	if _players.size() < 2 or not _players.has(peer_id):
		return false
	var p: Node = _players[peer_id]
	if p.is_downed or p.is_hidden:
		return false
	for tid: StringName in _tasks.keys():
		var t: Dictionary = _tasks[tid]
		if not bool(t["requires_two"]) or bool(t["completed"]):
			continue
		var pos: Vector2 = (t["node"] as Node2D).global_position
		var semua_di_sini: bool = true
		for pid: int in _players.keys():
			var q: Node = _players[pid]
			if q.is_downed or q.is_hidden or (q as Node2D).global_position.distance_to(pos) > JARAK_TUGAS_BERDUA:
				semua_di_sini = false
				break
		if semua_di_sini:
			return true
	return false


## Untuk HUD (busur hijau): ke mana penanda Item Bangkit menunjuk bagi pemain
## di PC ini. Teman dikurung & item belum diambil -> ke item; item sedang
## dibawa pemain ini -> ke kurungan. Selain itu {"ada": false}.
func get_tujuan_bangkit() -> Dictionary:
	var pid: int = NetworkManager.local_peer_id()
	var p: Node2D = get_local_player() as Node2D
	if p == null or p.is_downed or _level_ended or _cage_peer == -1 or _cage_peer == pid:
		return {"ada": false}
	if _revive_carrier == pid and cage != null:
		return {"ada": true, "pos": cage.global_position, "jenis": "kurungan"}
	if _revive_visible and revive_item != null:
		return {"ada": true, "pos": revive_item.global_position, "jenis": "item"}
	return {"ada": false}


# ------------------------------------------------- posisi aman (anti nyangkut)
## true kalau badan pemain (bentuk collision di player.tscn) muat di posisi
## ini tanpa menyentuh tembok / furnitur (collision layer 1). Musuh dan
## pemain lain diabaikan. skala < 1 = cek bentuk yang diperkecil (dipakai
## pengaman nyangkut, supaya menempel tembok biasa tidak dihitung).
func bebas_tabrakan(pos: Vector2, skala: float = 1.0) -> bool:
	var bentuk: Shape2D = null
	var geser := Transform2D.IDENTITY
	for pid: int in _players.keys():
		var cs := (_players[pid] as Node).get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs != null and cs.shape != null:
			bentuk = cs.shape
			geser = cs.transform
			break
	if bentuk == null:
		var bulat := CircleShape2D.new()
		bulat.radius = 6.0
		bentuk = bulat
		geser = Transform2D(0.0, Vector2(0, 3))
	if not is_equal_approx(skala, 1.0):
		bentuk = bentuk.duplicate()
		if bentuk is CapsuleShape2D:
			var kapsul := bentuk as CapsuleShape2D
			kapsul.radius *= skala
			kapsul.height *= skala
		elif bentuk is CircleShape2D:
			var bulat2 := bentuk as CircleShape2D
			bulat2.radius *= skala
		elif bentuk is RectangleShape2D:
			var kotak := bentuk as RectangleShape2D
			kotak.size *= skala
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = bentuk
	q.transform = Transform2D(geser.get_rotation(), pos + geser.origin)
	q.collision_mask = 1
	q.collide_with_areas = false
	var hasil: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(q, 8)
	for h: Dictionary in hasil:
		var c: Object = h.get("collider")
		if c is Node and ((c as Node).is_in_group("Enemy") or (c as Node).is_in_group("Player")):
			continue
		return false
	return true


## Posisi aman terdekat: pos itu sendiri kalau muat, kalau tidak tengah
## sel lantai terdekat (±5 sel) yang muat.
func posisi_aman(pos: Vector2) -> Vector2:
	if bebas_tabrakan(pos):
		return pos
	if _pathfinder == null:
		return pos
	var sel: Vector2i = _pathfinder.world_to_cell(pos)
	var terbaik: Vector2 = pos
	var jarak_terbaik: float = INF
	for dy: int in range(-5, 6):
		for dx: int in range(-5, 6):
			var c: Vector2i = sel + Vector2i(dx, dy)
			if _pathfinder.is_cell_blocked(c):
				continue
			var titik: Vector2 = _pathfinder.cell_to_world(c)
			var d: float = titik.distance_squared_to(pos)
			if d < jarak_terbaik and bebas_tabrakan(titik):
				jarak_terbaik = d
				terbaik = titik
	return terbaik
