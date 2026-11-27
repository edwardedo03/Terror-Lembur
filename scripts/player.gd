extends CharacterBody2D
## Player top-down (keyboard). Satu instance per peer, otoritas = peer pemilik.
##
## Otoritas lokal membaca input & bergerak; posisi/state dikirim ke peer lain
## via RPC unreliable 20 Hz, peer lain melakukan lerp. State gameplay
## (sembunyi/terkurung/bawa item) dimiliki host dan disebar via RPC reliable.
## Grup: "Player".

const WALK_SPEED: float = 150.0
const SPRINT_SPEED: float = 210.0
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN: float = 25.0   # habis per detik saat lari
const STAMINA_REGEN: float = 18.0   # terisi per detik saat tidak lari
const STAMINA_REGEN_DELAY: float = 0.8  # jeda sebelum stamina mulai terisi lagi
const STAMINA_MIN_TO_SPRINT: float = 25.0  # stamina minimal untuk bisa lari lagi setelah habis
const SYNC_INTERVAL: float = 0.05

@export var player_index: int = 1

var peer_id: int = 1
var is_hidden: bool = false
var is_downed: bool = false
var carrying_revive: bool = false
var is_sprinting: bool = false
var iframes_left: float = 0.0
var auto_walk_target: Vector2 = Vector2.INF  # jalan otomatis (transisi selesai level); INF = tidak aktif
var interact_held: bool = false
var minigame_open: bool = false
var stamina: float = STAMINA_MAX
var _sprint_locked: bool = false
var _regen_delay: float = 0.0

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


func _ready() -> void:
	add_to_group("Player")
	peer_id = get_multiplayer_authority()
	if player_index == 2:
		_base_tint = Color(0.65, 0.8, 1.0)
		name_label.text = "P2"
	else:
		name_label.text = "P1"
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var is_local: bool = is_multiplayer_authority()
	camera.enabled = is_local
	if is_local:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = 64 * 32
		camera.limit_bottom = 40 * 32
		camera.make_current()
	_target_pos = global_position


func _physics_process(delta: float) -> void:
	if iframes_left > 0.0:
		iframes_left = maxf(0.0, iframes_left - delta)
	if not is_multiplayer_authority():
		return
	# Jalan otomatis keluar (transisi selesai level): abaikan input dan
	# jalan ke target dengan kecepatan jalan biasa. Dipakai saat semua
	# pemain sudah di pintu keluar; level yang mengatur targetnya.
	if auto_walk_target != Vector2.INF and not is_downed and not is_hidden:
		var to_target: Vector2 = auto_walk_target - global_position
		if to_target.length() <= 10.0:
			velocity = Vector2.ZERO
			auto_walk_target = Vector2.INF
		else:
			velocity = to_target.normalized() * WALK_SPEED
		move_and_slide()
		_sync_tick(delta)
		return
	var level: Node = get_tree().get_first_node_in_group("LevelManager")
	var level_running: bool = level == null or level.is_level_running()
	# Interact: tekan/lepas diteruskan ke Level (host yang memutuskan efeknya).
	if Input.is_action_just_pressed("interact"):
		interact_held = true
		if level != null:
			level.notify_interact_pressed(peer_id)
	if Input.is_action_just_released("interact"):
		interact_held = false
		if level != null:
			level.notify_interact_released(peer_id)
	if is_downed or is_hidden or minigame_open or not level_running:
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_tick(delta)
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	 # Stamina: lari menguras, diam/jalan mengisi lagi (setelah jeda singkat).
	var want_sprint: bool = Input.is_action_pressed("sprint") and dir.length() > 0.1
	if want_sprint and not _sprint_locked:
		is_sprinting = true
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		_regen_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			_sprint_locked = true
	else:
		is_sprinting = false
		if _regen_delay > 0.0:
			_regen_delay -= delta
		elif stamina < STAMINA_MAX:
			stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
			if _sprint_locked and stamina >= STAMINA_MIN_TO_SPRINT:
				_sprint_locked = false
	var speed: float = SPRINT_SPEED if is_sprinting else WALK_SPEED
	velocity = dir.normalized() * speed if dir.length() > 0.1 else Vector2.ZERO
	move_and_slide()
	_sync_tick(delta)


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

func get_stamina_ratio() -> float:
	return clampf(stamina / STAMINA_MAX, 0.0, 1.0)

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
	_target_pos = pos
	_has_target = true
	velocity = vel
	is_hidden = hidden
	is_downed = downed
	carrying_revive = carrying
	is_sprinting = sprinting
	if has_iframes and iframes_left <= 0.0:
		iframes_left = 0.6
	# Koreksi keras kalau meleset jauh (mis. teleport revive).
	if global_position.distance_to(pos) > 120.0:
		global_position = pos
