extends Node2D
## Komputer security di R. Security — Level 2 (tampilan saja).
##
## Logika (menyala, error, jam) ada di level_2.gd. Level memanggil
## set_status() di semua PC: MATI (layar standby biru berdenyut, supaya
## mudah ditemukan) sebelum dinyalakan pertama kali,
## NYALA saat denah aktif, ERROR saat kabel putus (layar berkedip merah).

enum Status { MATI, NYALA, ERROR }

const TEX_CAHAYA: Texture2D = preload("res://assets/sprites/light_soft.png")

var status: int = Status.MATI

var _layar: ColorRect = null
var _cahaya: PointLight2D = null
var _waktu: float = 0.0


func _ready() -> void:
	z_index = 6
	var bingkai := ColorRect.new()
	bingkai.color = Color(0.12, 0.12, 0.14)
	bingkai.size = Vector2(22, 16)
	bingkai.position = Vector2(-11, -14)
	add_child(bingkai)
	_layar = ColorRect.new()
	_layar.size = Vector2(18, 12)
	_layar.position = Vector2(-9, -12)
	add_child(_layar)
	var kaki := ColorRect.new()
	kaki.color = Color(0.12, 0.12, 0.14)
	kaki.size = Vector2(6, 4)
	kaki.position = Vector2(-3, 2)
	add_child(kaki)
	_cahaya = PointLight2D.new()
	_cahaya.name = "CahayaLayar"
	_cahaya.texture = TEX_CAHAYA
	_cahaya.position = Vector2(0, -6)
	add_child(_cahaya)
	_terapkan()


func set_status(baru: int) -> void:
	if baru == status:
		return
	status = baru
	_terapkan()


func _terapkan() -> void:
	if _layar == null:
		return
	match status:
		Status.MATI:
			# Layar standby biru muda yang berdenyut pelan supaya komputernya
			# mudah ditemukan di gelap (warnanya sama dengan busur penunjuk
			# komputer di HUD). Cahayanya lebih lebar dari lampu standby lama.
			_layar.color = Color(0.12, 0.25, 0.42)
			_cahaya.color = Color(0.45, 0.78, 1.0)
			_cahaya.texture_scale = 0.32
		Status.NYALA:
			_layar.color = Color(0.25, 0.55, 0.9)
			_cahaya.color = Color(0.45, 0.7, 1.0)
			_cahaya.texture_scale = 0.55
		Status.ERROR:
			_layar.color = Color(0.8, 0.1, 0.1)
			_cahaya.color = Color(1.0, 0.2, 0.15)
			_cahaya.texture_scale = 0.5


func _process(delta: float) -> void:
	_waktu += delta
	if _cahaya == null:
		return
	match status:
		Status.MATI:
			var denyut: float = 0.5 + 0.5 * sin(_waktu * TAU / 1.6)
			_cahaya.energy = 0.25 + 0.75 * denyut
			_layar.color = Color(0.12, 0.25, 0.42).lerp(Color(0.35, 0.62, 0.95), denyut)
		Status.NYALA:
			_cahaya.energy = 0.9 + 0.08 * sin(_waktu * 9.0)
		Status.ERROR:
			_cahaya.energy = 1.1 if fmod(_waktu, 0.4) < 0.2 else 0.1
