extends MinigameBase
## Sambung Kabel — minigame perbaikan error komputer security (Level 2).
## 4 kabel berwarna di kiri harus dicolok ke lubang berwarna sama di kanan
## (urutan lubang diacak). Kabel disambung satu per satu dari atas: tekan
## angka 1-4 = nomor lubang yang warnanya sama. Waktu 8 detik; kalau habis,
## lubang diacak ulang dan mulai lagi dari awal. Salah colok = waktu -1 detik.

const WAKTU: float = 8.0
const NAMA: Array[String] = ["MERAH", "BIRU", "KUNING", "HIJAU"]
const WARNA: Array[Color] = [Color(0.95, 0.3, 0.3), Color(0.35, 0.6, 1.0), Color(0.98, 0.88, 0.3), Color(0.4, 0.92, 0.45)]

var _lubang: Array[int] = []  # _lubang[i] = warna di lubang nomor i+1
var _ke: int = 0  # kabel ke berapa yang sedang disambung (0..3)
var _sisa: float = WAKTU

var _kabel_labels: Array[Label] = []
var _lubang_rects: Array[ColorRect] = []
var _waktu_label: Label = null
var _petunjuk_label: Label = null


func setup() -> void:
	game_title = "Sambung Kabel"
	instructions = "Colok kabel kiri ke lubang yang WARNANYA SAMA. Tekan angka 1-4 (nomor lubang). Waktu 8 detik!"
	custom_minimum_size = Vector2(560, 240)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	_waktu_label = _mk_label("", 20, Color(1, 0.9, 0.6))
	vbox.add_child(_waktu_label)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 70)
	vbox.add_child(hbox)
	var kiri := VBoxContainer.new()
	kiri.add_theme_constant_override("separation", 6)
	hbox.add_child(kiri)
	for i: int in range(4):
		var l := _mk_label("", 17, WARNA[i])
		l.custom_minimum_size = Vector2(190, 26)
		kiri.add_child(l)
		_kabel_labels.append(l)
	var kanan := VBoxContainer.new()
	kanan.add_theme_constant_override("separation", 6)
	hbox.add_child(kanan)
	for i: int in range(4):
		var baris := HBoxContainer.new()
		baris.add_theme_constant_override("separation", 8)
		kanan.add_child(baris)
		var nomor := _mk_label("[%d]" % (i + 1), 17, Color(0.75, 0.9, 1))
		baris.add_child(nomor)
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(60, 24)
		baris.add_child(r)
		_lubang_rects.append(r)
	_petunjuk_label = _mk_label("", 17, Color(0.9, 0.9, 0.95))
	vbox.add_child(_petunjuk_label)
	_acak_ulang()


func handle_key(event: InputEventKey) -> void:
	if _done:
		return
	var n: int = _pressed_number(event)
	if n < 1 or n > 4:
		return
	if _lubang[n - 1] == _ke:
		_ke += 1
		if _ke >= 4:
			_set_status("Semua kabel tersambung! Komputer menyala lagi.", true)
			_refresh()
			_finish()
			return
		_set_status("Klik! Kabel tersambung.", true)
	else:
		_sisa = maxf(0.0, _sisa - 1.0)
		_set_status("Salah lubang! Waktu -1 detik.", false)
	_refresh()


func tick(delta: float) -> void:
	if _done:
		return
	_sisa -= delta
	if _sisa <= 0.0:
		_set_status("Waktu habis! Lubang teracak lagi, ulangi dari awal.", false)
		_acak_ulang()
	_waktu_label.text = "Sisa waktu: %.1f detik" % maxf(0.0, _sisa)


func get_progress() -> float:
	return float(_ke) / 4.0


func debug_hint() -> Dictionary:
	# Nomor lubang yang benar untuk kabel yang sedang disambung.
	for i: int in range(4):
		if _lubang[i] == _ke:
			return {"keycode": KEY_1 + i}
	return {}


func _acak_ulang() -> void:
	_lubang = [0, 1, 2, 3]
	_lubang.shuffle()
	_ke = 0
	_sisa = WAKTU
	_refresh()


func _refresh() -> void:
	for i: int in range(4):
		var tanda: String = "  ✓" if i < _ke else ("  ←" if i == _ke else "")
		_kabel_labels[i].text = "Kabel %s%s" % [NAMA[i], tanda]
		_lubang_rects[i].color = WARNA[_lubang[i]]
	if _ke < 4:
		_petunjuk_label.text = "Sekarang: kabel %s → tekan nomor lubang %s" % [NAMA[_ke], NAMA[_ke].to_lower()]
	else:
		_petunjuk_label.text = "Tersambung semua!"
