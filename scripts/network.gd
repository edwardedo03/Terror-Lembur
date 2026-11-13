extends Node

const PORT := 7000
const MAX_PLAYERS := 2
const DISCOVERY_PORT := 7001
const DISCOVERY_MSG := "TERROR_LEMBUR"

var player_scene: PackedScene = preload("res://scenes/worker_char.tscn")

@onready var players: Node2D = $"../YSort"
@onready var spawner: MultiplayerSpawner = $"../Spawner"

var menu: CanvasLayer
var ip_input: LineEdit
var status_label: Label
var server_list_vbox: VBoxContainer
var server_list_label: Label

var discover_udp: PacketPeerUDP
var listen_udp: PacketPeerUDP
var discovered: Dictionary = {}
var discover_timer := 0.0
var is_hosting := false
var is_listening := false

func _ready() -> void:
	spawner.add_spawnable_scene(player_scene.resource_path)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_hide_menu()
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
			discover_udp.put_packet((DISCOVERY_MSG + ":" + str(PORT)).to_utf8_buffer())
	if is_listening and listen_udp:
		while listen_udp.get_available_packet_count() > 0:
			var pkt := listen_udp.get_packet()
			var sender_ip := listen_udp.get_packet_ip()
			var text := pkt.get_string_from_utf8()
			if text.begins_with(DISCOVERY_MSG):
				discovered[sender_ip] = Time.get_ticks_msec()
		var now := Time.get_ticks_msec()
		var changed := false
		for ip in discovered.keys():
			if now - int(discovered[ip]) > 3000:
				discovered.erase(ip)
				changed = true
		if changed or discovered.size() != server_list_vbox.get_child_count():
			_refresh_server_list()

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
	_stop_listening()
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

func _start_broadcast() -> void:
	discover_udp = PacketPeerUDP.new()
	discover_udp.set_broadcast_enabled(true)
	discover_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	is_hosting = true
	discover_timer = 0.0
	print("DISCOVERY broadcasting on ", DISCOVERY_PORT)

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
		listen_udp = null
		return
	is_listening = true
	print("DISCOVERY listening on ", DISCOVERY_PORT)

func _stop_listening() -> void:
	is_listening = false
	if listen_udp:
		listen_udp.close()
		listen_udp = null

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
		btn.pressed.connect(func() -> void: join(str(ip)))
		server_list_vbox.add_child(btn)

func _build_menu() -> void:
	menu = CanvasLayer.new()
	menu.name = "Menu"
	add_child(menu)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 340)
	menu.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "TERROR LEMBUR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "Multiplayer Lokal (LAN)"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var host_btn := Button.new()
	host_btn.text = "Host (Buat Server)"
	host_btn.pressed.connect(host)
	vbox.add_child(host_btn)
	server_list_label = Label.new()
	server_list_label.text = "Mencari server di LAN..."
	server_list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(server_list_label)
	server_list_vbox = VBoxContainer.new()
	server_list_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(server_list_vbox)
	var manual_label := Label.new()
	manual_label.text = "Atau join manual pakai IP:"
	manual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(manual_label)
	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "IP server"
	vbox.add_child(ip_input)
	var join_btn := Button.new()
	join_btn.text = "Join Server"
	join_btn.pressed.connect(func() -> void: join(ip_input.text.strip_edges()))
	vbox.add_child(join_btn)
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)
	_start_listening()
