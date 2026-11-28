extends Node2D
## Titik cas HP (colokan di dinding/meja) — Level 2.
##
## Node ini hanya tampilan. Logika ngecas (siapa yang ngecas, korslet,
## mati karena genset) dimiliki level_2.gd di host, lalu level memanggil
## set_status() di semua PC. Lampu indikator kecil tetap menyala di gelap
## supaya colokan bisa ditemukan kalau pemain sudah cukup dekat.
## Titik cas yang sedang punya DENAH diberi tanda kertas denah kecil
## (digambar dari kode) lewat set_ada_denah().

enum Status { SIAP, DIPAKAI, KORSLET, MATI }

const TEX_CAHAYA: Texture2D = preload("res://assets/sprites/light_soft.png")
const WARNA: Dictionary = {
	Status.SIAP: Color(0.35, 1.0, 0.45),
	Status.DIPAKAI: Color(1.0, 0.85, 0.25),
	Status.KORSLET: Color(1.0, 0.25, 0.2),
	Status.MATI: Color(0.25, 0.25, 0.25),
}

## Nama area yang muncul di pesan & layar komputer.
@export var nama_area: String = "Titik cas"
## Fase 4 (Subuh, 04.00–05.00) hanya titik cas yang dicentang ini yang masih berfungsi.
@export var aktif_saat_subuh: bool = false

var status: int = Status.SIAP

var ada_denah: bool = false
var _led: ColorRect = null
var _ikon_denah: Node2D = null
var _indikator: PointLight2D = null
var _waktu: float = 0.0


func _ready() -> void:
	z_index = 6
	var pelat := ColorRect.new()
	pelat.color = Color(0.82, 0.82, 0.78)
	pelat.size = Vector2(12, 16)
	pelat.position = Vector2(-6, -8)
	add_child(pelat)
	for i: int in range(2):
		var lubang := ColorRect.new()
		lubang.color = Color(0.15, 0.15, 0.15)
		lubang.size = Vector2(2, 4)
		lubang.position = Vector2(-3 + i * 4, -5)
		add_child(lubang)
	_led = ColorRect.new()
	_led.size = Vector2(4, 3)
	_led.position = Vector2(-2, 3)
	add_child(_led)
	_indikator = PointLight2D.new()
	_indikator.name = "Indikator"
	_indikator.texture = TEX_CAHAYA
	_indikator.texture_scale = 0.22
	add_child(_indikator)
	_ikon_denah = _IkonDenah.new()
	_ikon_denah.name = "TandaDenah"
	_ikon_denah.position = Vector2(13, -6)
	_ikon_denah.visible = false
	add_child(_ikon_denah)
	# cahaya kecil supaya tanda denah kelihatan di gelap (ikut sembunyi bersama ikon)
	var cahaya_ikon := PointLight2D.new()
	cahaya_ikon.texture = TEX_CAHAYA
	cahaya_ikon.texture_scale = 0.12
	cahaya_ikon.color = Color(0.95, 0.9, 0.75)
	cahaya_ikon.energy = 0.6
	_ikon_denah.add_child(cahaya_ikon)
	_terapkan()


func set_status(baru: int) -> void:
	if baru == status:
		return
	status = baru
	_terapkan()


func set_ada_denah(ada: bool) -> void:
	if ada == ada_denah:
		return
	ada_denah = ada
	if _ikon_denah != null:
		_ikon_denah.visible = ada


func _terapkan() -> void:
	if _led == null:
		return
	var w: Color = WARNA.get(status, Color.WHITE)
	_led.color = w
	_indikator.color = w
	_indikator.enabled = status != Status.MATI


func _process(delta: float) -> void:
	_waktu += delta
	if _indikator == null:
		return
	match status:
		Status.SIAP:
			_indikator.energy = 0.55
		Status.DIPAKAI:
			# Saat ngecas lampunya terang & berdenyut (bisa terlihat Satpam).
			_indikator.energy = 1.3 + 0.4 * sin(_waktu * 6.0)
			_indikator.texture_scale = 0.4
		Status.KORSLET:
			_indikator.energy = 0.9 if fmod(_waktu, 0.5) < 0.25 else 0.15
			_indikator.texture_scale = 0.22
		_:
			_indikator.energy = 0.0
	if status != Status.DIPAKAI:
		_indikator.texture_scale = 0.22


# Tanda "ada denah": kertas denah terlipat 3 dengan titik merah "Anda di sini".
class _IkonDenah extends Node2D:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		position.y = -6.0 + sin(_t * 3.0) * 1.0  # mengambang pelan supaya menarik perhatian
		queue_redraw()

	func _draw() -> void:
		var kertas := Color(0.9, 0.88, 0.8)
		var lipat := Color(0.72, 0.7, 0.62)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -4), Vector2(-2, -5), Vector2(-2, 4), Vector2(-6, 5)]), kertas)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -5), Vector2(2, -4), Vector2(2, 5), Vector2(-2, 4)]), lipat)
		draw_colored_polygon(PackedVector2Array([Vector2(2, -4), Vector2(6, -5), Vector2(6, 4), Vector2(2, 5)]), kertas)
		draw_line(Vector2(-5, -1), Vector2(-3, -1), Color(0.3, 0.45, 0.6), 1.0)
		draw_line(Vector2(3, 1), Vector2(5, 1), Color(0.3, 0.45, 0.6), 1.0)
		draw_circle(Vector2(0, 0), 1.3, Color(0.85, 0.15, 0.1))
