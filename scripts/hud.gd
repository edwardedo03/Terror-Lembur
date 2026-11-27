extends CanvasLayer
## HUD Level 1 — dibangun dari kode supaya mudah diubah tanpa mengotak-atik
## file .tscn. Menampilkan tugas, waktu, status pemain, prompt interaksi,
## pesan tengah layar, panel hasil (ending + penilaian), dan panel putus koneksi.
## Gaya visual: UiTheme (kantor lembur: gelap hangat, garis rambut, mono,
## satu aksen amber).

var _tasks_label: Label = null
var _timer_label: Label = null
var _status_label: Label = null
var _prompt_label: Label = null
var _message_label: Label = null
var _flash_rect: ColorRect = null
var _result_panel: CenterContainer = null
var _result_dim: ColorRect = null
var _result_title: Label = null
var _result_stats: VBoxContainer = null
var _stat_time: Label = null
var _stat_deaths: Label = null
var _stat_tasks: Label = null
var _result_star_boxes: Array[UiTheme.StarIcon] = []
var _result_star_count: Label = null
var _disconnect_panel: CenterContainer = null
var _disconnect_label: Label = null
var _message_timer: float = 0.0
var _flash_alpha: float = 0.0
var _task_total: int = 0
var _stamina_bar: ProgressBar = null
var _stamina_fill: StyleBoxFlat = null

# --- Alert musuh di tepi layar ---
# Musuh yang mendekat (masih di luar layar) memerahkan tepi layar di
# arah musuh berada, supaya pertemuan tidak tiba-tiba: pemain dapat
# peringatan + arah sebelum musuh masuk ke tampilan layar.
# ALERT_RANGE 320 px: kamera zoom 5.55 -> setengah lebar layar cuma
# ~115 px, jadi alert sudah menyala jauh sebelum musuh terlihat.
# Intensitas naik linear saat musuh mendekat, dan berdenyut saat CHASE.
const ALERT_RANGE: float = 320.0
const ALERT_MAX_ALPHA: float = 0.55
const ALERT_THICKNESS: float = 26.0
const ALERT_COLOR := Color(0.9, 0.12, 0.12)
var _alert_top: ColorRect = null
var _alert_bottom: ColorRect = null
var _alert_left: ColorRect = null
var _alert_right: ColorRect = null
var _alert_time: float = 0.0


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_stamina_bar()
	_build_prompt_and_message()
	_build_result_panel()
	_build_disconnect_panel()
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0, 0, 0, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	_build_enemy_alert()
	# Flash dan alert harus di bawah panel hasil: pindahkan panel ke depan.
	if _result_panel != null:
		move_child(_result_panel, -1)
	if _disconnect_panel != null:
		move_child(_disconnect_panel, -1)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0 and _message_label != null:
			_message_label.text = ""
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 0.8)
		_flash_rect.color = Color(0, 0, 0, _flash_alpha)
	_update_enemy_alert(delta)


func set_task_total(total: int) -> void:
	_task_total = total


func update_tasks(done: int, total: int, exit_open: bool) -> void:
	if _tasks_label == null:
		return
	var extra: String = " | PINTU TERBUKA!" if exit_open else ""
	_tasks_label.text = "Tugas: %d/%d%s" % [done, total, extra]
	_tasks_label.add_theme_color_override("font_color", UiTheme.AMBER if exit_open else UiTheme.INK)


func update_timer(time_sec: float) -> void:
	if _timer_label == null:
		return
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	_timer_label.text = "Waktu: %02d:%02d" % [m, s]


# Dipakai Level 2: jam game ("21.00") dan teks laporan sudah diformat
# oleh level, jadi HUD hanya menampilkan string-nya apa adanya.
func set_timer_text(text: String) -> void:
	if _timer_label != null:
		_timer_label.text = text


func set_tasks_text(text: String) -> void:
	if _tasks_label != null:
		_tasks_label.text = text


func update_status(lines: Array[String]) -> void:
	if _status_label == null:
		return
	_status_label.text = "\n".join(lines)


