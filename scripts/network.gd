extends Node

const PORT := 7000
const MAX_PLAYERS := 2
const DISCOVERY_PORT := 7001
const DISCOVERY_MSG := "TERROR_LEMBUR"
const DISCOVER_REQUEST := "TERROR_LEMBUR?DISCOVER"

var player_scene: PackedScene = preload("res://scenes/worker_char.tscn")

@onready var players: Node2D = $"../YSort"
@onready var spawner: MultiplayerSpawner = $"../Spawner"

var menu: CanvasLayer
var ip_input: LineEdit
var status_label: Label
var server_list_vbox: VBoxContainer
var server_list_label: Label
var ip_hint_label: Label

var discover_udp: PacketPeerUDP
var listen_udp: PacketPeerUDP
var discovered: Dictionary = {}
var listed_ips: Array = []
var discover_timer := 0.0
var request_timer := 0.0
var broadcast_targets: Array[String] = []
var is_hosting := false
var is_listening := false
var menu_title: Label
var menu_flicker_t := 0.0

func _ready() -> void:
	spawner.add_spawnable_scene(player_scene.resource_path)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_hide_menu()
		_show_hud()
		if multiplayer.is_server():
			spawn_player(1)
			for id in multiplayer.get_peers():
				spawn_player(id)
		return
	var args := OS.get_cmdline_user_args()
	if "--host" in args:
		host()
	elif "--join" in args:
		var ip := "127.0.0.1"
		var idx := args.find("--join")
		if idx >= 0 and idx + 1 < args.size():
			ip = args[idx + 1]
		join(ip)
	else:
		_build_menu()

func _process(delta: float) -> void:
	if is_hosting and discover_udp:
		discover_timer += delta
		if discover_timer >= 1.0:
			discover_timer = 0.0
			for target in broadcast_targets:
				discover_udp.set_dest_address(target, DISCOVERY_PORT)
				var err := discover_udp.put_packet((DISCOVERY_MSG + ":" + str(PORT)).to_utf8_buffer())
				if err != OK:
					print("DISCOVERY broadcast ke ", target, " gagal: ", err)
	if is_listening and listen_udp:
		while listen_udp.get_available_packet_count() > 0:
			var pkt := listen_udp.get_packet()
			var sender_ip := listen_udp.get_packet_ip()
			var text := pkt.get_string_from_utf8()
			if text == DISCOVER_REQUEST:
				if is_hosting and discover_udp:
					discover_udp.set_dest_address(sender_ip, DISCOVERY_PORT)
					discover_udp.put_packet((DISCOVERY_MSG + ":" + str(PORT)).to_utf8_buffer())
					print("DISCOVERY balas ke ", sender_ip)
			elif text.begins_with(DISCOVERY_MSG):
				discovered[sender_ip] = Time.get_ticks_msec()
		if is_listening and not is_hosting and discover_udp:
			request_timer += delta
			if request_timer >= 1.0:
				request_timer = 0.0
				for target in broadcast_targets:
					discover_udp.set_dest_address(target, DISCOVERY_PORT)
					discover_udp.put_packet(DISCOVER_REQUEST.to_utf8_buffer())
		var now := Time.get_ticks_msec()
		for ip in discovered.keys():
			if now - int(discovered[ip]) > 3000:
				discovered.erase(ip)
		var current := discovered.keys()
		current.sort()
		if current != listed_ips:
			listed_ips = current.duplicate()
			_refresh_server_list()
	if menu != null and menu.visible and menu_title != null:
		menu_flicker_t += delta
		if menu_flicker_t > 0.09:
			menu_flicker_t = 0.0
			if randf() < 0.07:
				menu_title.modulate = Color(0.55, 0.55, 0.55, 1)
			else:
				menu_title.modulate = Color.WHITE

func _make_peer() -> MultiplayerPeer:
	if "--ws" in OS.get_cmdline_user_args():
		return WebSocketMultiplayerPeer.new()
	return ENetMultiplayerPeer.new()

