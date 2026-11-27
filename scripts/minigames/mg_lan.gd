extends MinigameBase
## Perbaiki Kabel LAN — memory matching: 8 ujung kabel (4 pasang warna)
## tertutup. Tekan angka 1-8 untuk membuka satu ujung, lalu buka ujung
## lain: kalau warnanya sama, pasangan tersambung; kalau beda, keduanya
## tertutup lagi setelah 0.8 detik. Sambungkan keempat pasang.

const PAIRS: int = 4
const FLIP_BACK_DELAY: float = 0.8

const COLOR_NAMES: Array[String] = ["Merah", "Kuning", "Hijau", "Biru"]
const COLORS: Array[Color] = [
	Color(0.9, 0.25, 0.25),
	Color(1.0, 0.8, 0.25),
	Color(0.35, 0.8, 0.4),
	Color(0.35, 0.6, 1.0),
]

var _cards: Array[int] = []  # 8 entri, nilai 0-3 (indeks warna)
var _state: Array[int] = []  # 0 = tertutup, 1 = terbuka, 2 = tersambung
var _first: int = -1  # slot pertama yang dibuka (-1 = belum ada)
var _pending: Array[int] = []  # dua slot salah yang menunggu ditutup lagi
var _lock: float = 0.0  # timer tutup-ulang
var _matched: int = 0

var _slots: Array[Panel] = []
var _slot_labels: Array[Label] = []
var _count_label: Label = null


func supports_shared() -> bool:
	return true


func get_shared_state() -> Dictionary:
	return {
		"cards": _cards.duplicate(),
		"state": _state.duplicate(),
		"first": _first,
		"pending": _pending.duplicate(),
		"lock": _lock,
		"matched": _matched,
		"done": _done,
		"status": _last_status,
		"status_good": _last_status_good,
	}


func apply_shared_state(s: Dictionary) -> void:
	_cards.clear()
	for v in (s.get("cards", []) as Array):
		_cards.append(int(v))
	_state.clear()
	for v in (s.get("state", []) as Array):
		_state.append(int(v))
	_first = int(s.get("first", -1))
	_pending.clear()
	for v in (s.get("pending", []) as Array):
		_pending.append(int(v))
	_lock = float(s.get("lock", 0.0))
	_matched = int(s.get("matched", 0))
	_done = bool(s.get("done", false))
	for i in range(_slots.size()):
		_refresh_slot(i)
	_count_label.text = "Tersambung: %d/4" % _matched


func setup() -> void:
	game_title = "Perbaiki Kabel LAN"
	instructions = "Kabel LAN acak-acakan. Buka dua ujung kabel (tekan 1-8): kalau warnanya sama, tersambung. Sambungkan keempat pasang."
	custom_minimum_size = Vector2(560, 240)
	_cards = [0, 0, 1, 1, 2, 2, 3, 3]
	_cards.shuffle()
	_state = [0, 0, 0, 0, 0, 0, 0, 0]
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	vbox.add_child(_mk_label("Buka dua ujung kabel dengan warna yang sama (tekan 1-8)", 16, Color(0.93, 0.89, 0.78)))
	for row in range(2):
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(hbox)
		for col in range(4):
			var i: int = row * 4 + col
			var slot := Panel.new()
			slot.custom_minimum_size = Vector2(120, 72)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(slot)
			var lbl := Label.new()
			lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(lbl)
			_slots.append(slot)
			_slot_labels.append(lbl)
			_refresh_slot(i)
	_count_label = _mk_label("Tersambung: 0/4", 18, Color(1, 0.9, 0.6))
	vbox.add_child(_count_label)


func handle_key(event: InputEventKey) -> void:
	if _done or _lock > 0.0:
		return
	var n: int = _pressed_slot(event)
	if n == 0:
		return
	var i: int = n - 1
	if _state[i] != 0:
		return
	_state[i] = 1
	_refresh_slot(i)
	if _first == -1:
		_first = i
		_set_status("Ujung %d dibuka: %s. Cari pasangannya!" % [n, COLOR_NAMES[_cards[i]]], true)
		return
	if _cards[_first] == _cards[i]:
		_state[_first] = 2
		_state[i] = 2
		_refresh_slot(_first)
		_refresh_slot(i)
		_matched += 1
		_first = -1
		_count_label.text = "Tersambung: %d/4" % _matched
		_set_status("Pasangan %s tersambung! (%d/4)" % [COLOR_NAMES[_cards[i]], _matched], true)
		if _matched >= PAIRS:
			_finish()
	else:
		_pending = [_first, i]
		_lock = FLIP_BACK_DELAY
		_first = -1
		_set_status("Bukan pasangan... tertutup lagi!", false)
		# SENGAJA tidak _report_mistake(): salah di task LAN Timur ini
		# biasa saja, tidak memanggil musuh (permintaan Edward 27 Nov).
		# Kartu tetap tertutup lagi + status "salah" di atas.


func tick(delta: float) -> void:
	if _done or _lock <= 0.0:
		return
	_lock -= delta
	if _lock <= 0.0:
		for i in _pending:
			_state[i] = 0
			_refresh_slot(i)
		_pending.clear()


func get_progress() -> float:
	return float(_matched) / float(PAIRS)


func debug_hint() -> Dictionary:
	if _first != -1:
		for j in range(_cards.size()):
			if j != _first and _state[j] == 0 and _cards[j] == _cards[_first]:
				return {"type": "lan", "next_slot": j + 1}
	return {"type": "lan"}


func _pressed_slot(event: InputEventKey) -> int:
	var n: int = _pressed_number(event)
	if n > 0:
		return n
	for k in range(5, 9):
		if event.keycode == KEY_5 + (k - 5) or event.keycode == KEY_KP_5 + (k - 5):
			return k
	return 0


func _refresh_slot(i: int) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	if _state[i] == 0:
		style.bg_color = Color(0.12, 0.12, 0.13)
		style.border_color = Color(0.35, 0.35, 0.38)
		_slot_labels[i].text = "%d\n?" % (i + 1)
		_slot_labels[i].add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	elif _state[i] == 1:
		style.bg_color = COLORS[_cards[i]]
		style.border_color = Color.WHITE
		_slot_labels[i].text = "%d\n%s" % [i + 1, COLOR_NAMES[_cards[i]]]
		_slot_labels[i].add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	else:
		style.bg_color = COLORS[_cards[i]]
		style.border_color = Color(0.35, 0.9, 0.4)
		_slot_labels[i].text = "%d\n%s ✓" % [i + 1, COLOR_NAMES[_cards[i]]]
		_slot_labels[i].add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_slots[i].add_theme_stylebox_override("panel", style)
