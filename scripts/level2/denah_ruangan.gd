extends CanvasLayer
## Denah ruangan Level 2 — seperti "denah evakuasi" yang ditempel di dekat
## colokan. Semuanya digambar dari kode (tanpa gambar).
##
## Aturan (diatur di level_2.gd):
## - Hanya bisa dibuka (tombol M) SAMBIL ngecas di titik cas yang punya
##   tanda denah. Ada 3 titik cas bertanda, dipilih acak; kalau titik itu
##   korslet, tandanya pindah ke titik cas lain yang siap.
## - Yang tampil cuma kotak ruangan + nama singkat, tanpa koridor.
## - Ruangan baru muncul di denah setelah pernah dimasuki salah satu pemain.
## - Tertutup sendiri kalau HP dicabut / berhenti ngecas. M atau Esc = tutup.

const F_MONO: Font = preload("res://assets/level2/fonts/lmmono10-regular.otf")
const F_MONO_TEBAL: Font = preload("res://assets/level2/fonts/lmmonolt10-bold.otf")

var level: Node = null

var _kertas: Control = null
var _terbuka: bool = false


func _ready() -> void:
	layer = 12  # di atas HUD malam (11): denah menutupi papan laporan & bar energi
	_kertas = _Kertas.new()
	_kertas.denah = self
	_kertas.font = F_MONO_TEBAL
	_kertas.font_tipis = F_MONO
	_kertas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kertas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kertas)
	visible = false


func is_terbuka() -> bool:
	return _terbuka


func buka() -> void:
	if _terbuka:
		return
	_terbuka = true
	visible = true
	_kertas.mulai()


func tutup() -> void:
	if not _terbuka:
		return
	_terbuka = false
	visible = false


func _input(event: InputEvent) -> void:
	if _terbuka and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		tutup()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _terbuka:
		_kertas.queue_redraw()


