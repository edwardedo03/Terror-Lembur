extends Node
## AlurLevel (Autoload) — alur layar setelah Host / Join.
##
##   Main menu ── BUAT GAME ──> Pilih Level (host) ──> Level 1 / Level 2
##             └─ GABUNG GAME ─> Menunggu host ─────> ikut level pilihan host
##   Selesai level ── PILIH LEVEL ──> Pilih Level (host) + Menunggu host (teman)
##                 └─ MENU UTAMA ──> main menu (koneksi diputus)
##
## Host yang memutuskan level. Client hanya mengikuti lewat RPC di node
## autoload ini. Path node autoload (/root/AlurLevel) sama di kedua PC,
## jadi RPC tetap sampai walau scene yang sedang terbuka di kedua PC
## berbeda (misalnya host di Pilih Level, teman di Menunggu host).
##
## Level 1 diawali cerita (story_intro.tscn), Level 2 langsung main.
## Teman yang join saat host sudah di dalam level langsung dibawa ke
## level itu tanpa cerita (level akan mengirim state penuh lewat sync).

const SCENE_MENU_UTAMA: String = "res://scenes/main_menu.tscn"
const SCENE_PILIH_LEVEL: String = "res://scenes/menu/pilih_level.tscn"
const SCENE_MENUNGGU_HOST: String = "res://scenes/menu/menunggu_host.tscn"
const SCENE_CERITA: String = "res://scenes/story_intro.tscn"
const SCENE_LEVEL: Dictionary = {
	"level_1": "res://scenes/level_1.tscn",
	"level_2": "res://scenes/level2/level_2.tscn",
}
const NAMA_LEVEL: Dictionary = {
	"level_1": "LEVEL 1 LANTAI KANTOR",
	"level_2": "LEVEL 2 LOBI GELAP",
}
## Jeda kecil di PC teman sebelum pindah scene, supaya tulisan
## "Host memilih LEVEL ..." sempat terbaca.
const JEDA_PINDAH_CLIENT: float = 0.6

## Client: jawaban status dari host sudah datang (level aktif + progres).
signal status_host_diterima(level_id: String)
## Client: host baru saja memilih level.
signal level_dipilih_host(level_id: String)

## Level yang sedang dimainkan host ("" = sedang di layar menu).
var level_aktif: String = ""
## Client: salinan progres host (lihat GameProgress.ringkasan()).
var progres_host: Dictionary = {}
## Client: IP host yang dipakai saat Join (untuk label Dymo).
var ip_host: String = ""
## Pesan sekali tampil di main menu (misalnya "Host keluar dari game").
var pesan_menu: String = ""
## true kalau main menu dibuka langsung dari akhir intro sinematik
## (scenes/menu/intro.tscn). Main menu lalu tampil dalam mode "sambungan":
## judul muncul dari gelap, kartu lembur keluar dari mesin absen, baru
## tombol-tombolnya. Dibaca sekali lalu dikembalikan ke false oleh main menu.
var dari_intro: bool = false


# ----------------------------------------------------------------- host ---
## Host / solo: buka layar Pilih Level.
func ke_pilih_level() -> void:
	level_aktif = ""
	get_tree().change_scene_to_file(SCENE_PILIH_LEVEL)


## Host / solo: mulai level yang dipilih. Teman ikut pindah lewat RPC.
func mulai_level(level_id: String) -> void:
	if not SCENE_LEVEL.has(level_id):
		push_warning("[AlurLevel] level tidak dikenal: %s" % level_id)
		return
	level_aktif = level_id
	if NetworkManager.mode == NetworkManager.Mode.HOST:
		rpc("_mulai_level_rpc", level_id)
	_pindah_ke_level(level_id, true)


## Host (dari panel hasil): kembali ke Pilih Level tanpa memutus koneksi.
## Teman dibawa ke layar Menunggu host.
func kembali_ke_pilih_level() -> void:
	level_aktif = ""
	if NetworkManager.mode == NetworkManager.Mode.HOST:
		rpc("_ke_menunggu_rpc", GameProgress.ringkasan())
	get_tree().change_scene_to_file(SCENE_PILIH_LEVEL)


