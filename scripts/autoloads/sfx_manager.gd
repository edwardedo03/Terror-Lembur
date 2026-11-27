extends Node
## SfxManager (Autoload) — semua efek suara (SFX) game.
##
## Dipakai lewat tiga cara:
##   play_shared(nama)  — bunyi di SEMUA PC (host memutar lokal lalu
##                         menyiarkan lewat RPC). Untuk kejadian dunia
##                         yang didengar berdua: alarm, complete, door,
##                         ghost_attack, ghost_tp.
##   play_for(peer, nama) — bunyi HANYA di PC pemain itu (host memutar
##                         lokal kalau itu dirinya, atau mengirim RPC ke
##                         peer itu). Untuk aksi pribadi: hide, pick.
##   play_local(nama)   — bunyi hanya di PC ini, tanpa RPC. Untuk yang
##                         memang lokal: keypad_click / keypad_beep
##                         (dipanggil dari minigame keypad) dan untuk
##                         detak yang dihitung tiap PC sendiri.
##
## Tiga suara "hidup" dihitung sendiri di tiap PC dari keadaan lokal
## (tidak lewat RPC), supaya terasa posisional:
##   heartbeat — berdetak selama di level & hidup; makin cepat kalau
##     musuh mendekat dalam jarak pandang (430) atau sedang mengejar
##     pemain ini. File heartbeat berisi 5 detak; yang dipakai cuma
##     detak pertama (lub-dub 0-0,3 dtk), ritmenya diatur timer.
##   tick — menggantikan heartbeat saat pemain ini tertangkap (downed);
##     berbunyi berkala seperti jam. Begitu di-revive, kembali ke
##     heartbeat.
##   step — langkah kaki musuh; berbunyi saat musuh berlari (CHASE)
##     atau berada dekat pemain ini. Makin dekat makin keras.
##
## Volume one-shot bisa diubah di konstanta _VOL di bawah.

# --- File SFX (dipilih dari assets/sfx; lihat PANDUAN untuk alternatif) ---
const ALARM_STREAM: AudioStream = preload("res://assets/sfx/alarm/Siren_Head_Emergency_Alert_DailySounds.mp3")
const COMPLETE_STREAM: AudioStream = preload("res://assets/sfx/complete/UIMisc_Confirm Bell_GNOMO_BLHM.ogg")
const DOOR_STREAM: AudioStream = preload("res://assets/sfx/door/DOORAntq_Dungeon Door Open 01_GNOMO_HELL.ogg")
const GHOST_ATTACK_STREAM: AudioStream = preload("res://assets/sfx/ghost_attack/CREAEthr_Lofi Ghost Attack 02_OGNM_TPOS.ogg")
const GHOST_TP_STREAM: AudioStream = preload("res://assets/sfx/ghost_tp/DSGNImpt_Ghostly Impact 01_GNOMO_CCRS.ogg")
const HEARTBEAT_STREAM: AudioStream = preload("res://assets/sfx/heartbeat/Heartbeat_Thump_DailySounds.mp3")
const HIDE_STREAM: AudioStream = preload("res://assets/sfx/hide/DSGNImpt_Light Woosh 02_GNOMO_BLHM.ogg")
const KEYPAD_BEEP_STREAM: AudioStream = preload("res://assets/sfx/keypad-beep/UIBeep_Back Cancel 01_GNOMO_CCRS.ogg")
const KEYPAD_CLICK_STREAM: AudioStream = preload("res://assets/sfx/keypad-click/UIClick_Click_GNOMO_BLHM.ogg")
const PICK_STREAM: AudioStream = preload("res://assets/sfx/pick/OBJCoin_Shop Buy_GNOMO_BLHM.ogg")
const STEP_STREAM: AudioStream = preload("res://assets/sfx/step/FEETHmn_Footsteps Stone 01_OGNM_TPOS.ogg")
const TICK_STREAM: AudioStream = preload("res://assets/sfx/tick/UIClick_Click Hover 01_GNOMO_CCRS.ogg")

# --- Volume one-shot (dB; 0 = paling keras) ---
const _VOL: Dictionary = {
	&"alarm": -6.0,
	&"complete": -4.0,
	&"door": -6.0,
	&"ghost_attack": -4.0,
	&"ghost_tp": -4.0,
	&"hide": -8.0,
	&"keypad_beep": -6.0,
	&"keypad_click": -10.0,
	&"pick": -6.0,
}

