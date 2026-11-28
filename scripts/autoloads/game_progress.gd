extends Node
## GameProgress (Autoload) — simpan bintang & waktu terbaik per level.
## Disimpan di user://terror_lembur_progress.cfg (per PC), jadi progres
## tetap ada walau game ditutup lalu dibuka lagi.
##
## Tambahan untuk menu baru:
## - sudah_tamat() / level_terbuka(): Level 2 terbuka kalau Level 1 sudah
##   pernah tamat di PC ini.
## - ringkasan(): progres dalam bentuk Dictionary biasa supaya bisa dikirim
##   host ke PC teman (kartu lembur di PC teman ikut progres host).
## - reset_progres(): hapus semua progres level (tombol MODE EDITOR).
## - IP host terakhir yang dipakai Join disimpan di file yang sama supaya
##   PC 2 tidak perlu mengetik ulang.

const SAVE_PATH: String = "user://terror_lembur_progress.cfg"
const LEVEL_IDS: Array[String] = ["level_1", "level_2"]
const SECTION_JARINGAN: String = "jaringan"

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(SAVE_PATH)


func record_level_result(level_id: String, stars: int, time_sec: float, ending: String, success: bool) -> void:
	if not success:
		return
	var prev_stars: int = int(_cfg.get_value(level_id, "stars", 0))
	if stars > prev_stars:
		_cfg.set_value(level_id, "stars", stars)
	var prev_time: float = float(_cfg.get_value(level_id, "best_time", 0.0))
	if prev_time <= 0.0 or time_sec < prev_time:
		_cfg.set_value(level_id, "best_time", time_sec)
	_cfg.set_value(level_id, "ending", ending)
	_cfg.set_value(level_id, "completions", int(_cfg.get_value(level_id, "completions", 0)) + 1)
	_cfg.save(SAVE_PATH)


func get_stars(level_id: String) -> int:
	return int(_cfg.get_value(level_id, "stars", 0))


func get_best_time(level_id: String) -> float:
	return float(_cfg.get_value(level_id, "best_time", 0.0))


func get_ending(level_id: String) -> String:
	return String(_cfg.get_value(level_id, "ending", ""))


## true kalau level ini sudah pernah diselesaikan (berhasil kabur).
func sudah_tamat(level_id: String) -> bool:
	return int(_cfg.get_value(level_id, "completions", 0)) > 0 or get_best_time(level_id) > 0.0


## Level 1 selalu terbuka. Level 2 terbuka setelah Level 1 tamat.
func level_terbuka(level_id: String) -> bool:
	if level_id == "level_2":
		return sudah_tamat("level_1")
	return true


## Progres semua level sebagai Dictionary biasa (aman dikirim lewat RPC):
## { "level_1": {"tamat": bool, "bintang": int, "waktu": float, "terbuka": bool}, ... }
func ringkasan() -> Dictionary:
	var hasil: Dictionary = {}
	for lid: String in LEVEL_IDS:
		hasil[lid] = {
			"tamat": sudah_tamat(lid),
			"bintang": get_stars(lid),
			"waktu": get_best_time(lid),
			"terbuka": level_terbuka(lid),
		}
	return hasil


## Hapus progres semua level (IP terakhir tetap disimpan).
func reset_progres() -> void:
	for lid: String in LEVEL_IDS:
		if _cfg.has_section(lid):
			_cfg.erase_section(lid)
	_cfg.save(SAVE_PATH)


func ip_terakhir() -> String:
	return String(_cfg.get_value(SECTION_JARINGAN, "ip_host", ""))


func simpan_ip_terakhir(ip: String) -> void:
	_cfg.set_value(SECTION_JARINGAN, "ip_host", ip.strip_edges())
	_cfg.save(SAVE_PATH)
