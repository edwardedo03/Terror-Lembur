extends CharacterBody2D
## SATPAM LEVEL 2 (salinan scripts/enemy.gd; file aslinya tidak diubah).
## Sementara AI-nya masih sama dengan musuh Level 1. Bedanya: warna sprite
## asli (tanpa tint ungu). AI Satpam baru (Tahap 2) nanti dibuat di file ini,
## jadi musuh Level 1 tidak ikut berubah.
## Tambahan Level 2: pemain yang sedang BERDUA (<= 2,5 tile, atau sama-sama
## di alat tugas berdua) tidak bisa ditangkap. Satpam juga tidak berani
## mendekati mereka: kalau sudah dekat, ia berhenti mengejar dan kembali
## patroli ke titik yang menjauh dari mereka (lihat level_2.gd is_pemain_aman).
##
## Enemy "Sosok Lembur" — stalker yang patrol, mengejar, lalu blink.
##
## Hanya host yang menjalankan AI. Client menerima posisi/state via RPC
## unreliable dan melakukan lerp. State:
## PATROL (ikuti loop waypoint) -> CHASE (A* ke pemain) -> SEARCH
## (cek posisi terakhir) -> PATROL. BLINK: hilang sesaat (lampu padam),
## teleport ke spawn acak yang jauh, lalu BLIND 2.5 dtk (tidak bisa
## mendeteksi) supaya pemain yang berhadapan masih sempat kabur.

enum State { PATROL, CHASE, SEARCH, BLIND, VANISH, STUNNED }

const SIGHT_RANGE: float = 430.0
const HEAR_RANGE: float = 330.0
const CATCH_RANGE: float = 27.0
const SUSPICION_TIME: float = 0.8
const LOSE_SIGHT_TIME: float = 4.0
const PATROL_SPEED: float = 95.0
const CHASE_SPEED: float = 205.0
const SEARCH_SPEED: float = 130.0
const BLIND_SPEED: float = 55.0
const BLINK_MIN: float = 16.0
const BLINK_MAX: float = 26.0
const BLIND_TIME: float = 2.5
const SYNC_INTERVAL: float = 0.05
const JARAK_LANGSUNG: float = 80.0  # ±2,5 tile: kalau target sedekat ini & terlihat, kejar lurus (bukan lewat grid)
const JARAK_SEGAN: float = 150.0  # ±4,7 tile: dari jarak ini Satpam berbalik menjauhi pemain yang berdua

var state: int = State.PATROL
var pathfinder: GridPathfinder = null
var patrol_points: Array[Vector2] = []
var spawn_points: Array[Vector2] = []

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _patrol_index: int = 0
var _repath_timer: float = 0.0
var _perception_timer: float = 0.0
var _suspicion: float = 0.0
var _target: Node2D = null
var _last_known: Vector2 = Vector2.ZERO
var _lose_timer: float = 0.0
var _search_timer: float = 0.0
var _blink_timer: float = 20.0
var _blind_timer: float = 0.0
var _stun_timer: float = 0.0
var _vanish_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _sync_timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _bob_time: float = 0.0
var _last_anim_pos: Vector2 = Vector2.ZERO
var _facing: String = "down"
var _base_tint: Color = Color.WHITE  # sprite Manager tampil apa adanya
var _segan_timer: float = 0.0
var _jeda_langsung: float = 0.0  # >0 = sementara kejar lewat grid saja (habis nyangkut di sudut)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_label: Label = $StateLabel
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	add_to_group("Enemy")
	_target_pos = global_position
	_last_pos = global_position
	_blink_timer = randf_range(BLINK_MIN, BLINK_MAX)


