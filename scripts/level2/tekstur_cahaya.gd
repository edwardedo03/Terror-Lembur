extends RefCounted
## Tekstur cahaya Level 2, dibuat dari KODE saat game jalan (tidak ada file
## gambar). Dipanggil lewat preload: TeksturCahaya.lingkaran() dst.
## Hasilnya disimpan (cache) supaya hanya dibuat sekali.
##
## - lingkaran(): lingkaran pandang, putih di tengah lalu memudar halus
##   (rumus 1 - smoothstep, sama seperti versi PNG yang lama).
## - senter():    kerucut senter menghadap ke kanan (+X), lebar ±27°.
## - pertanda():  potongan cincin di tepi lingkaran pandang, menghadap ke
##   kanan (+X). Dipakai lampu merah "pertanda Satpam" (diputar ke arah
##   Satpam oleh level_2.gd).

const UKURAN: int = 256

static var _lingkaran: Texture2D = null
static var _senter: Texture2D = null
static var _pertanda: Texture2D = null


static func lingkaran() -> Texture2D:
	if _lingkaran != null:
		return _lingkaran
	var g := Gradient.new()
	var titik := PackedFloat32Array()
	var warna := PackedColorArray()
	for i: int in range(17):
		var x: float = i / 16.0
		titik.append(x)
		warna.append(Color(1, 1, 1, 1.0 - smoothstep(0.0, 1.0, x)))
	g.offsets = titik
	g.colors = warna
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = UKURAN
	t.height = UKURAN
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_lingkaran = t
	return t


static func senter() -> Texture2D:
	if _senter != null:
		return _senter
	var img := Image.create_empty(UKURAN, UKURAN, false, Image.FORMAT_RGBA8)
	var c: float = UKURAN * 0.5
	var panjang: float = c * 0.985
	for y: int in range(UKURAN):
		for x: int in range(UKURAN):
			var dx: float = x + 0.5 - c
			var dy: float = y + 0.5 - c
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = 0.0
			if dx > -12.0 and d < panjang:
				var sudut: float = absf(rad_to_deg(atan2(dy, maxf(dx, 0.001))))
				var jauh: float = pow(1.0 - d / panjang, 1.3)
				var pangkal: float = smoothstep(-12.0, 6.0, dx)
				var sisi: float = 1.0 - smoothstep(10.0, 28.0, sudut)
				a = jauh * pangkal * sisi
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_senter = ImageTexture.create_from_image(img)
	return _senter


static func pertanda() -> Texture2D:
	if _pertanda != null:
		return _pertanda
	var img := Image.create_empty(UKURAN, UKURAN, false, Image.FORMAT_RGBA8)
	var c: float = UKURAN * 0.5
	for y: int in range(UKURAN):
		for x: int in range(UKURAN):
			var dx: float = x + 0.5 - c
			var dy: float = y + 0.5 - c
			var r: float = sqrt(dx * dx + dy * dy) / c  # 0 di tengah, 1 di tepi
			# cincin di bagian gradasi lingkaran pandang (puncak ±0,68 jari-jari)
			var cincin: float = exp(-pow((r - 0.68) / 0.17, 2.0))
			var sudut: float = absf(rad_to_deg(atan2(dy, dx)))
			var busur: float = 1.0 - smoothstep(25.0, 70.0, sudut)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(cincin * busur, 0.0, 1.0)))
	_pertanda = ImageTexture.create_from_image(img)
	return _pertanda
