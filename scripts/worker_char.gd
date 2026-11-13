extends CharacterBody2D

const SPEED := 200.0
const ACCEL := 1400.0
const FRICTION := 1600.0
const SPRINT_MULT := 1.5
const STAMINA_DRAIN := 30.0
const STAMINA_REGEN := 22.0
const SHOUT_COOLDOWN := 5.0
const SHOUT_RADIUS := 500.0

var facing := Vector2.DOWN
var bot_mode := false
var bot_time := 0.0
var locked := false
var hiding := false
var interacting := false
var interact_target := -1
var flashlight_on := true
var has_throwable := false
var shout_timer := 0.0
var hide_spot := Vector2.ZERO
var stamina := 100.0
var sprinting := false
var step_timer := 0.0
var name_label: Label

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var light: PointLight2D = $Flashlight

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	bot_mode = "--bot" in OS.get_cmdline_user_args()
	camera.enabled = is_multiplayer_authority()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	var is_ara := name.to_int() == 1
	var char_name := "ARA" if is_ara else "BIMA"
	var name_color := Color(1.0, 0.85, 0.4) if is_ara else Color(0.6, 0.85, 1.0)
	if not is_ara:
		sprite.modulate = Color(0.65, 0.85, 1.0)
	else:
		sprite.modulate = Color(1.0, 0.92, 0.7)
	name_label = Label.new()
	name_label.text = char_name
	name_label.position = Vector2(-24, -56)
	name_label.size = Vector2(48, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 5)
	add_child(name_label)
	if name.to_int() == 1:
		position = Vector2(320, 320)
	else:
		position = Vector2(960, 320)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if shout_timer > 0.0:
		shout_timer -= delta
	var input_dir := Vector2.ZERO
	if bot_mode:
		bot_time += delta
		var phase := int(bot_time / 2.0) % 4
		match phase:
			0:
				input_dir = Vector2.RIGHT
			1:
				input_dir = Vector2.DOWN
			2:
				input_dir = Vector2.LEFT
			3:
				input_dir = Vector2.UP
	else:
		input_dir = Input.get_vector("left", "right", "up", "down")
	if locked or hiding or interacting:
		input_dir = Vector2.ZERO
	sprinting = not bot_mode and Input.is_action_pressed("sprint") and input_dir.length() > 0.1 and stamina > 0.0
	var speed := SPEED * SPRINT_MULT if sprinting else SPEED
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(100.0, stamina + STAMINA_REGEN * delta)
	if input_dir.length() > 0.1:
		velocity = velocity.move_toward(input_dir.normalized() * speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	_update_actions(input_dir)

func _update_actions(input_dir: Vector2) -> void:
	if bot_mode:
		return
	if Input.is_action_just_pressed("flashlight"):
		flashlight_on = not flashlight_on
		light.enabled = flashlight_on
	if Input.is_action_just_pressed("shout") and shout_timer <= 0.0:
		shout_timer = SHOUT_COOLDOWN
		var lvl := get_parent().get_parent()
		if lvl != null:
			if lvl.has_method("play_sfx"):
				lvl.play_sfx("shout", -6.0)
			lvl.rpc_id(1, "report_noise", global_position, SHOUT_RADIUS)
	if Input.is_action_just_pressed("hide"):
		_toggle_hide()
	if Input.is_action_just_pressed("throw_item") and has_throwable:
		_throw()
	if input_dir.length() > 0.1 and hiding:
		_unhide()
	_update_interact()

func _update_interact() -> void:
	var lvl := get_parent().get_parent()
	if lvl == null or not lvl.has_method("nearest_interactable"):
		interacting = false
		interact_target = -1
		return
	if not Input.is_action_pressed("interact"):
		interacting = false
		interact_target = -1
		return
	var id: int = lvl.nearest_interactable(global_position)
	if id < 0:
		interacting = false
		interact_target = -1
		return
	interacting = true
	interact_target = id

func _toggle_hide() -> void:
	if hiding:
		_unhide()
		return
	var lvl := get_parent().get_parent()
	if lvl == null or not lvl.has_method("nearest_desk"):
		return
	var spot: Vector2 = lvl.nearest_desk(global_position)
	if spot == Vector2.INF:
		return
	hiding = true
	hide_spot = spot
	global_position = spot
	sprite.modulate.a = 0.45
	if name_label != null:
		name_label.modulate.a = 0.45

func _unhide() -> void:
	hiding = false
	sprite.modulate.a = 1.0
	if name_label != null:
		name_label.modulate.a = 1.0

func _throw() -> void:
	has_throwable = false
	var lvl := get_parent().get_parent()
	if lvl != null:
		lvl.rpc_id(1, "spawn_throwable", global_position, facing)

func _process(_delta: float) -> void:
	if velocity.length() > 10.0:
		if absf(velocity.x) > absf(velocity.y):
			facing = Vector2.RIGHT if velocity.x > 0.0 else Vector2.LEFT
		else:
			facing = Vector2.DOWN if velocity.y > 0.0 else Vector2.UP
		sprite.play("walk_" + _dir_name(facing))
		if is_multiplayer_authority() and not bot_mode:
			step_timer -= _delta
			if step_timer <= 0.0:
				step_timer = 0.24 if sprinting else 0.34
				var lvl2 := get_parent().get_parent()
				if lvl2 != null and lvl2.has_method("play_sfx"):
					lvl2.play_sfx("step", -16.0, randf_range(0.92, 1.08))
	else:
		sprite.play("idle_" + _dir_name(facing))
	light.position = facing * 24.0

func _dir_name(dir: Vector2) -> String:
	if dir == Vector2.RIGHT:
		return "right"
	if dir == Vector2.LEFT:
		return "left"
	if dir == Vector2.UP:
		return "up"
	return "down"

@rpc("any_peer", "call_local")
func set_locked(value: bool) -> void:
	locked = value
	if value:
		velocity = Vector2.ZERO
		interacting = false
		hiding = false
		sprite.modulate.a = 1.0
		if name_label != null:
			name_label.modulate.a = 1.0

@rpc("any_peer", "call_local")
func give_throwable() -> void:
	has_throwable = true
	var lvl := get_parent().get_parent()
	if lvl != null and lvl.has_method("play_sfx"):
		lvl.play_sfx("pickup", -6.0)
