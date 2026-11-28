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


# ------------------------------------------------------------- IP lokal ---
## Kata di nama adapter yang menandakan adapter virtual (bukan Wi-Fi/LAN
## sungguhan). IP dari adapter ini tidak ditampilkan di menu.
const ADAPTER_VIRTUAL: Array[String] = [
	"virtualbox", "vbox", "vmware", "vethernet", "hyper-v", "wsl",
	"docker", "loopback", "bluetooth", "host-only",
]


## Daftar IPv4 PC ini yang bisa dipakai teman untuk Join, urut dari yang
## paling mungkin benar (Wi-Fi / Ethernet 192.168.x dulu). Dipakai label
## "IP MESIN INI" di main menu dan Pilih Level, jadi host tidak perlu
## membuka cmd lalu ipconfig. Tiap isi: { "ip": "192.168.1.7", "adapter": "Wi-Fi" }.
func daftar_ip_lan() -> Array[Dictionary]:
	var hasil: Array[Dictionary] = []
	var sudah: Dictionary = {}
	for iface: Dictionary in IP.get_local_interfaces():
		var nama: String = String(iface.get("friendly", iface.get("name", "")))
		if _adapter_virtual(nama):
			continue
		var alamat: Variant = iface.get("addresses", [])
		for ip: String in alamat:
			if not _ipv4_lan(ip) or sudah.has(ip):
				continue
			sudah[ip] = true
			hasil.append({"ip": ip, "adapter": nama})
	if hasil.is_empty():
		# Cadangan kalau daftar adapter kosong di OS tertentu.
		for ip: String in IP.get_local_addresses():
			if _ipv4_lan(ip) and not sudah.has(ip):
				sudah[ip] = true
				hasil.append({"ip": ip, "adapter": ""})
	hasil.sort_custom(_ip_lebih_dulu)
	return hasil


## IP utama untuk label Dymo ("" kalau tidak ada jaringan).
func ip_utama() -> String:
	var daftar: Array[Dictionary] = daftar_ip_lan()
	if daftar.is_empty():
		return ""
	return String(daftar[0]["ip"])


func _adapter_virtual(nama: String) -> bool:
	var kecil: String = nama.to_lower()
	for kata: String in ADAPTER_VIRTUAL:
		if kecil.contains(kata):
			return true
	return false


func _ipv4_lan(ip: String) -> bool:
	if ip.count(".") != 3:
		return false
	return not (ip.begins_with("127.") or ip.begins_with("169.254.") or ip == "0.0.0.0")


func _ip_lebih_dulu(a: Dictionary, b: Dictionary) -> bool:
	return _skor_ip(a) < _skor_ip(b)


func _skor_ip(isi: Dictionary) -> int:
	var ip: String = String(isi.get("ip", ""))
	var adapter: String = String(isi.get("adapter", "")).to_lower()
	var skor: int = 50
	if ip.begins_with("192.168."):
		skor = 10
	elif ip.begins_with("10."):
		skor = 20
	elif ip.begins_with("172."):
		skor = 30
	if adapter.contains("wi-fi") or adapter.contains("wifi") or adapter.contains("wlan") \
			or adapter.contains("wireless") or adapter.contains("ethernet"):
		skor -= 5
	return skor


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