func show_prompt(text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = text

func set_stamina(ratio: float) -> void:
	if _stamina_bar == null:
		return
	_stamina_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	if _stamina_fill != null:
		_stamina_fill.bg_color = UiTheme.RED if ratio < 0.25 else UiTheme.GREEN


func _build_stamina_bar() -> void:
	var label := _mk_label("STAMINA", 12, UiTheme.MUTED, Vector2.ZERO)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_right = 80
	label.offset_top = -56
	label.offset_bottom = -36
	add_child(label)
	_stamina_fill = UiTheme.bar_fill_style(UiTheme.GREEN)
	var bg := UiTheme.bar_bg_style()
	_stamina_bar = ProgressBar.new()
	_stamina_bar.min_value = 0.0
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.show_percentage = false
	_stamina_bar.add_theme_stylebox_override("background", bg)
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	_stamina_bar.anchor_top = 1.0
	_stamina_bar.anchor_bottom = 1.0
	_stamina_bar.offset_left = 84
	_stamina_bar.offset_right = 284
	_stamina_bar.offset_top = -54
	_stamina_bar.offset_bottom = -34
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bar)

func show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_timer = 3.5


func flash_blackout() -> void:
	_flash_alpha = 0.6


func _build_enemy_alert() -> void:
	# Empat strip merah di tepi layar (atas/bawah/kiri/kanan). Strip
	# kiri/kanan dijepit di antara strip atas/bawah supaya sudut tidak
	# bertumpuk dua kali lebih gelap.
	_alert_top = _mk_alert_edge(0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, ALERT_THICKNESS)
	_alert_bottom = _mk_alert_edge(0.0, 1.0, 1.0, 1.0, 0.0, -ALERT_THICKNESS, 0.0, 0.0)
	_alert_left = _mk_alert_edge(0.0, 0.0, 0.0, 1.0, 0.0, ALERT_THICKNESS, ALERT_THICKNESS, -ALERT_THICKNESS)
	_alert_right = _mk_alert_edge(1.0, 0.0, 1.0, 1.0, -ALERT_THICKNESS, ALERT_THICKNESS, 0.0, -ALERT_THICKNESS)