func _physics_process(delta: float) -> void:
	if not _is_ai_owner():
		return
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	if level == null or not level.is_level_running():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = 0.15
		_update_perception(0.15)
	# Director: blink berkala saat tidak mengejar.
	_blink_timer -= delta
	if _blink_timer <= 0.0 and (state == State.PATROL or state == State.SEARCH):
		_start_blink()

	match state:
		State.PATROL:
			_patrol_tick(delta)
		State.CHASE:
			_chase_tick(delta)
		State.SEARCH:
			_search_tick(delta)
		State.BLIND:
			_blind_timer -= delta
			_follow_path(delta, BLIND_SPEED)
			if _blind_timer <= 0.0:
				_set_state(State.PATROL)
		State.VANISH:
			_vanish_timer -= delta
			velocity = Vector2.ZERO
			move_and_slide()
			if _vanish_timer <= 0.0:
				_finish_blink()
		State.STUNNED:
			_stun_timer -= delta
			velocity = Vector2.ZERO
			move_and_slide()
			if _stun_timer <= 0.0:
				_set_state(State.PATROL)
	_check_catch()
	_check_stuck(delta)
	_sync_tick(delta)


func _process(delta: float) -> void:
	if not _is_ai_owner() and _has_target:
		global_position = global_position.lerp(_target_pos, minf(1.0, delta * 12.0))
	_bob_time += delta * (8.0 if state == State.CHASE else 3.0)
	sprite.position.y = -4.0 + sin(_bob_time) * 1.5
	_update_animation()
	match state:
		State.CHASE:
			sprite.modulate = Color(1.4, 0.7, 0.7) * _base_tint
			state_label.text = "!"
			glow.energy = 0.9
		State.BLIND:
			sprite.modulate = Color(0.5, 0.5, 0.6) * _base_tint
			state_label.text = "..."
			glow.energy = 0.25
		State.VANISH:
			sprite.modulate = Color(1, 1, 1, 0.0)
			state_label.text = ""
			glow.energy = 0.0
		_:
			sprite.modulate = _base_tint
			state_label.text = "?"
			glow.energy = 0.55
	visible = state != State.VANISH


func _update_animation() -> void:
	var moving: bool = false
	var dir_vec: Vector2 = velocity
	if _is_ai_owner():
		moving = velocity.length() > 10.0
	else:
		var d: Vector2 = global_position - _last_anim_pos
		moving = d.length() > 0.5
		dir_vec = d
	_last_anim_pos = global_position
	if state == State.VANISH or state == State.STUNNED:
		moving = false
	if moving:
		_facing = _dir_name(dir_vec)
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


func _is_ai_owner() -> bool:
	# Solo/host = AI lokal. Client hanya menampilkan.
	return NetworkManager.is_server_authority()


func _set_state(next: int) -> void:
	if state == next:
		return
	state = next
	_path = PackedVector2Array()
	_path_index = 0