# --- Heartbeat (jangan terlalu besar, kata Edward) ---
# Baseline -12 dB: cukup terdengar saat tidak ada musuh (dulu -20 dB
# sampai tidak kedengaran sama sekali). Makin dekat musuh makin keras
# (-8 dB) dan makin cepat (0,45 dtk).
const HB_SLOW_INTERVAL: float = 1.0   # musuh jauh: ~60 detak/menit
const HB_FAST_INTERVAL: float = 0.45  # musuh dekat / dikejar: ~133 detak/menit
const HB_VOL_QUIET: float = -12.0
const HB_VOL_LOUD: float = -8.0
const HB_BEAT_LEN: float = 0.3  # panjang satu detak (lub-dub) di file
const HB_DANGER_RANGE: float = 430.0  # jarak pandang musuh (SIGHT_RANGE)
const HB_DANGER_CLOSE: float = 120.0  # sedekat ini = bahaya penuh

# --- Tick (saat tertangkap) ---
const TICK_INTERVAL: float = 0.7
const TICK_VOL_DB: float = -12.0

# --- Step (langkah musuh) ---
const STEP_HEAR_RANGE: float = 350.0
const STEP_INTERVAL_CHASE: float = 0.45  # musuh berlari
const STEP_INTERVAL_NEAR: float = 0.65   # musuh dekat tapi jalan biasa
const STEP_VOL_FAR: float = -22.0
const STEP_VOL_CLOSE: float = -10.0

# --- Step pemain sendiri (langkah kaki sendiri saat berjalan/lari) ---
# Diputar lokal di tiap PC, pelan saja supaya tidak mengganggu.
const PLAYER_STEP_INTERVAL_WALK: float = 0.45
const PLAYER_STEP_INTERVAL_SPRINT: float = 0.32
const PLAYER_STEP_VOL_WALK: float = -18.0
const PLAYER_STEP_VOL_SPRINT: float = -14.0
const PLAYER_STEP_MIN_SPEED: float = 50.0  # di bawah ini dianggap diam

# State.CHASE di enemy.gd (enum State: PATROL 0, CHASE 1, SEARCH 2,
# BLIND 3, VANISH 4, STUNNED 5). Dipakai literal karena enemy.gd
# tidak punya class_name.
const ENEMY_CHASE_STATE: int = 1

const _POOL_SIZE: int = 8

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _hb_player: AudioStreamPlayer
var _hb_timer: float = 0.0
var _tick_timer: float = 0.0
var _step_timer: float = 0.0
var _player_step_timer: float = 0.0


