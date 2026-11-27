extends Node
## NetworkManager (Autoload) — sesi ENet 2 pemain untuk Terror Lembur.
##
## Mode: SOLO (tes 1 pemain, tanpa peer), HOST (PC 1, otoritas game),
## CLIENT (PC 2, ikut host). Level membaca mode ini untuk memutuskan
## apakah RPC dipakai dan siapa yang menjalankan AI/state.
## Port default 7777/UDP. Untuk 2 PC: samakan Wi-Fi/LAN, client isi IP LAN host.

enum Mode { SOLO, HOST, CLIENT }

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connected_to_host
signal connection_failed
signal host_disconnected

const PORT: int = 7777
# Jumlah KLIEN yang boleh join. Di ENet ini jumlah klien, bukan total pemain,
# jadi 1 = total 2 pemain (host + 1 klien). Dulu 2 sehingga pemain ke-3 bisa
# masuk, memicu softlock revive (B1) dan spawn duplikat di posisi P2.
const MAX_PEERS: int = 1

var mode: int = Mode.SOLO
var connected_ids: Array[int] = []

var _peer: ENetMultiplayerPeer = null


func _ready() -> void:
	_ensure_input_actions()
	# Peer offline untuk mode solo: is_multiplayer_authority() dan
	# get_unique_id() butuh peer yang valid, kalau tidak Godot men-spam error.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_networked() -> bool:
	return mode == Mode.HOST or mode == Mode.CLIENT


func is_server_authority() -> bool:
	# Solo dan Host sama-sama menjalankan otoritas (AI, task, pintu, ending).
	return mode == Mode.SOLO or mode == Mode.HOST


func local_peer_id() -> int:
	if mode == Mode.SOLO:
		return 1
	return multiplayer.get_unique_id()


func host_game() -> Error:
	disconnect_all()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(PORT, MAX_PEERS)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	mode = Mode.HOST
	return OK


func join_game(ip: String) -> Error:
	disconnect_all()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	mode = Mode.CLIENT
	return OK


func start_solo() -> void:
	disconnect_all()
	mode = Mode.SOLO


func disconnect_all() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected_ids.clear()
	mode = Mode.SOLO


func _on_peer_connected(peer_id: int) -> void:
	if peer_id not in connected_ids:
		connected_ids.append(peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	connected_ids.erase(peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	connected_to_host.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	host_disconnected.emit()


# Pengaman: kalau InputMap di project.godot belum kebaca (mis. project
# dibuka dari versi editor lain), aksi tetap dibuat di runtime.
func _ensure_input_actions() -> void:
	_add_key_action(&"move_up", [KEY_W, KEY_UP], [true, false])
	_add_key_action(&"move_down", [KEY_S, KEY_DOWN], [true, false])
	_add_key_action(&"move_left", [KEY_A, KEY_LEFT], [true, false])
	_add_key_action(&"move_right", [KEY_D, KEY_RIGHT], [true, false])
	_add_key_action(&"interact", [KEY_E, KEY_F], [true, true])
	_add_key_action(&"sprint", [KEY_SHIFT], [false])


func _add_key_action(action: StringName, keys: Array, use_physical: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for i: int in range(keys.size()):
			var ev := InputEventKey.new()
			if use_physical[i]:
				ev.physical_keycode = keys[i]
			else:
				ev.keycode = keys[i]
			InputMap.action_add_event(action, ev)