func host() -> void:
	var peer := _make_peer()
	var err: Error
	if peer is WebSocketMultiplayerPeer:
		err = (peer as WebSocketMultiplayerPeer).create_server(PORT)
	else:
		err = (peer as ENetMultiplayerPeer).create_server(PORT, MAX_PLAYERS)
	if err != OK:
		_set_status("Gagal host: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	_hide_menu()
	_show_hud()
	_start_broadcast()
	spawn_player(1)
	_set_status("Hosting di port %d. Menunggu pemain 2..." % PORT)
	print("HOST started on port ", PORT)

func join(ip: String) -> void:
	var peer := _make_peer()
	var err: Error
	if peer is WebSocketMultiplayerPeer:
		err = (peer as WebSocketMultiplayerPeer).create_client("ws://%s:%d" % [ip, PORT])
	else:
		err = (peer as ENetMultiplayerPeer).create_client(ip, PORT)
	if err != OK:
		_set_status("Gagal join: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	_hide_menu()
	_show_hud()
	_stop_listening()
	_set_status("Menghubungi %s:%d ..." % [ip, PORT])
	print("JOIN connecting to ", ip, ":", PORT)

func spawn_player(id: int) -> void:
	if players.has_node(str(id)):
		return
	var p := player_scene.instantiate()
	p.name = str(id)
	p.position = Vector2(320, 320) if id == 1 else Vector2(960, 320)
	players.add_child(p, true)
	print("spawned player ", id, " at ", p.position)

func _on_peer_connected(id: int) -> void:
	print("peer connected: ", id)
	if multiplayer.is_server():
		spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	print("peer disconnected: ", id)
	var node := players.get_node_or_null(str(id))
	if node:
		node.queue_free()

func _on_connected_to_server() -> void:
	_set_status("Terhubung ke server. Menunggu spawn...")
	print("connected to server, my id: ", multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_set_status("Gagal terhubung ke server.")
	print("connection failed")

func _on_server_disconnected() -> void:
	_set_status("Server terputus.")
	print("server disconnected")

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
	print("[status] ", text)

func _hide_menu() -> void:
	if menu:
		menu.visible = false

func _show_hud() -> void:
	var lvl := get_parent()
	if lvl != null and lvl.has_method("show_hud"):
		lvl.show_hud()

func _compute_broadcast_targets() -> Array[String]:
	var targets: Array[String] = ["255.255.255.255"]
	for ip in IP.get_local_addresses():
		if ip.begins_with("127.") or ip.begins_with("169.254.") or ":" in ip:
			continue
		var parts := ip.split(".")
		if parts.size() == 4:
			var bcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if bcast not in targets:
				targets.append(bcast)
	return targets

func _start_broadcast() -> void:
	discover_udp = PacketPeerUDP.new()
	discover_udp.set_broadcast_enabled(true)
	discover_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	broadcast_targets = _compute_broadcast_targets()
	is_hosting = true
	discover_timer = 0.0
	print("DISCOVERY broadcasting on ", DISCOVERY_PORT, " ke ", broadcast_targets)

func _stop_broadcast() -> void:
	is_hosting = false
	if discover_udp:
		discover_udp.close()
		discover_udp = null

func _start_listening() -> void:
	listen_udp = PacketPeerUDP.new()
	var err := listen_udp.bind(DISCOVERY_PORT)
	if err != OK:
		print("DISCOVERY listen failed: ", err)
		_set_status("Auto-detect gagal (port 7001 dipakai). Pakai join manual.")
		listen_udp = null
		return
	discover_udp = PacketPeerUDP.new()
	discover_udp.set_broadcast_enabled(true)
	broadcast_targets = _compute_broadcast_targets()
	is_listening = true
	request_timer = 0.0
	var my_ips: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("127.") or ":" in ip:
			continue
		my_ips.append(ip)
	if ip_hint_label:
		ip_hint_label.text = "IP PC ini: " + ", ".join(my_ips) + "  (pastikan 2 PC satu WiFi)"
	print("DISCOVERY listening on ", DISCOVERY_PORT, " target: ", broadcast_targets)

func _stop_listening() -> void:
	is_listening = false
	if listen_udp:
		listen_udp.close()
		listen_udp = null
	if discover_udp and not is_hosting:
		discover_udp.close()
		discover_udp = null

func _refresh_server_list() -> void:
	if server_list_vbox == null:
		return
	for child in server_list_vbox.get_children():
		child.queue_free()
	if discovered.is_empty():
		server_list_label.text = "Mencari server di LAN..."
		return
	server_list_label.text = "Server ketemu di LAN:"
	for ip in discovered.keys():
		var btn := Button.new()
		btn.text = "Join " + str(ip)
		btn.custom_minimum_size = Vector2(0, 36)
		UITheme.apply_button(btn, 16)
		btn.pressed.connect(func() -> void: join(str(ip)))
		server_list_vbox.add_child(btn)

func _build_menu() -> void:
	menu = CanvasLayer.new()
	menu.name = "Menu"
	add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	menu.add_child(UITheme.make_vignette(1280, 720))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)
	menu_title = UITheme.make_label("TERROR LEMBUR", UITheme.title_font(), 72, UITheme.COL_BLOOD_BRIGHT)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_color_override("font_outline_color", Color(0.05, 0, 0, 1))
	menu_title.add_theme_constant_override("outline_size", 14)
	menu_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	menu_title.add_theme_constant_override("shadow_offset_x", 4)
	menu_title.add_theme_constant_override("shadow_offset_y", 4)
	vb.add_child(menu_title)
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(badge_row)
	var badge := PanelContainer.new()
	UITheme.apply_panel(badge, Color(0.25, 0.05, 0.05, 0.92), UITheme.COL_BLOOD, 1, 4)
	badge.add_child(UITheme.make_label("2 PEMAIN  •  LAN  •  GOTONG ROYONG  •  ARA & BIMA", UITheme.body_font(), 14, UITheme.COL_GOLD))
	badge_row.add_child(badge)
	var tag := UITheme.make_label("Dua karyawan lembur. Satu bos yang tidak pernah pulang.", UITheme.body_font(), 16, UITheme.COL_PAPER)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)
	var panel := PanelContainer.new()
	UITheme.apply_panel(panel)
	panel.custom_minimum_size = Vector2(500, 0)
	vb.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 8)
	margin.add_child(pvb)
	var how_head := UITheme.make_label("CARA BERMAIN", UITheme.body_font(), 14, UITheme.COL_GOLD)
	how_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(how_head)
	var how := RichTextLabel.new()
	how.bbcode_enabled = true
	how.fit_content = true
	how.scroll_active = false
	how.add_theme_font_override("normal_font", UITheme.body_font())
	how.add_theme_font_size_override("normal_font_size", 15)
	how.add_theme_color_override("default_color", UITheme.COL_PAPER)
	how.text = "[center][color=#ffd34d]WASD[/color] gerak   [color=#ffd34d]E[/color] tahan: tugas   [color=#ffd34d]Q[/color] lempar barang\n[color=#ffd34d]F[/color] teriak   [color=#ffd34d]R[/color] senter   [color=#ffd34d]C[/color] ngumpet di bawah meja\nSelesaikan 3 tugas, lalu kabur lewat [color=#ff5555]PINTU KELUAR[/color].[/center]"
	pvb.add_child(how)
	var sep := HSeparator.new()
	pvb.add_child(sep)
	var host_btn := Button.new()
	host_btn.text = "Host (Buat Server)"
	host_btn.custom_minimum_size = Vector2(0, 44)
	UITheme.apply_button(host_btn, 18)
	host_btn.pressed.connect(host)
	pvb.add_child(host_btn)
	server_list_label = UITheme.make_label("Mencari server di LAN...", UITheme.body_font(), 14, UITheme.COL_GREY)
	server_list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(server_list_label)
	server_list_vbox = VBoxContainer.new()
	server_list_vbox.add_theme_constant_override("separation", 6)
	pvb.add_child(server_list_vbox)
	ip_hint_label = UITheme.make_label("", UITheme.body_font(), 13, Color(0.55, 0.55, 0.55))
	ip_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(ip_hint_label)
	var manual_label := UITheme.make_label("Atau join manual pakai IP:", UITheme.body_font(), 14, UITheme.COL_GREY)
	manual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(manual_label)
	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "IP server"
	UITheme.apply_line_edit(ip_input, 16)
	pvb.add_child(ip_input)
	var join_btn := Button.new()
	join_btn.text = "Join Server"
	join_btn.custom_minimum_size = Vector2(0, 44)
	UITheme.apply_button(join_btn, 18)
	join_btn.pressed.connect(func() -> void: join(ip_input.text.strip_edges()))
	pvb.add_child(join_btn)
	status_label = UITheme.make_label("", UITheme.body_font(), 14, UITheme.COL_GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvb.add_child(status_label)
	var foot := UITheme.make_label("Office Pixel Art by Imersa Studios  •  Modern Office Tileset by Rubber Studio  •  Pemrograman Gim, Universitas Katolik Indonesia Atma Jaya", UITheme.body_font(), 12, Color(0.45, 0.45, 0.45))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(foot)
	_start_listening()
