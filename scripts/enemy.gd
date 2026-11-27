extends CharacterBody2D
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
const PATROL_SPEED: float = 120.0
const CHASE_SPEED: float = 200.0
const SEARCH_SPEED: float = 140.0
const BLIND_SPEED: float = 55.0
const BLINK_MIN: float = 16.0
const BLINK_MAX: float = 26.0
const BLIND_TIME: float = 2.5
const SYNC_INTERVAL: float = 0.05

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
var _lure_active: bool = false
var _lose_timer: float = 0.0
var _search_timer: float = 0.0
var _blink_timer: float = 20.0
var _blind_timer: float = 0.0
var _stun_timer: float = 0.0
var _vanish_timer: float = 0.0
var _last_target_dist: float = INF
var _progress_timer: float = 0.0
var _last_blink_dest: Vector2 = Vector2(-9999, -9999)
var _sync_timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _bob_time: float = 0.0
var _last_anim_pos: Vector2 = Vector2.ZERO
var _facing: String = "down"
var _base_tint: Color = Color(0.45, 0.42, 0.55)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_label: Label = $StateLabel
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	add_to_group("Enemy")
	_target_pos = global_position
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
	# Director: blink berkala saat tidak mengejar. Timer dijeda selama
	# lure — musuh harus sampai di trap dulu sebelum bisa teleport lagi.
	if not _lure_active:
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
	if next != State.CHASE:
		_lure_active = false
	state = next
	_path = PackedVector2Array()
	_path_index = 0
	# Musuh mulai mengejar: bunyi serangan (hanya di host — _set_state
	# tidak dipanggil client saat sinkronisasi, lihat _sync_enemy).
	if next == State.CHASE:
		SfxManager.play_shared(&"ghost_attack")


func investigate(pos: Vector2) -> void:
	# Dipanggil host saat perangkap terpicu: musuh "mendengar" sesuatu
	# di pos, lalu CHASE ke sana. Tanpa target pemain, begitu sampai ia
	# SEARCH sebentar lalu kembali PATROL (lihat _update_perception).
	if not _is_ai_owner():
		return
	if state == State.BLIND or state == State.VANISH or state == State.STUNNED:
		return
	_last_known = pos
	_suspicion = 1.0
	_target = null
	_lose_timer = 0.0
	_set_state(State.CHASE)
	_lure_active = true
	_request_path(pos)


func hear_noise(pos: Vector2) -> bool:
	# Dipanggil host saat ada kesalahan di minigame: suara keras
	# memanggil musuh mendekat. SENGAJA tanpa batas jarak — dulu ada
	# radius 400, tapi itu bikin noise cuma ke-trigger sekali: habis
	# ngejar pertama, musuh blink menjauh (350–950px) / patrol jauh,
	# jadi kesalahan berikutnya hampir selalu di luar 400px dan musuh
	# tidak pernah datang lagi. Sekarang kesalahan SELALU memanggil
	# musuh (kecuali musuh sedang tidak bisa merespons, lihat bawah);
	# kalau musuh jauh, dia tetap datang, cuma butuh waktu jalan ke sana.
	# Bukan lure — timer blink tetap jalan, dan musuh hanya mengejar
	# posisi suara itu.
	if not _is_ai_owner():
		return false
	if state == State.BLIND or state == State.VANISH or state == State.STUNNED:
		return false
	_last_known = pos
	_suspicion = 1.0
	_target = null
	_lose_timer = 0.0
	_set_state(State.CHASE)
	_request_path(pos)
	return true


func _pick_next_patrol_index() -> int:
	if patrol_points.size() <= 1:
		return 0
	var next: int = _patrol_index
	while next == _patrol_index:
		next = randi() % patrol_points.size()
	return next