# ------------------------------------------------------------------ gambar
class _Kertas extends Control:
	const KERTAS := Color(0.93, 0.91, 0.85)
	const TINTA := Color(0.18, 0.22, 0.2)
	const HIJAU_EVAKUASI := Color(0.13, 0.47, 0.3)
	const MERAH := Color(0.82, 0.16, 0.12)

	var denah: Node = null
	var font: Font = null
	var font_tipis: Font = null
	var _waktu: float = 0.0
	var _muncul: float = 0.0  # animasi kertas "diangkat" saat dibuka

	func mulai() -> void:
		_muncul = 0.0

	func _process(delta: float) -> void:
		_waktu += delta
		_muncul = minf(1.0, _muncul + delta * 5.0)

	func _goyang(titik: Array, warna: Color, tebal: float, benih: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = benih
		var hasil := PackedVector2Array()
		for p: Vector2 in titik:
			hasil.append(p + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8)))
		draw_polyline(hasil, warna, tebal, true)

	func _draw() -> void:
		var lv: Node = denah.level if denah != null else null
		if lv == null:
			return
		var vp: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55 * _muncul))
		var ukuran_map: Vector2 = Vector2(lv.get_map_size_tiles())
		var s: float = minf(vp.x * 0.76 / ukuran_map.x, vp.y * 0.66 / ukuran_map.y)
		var isi: Vector2 = ukuran_map * s
		var kertas_ukuran: Vector2 = isi + Vector2(44, 98)
		var ease: float = 1.0 - pow(1.0 - _muncul, 3.0)
		var pusat: Vector2 = vp * 0.5 + Vector2(0, 30.0 * (1.0 - ease))
		draw_set_transform(pusat, deg_to_rad(-1.2), Vector2.ONE * (0.96 + 0.04 * ease))
		var o: Vector2 = -kertas_ukuran * 0.5
		# kertas + bayangan + selotip
		draw_rect(Rect2(o + Vector2(6, 8), kertas_ukuran), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(o, kertas_ukuran), KERTAS)
		for x: float in [o.x + 30.0, o.x + kertas_ukuran.x - 90.0]:
			draw_rect(Rect2(Vector2(x, o.y - 8), Vector2(60, 16)), Color(0.95, 0.93, 0.84, 0.75))
		# kepala kertas hijau ala denah evakuasi
		draw_rect(Rect2(o, Vector2(kertas_ukuran.x, 40)), HIJAU_EVAKUASI)
		draw_string(font, o + Vector2(18, 26), "DENAH LOBI  ·  LANTAI DASAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
		var info: Array = lv.get_info_ruangan()
		var ketemu: int = 0
		for r: Dictionary in info:
			if bool(r["terbuka"]):
				ketemu += 1
		draw_string(font, o + Vector2(kertas_ukuran.x - 18 - 220, 26), "%d / %d ruangan" % [ketemu, info.size()], HORIZONTAL_ALIGNMENT_RIGHT, 220, 13, Color(1, 1, 1, 0.85))
		var asal: Vector2 = o + Vector2(22, 56)
		# garis luar gedung (putus-putus, supaya tahu batas lobi)
		var luar := Rect2(asal, isi)
		draw_dashed_line(luar.position, Vector2(luar.end.x, luar.position.y), Color(TINTA, 0.25), 1.0, 6.0)
		draw_dashed_line(Vector2(luar.end.x, luar.position.y), luar.end, Color(TINTA, 0.25), 1.0, 6.0)
		draw_dashed_line(luar.end, Vector2(luar.position.x, luar.end.y), Color(TINTA, 0.25), 1.0, 6.0)
		draw_dashed_line(Vector2(luar.position.x, luar.end.y), luar.position, Color(TINTA, 0.25), 1.0, 6.0)
		# ruangan besar digambar dulu, ruangan kecil di atasnya
		var urut: Array = info.duplicate()
		urut.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Rect2i(a["kotak"]).get_area() > Rect2i(b["kotak"]).get_area())
		var i: int = 0
		for r: Dictionary in urut:
			i += 1
			if not bool(r["terbuka"]):
				continue
			var k: Rect2i = r["kotak"]
			var rect := Rect2(asal + Vector2(k.position) * s, Vector2(k.size) * s).grow(-1.5)
			var warna_isi: Color = Color(0.99, 0.93, 0.7) if bool(r["di_sini"]) else Color(0.84, 0.88, 0.82)
			draw_rect(rect, warna_isi)
			_goyang([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position], TINTA, 1.8, 500 + i)
			var ukuran_huruf: int = int(clampf(s * 1.15, 9.0, 14.0))
			draw_string(font, Vector2(rect.position.x, rect.get_center().y + ukuran_huruf * 0.35), str(r["pendek"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, ukuran_huruf, TINTA)
			if bool(r["ada_laporan"]):
				var c: Vector2 = rect.position + Vector2(12, 12)
				var denyut: float = 0.75 + 0.25 * sin(_waktu * 5.0)
				draw_circle(c, 8.0, Color(MERAH, denyut))
				draw_string(font, c + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
		# posisi pemain sendiri
		var p: Node2D = lv.get_local_player() as Node2D
		if p != null:
			var titik: Vector2 = asal + p.global_position / 32.0 * s
			draw_circle(titik, 4.5 + 1.5 * sin(_waktu * 6.0), Color(MERAH, 0.35))
			draw_circle(titik, 3.5, MERAH)
			# label dengan alas putih supaya tidak menabrak nama ruangan
			var lebar_label: float = font.get_string_size("KAMU DI SINI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var alas := Rect2(titik + Vector2(7, -16), Vector2(lebar_label + 8, 14))
			draw_rect(alas, Color(1, 1, 1, 0.92))
			draw_rect(alas, MERAH, false, 1.0)
			draw_string(font, alas.position + Vector2(4, 11), "KAMU DI SINI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MERAH)
		# kaki kertas
		var y_kaki: float = o.y + kertas_ukuran.y - 14
		draw_string(font_tipis, Vector2(o.x + 22, y_kaki), "Ruangan muncul setelah dimasuki salah satu dari kalian.   ! = ada laporan", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(TINTA, 0.75))
		draw_string(font_tipis, Vector2(o.x + kertas_ukuran.x - 22 - 200, y_kaki), "[M] / [Esc] tutup", HORIZONTAL_ALIGNMENT_RIGHT, 200, 11, Color(TINTA, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