func _mk_alert_edge(al: float, at: float, ar: float, ab: float, off_left: float, off_top: float, off_right: float, off_bottom: float) -> ColorRect:
	var r := ColorRect.new()
	r.anchor_left = al
	r.anchor_top = at
	r.anchor_right = ar
	r.anchor_bottom = ab
	r.offset_left = off_left
	r.offset_right = off_right
	r.offset_top = off_top
	r.offset_bottom = off_bottom
	r.color = Color(ALERT_COLOR.r, ALERT_COLOR.g, ALERT_COLOR.b, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _update_enemy_alert(delta: float) -> void:
	_alert_time += delta
	var a_top: float = 0.0
	var a_bottom: float = 0.0
	var a_left: float = 0.0
	var a_right: float = 0.0
	var lv: Node = _level()
	var running: bool = lv != null and lv.has_method("is_level_running") and bool(lv.is_level_running())
	var enemy: Node = get_tree().get_first_node_in_group("Enemy")
	var p: Node = null
	if lv != null and lv.has_method("get_local_player"):
		p = lv.get_local_player()
	if running and enemy != null and p != null and not bool(p.get("is_downed")):
		# Musuh hanya berbahaya saat PATROL/CHASE/SEARCH; saat BLIND /
		# VANISH / STUNNED ia tidak bisa menangkap (_check_catch di
		# enemy.gd langsung return), jadi alert dimatikan.
		var st: int = int(enemy.get("state")) if enemy.get("state") != null else 0
		if st == 0 or st == 1 or st == 2:
			var d: Vector2 = (enemy as Node2D).global_position - (p as Node2D).global_position
			var dist: float = d.length()
			if dist < ALERT_RANGE and dist > 1.0:
				var t: float = 1.0 - dist / ALERT_RANGE
				var ax: float = absf(d.x)
				var ay: float = absf(d.y)
				var s: float = ax + ay
				if s > 0.0:
					var w: float = t * ALERT_MAX_ALPHA
					if d.x > 0.0:
						a_right = w * ax / s
					elif d.x < 0.0:
						a_left = w * ax / s
					if d.y > 0.0:
						a_bottom = w * ay / s
					elif d.y < 0.0:
						a_top = w * ay / s
					if st == 1:  # CHASE: berdenyut supaya terasa genting
						var pulse: float = 0.85 + 0.15 * sin(_alert_time * 6.0)
						a_top *= pulse
						a_bottom *= pulse
						a_left *= pulse
						a_right *= pulse
	_set_alert_alpha(_alert_top, a_top)
	_set_alert_alpha(_alert_bottom, a_bottom)
	_set_alert_alpha(_alert_left, a_left)
	_set_alert_alpha(_alert_right, a_right)


func _set_alert_alpha(rect: ColorRect, alpha: float) -> void:
	if rect == null:
		return
	rect.color = Color(ALERT_COLOR.r, ALERT_COLOR.g, ALERT_COLOR.b, clampf(alpha, 0.0, ALERT_MAX_ALPHA))


func show_result(success: bool, stars: int, ending: String, time_sec: float, deaths: int, done: int, total: int) -> void:
	if _result_panel == null:
		return
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	var title_color: Color = UiTheme.GREEN if success and ending == "Happy Ending" else (UiTheme.AMBER if success else UiTheme.RED)
	_result_title.text = (ending if success else "GAGAL: KEDUA PEMAIN TERTANGKAP").to_upper()
	_result_title.add_theme_color_override("font_color", title_color)
	_stat_time.text = "%02d:%02d" % [m, s]
	_stat_deaths.text = str(deaths)
	_stat_tasks.text = "%d/%d" % [done, total]
	for i in range(3):
		_set_star_box(_result_star_boxes[i], i < stars)
	_result_star_count.text = "%d/3" % stars
	_result_dim.visible = true
	_result_panel.visible = true


func show_disconnect(text: String) -> void:
	if _disconnect_panel == null:
		return
	_disconnect_label.text = text
	_disconnect_panel.visible = true


func hide_disconnect() -> void:
	# Dipanggil saat partner yang sempat terputus bergabung lagi,
	# supaya pesan "Partner terputus" hilang bersamaan dengan
	# game yang dilanjutkan (lihat _on_peer_joined di level_1.gd).
	if _disconnect_panel == null:
		return
	_disconnect_panel.visible = false


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.position = Vector2(10, 10)
	panel.size = Vector2(320, 62)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	_tasks_label = _mk_label("Tugas: 0/0", 16, UiTheme.INK, Vector2.ZERO)
	vbox.add_child(_tasks_label)
	_timer_label = _mk_label("Waktu: 00:00", 16, UiTheme.AMBER, Vector2.ZERO)
	vbox.add_child(_timer_label)
	_status_label = _mk_label("", 14, UiTheme.INK, Vector2.ZERO)
	_status_label.anchor_left = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = -320
	_status_label.offset_right = -14
	_status_label.offset_top = 12
	_status_label.offset_bottom = 60
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status_label)
	var hint := _mk_label("WASD/Panah: Gerak  |  Shift: Lari (berisik!)  |  E: Interaksi  |  Esc: Batalkan tugas  |  Tepi layar merah = musuh dekat", 12, UiTheme.MUTED, Vector2.ZERO)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 12
	hint.offset_right = 700
	hint.offset_top = -26
	hint.offset_bottom = -6
	add_child(hint)


func _build_prompt_and_message() -> void:
	var prompt_panel := PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_left = -320
	prompt_panel.offset_right = 320
	prompt_panel.offset_top = -58
	prompt_panel.offset_bottom = -30
	add_child(prompt_panel)
	var prompt_center := CenterContainer.new()
	prompt_panel.add_child(prompt_center)
	_prompt_label = _mk_label("", 16, UiTheme.INK, Vector2.ZERO)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_center.add_child(_prompt_label)
	_message_label = _mk_label("", 17, UiTheme.AMBER, Vector2.ZERO)
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.offset_left = -400
	_message_label.offset_right = 400
	_message_label.offset_top = 78
	_message_label.offset_bottom = 104
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)