func _patrol_tick(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _path.is_empty():
		_request_path(patrol_points[_patrol_index])
	_follow_path(delta, PATROL_SPEED)
	if _path_index >= _path.size() and not _path.is_empty():
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_path = PackedVector2Array()


func _chase_tick(delta: float) -> void:
	_repath_timer -= delta
	# Dari dekat: kejar lurus ke pemain. Jalur grid berhenti di tengah sel
	# lantai terdekat, padahal pemain bisa berdiri di sela-sela furnitur
	# (lebih dari jarak tangkap dari tengah sel) -> dulu tidak bisa ditangkap.
	_jeda_langsung = maxf(0.0, _jeda_langsung - delta)
	if _target != null and is_instance_valid(_target) and _jeda_langsung <= 0.0 and not _target.is_hidden:
		var ke_target: Vector2 = _target.global_position - global_position
		if ke_target.length() <= JARAK_LANGSUNG and _has_line_of_sight(_target):
			_last_known = _target.global_position
			velocity = ke_target.normalized() * CHASE_SPEED
			move_and_slide()
			return
	if _target != null and is_instance_valid(_target):
		_last_known = _target.global_position
		if _repath_timer <= 0.0:
			_repath_timer = 0.25
			_request_path(_last_known)
	_follow_path(delta, CHASE_SPEED)


func _search_tick(delta: float) -> void:
	_search_timer -= delta
	_follow_path(delta, SEARCH_SPEED)
	if _search_timer <= 0.0:
		_set_state(State.PATROL)


func _follow_path(delta: float, speed: float) -> void:
	if _path.is_empty() or _path_index >= _path.size():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var target: Vector2 = _path[_path_index]
	var to_target: Vector2 = target - global_position
	if to_target.length() < 9.0:
		_path_index += 1
		velocity = Vector2.ZERO
		move_and_slide()
		return
	velocity = to_target.normalized() * speed
	move_and_slide()


func _request_path(dest: Vector2) -> void:
	if pathfinder == null:
		return
	_path = pathfinder.find_path_world(global_position, dest)
	_path_index = 0


func _aman(p: Node) -> bool:
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	return level != null and level.has_method("is_pemain_aman") and level.is_pemain_aman(int(p.peer_id))


func _update_perception(step: float) -> void:
	_segan_timer = maxf(0.0, _segan_timer - step)
	if state == State.BLIND or state == State.VANISH or state == State.STUNNED:
		return
	var best: Node2D = null
	var best_dist: float = INF
	for p: Node in get_tree().get_nodes_in_group("Player"):
		if not (p is Node2D):
			continue
		if p.is_downed:
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if _aman(p):
			# Berdua = tidak dikejar. Kalau sudah dekat, Satpam berbalik.
			if p == _target:
				_target = null
				_suspicion = 0.0
				_lose_timer = 0.0
				if state == State.CHASE or state == State.SEARCH:
					_set_state(State.PATROL)
			if dist <= JARAK_SEGAN and _segan_timer <= 0.0:
				_segan_timer = 2.0
				_menjauh_dari(p.global_position)
			continue
		# Sembunyi = tidak terlihat sama sekali. Kalau yang sedang dikejar
		# masuk persembunyian, Satpam mencari di posisi terakhirnya saja
		# (dulu: kalau <= 42 px tetap dikejar padahal tidak bisa ditangkap,
		# jadi Satpam mondar-mandir di depan lemari tanpa akhir).
		if p.is_hidden:
			if p == _target:
				_target = null
				_suspicion = 0.0
				_lose_timer = 0.0
				if state == State.CHASE:
					_search_timer = 3.0
					_set_state(State.SEARCH)
					_request_path(_last_known)
			continue
		if dist < best_dist:
			best_dist = dist
			best = p
	if best == null:
		_decay_suspicion(step)
		return
	var seen: bool = best_dist <= SIGHT_RANGE and _has_line_of_sight(best)
	var heard: bool = best.is_sprinting and best_dist <= HEAR_RANGE
	if seen:
		_suspicion += step / SUSPICION_TIME
		_last_known = best.global_position
		_lose_timer = 0.0
	elif heard:
		_suspicion += step / (SUSPICION_TIME * 2.5)
		_last_known = best.global_position
	else:
		_decay_suspicion(step)
	if _suspicion >= 1.0 and state != State.CHASE:
		_target = best
		_set_state(State.CHASE)
		_repath_timer = 0.0
		_suspicion = 1.0
	if state == State.CHASE:
		if not seen and not heard:
			_lose_timer += step
			if _lose_timer >= LOSE_SIGHT_TIME:
				_target = null
				_suspicion = 0.0
				_search_timer = 3.0
				_set_state(State.SEARCH)
				_request_path(_last_known)
		else:
			_lose_timer = 0.0
			_target = best


func _menjauh_dari(pos: Vector2) -> void:
	# Kembali patroli ke titik patroli yang tidak searah dengan pemain dan
	# cukup jauh dari mereka (yang terdekat dari posisi Satpam sekarang).
	_set_state(State.PATROL)
	_path = PackedVector2Array()
	_path_index = 0
	if patrol_points.is_empty():
		return
	var arah_pemain: Vector2 = pos - global_position
	var terbaik: int = -1
	var jarak_terbaik: float = INF
	var terjauh: int = 0
	var jarak_terjauh: float = -1.0
	for i: int in range(patrol_points.size()):
		var pt: Vector2 = patrol_points[i]
		var dari_pemain: float = pt.distance_to(pos)
		if dari_pemain > jarak_terjauh:
			jarak_terjauh = dari_pemain
			terjauh = i
		if dari_pemain < 260.0 or (pt - global_position).dot(arah_pemain) > 0.0:
			continue
		var d: float = global_position.distance_to(pt)
		if d < jarak_terbaik:
			jarak_terbaik = d
			terbaik = i
	_patrol_index = terbaik if terbaik != -1 else terjauh


func _decay_suspicion(step: float) -> void:
	_suspicion = maxf(0.0, _suspicion - step * 0.8)
	if state == State.CHASE:
		_lose_timer += step
		if _lose_timer >= LOSE_SIGHT_TIME:
			_target = null
			_search_timer = 3.0
			_set_state(State.SEARCH)
			_request_path(_last_known)


func _has_line_of_sight(target: Node2D) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()


func _check_catch() -> void:
	if state == State.BLIND or state == State.VANISH or state == State.STUNNED:
		return
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	if level == null:
		return
	for p: Node in get_tree().get_nodes_in_group("Player"):
		if p.is_downed or p.is_hidden:
			continue
		if p.iframes_left > 0.0:
			continue
		if _aman(p):
			continue  # berdua = tidak bisa ditangkap
		if global_position.distance_to(p.global_position) <= CATCH_RANGE:
			_stun_timer = 2.0
			_set_state(State.STUNNED)
			_target = null
			_suspicion = 0.0
			level.on_player_caught(p.peer_id)
			return


func _check_stuck(delta: float) -> void:
	if velocity.length() < 5.0:
		_stuck_timer = 0.0
		_last_pos = global_position
		return
	if global_position.distance_to(_last_pos) < 3.0:
		_stuck_timer += delta
		if _stuck_timer > 1.0:
			_stuck_timer = 0.0
			if state == State.PATROL and not patrol_points.is_empty():
				_patrol_index = (_patrol_index + 1) % patrol_points.size()
			if state == State.CHASE:
				# Nyangkut di sudut furnitur saat kejar lurus -> 1 detik
				# lewat jalur grid dulu supaya bisa memutar.
				_jeda_langsung = 1.0
				_repath_timer = 0.0
			_path = PackedVector2Array()
	else:
		_stuck_timer = 0.0
		_last_pos = global_position


func _start_blink() -> void:
	_blink_timer = randf_range(BLINK_MIN, BLINK_MAX)
	_set_state(State.VANISH)
	_vanish_timer = 0.6
	velocity = Vector2.ZERO
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	if level != null:
		level.trigger_blackout_pulse()
	_sync_now()


func _finish_blink() -> void:
	var dest: Vector2 = _pick_blink_destination()
	global_position = dest
	velocity = Vector2.ZERO
	_blind_timer = BLIND_TIME
	_set_state(State.BLIND)
	_suspicion = 0.0
	_target = null
	if not patrol_points.is_empty():
		_request_path(_nearest_patrol_point())
	_sync_now()


func _pick_blink_destination() -> Vector2:
	if spawn_points.is_empty():
		return global_position
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")
	var candidates: Array[Vector2] = []
	for sp: Vector2 in spawn_points:
		var nearest: float = INF
		for p: Node in players:
			if p is Node2D and not p.is_downed:
				nearest = minf(nearest, sp.distance_to(p.global_position))
		if nearest >= 350.0 and nearest <= 950.0:
			candidates.append(sp)
	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]
	# Fallback: spawn terjauh dari pemain terdekat.
	var best: Vector2 = spawn_points[0]
	var best_score: float = -1.0
	for sp: Vector2 in spawn_points:
		var nearest: float = INF
		for p: Node in players:
			if p is Node2D and not p.is_downed:
				nearest = minf(nearest, sp.distance_to(p.global_position))
		if nearest > best_score:
			best_score = nearest
			best = sp
	return best


func _nearest_patrol_point() -> Vector2:
	var best: Vector2 = patrol_points[0]
	var best_dist: float = INF
	for pt: Vector2 in patrol_points:
		var d: float = global_position.distance_to(pt)
		if d < best_dist:
			best_dist = d
			best = pt
	return best


func _sync_tick(delta: float) -> void:
	if not NetworkManager.is_networked():
		return
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		_sync_now()


func _sync_now() -> void:
	if NetworkManager.is_networked():
		rpc("_sync_enemy", global_position, state)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_enemy(pos: Vector2, new_state: int) -> void:
	_target_pos = pos
	_has_target = true
	state = new_state
	if global_position.distance_to(pos) > 140.0:
		global_position = pos
