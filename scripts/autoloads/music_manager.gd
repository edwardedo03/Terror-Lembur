extends Node
## MusicManager (Autoload) — backsound game dengan loop crossfade yang halus.
##
## Main menu: Ghost Story. Level 1: The House of Leaves. Level 2: Insistent
## (yd, OpenGameArt, CC0; file .ogg). Lagu diputar ulang BUKAN
## dengan "putar dari 0" (itu menimbulkan jeda hening / bunyi klik di
## ujung MP3), tapi dengan crossfade: sesaat sebelum lagu habis, salinan
## kedua lagu itu mulai diputar dari awal dengan volume pelan, lalu
## volume keduanya disilangkan (yang lama meredup, yang baru mengeras).
## Hasilnya lagu berulang tanpa jeda dan tanpa klik. Pindah lagu
## (menu -> level, level -> menu) juga crossfade, bukan putus lalu mulai.
##
## Musik itu lokal — tiap PC memutar sendiri, tidak lewat network,
## jadi tidak ada RPC di sini. Dipanggil dari _ready main_menu.gd,
## pilih_level.gd, menunggu_host.gd (lagu menu), level_1.gd (play_level)
## dan level_2.gd (play_level2); pindah layar = crossfade ke lagu berikutnya.

# Tipe AudioStream (bukan AudioStreamMP3) supaya MP3 dan OGG sama-sama bisa.
const MENU_STREAM: AudioStream = preload("res://assets/backsound/main_menu/Ghost20Story.mp3")
const LEVEL_STREAM: AudioStream = preload("res://assets/backsound/level_1/The20of20Leaves.mp3")
const LEVEL2_STREAM: AudioStream = preload("res://assets/backsound/level_2/Insistent.ogg")

## Volume musik. Ubah kalau terlalu pelan / keras (0 = paling keras).
const MUSIC_VOLUME_DB: float = -12.0
## Volume musik Level 2, sengaja lebih pelan: di lobi gelap musik cuma latar
## tipis, supaya suasana tetap sunyi dan bunyi efek game tetap terdengar.
const LEVEL2_VOLUME_DB: float = -17.0
## Lamanya crossfade (detik). Dipakai untuk loop maupun pindah lagu.
const FADE_TIME: float = 2.5
const SILENT_DB: float = -80.0

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _idle: AudioStreamPlayer
var _current: AudioStream = null
var _crossfading: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "MusicA"
	_player_a.volume_db = SILENT_DB
	add_child(_player_a)
	_player_b = AudioStreamPlayer.new()
	_player_b.name = "MusicB"
	_player_b.volume_db = SILENT_DB
	add_child(_player_b)
	_active = _player_a
	_idle = _player_b


func _process(_delta: float) -> void:
	# Loop: sesaat sebelum lagu habis, mulai crossfade ke salinan
	# yang sama dari awal. Dijaga supaya tidak dobel saat crossfade
	# sedang jalan.
	if _current == null or _crossfading:
		return
	if not _active.playing:
		return
	var length: float = _current.get_length()
	if length <= FADE_TIME + 1.0:
		return
	if _active.get_playback_position() >= length - FADE_TIME:
		_crossfade_to(_current)


## Putar backsound main menu (Ghost Story).
func play_menu() -> void:
	_play_track(MENU_STREAM)


## Putar backsound Level 1 (The House of Leaves).
func play_level() -> void:
	_play_track(LEVEL_STREAM)


## Putar backsound Level 2 (Insistent), lebih pelan dari Level 1.
func play_level2() -> void:
	_play_track(LEVEL2_STREAM)


## Berhentikan semua musik (fade-out). Saat ini tidak dipanggil dari
## mana pun; disediakan kalau nanti ada layar yang mau hening.
func stop_music() -> void:
	_settle_crossfade()
	_kill_fade_tween()
	_current = null
	for p: AudioStreamPlayer in [_active, _idle]:
		if p.playing:
			var t: Tween = create_tween()
			t.tween_property(p, "volume_db", SILENT_DB, FADE_TIME)
			t.tween_callback(p.stop)


func _play_track(stream: AudioStream) -> void:
	# Lagu yang sama sudah jalan: jangan mulai dari awal lagi.
	if stream == _current and _active.playing:
		return
	_settle_crossfade()
	if not _active.playing and not _idle.playing:
		# Belum ada lagu: putar langsung dengan fade-in.
		_current = stream
		_active.stream = stream
		_active.volume_db = SILENT_DB
		_active.play()
		_fade_to(_active, _volume_lagu(stream))
		return
	_crossfade_to(stream)


## Volume tujuan tiap lagu (Level 2 lebih pelan).
func _volume_lagu(stream: AudioStream) -> float:
	if stream == LEVEL2_STREAM:
		return LEVEL2_VOLUME_DB
	return MUSIC_VOLUME_DB


func _crossfade_to(stream: AudioStream) -> void:
	_settle_crossfade()
	_kill_fade_tween()
	_crossfading = true
	_current = stream
	_idle.stream = stream
	_idle.volume_db = SILENT_DB
	_idle.play()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_active, "volume_db", SILENT_DB, FADE_TIME)
	_fade_tween.tween_property(_idle, "volume_db", _volume_lagu(stream), FADE_TIME)
	_fade_tween.chain().tween_callback(_finish_crossfade)


func _finish_crossfade() -> void:
	_active.stop()
	var tmp: AudioStreamPlayer = _active
	_active = _idle
	_idle = tmp
	_crossfading = false
	_fade_tween = null


func _settle_crossfade() -> void:
	# Kalau ada crossfade yang sedang jalan lalu diminta lagu lain,
	# selesaikan dulu crossfade itu seketika: yang lama berhenti,
	# yang baru jadi aktif. Tanpa ini, dua player bisa jalan
	# bersamaan dan _crossfading nyangkut true.
	if not _crossfading:
		return
	_kill_fade_tween()
	_active.stop()
	_idle.volume_db = _volume_lagu(_current)
	var tmp: AudioStreamPlayer = _active
	_active = _idle
	_idle = tmp
	_crossfading = false


func _fade_to(player: AudioStreamPlayer, target_db: float) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", target_db, FADE_TIME)


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