func _build_result_panel() -> void:
	_result_dim = ColorRect.new()
	_result_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_dim.color = UiTheme.DIM
	_result_dim.visible = false
	_result_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_result_dim)
	_result_panel = CenterContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	add_child(_result_panel)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.custom_minimum_size = Vector2(640, 0)
	_result_panel.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)
	_result_title = UiTheme.mk_title("", 40, UiTheme.INK)
	vbox.add_child(_result_title)
	vbox.add_child(_spacer(14))
	vbox.add_child(UiTheme.hairline())
	vbox.add_child(_spacer(12))
	_result_stats = VBoxContainer.new()
	_result_stats.add_theme_constant_override("separation", 8)
	vbox.add_child(_result_stats)
	_stat_time = _stat_row("WAKTU")
	_stat_deaths = _stat_row("TERTANGKAP")
	_stat_tasks = _stat_row("TUGAS")
	vbox.add_child(_spacer(12))
	vbox.add_child(UiTheme.hairline())
	vbox.add_child(_spacer(12))
	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 10)
	vbox.add_child(rate_row)
	var rate_label := UiTheme.mk_label("PENILAIAN", 14, UiTheme.MUTED)
	rate_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_row.add_child(rate_label)
	_result_star_boxes.clear()
	for i in range(3):
		var star := UiTheme.StarIcon.new()
		star.custom_minimum_size = Vector2(20, 20)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rate_row.add_child(star)
		_result_star_boxes.append(star)
	_result_star_count = UiTheme.mk_label("0/3", 16, UiTheme.INK)
	_result_star_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_row.add_child(_result_star_count)
	vbox.add_child(_spacer(22))
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)
	var retry := Button.new()
	retry.text = "MAIN LAGI"
	retry.custom_minimum_size = Vector2(160, 44)
	UiTheme.style_button(retry)
	retry.pressed.connect(_on_retry_pressed)
	hbox.add_child(retry)
	var menu := Button.new()
	menu.text = "MENU UTAMA"
	menu.custom_minimum_size = Vector2(160, 44)
	UiTheme.style_button(menu)
	menu.pressed.connect(_on_menu_pressed)
	hbox.add_child(menu)


func _build_disconnect_panel() -> void:
	_disconnect_panel = CenterContainer.new()
	_disconnect_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_disconnect_panel.visible = false
	add_child(_disconnect_panel)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.custom_minimum_size = Vector2(480, 0)
	_disconnect_panel.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	_disconnect_label = UiTheme.mk_label("", 16, UiTheme.INK, null, HORIZONTAL_ALIGNMENT_CENTER)
	_disconnect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_disconnect_label)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	var menu := Button.new()
	menu.text = "MENU UTAMA"
	menu.custom_minimum_size = Vector2(160, 44)
	UiTheme.style_button(menu)
	menu.pressed.connect(_on_menu_pressed)
	hbox.add_child(menu)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _stat_row(label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := UiTheme.mk_label(label_text, 14, UiTheme.MUTED)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	var val := UiTheme.mk_label("", 16, UiTheme.INK, null, HORIZONTAL_ALIGNMENT_RIGHT)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	_result_stats.add_child(row)
	return val


func _set_star_box(box: UiTheme.StarIcon, filled: bool) -> void:
	box.filled = filled


func _mk_label(text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	# Label HUD: mono sistem. Outline tipis dipertahankan karena label
	# duduk langsung di atas scene game, bukan di dalam panel.
	var l := UiTheme.mk_label(text, font_size, color)
	l.position = pos
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _level() -> Node:
	return get_tree().get_first_node_in_group("LevelManager")


func _on_retry_pressed() -> void:
	var lv: Node = _level()
	if lv != null:
		lv.request_restart()


func _on_menu_pressed() -> void:
	var lv: Node = _level()
	if lv != null:
		lv.request_menu()
	else:
		NetworkManager.disconnect_all()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