func _ready() -> void:
	_streams = {
		&"alarm": ALARM_STREAM,
		&"complete": COMPLETE_STREAM,
		&"door": DOOR_STREAM,
		&"ghost_attack": GHOST_ATTACK_STREAM,
		&"ghost_tp": GHOST_TP_STREAM,
		&"heartbeat": HEARTBEAT_STREAM,
		&"hide": HIDE_STREAM,
		&"keypad_beep": KEYPAD_BEEP_STREAM,
		&"keypad_click": KEYPAD_CLICK_STREAM,
		&"pick": PICK_STREAM,
		&"step": STEP_STREAM,
		&"tick": TICK_STREAM,
	}
	for i: int in range(_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.volume_db = 0.0
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_hb_player = AudioStreamPlayer.new()
	_hb_player.name = "Heartbeat"
	_hb_player.volume_db = HB_VOL_QUIET
	_hb_player.bus = "Master"
	add_child(_hb_player)


func _process(delta: float) -> void:
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	if level == null or not level.is_level_running():
		return
	var p: Node = _local_player()
	var e: Node = _enemy()
	if p == null or e == null:
		return
	if bool(p.get("is_downed")):
		# Tertangkap: heartbeat berhenti, diganti bunyi tick berkala.
		# Begitu di-revive (is_downed false), heartbeat jalan lagi.
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = TICK_INTERVAL
			_play_local(&"tick", TICK_VOL_DB)
		return
	# Hidup: heartbeat, kecepatannya ikut bahaya.
	var danger: float = _danger_level(p, e)
	var interval: float = lerpf(HB_SLOW_INTERVAL, HB_FAST_INTERVAL, danger)
	_hb_timer -= delta
	if _hb_timer <= 0.0:
		_hb_timer = interval
		_play_heartbeat_beat(danger)
	# Langkah kaki musuh: saat berlari (CHASE) atau dekat pemain ini.
	_update_steps(delta, p, e)
	# Langkah kaki pemain sendiri saat berjalan/lari.
	_update_player_steps(delta, p)


## Bunyi di semua PC (host memutar lokal + menyiarkan ke peer lain).
## Dipanggil dari kode host (otoritas server). Kalau dipanggil client,
## hanya bunyi lokal (client tidak menyiarkan).
func play_shared(sfx_name: StringName) -> void:
	_play_local(sfx_name)
	if NetworkManager.is_networked() and NetworkManager.is_server_authority():
		rpc("_play_sfx_rpc", sfx_name)


## Bunyi hanya di PC pemain itu. Dipanggil dari kode host.
func play_for(peer_id: int, sfx_name: StringName) -> void:
	if peer_id == NetworkManager.local_peer_id():
		_play_local(sfx_name)
	elif NetworkManager.is_networked() and NetworkManager.is_server_authority():
		rpc_id(peer_id, "_play_sfx_rpc", sfx_name)


## Bunyi hanya di PC ini (tanpa RPC). Dipanggil dari kode lokal
## (mis. minigame keypad) dan dari dalam manager ini sendiri.
func play_local(sfx_name: StringName) -> void:
	_play_local(sfx_name)


@rpc("any_peer", "call_remote", "reliable")
func _play_sfx_rpc(sfx_name: StringName) -> void:
	_play_local(sfx_name)


func _play_local(sfx_name: StringName, volume_db: float = NAN) -> AudioStreamPlayer:
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null:
		return null
	var vol: float = volume_db
	if is_nan(vol):
		vol = float(_VOL.get(sfx_name, -6.0))
	var player: AudioStreamPlayer = _free_player()
	player.stream = stream
	player.volume_db = vol
	player.play()
	return player


func _free_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _pool[_next_player]
	_next_player = (_next_player + 1) % _POOL_SIZE
	return p


func _play_heartbeat_beat(danger: float) -> void:
	# File berisi 5 detak; yang dipakai cuma detak pertama (lub-dub).
	# Berhentikan sebelum detak kedua supaya ritmenya diatur timer,
	# bukan isi file.
	_hb_player.stream = HEARTBEAT_STREAM
	_hb_player.volume_db = lerpf(HB_VOL_QUIET, HB_VOL_LOUD, danger)
	_hb_player.play(0.0)
	get_tree().create_timer(HB_BEAT_LEN).timeout.connect(_hb_player.stop)


func _danger_level(p: Node, e: Node) -> float:
	# Dikejar musuh = bahaya penuh (detak tercepat).
	if int(e.get("state")) == ENEMY_CHASE_STATE and e.get("_target") == p:
		return 1.0
	var dist: float = p.global_position.distance_to(e.global_position)
	if dist >= HB_DANGER_RANGE:
		return 0.0
	if dist <= HB_DANGER_CLOSE:
		return 1.0
	return 1.0 - (dist - HB_DANGER_CLOSE) / (HB_DANGER_RANGE - HB_DANGER_CLOSE)


func _update_steps(delta: float, p: Node, e: Node) -> void:
	var chasing: bool = int(e.get("state")) == ENEMY_CHASE_STATE
	var dist: float = p.global_position.distance_to(e.global_position)
	if not chasing and dist > STEP_HEAR_RANGE:
		return
	var interval: float = STEP_INTERVAL_CHASE if chasing else STEP_INTERVAL_NEAR
	var closeness: float = clampf(1.0 - dist / STEP_HEAR_RANGE, 0.0, 1.0)
	var vol: float = lerpf(STEP_VOL_FAR, STEP_VOL_CLOSE, closeness)
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = interval
		_play_local(&"step", vol)


func _update_player_steps(delta: float, p: Node) -> void:
	# Langkah kaki pemain sendiri: bunyi saat bergerak (jalan/lari),
	# pelan saja. Tidak bunyi saat diam, ngumpet, atau minigame terbuka
	# (saat itu pemain memang tidak bergerak).
	if bool(p.get("is_hidden")) or bool(p.get("minigame_open")):
		return
	var speed: float = (p.get("velocity") as Vector2).length()
	if speed < PLAYER_STEP_MIN_SPEED:
		return
	var sprinting: bool = bool(p.get("is_sprinting"))
	var interval: float = PLAYER_STEP_INTERVAL_SPRINT if sprinting else PLAYER_STEP_INTERVAL_WALK
	var vol: float = PLAYER_STEP_VOL_SPRINT if sprinting else PLAYER_STEP_VOL_WALK
	_player_step_timer -= delta
	if _player_step_timer <= 0.0:
		_player_step_timer = interval
		_play_local(&"step", vol)


func _local_player() -> Node:
	for pl: Node in get_tree().get_nodes_in_group("Player"):
		if pl.is_multiplayer_authority():
			return pl
	return null


func _enemy() -> Node:
	return get_tree().get_first_node_in_group("Enemy")