func _patrol_tick(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _path.is_empty():
		_request_path(patrol_points[_patrol_index])
	_follow_path(delta, PATROL_SPEED)
	if _path_index >= _path.size() and not _path.is_empty():
		_patrol_index = _pick_next_patrol_index()
		_path = PackedVector2Array()


func _chase_tick(delta: float) -> void:
	_repath_timer -= delta
	if _target != null and is_instance_valid(_target):
		# Sengaja TIDAK menulis _last_known dari posisi live pemain:
		# musuh hanya boleh mengejar posisi terakhir yang TERLIHAT.
		if _repath_timer <= 0.0:
			_repath_timer = 0.25
			_request_path(_last_known)
	var speed: float = CHASE_SPEED * 1.5 if _lure_active else CHASE_SPEED
	_follow_path(delta, speed)
	if _lure_active:
		if global_position.distance_to(_last_known) < 24.0:
			# Sampai di trap: lure selesai, timer blink mulai dari awal.
			_lure_active = false
			_blink_timer = randf_range(BLINK_MIN, BLINK_MAX)
		elif _path.is_empty() or _path_index >= _path.size():
			# Tujuan tidak bisa dicapai (path buntu) ATAU sudah sampai
			# di ujung jalur — mis. trap yang sel-nya diblokir supaya
			# musuh tidak menginjaknya, jadi jalur berhenti di sel
			# sebelah trap. Lure selesai di sini (musuh mengintip dari
			# sebelah trap, bukan berdiri di atasnya).
			_lure_active = false


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
	if to_target.length() < 6.0:
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


func _update_perception(step: float) -> void:
	if state == State.BLIND or state == State.VANISH or state == State.STUNNED:
		return
	# Begitu pemain sembunyi/terkurung, musuh langsung "kehilangan" dia:
	# jangan terus mengejar tempat sembunyinya sampai lose timer habis.
	if _target != null and (not is_instance_valid(_target) or _target.is_hidden or _target.is_downed):
		_target = null
	# Periksa SEMUA pemain satu per satu — bukan cuma yang terdekat.
	# (Bug lama: "best" = pemain terdekat, tapi seen/heard cuma dihitung
	# untuk dia; kalau dia di balik tembok sementara pemain lain kelihatan,
	# musuh malah menyerah dan tidak ganti target.)
	var best: Node2D = null
	var best_dist: float = INF
	var best_seen: bool = false
	var best_heard: bool = false
	for p: Node in get_tree().get_nodes_in_group("Player"):
		if not (p is Node2D):
			continue
		if p.is_downed:
			continue
		# Sembunyi = tidak terdeteksi SAMA SEKALI. Dulu ada pengecualian
		# 42px (musuh yang sudah sangat dekat bisa "menemukan" pemain
		# yang ngumpet), tapi karena pemain ngumpet tidak bisa ditangkap
		# (_check_catch melewatkan mereka), musuh malah nungguin tempat
		# sembunyi itu selamanya: tiap 0,15 dtk dia "melihat" lagi
		# pemain ngumpet itu dan lose timer selalu di-reset. Sekarang
		# ngumpet itu aman penuh — musuh terus ngejar pemain lain atau
		# patrol, dan tidak akan camp di tempat sembunyi.
		if p.is_hidden:
			continue
		var dist: float = global_position.distance_to(p.global_position)
		var seen: bool = dist <= SIGHT_RANGE and _has_line_of_sight(p)
		var heard: bool = p.is_sprinting and dist <= HEAR_RANGE
		if not seen and not heard:
			continue
		if dist < best_dist:
			best_dist = dist
			best = p
			best_seen = seen
			best_heard = heard
	if best == null:
		_decay_suspicion(step)
		return
	if best_seen:
		_suspicion += step / SUSPICION_TIME
		_last_known = best.global_position
		_lose_timer = 0.0
	elif best_heard:
		_suspicion += step / (SUSPICION_TIME * 2.5)
		_last_known = best.global_position
	if _suspicion >= 1.0 and state != State.CHASE:
		_target = best
		_set_state(State.CHASE)
		_repath_timer = 0.0
		_suspicion = 1.0
	if state == State.CHASE:
		# Pemain terdeteksi = langsung kejar dia; target bisa BERGANTI
		# ke pemain lain yang lebih dekat dan terdeteksi.
		_lose_timer = 0.0
		_lure_active = false
		_target = best


func _decay_suspicion(step: float) -> void:
	_suspicion = maxf(0.0, _suspicion - step * 0.8)
	if state == State.CHASE and not _lure_active:
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
		if global_position.distance_to(p.global_position) <= CATCH_RANGE:
			_stun_timer = 2.0
			_set_state(State.STUNNED)
			_target = null
			_suspicion = 0.0
			level.on_player_caught(p.peer_id)
			return


func _check_stuck(delta: float) -> void:
	if _path.is_empty() or _path_index >= _path.size():
		_progress_timer = 0.0
		_last_target_dist = INF
		return
	var target_dist: float = global_position.distance_to(_path[_path_index])
	if velocity.length() > 5.0 and target_dist > _last_target_dist - 4.0:
		_progress_timer += delta
		if _progress_timer > 0.7:
			_progress_timer = 0.0
			_last_target_dist = INF
			_path = PackedVector2Array()
			if state == State.PATROL and not patrol_points.is_empty():
				_patrol_index = _pick_next_patrol_index()
			elif state == State.CHASE or state == State.SEARCH:
				# Coba rute baru ke tujuan terakhir (penting saat lure:
				# _target null, jadi tanpa repath di sini musuh diam saja).
				_request_path(_last_known)
			elif state == State.BLIND and not patrol_points.is_empty():
				_request_path(_nearest_patrol_point())
	else:
		_progress_timer = 0.0
		_last_target_dist = target_dist


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
	if pathfinder != null:
		global_position = pathfinder.snap_to_walkable(global_position)
	velocity = Vector2.ZERO
	_blind_timer = BLIND_TIME
	_set_state(State.BLIND)
	# Teleport selesai (muncul di tempat baru): bunyi pindahan.
	SfxManager.play_shared(&"ghost_tp")
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
		var pool: Array[Vector2] = []
		for sp: Vector2 in candidates:
			if sp != _last_blink_dest:
				pool.append(sp)
		if pool.is_empty():
			pool = candidates
		_last_blink_dest = pool[randi() % pool.size()]
		return _last_blink_dest
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