# --------------------------------------------------------------- client ---
## Client: pindah ke layar Menunggu host (dipanggil main menu setelah
## berhasil tersambung).
func ke_menunggu_host(ip: String) -> void:
	ip_host = ip.strip_edges()
	level_aktif = ""
	progres_host = {}
	get_tree().change_scene_to_file(SCENE_MENUNGGU_HOST)


## Client: tanya host sedang di mana (dipanggil layar Menunggu host,
## diulang tiap detik sampai dijawab).
func minta_status() -> void:
	if NetworkManager.mode != NetworkManager.Mode.CLIENT:
		return
	rpc_id(1, "_minta_status_rpc")


# --------------------------------------------------------------- semua ---
## Putus koneksi lalu kembali ke main menu. pesan (opsional) ditampilkan
## sekali di main menu.
func ke_menu_utama(pesan: String = "") -> void:
	NetworkManager.disconnect_all()
	level_aktif = ""
	progres_host = {}
	pesan_menu = pesan
	get_tree().change_scene_to_file(SCENE_MENU_UTAMA)


## Main menu mengambil pesan sekali tampil lalu mengosongkannya.
func ambil_pesan_menu() -> String:
	var p: String = pesan_menu
	pesan_menu = ""
	return p


## Progres yang ditampilkan di kartu lembur: di PC teman ikut progres host
## (kalau sudah diterima), selain itu progres PC ini sendiri.
func progres_tampil() -> Dictionary:
	if NetworkManager.mode == NetworkManager.Mode.CLIENT and not progres_host.is_empty():
		return progres_host
	return GameProgress.ringkasan()


func nama_level(level_id: String) -> String:
	return String(NAMA_LEVEL.get(level_id, level_id.to_upper()))


func _pindah_ke_level(level_id: String, pakai_cerita: bool) -> void:
	if level_id == "level_1" and pakai_cerita:
		get_tree().change_scene_to_file(SCENE_CERITA)
	else:
		get_tree().change_scene_to_file(String(SCENE_LEVEL[level_id]))


func _di_layar_menunggu() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path == SCENE_MENUNGGU_HOST


# ------------------------------------------------------------------ RPC ---
@rpc("any_peer", "call_remote", "reliable")
func _minta_status_rpc() -> void:
	if NetworkManager.mode != NetworkManager.Mode.HOST:
		return
	var pengirim: int = multiplayer.get_remote_sender_id()
	rpc_id(pengirim, "_status_rpc", level_aktif, GameProgress.ringkasan())


@rpc("authority", "call_remote", "reliable")
func _status_rpc(level_id: String, progres: Dictionary) -> void:
	progres_host = progres
	level_aktif = level_id
	status_host_diterima.emit(level_id)
	# Join saat host sudah di dalam level: langsung masuk, tanpa cerita.
	if level_id != "" and SCENE_LEVEL.has(level_id) and _di_layar_menunggu():
		_pindah_ke_level(level_id, false)


@rpc("authority", "call_remote", "reliable")
func _mulai_level_rpc(level_id: String) -> void:
	if not SCENE_LEVEL.has(level_id):
		return
	level_aktif = level_id
	level_dipilih_host.emit(level_id)
	await get_tree().create_timer(JEDA_PINDAH_CLIENT).timeout
	# Bisa saja koneksi putus selama jeda: jangan masuk level sendirian.
	if NetworkManager.mode != NetworkManager.Mode.CLIENT or level_aktif != level_id:
		return
	_pindah_ke_level(level_id, true)


@rpc("authority", "call_remote", "reliable")
func _ke_menunggu_rpc(progres: Dictionary) -> void:
	level_aktif = ""
	progres_host = progres
	get_tree().change_scene_to_file(SCENE_MENUNGGU_HOST)
