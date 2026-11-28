class_name HudMalam
extends CanvasLayer
## HUD Level 2 — dibuat dari "benda-benda kantor", semuanya digambar dari
## kode (bentuk sederhana, tanpa gambar tambahan):
## - HP pemain (kiri bawah): baterai, jam, fase, notifikasi laporan,
##   tombol senter (R). Kalau baterai 0% layar HP mati -> jam & notifikasi
##   ikut hilang.
## - Papan laporan (kanan atas): menu dropdown beranimasi. Kertasnya
##   "menggulung" turun/naik. Turun sendiri beberapa detik kalau ada laporan
##   baru; Tab untuk buka / tutup kapan saja. Tiap baris: jam, nama alat,
##   ruangan & batas waktu.
## - ID card (kiri atas): status P1/P2 + garis baterai, cap DIKURUNG.
##   Kalau dua pemain sedang berdua (aman dari Satpam), kartunya dijepit
##   klip kertas.
## - Label Dymo (bawah tengah): tombol yang bisa ditekan sekarang.
## - Baris log merah (atas tengah): kejadian besar, diketik huruf demi huruf.
## - Bar energi lari (di atas kepala pemain sendiri): kecil & tipis, hanya
##   muncul saat lari / mengisi lagi.
## - Kotak debug (kanan bawah): hanya kalau debug di node Level2 dinyalakan.
## Dibuat oleh level_2.gd saat game mulai; datanya dibaca dari level.

const F_INTER_LIGHT: Font = preload("res://assets/level2/fonts/Inter-Light.otf")
const F_INTER: Font = preload("res://assets/level2/fonts/Inter-Medium.otf")
const F_INTER_TEBAL: Font = preload("res://assets/level2/fonts/Inter-SemiBold.otf")
const F_MONO: Font = preload("res://assets/level2/fonts/lmmono10-regular.otf")
const F_MONO_TEBAL: Font = preload("res://assets/level2/fonts/lmmonolt10-bold.otf")

const KUNING := Color(1.0, 0.745, 0.333)
const MERAH := Color(0.92, 0.31, 0.27)
const HIJAU := Color(0.47, 0.87, 0.55)
const TINTA := Color(0.925, 0.91, 0.88)
const REDUP := Color(0.59, 0.59, 0.635)

var level: Node = null
# Font disimpan juga sebagai variabel supaya bisa dipakai kelas-kelas di bawah.
var f_light: Font = F_INTER_LIGHT
var f_inter: Font = F_INTER
var f_tebal: Font = F_INTER_TEBAL
var f_mono: Font = F_MONO
var f_mono_tebal: Font = F_MONO_TEBAL

var notif: Array = []  # [{warna, app, judul, isi, waktu}] terbaru di depan
var prompt: String = ""
var debug_teks: String = ""
var debug_tag: bool = false
var log_antrian: Array = []  # [[teks, warna]]


func _ready() -> void:
	layer = 11
	_tambah(_KartuPemain.new(), "KartuPemain")
	_tambah(_PapanLaporan.new(), "PapanLaporan")
	_tambah(_HpPemain.new(), "HpPemain")
	_tambah(_LabelDymo.new(), "LabelDymo")
	_tambah(_LogLayar.new(), "LogLayar")
	_tambah(_KotakDebug.new(), "KotakDebug")
	_tambah(_PenandaBangkit.new(), "PenandaBangkit")
	# Busur kedua (biru muda) menunjuk komputer security sampai komputer
	# dinyalakan pertama kali (level_2.gd -> get_tujuan_komputer()).
	var penanda_komputer := _PenandaBangkit.new()
	penanda_komputer.warna = _PenandaBangkit.BIRU_KOMPUTER
	penanda_komputer.metode = "get_tujuan_komputer"
	_tambah(penanda_komputer, "PenandaKomputer")
	_tambah(_BarEnergi.new(), "BarEnergi")


func _tambah(w: Control, nama: String) -> void:
	w.name = nama
	w.set("hud", self)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w)


# ------------------------------------------------------------ API untuk level
func kabar(jenis: String, judul: String, isi: String = "") -> void:
	match jenis:
		"laporan":
			_notif(KUNING, "SISTEM GEDUNG", judul, isi)
		"beres":
			_notif(HIJAU, "SISTEM GEDUNG", "Beres: " + judul, isi)
		"bahaya":
			_notif(MERAH, "SISTEM GEDUNG", judul, isi)
			tulis_log(judul + ("  —  " + isi if isi != "" else ""), MERAH)
		"info":
			tulis_log(judul + ("  —  " + isi if isi != "" else ""), TINTA)
		_:
			# Pesan pribadi: muncul di HP; kalau HP mati jadi baris log abu-abu.
			if hp_hidup():
				_notif(REDUP, "HP", judul, isi)
			else:
				tulis_log(judul, REDUP)


func set_prompt(teks: String) -> void:
	prompt = teks


func set_debug(teks: String, tampil_tag: bool) -> void:
	debug_teks = teks
	debug_tag = tampil_tag


func tulis_log(teks: String, warna: Color) -> void:
	var jam: String = ""
	if level != null:
		jam = level.get_teks_jam()
	log_antrian.append(["> %s  %s" % [jam, teks.to_upper()], warna])
	while log_antrian.size() > 4:
		log_antrian.pop_front()


func hp_hidup() -> bool:
	if level == null:
		return false
	return level.get_baterai(NetworkManager.local_peer_id()) > 0.0


func _notif(warna: Color, app: String, judul: String, isi: String) -> void:
	notif.push_front({"warna": warna, "app": app, "judul": judul, "isi": isi, "waktu": Time.get_ticks_msec()})
	while notif.size() > 4:
		notif.pop_back()


# =========================================================== kelas dasar
class _Widget extends Control:
	var hud: Node = null

	func _process(_delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		queue_redraw()

	func _atur_posisi(_vp: Vector2) -> void:
		pass

	# Pemain di PC ini (dipakai bar energi & busur Item Bangkit).
	func _pemain() -> Node:
		if hud == null or hud.level == null:
			return null
		return hud.level.get_local_player()

	# true kalau denah / layar komputer sedang terbuka (penanda di atas
	# kepala tidak perlu tampil).
	func _ada_layar_penuh() -> bool:
		var lv: Node = hud.level if hud != null else null
		if lv == null:
			return false
		var dn: Node = lv.get("denah")
		if dn != null and dn.has_method("is_terbuka") and dn.is_terbuka():
			return true
		var lk: Node = lv.get("layar_komputer")
		return lk != null and lk.has_method("is_terbuka") and lk.is_terbuka()

	func kotak(r: Rect2, warna: Color, radius: float, tebal_garis: float = 0.0, warna_garis: Color = Color(0, 0, 0, 0)) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = warna
		sb.set_corner_radius_all(int(radius))
		if tebal_garis > 0.0:
			sb.set_border_width_all(int(tebal_garis))
			sb.border_color = warna_garis
		sb.anti_aliasing = true
		draw_style_box(sb, r)

	func teks(f: Font, pos: Vector2, s: String, ukuran: int, warna: Color) -> void:
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)

	func lebar_teks(f: Font, s: String, ukuran: int) -> float:
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran).x

	func teks_tengah(f: Font, pusat: Vector2, s: String, ukuran: int, warna: Color) -> void:
		var x: float = pusat.x - lebar_teks(f, s, ukuran) * 0.5
		draw_string(f, Vector2(x, pusat.y + f.get_ascent(ukuran) * 0.38), s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)

	func teks_kanan(f: Font, kanan: Vector2, s: String, ukuran: int, warna: Color) -> void:
		draw_string(f, Vector2(kanan.x - lebar_teks(f, s, ukuran), kanan.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran, warna)

	func pendekkan(f: Font, s: String, ukuran: int, lebar_maks: float) -> String:
		if lebar_teks(f, s, ukuran) <= lebar_maks:
			return s
		var t: String = s
		while t.length() > 1 and lebar_teks(f, t + "…", ukuran) > lebar_maks:
			t = t.substr(0, t.length() - 1)
		return t + "…"

	func goyang(titik: Array, warna: Color, tebal: float, benih: int) -> void:
		# Garis "tulisan tangan": tiap titik digeser sedikit (acak, tapi sama
		# tiap frame karena benihnya tetap).
		var rng := RandomNumberGenerator.new()
		rng.seed = benih
		var hasil := PackedVector2Array()
		for p: Vector2 in titik:
			hasil.append(p + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)))
		draw_polyline(hasil, warna, tebal, true)


# ================================================================ HP
class _HpPemain extends _Widget:
	var _t: float = 0.0

	func _ready() -> void:
		size = Vector2(168, 262)
		pivot_offset = size * 0.5
		rotation = deg_to_rad(-4.0)

	func _atur_posisi(vp: Vector2) -> void:
		position = Vector2(22.0, vp.y - 250.0)

	func _process(delta: float) -> void:
		_t += delta
		super._process(delta)

	func _draw() -> void:
		var lv: Node = hud.level
		if lv == null:
			return
		var w: float = size.x
		var h: float = size.y
		kotak(Rect2(5, 7, w, h), Color(0, 0, 0, 0.45), 26)
		kotak(Rect2(0, 0, w, h), Color(0.07, 0.07, 0.086), 26, 2, Color(0.27, 0.27, 0.31))
		var layar := Rect2(9, 9, w - 18, h - 18)
		var pid: int = NetworkManager.local_peer_id()
		var b: float = lv.get_baterai(pid)
		if b <= 0.0:
			_layar_mati(layar)
		else:
			_layar_hidup(layar, lv, pid, b)
		kotak(Rect2(w * 0.5 - 22, 14, 44, 6), Color(0.04, 0.04, 0.05), 3)

	func _layar_mati(r: Rect2) -> void:
		kotak(r, Color(0.024, 0.024, 0.03), 18)
		# pantulan kaca
		draw_colored_polygon(PackedVector2Array([
			r.position + Vector2(r.size.x * 0.55, 2), r.position + Vector2(r.size.x * 0.72, 2),
			r.position + Vector2(r.size.x * 0.25, r.size.y - 2), r.position + Vector2(r.size.x * 0.08, r.size.y - 2)]),
			Color(1, 1, 1, 0.025))
		var kedip: float = 1.0 if fmod(_t, 1.2) < 0.7 else 0.25
		var m := Color(0.92, 0.31, 0.27, kedip)
		var bx: float = r.position.x + r.size.x * 0.5 - 17.0
		var by: float = r.position.y + r.size.y * 0.34
		kotak(Rect2(bx, by, 30, 15), Color(0, 0, 0, 0), 3, 2, m)
		draw_rect(Rect2(bx + 31, by + 5, 3, 5), m)
		draw_rect(Rect2(bx + 3, by + 3, 3, 9), m)
		teks_tengah(hud.f_tebal, Vector2(r.position.x + r.size.x * 0.5, by + 33), "0%", 12, m)
		teks_tengah(hud.f_inter, Vector2(r.position.x + r.size.x * 0.5, by + 51), "colokkan pengisi daya", 9, Color(0.47, 0.47, 0.51))

	func _layar_hidup(r: Rect2, lv: Node, pid: int, b: float) -> void:
		kotak(r, Color(0.05, 0.063, 0.11), 18)
		kotak(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.42)), Color(0.15, 0.2, 0.34, 0.35), 18)
		var x0: float = r.position.x
		var y0: float = r.position.y
		var lw: float = r.size.x
		var putih := Color(0.86, 0.87, 0.92)
		# --- status bar
		teks(hud.f_inter, Vector2(x0 + 10, y0 + 15), "WiFi Kantor", 9, putih)
		var bx: float = x0 + lw - 30.0
		kotak(Rect2(bx, y0 + 7, 18, 9), Color(0, 0, 0, 0), 2, 1, putih)
		draw_rect(Rect2(bx + 19, y0 + 9.5, 1.5, 4), putih)
		var warna_b: Color = Color(0.47, 0.87, 0.55) if b >= 20.0 else Color(0.92, 0.31, 0.27)
		draw_rect(Rect2(bx + 1.5, y0 + 8.5, 15.0 * clampf(b / 100.0, 0.0, 1.0), 6), warna_b)
		teks_kanan(hud.f_tebal, Vector2(bx - 3, y0 + 15), "%d%%" % int(ceil(b)), 9, putih)
		var ngecas: bool = lv.get_area_cas(pid) != ""
		if ngecas:
			draw_colored_polygon(PackedVector2Array([Vector2(bx + 10, y0 + 6), Vector2(bx + 6, y0 + 12), Vector2(bx + 9, y0 + 12),
				Vector2(bx + 8, y0 + 17), Vector2(bx + 12, y0 + 11), Vector2(bx + 9, y0 + 11)]), Color.WHITE)
		# --- jam (titik di tengah berkedip saat jam berjalan)
		var menit: float = lv.get_jam_menit()
		var berhenti: bool = not lv.is_jam_berjalan()
		var warna_jam: Color = Color(0.94, 0.94, 0.97)
		if lv.get_teks_error() != "":
			warna_jam = Color(0.92, 0.31, 0.27)
		elif not lv.is_komputer_pernah():
			warna_jam = Color(0.55, 0.57, 0.65)
		var total: int = int(menit)
		var hh: String = "%02d" % ((21 + int(total / 60.0)) % 24)
		var mm: String = "%02d" % (total % 60)
		var uk: int = 38
		var w_hh: float = lebar_teks(hud.f_light, hh, uk)
		var w_tt: float = lebar_teks(hud.f_light, ".", uk)
		var w_mm: float = lebar_teks(hud.f_light, mm, uk)
		var xj: float = x0 + (lw - (w_hh + w_tt + w_mm)) * 0.5
		var yj: float = y0 + 62.0
		teks(hud.f_light, Vector2(xj, yj), hh, uk, warna_jam)
		var a_titik: float = 1.0 if (berhenti or fmod(_t, 1.0) < 0.5) else 0.15
		teks(hud.f_light, Vector2(xj + w_hh, yj), ".", uk, Color(warna_jam, a_titik))
		teks(hud.f_light, Vector2(xj + w_hh + w_tt, yj), mm, uk, warna_jam)
		teks_tengah(hud.f_inter, Vector2(x0 + lw * 0.5, y0 + 76), lv.get_teks_sub_hp(), 9, Color(0.67, 0.69, 0.77))
		var y: float = y0 + 88.0
		if ngecas:
			kotak(Rect2(x0 + lw * 0.5 - 40, y0 + 81, 80, 14), Color(0.24, 0.63, 0.35, 0.35), 7)
			teks_tengah(hud.f_tebal, Vector2(x0 + lw * 0.5, y0 + 88), "mengisi daya", 8, Color(0.67, 0.94, 0.75))
			y += 12.0
		# --- notifikasi (paling baru di atas, maks 2)
		var sekarang: int = Time.get_ticks_msec()
		var n: int = 0
		for d: Dictionary in hud.notif:
			if n >= 2:
				break
			kotak(Rect2(x0 + 7, y, lw - 14, 44), Color(1, 1, 1, 0.12), 10)
			var wi: Color = d["warna"]
			kotak(Rect2(x0 + 13, y + 7, 12, 12), wi, 3)
			teks_tengah(hud.f_tebal, Vector2(x0 + 19, y + 13), "!", 8, Color(0.08, 0.08, 0.1))
			teks(hud.f_tebal, Vector2(x0 + 30, y + 16), str(d["app"]), 7, Color(0.75, 0.76, 0.82))
			var umur: float = (sekarang - int(d["waktu"])) / 1000.0
			teks_kanan(hud.f_inter, Vector2(x0 + lw - 13, y + 16), "baru saja" if umur < 20.0 else "tadi", 7, Color(0.59, 0.61, 0.67))
			teks(hud.f_tebal, Vector2(x0 + 13, y + 30), pendekkan(hud.f_tebal, str(d["judul"]), 10, lw - 28), 10, Color(0.96, 0.96, 0.98))
			if str(d["isi"]) != "":
				teks(hud.f_inter, Vector2(x0 + 13, y + 40), pendekkan(hud.f_inter, str(d["isi"]), 8, lw - 28), 8, Color(0.73, 0.75, 0.8))
			y += 50.0
			n += 1
		# --- tombol senter (seperti di lock screen HP)
		var nyala: bool = lv.is_senter_nyala(pid)
		var c := Vector2(x0 + 24, r.end.y - 24)
		draw_circle(c, 15.0, Color(1.0, 0.745, 0.333) if nyala else Color(1, 1, 1, 0.15))
		var ikon: Color = Color(0.12, 0.09, 0.04) if nyala else Color(0.88, 0.88, 0.92)
		draw_rect(Rect2(c.x - 3, c.y - 2, 6, 11), ikon)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -9), c + Vector2(5, -9), c + Vector2(3, -2), c + Vector2(-3, -2)]), ikon)
		teks(hud.f_tebal, Vector2(c.x + 21, c.y + 4), "R", 10, Color(0.67, 0.69, 0.77))


# ================================================= papan laporan (dropdown)
class _PapanLaporan extends _Widget:
	const LEBAR: float = 236.0
	const TINGGI_KEPALA: float = 34.0
	const TINGGI_BARIS: float = 34.0
	const KERTAS := Color(0.957, 0.827, 0.369)
	const KERTAS_GELAP := Color(0.84, 0.7, 0.27)
	const COKLAT := Color(0.27, 0.2, 0.08)
	const MERAH_PENA := Color(0.78, 0.16, 0.14)
	const BIRU_PENA := Color(0.14, 0.27, 0.59)
	const DETIK_TURUN_SENDIRI: float = 5.0

	var _t: float = 0.0  # 0 = tergulung, 1 = terbuka penuh (bisa sedikit lebih karena pegas)
	var _kec: float = 0.0
	var _dipin: bool = false  # dibuka pakai Tab
	var _turun_sendiri: float = 0.0
	var _aktif_lama: Dictionary = {}
	var _waktu: float = 0.0

	func _ready() -> void:
		size = Vector2(LEBAR, 330)

	func _atur_posisi(vp: Vector2) -> void:
		position = Vector2(vp.x - LEBAR - 16.0, 10.0)

	func _unhandled_input(event: InputEvent) -> void:
		var k := event as InputEventKey
		if k != null and k.pressed and not k.echo and k.keycode == KEY_TAB:
			_dipin = not _dipin
			if not _dipin:
				_turun_sendiri = 0.0
			get_viewport().set_input_as_handled()

	func is_terbuka() -> bool:
		return _dipin or _turun_sendiri > 0.0

	func _process(delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		_waktu += delta
		# laporan baru -> kertas turun sendiri beberapa detik
		if hud != null and hud.level != null:
			for l: Dictionary in hud.level.get_info_laporan_semua():
				var kunci: String = str(l["nama"])
				var aktif: bool = str(l["status"]) == "aktif"
				if aktif and not bool(_aktif_lama.get(kunci, false)):
					_turun_sendiri = DETIK_TURUN_SENDIRI
				_aktif_lama[kunci] = aktif
		_turun_sendiri = maxf(0.0, _turun_sendiri - delta)
		# pegas teredam: sedikit memantul saat terbuka / tertutup
		var target: float = 1.0 if is_terbuka() else 0.0
		_kec += ((target - _t) * 120.0 - _kec * 14.0) * delta
		_t = clampf(_t + _kec * delta, -0.02, 1.08)
		queue_redraw()

	func _draw() -> void:
		var lv: Node = hud.level
		if lv == null:
			return
		var daftar: Array = lv.get_info_laporan_semua()
		var jumlah_aktif: int = 0
		for l: Dictionary in daftar:
			if str(l["status"]) == "aktif":
				jumlah_aktif += 1
		var w: float = LEBAR
		var atas: float = TINGGI_KEPALA - 6.0
		var tinggi_penuh: float = 16.0 + daftar.size() * TINGGI_BARIS + 20.0
		var tinggi: float = maxf(0.0, tinggi_penuh * _t)
		# --- kertas yang menggulung turun
		if tinggi > 2.0:
			var kiri: float = 10.0
			var kanan: float = w - 10.0
			var bawah: float = atas + tinggi
			var kertas := PackedVector2Array([Vector2(kiri, atas), Vector2(kanan, atas), Vector2(kanan, bawah - 3), Vector2(kiri + 1, bawah)])
			var bayang := PackedVector2Array()
			for p: Vector2 in kertas:
				bayang.append(p + Vector2(4, 5))
			draw_colored_polygon(bayang, Color(0, 0, 0, 0.35))
			draw_colored_polygon(kertas, KERTAS)
			var y: float = atas + 16.0
			var i: int = 0
			for l: Dictionary in daftar:
				if y + TINGGI_BARIS - 8.0 > bawah - 6.0:
					break  # baris ini belum "terbuka" oleh gulungan
				_baris(l, y, i)
				y += TINGGI_BARIS
				i += 1
			if atas + tinggi_penuh - 8.0 <= bawah:
				teks(hud.f_mono, Vector2(18, bawah - 8), "* wajib beres sebelum 05.00", 8, Color(0.47, 0.37, 0.16))
			# gulungan kertas di ujung bawah
			kotak(Rect2(kiri - 3, bawah - 4, kanan - kiri + 6, 9), KERTAS_GELAP, 4)
			draw_line(Vector2(kiri + 2, bawah - 2), Vector2(kanan - 2, bawah - 2), Color(1, 0.95, 0.75, 0.6), 1.0)
		else:
			# tergulung rapat di bawah papan
			kotak(Rect2(7, atas - 2, w - 14, 9), KERTAS_GELAP, 4)
			draw_line(Vector2(12, atas), Vector2(w - 12, atas), Color(1, 0.95, 0.75, 0.6), 1.0)
		# --- papan (clipboard) + penjepit
		kotak(Rect2(2, 4, w, TINGGI_KEPALA), Color(0, 0, 0, 0.35), 6)
		kotak(Rect2(0, 0, w, TINGGI_KEPALA), Color(0.42, 0.3, 0.17), 6, 1, Color(0.3, 0.2, 0.1))
		kotak(Rect2(w * 0.5 - 26, -5, 52, 13), Color(0.66, 0.67, 0.7), 4, 1, Color(0.45, 0.46, 0.5))
		kotak(Rect2(w * 0.5 - 9, -2, 18, 5), Color(0.42, 0.3, 0.17), 2)
		teks(hud.f_mono_tebal, Vector2(12, 24), "LAPORAN", 12, Color(0.98, 0.93, 0.8))
		if jumlah_aktif > 0:
			var label: String = "%d aktif" % jumlah_aktif
			var lb: float = lebar_teks(hud.f_mono_tebal, label, 10) + 12.0
			var denyut: float = 0.85 + 0.15 * sin(_waktu * 4.0)
			kotak(Rect2(78, 11, lb, 16), Color(MERAH_PENA.r, MERAH_PENA.g, MERAH_PENA.b, denyut), 8)
			teks(hud.f_mono_tebal, Vector2(84, 23), label, 10, Color(1, 0.95, 0.9))
		teks_kanan(hud.f_mono, Vector2(w - 26, 23), "Tab", 10, Color(0.98, 0.93, 0.8, 0.55))
		# panah ▾ berputar mengikuti buka/tutup
		var pusat := Vector2(w - 14, 17)
		var sudut: float = PI * clampf(_t, 0.0, 1.0)
		var panah := PackedVector2Array()
		for p: Vector2 in [Vector2(-5, -2.5), Vector2(5, -2.5), Vector2(0, 3.5)]:
			panah.append(pusat + p.rotated(sudut))
		draw_colored_polygon(panah, Color(0.98, 0.93, 0.8))

	func _baris(l: Dictionary, y: float, i: int) -> void:
		var w: float = LEBAR
		var st: String = str(l["status"])
		draw_line(Vector2(16, y + 22), Vector2(w - 16, y + 22), Color(0.84, 0.72, 0.31), 1.0)
		teks(hud.f_mono, Vector2(18, y + 5), str(l["jam"]), 10, Color(0.35, 0.27, 0.12))
		var x_nama: float = 62.0
		var lebar_maks: float = w - x_nama - 40.0
		if st == "belum":
			teks(hud.f_mono, Vector2(x_nama, y + 5), ". . . . . .", 10, Color(0.67, 0.55, 0.24))
			teks(hud.f_mono, Vector2(x_nama, y + 17), "belum ada laporan", 8, Color(0.6, 0.5, 0.25))
			return
		var nama: String = str(l["nama"]) + ("*" if bool(l["wajib"]) else "")
		teks(hud.f_mono_tebal, Vector2(x_nama, y + 5), pendekkan(hud.f_mono_tebal, nama, 11, lebar_maks), 11, Color(0.16, 0.125, 0.06))
		# baris kedua: ruangan (kiri) + batas waktu / keadaan (kanan)
		var kanan: String = "s/d " + str(l["batas"])
		if st == "beres":
			kanan = "beres"
		elif st == "telat":
			kanan = "TERLAMBAT"
		var warna_ket: Color = MERAH_PENA if st == "telat" else Color(0.4, 0.31, 0.13)
		var lebar_kanan: float = lebar_teks(hud.f_mono_tebal, kanan, 9)
		teks_kanan(hud.f_mono_tebal, Vector2(w - 16.0, y + 17), kanan, 9, warna_ket)
		var ruang: String = pendekkan(hud.f_mono, str(l["area"]), 9, w - 16.0 - lebar_kanan - 8.0 - x_nama)
		teks(hud.f_mono, Vector2(x_nama, y + 17), ruang, 9, Color(0.4, 0.31, 0.13))
		# kotak centang tulisan tangan
		var bx: float = w - 32.0
		goyang([Vector2(bx, y - 4), Vector2(bx + 11, y - 4.5), Vector2(bx + 11.5, y + 7), Vector2(bx, y + 7.5), Vector2(bx, y - 4)], Color(0.24, 0.18, 0.08), 1.3, 100 + i)
		if st == "aktif":
			var lingkar: Array = []
			for k: int in range(31):
				var a: float = 0.3 + (TAU + 0.3) * k / 30.0
				lingkar.append(Vector2(32 + 19 * cos(a), y + 1.5 + 8 * sin(a)))
			goyang(lingkar, MERAH_PENA, 1.4, 200 + i)
		elif st == "beres":
			goyang([Vector2(bx + 1, y + 1), Vector2(bx + 5, y + 6), Vector2(bx + 15, y - 8)], BIRU_PENA, 2.2, 300 + i)
		elif st == "telat":
			goyang([Vector2(x_nama - 4, y + 2), Vector2(bx - 6, y + 1)], MERAH_PENA, 2.0, 400 + i)
			teks(hud.f_mono_tebal, Vector2(bx + 15, y + 6), "!", 11, MERAH_PENA)


# =========================================================== ID card
class _KartuPemain extends _Widget:
	func _ready() -> void:
		size = Vector2(220, 120)

	func _atur_posisi(_vp: Vector2) -> void:
		position = Vector2.ZERO

	func _draw() -> void:
		var lv: Node = hud.level
		if lv == null:
			return
		var i: int = 0
		for p: Dictionary in lv.get_info_pemain():
			var cx: float = 40.0 + i * 62.0
			var pusat := Vector2(cx, 64)
			var sudut: float = deg_to_rad(-4.0 if i == 0 else 3.0)
			var tali := Color(0.16, 0.16, 0.19)
			draw_line(Vector2(cx - 10, 0), pusat + Vector2(0, -33).rotated(sudut), tali, 3.0, true)
			draw_line(Vector2(cx + 10, 0), pusat + Vector2(0, -33).rotated(sudut), tali, 3.0, true)
			draw_set_transform(pusat, sudut, Vector2.ONE)
			_kartu(p, i)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var status: String = str(p["status"])
			if status == "kurung" or status == "sembunyi":
				# Cap stempel miring di atas foto.
				var warna_cap: Color = Color(0.78, 0.16, 0.14, 0.92) if status == "kurung" else Color(0.3, 0.4, 0.6, 0.9)
				var kata: String = "DIKURUNG" if status == "kurung" else "SEMBUNYI"
				draw_set_transform(pusat + Vector2(0, -3).rotated(sudut), sudut - 0.3, Vector2.ONE)
				var lebar: float = lebar_teks(hud.f_mono_tebal, kata, 9) + 8.0
				draw_rect(Rect2(-lebar * 0.5, -8, lebar, 16), warna_cap, false, 1.6)
				teks_tengah(hud.f_mono_tebal, Vector2.ZERO, kata, 9, warna_cap)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			i += 1
		var info: Array = lv.get_info_pemain()
		if info.size() >= 2 and bool(info[0].get("aman", false)) and bool(info[1].get("aman", false)):
			_klip(Vector2(71, 44))

	func _klip(c: Vector2) -> void:
		# Klip kertas yang menjepit dua ID card = sedang berdua, aman dari Satpam.
		var logam := Color(0.78, 0.8, 0.84)
		var tebal: float = 1.8
		draw_arc(c + Vector2(-13, 0), 5.0, PI * 0.5, PI * 1.5, 12, logam, tebal, true)
		draw_arc(c + Vector2(14, 0), 5.0, -PI * 0.5, PI * 0.5, 12, logam, tebal, true)
		draw_line(c + Vector2(-13, -5), c + Vector2(14, -5), logam, tebal, true)
		draw_line(c + Vector2(-13, 5), c + Vector2(10, 5), logam, tebal, true)
		draw_arc(c + Vector2(10, 1.5), 3.5, PI * 0.5, PI * 1.5, 10, logam, tebal, true)
		draw_line(c + Vector2(10, -2), c + Vector2(-8, -2), logam, tebal, true)
		teks_tengah(hud.f_mono_tebal, c + Vector2(0, 15), "BERDUA", 8, Color(0.85, 0.9, 1.0, 0.85))

	func _kartu(p: Dictionary, i: int) -> void:
		var w: float = 54.0
		var h: float = 70.0
		var o := Vector2(-w * 0.5, -h * 0.5)
		var warna: Color = Color(0.31, 0.75, 0.67) if i == 0 else Color(0.43, 0.59, 0.94)
		var redup: float = 0.55 if str(p["status"]) == "sembunyi" else 1.0
		kotak(Rect2(o + Vector2(3, 4), Vector2(w, h)), Color(0, 0, 0, 0.4), 5)
		kotak(Rect2(o, Vector2(w, h)), Color(0.91 * redup, 0.9 * redup, 0.87 * redup), 5)
		draw_rect(Rect2(o + Vector2(0, 6), Vector2(w, 11)), Color(warna.r * redup, warna.g * redup, warna.b * redup))
		kotak(Rect2(o + Vector2(w * 0.5 - 7, 2), Vector2(14, 4)), Color(0.24, 0.24, 0.26), 2)
		var abu := Color(0.59 * redup, 0.59 * redup, 0.62 * redup)
		draw_circle(o + Vector2(w * 0.5, 28), 7.0, abu)
		draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.5 - 13, 50), o + Vector2(w * 0.5 - 10, 40), o + Vector2(w * 0.5, 37),
			o + Vector2(w * 0.5 + 10, 40), o + Vector2(w * 0.5 + 13, 50)]), abu)
		teks_tengah(hud.f_mono_tebal, o + Vector2(w * 0.5, 58), str(p["nama"]), 9, Color(0.16, 0.16, 0.18))
		var b: float = clampf(float(p["baterai"]) / 100.0, 0.0, 1.0)
		draw_rect(Rect2(o + Vector2(6, 63), Vector2((w - 12) * b, 2.5)), warna)


# =========================================================== label Dymo
class _LabelDymo extends _Widget:
	var _teks: String = ""

	func _atur_posisi(vp: Vector2) -> void:
		var t: String = str(hud.prompt).to_upper()
		_teks = t
		visible = t != ""
		var w: float = lebar_teks(hud.f_mono_tebal, t, 13) + 38.0
		size = Vector2(w, 32)
		pivot_offset = size * 0.5
		rotation = deg_to_rad(-1.2)
		position = Vector2(vp.x * 0.5 - w * 0.5, vp.y - 66.0)

	func _draw() -> void:
		if _teks == "":
			return
		var w: float = size.x
		var h: float = size.y
		var pita := PackedVector2Array([Vector2(6, 0), Vector2(w - 6, 0), Vector2(w, h * 0.5), Vector2(w - 6, h), Vector2(6, h), Vector2(0, h * 0.5)])
		var bayang := PackedVector2Array()
		for p: Vector2 in pita:
			bayang.append(p + Vector2(2, 4))
		draw_colored_polygon(bayang, Color(0, 0, 0, 0.5))
		draw_colored_polygon(pita, Color(0.086, 0.086, 0.1))
		teks_tengah(hud.f_mono_tebal, Vector2(w * 0.5 + 1, h * 0.5 + 1), _teks, 13, Color(0, 0, 0))
		teks_tengah(hud.f_mono_tebal, Vector2(w * 0.5, h * 0.5), _teks, 13, Color(0.93, 0.93, 0.94))


# ======================================================== log atas tengah
class _LogLayar extends _Widget:
	var _baris: String = ""
	var _warna: Color = Color.WHITE
	var _t: float = 0.0

	func _atur_posisi(vp: Vector2) -> void:
		size = Vector2(vp.x, 40)
		position = Vector2(0, 80)

	func _process(delta: float) -> void:
		if _baris == "" and not hud.log_antrian.is_empty():
			var item: Array = hud.log_antrian.pop_front()
			_baris = str(item[0])
			_warna = item[1]
			_t = 0.0
		if _baris != "":
			_t += delta
			if _t > _baris.length() / 45.0 + 4.5:
				_baris = ""
		super._process(delta)

	func _draw() -> void:
		if _baris == "":
			return
		var tampak: int = mini(_baris.length(), int(_t * 45.0))
		var s: String = _baris.substr(0, tampak)
		var lama_ketik: float = _baris.length() / 45.0
		var a: float = 1.0
		if _t > lama_ketik + 3.9:
			a = clampf(1.0 - (_t - lama_ketik - 3.9) / 0.6, 0.0, 1.0)
		var uk: int = 13
		var lebar_penuh: float = lebar_teks(hud.f_mono_tebal, _baris, uk)
		var x: float = size.x * 0.5 - lebar_penuh * 0.5
		draw_rect(Rect2(x - 12, 4, lebar_penuh + 34, 26), Color(0.04, 0, 0, 0.67 * a))
		teks(hud.f_mono_tebal, Vector2(x, 22), s, uk, Color(_warna, a))
		if fmod(_t, 0.8) < 0.5:
			var xk: float = x + lebar_teks(hud.f_mono_tebal, s, uk) + 4.0
			draw_rect(Rect2(xk, 9, 8, 16), Color(_warna, a))


# ============================================================ kotak debug
class _KotakDebug extends _Widget:
	func _atur_posisi(vp: Vector2) -> void:
		size = vp
		position = Vector2.ZERO

	func _draw() -> void:
		if hud.debug_tag:
			kotak(Rect2(size.x * 0.5 - 34, 6, 68, 18), Color(1.0, 0.8, 0.2, 0.9), 4)
			teks_tengah(hud.f_mono_tebal, Vector2(size.x * 0.5, 15), "DEBUG", 11, Color(0.1, 0.08, 0.02))
		if str(hud.debug_teks) == "":
			return
		var baris: PackedStringArray = str(hud.debug_teks).split("\n")
		var lebar: float = 0.0
		for b: String in baris:
			lebar = maxf(lebar, lebar_teks(hud.f_mono, b, 11))
		var tinggi: float = baris.size() * 14.0 + 12.0
		var x: float = size.x - lebar - 30.0
		var y: float = size.y - tinggi - 14.0
		kotak(Rect2(x - 8, y - 4, lebar + 24, tinggi), Color(0, 0, 0, 0.72), 6, 1, Color(1.0, 0.8, 0.2, 0.6))
		var yy: float = y + 10.0
		for b: String in baris:
			teks(hud.f_mono, Vector2(x + 4, yy), b, 11, Color(1.0, 0.9, 0.55))
			yy += 14.0


# ======================================================= bar energi lari
# Digambar di layar (bukan di dunia game) tepat di atas kepala pemain sendiri,
# jadi ukurannya tetap kecil walaupun kamera di-zoom dan tidak ikut gelap.
class _BarEnergi extends _Widget:
	# Bar energi lari kecil di atas kepala pemain lokal.
	# Warna dibuat kontras (kuning-amber + garis tepi gelap) supaya tetap
	# kelihatan di lantai yang terang kena lingkaran pandangan maupun di gelap.
	const LEBAR: float = 34.0
	const TINGGI: float = 4.0
	const DI_ATAS_KEPALA: float = -23.0  # titik di dunia game (px) relatif ke pemain
	const AMBER: Color = Color(1.0, 0.78, 0.18)  # sedang lari
	const AMBER_ISI: Color = Color(1.0, 0.86, 0.45)  # sedang mengisi (lebih pucat)
	const MERAH_HABIS: Color = Color(1.0, 0.27, 0.2)  # habis
	const TEPI: Color = Color(0.05, 0.04, 0.03)
	const BATAS_LARI: float = 0.3  # sama dengan ENERGI_MIN_LARI di player_level2.gd
	var _alpha: float = 0.0
	var _kedip: float = 0.0

	func _atur_posisi(vp: Vector2) -> void:
		size = vp
		position = Vector2.ZERO

	func _process(delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		queue_redraw()
		_kedip += delta
		var p: Node = _pemain()
		var perlu: bool = p != null and not p.is_hidden and not p.is_downed and not p.minigame_open \
			and not _ada_layar_penuh() and (p.is_sprinting or float(p.energi) < 0.999)
		# muncul cepat, hilang pelan setelah penuh
		_alpha = move_toward(_alpha, 1.0 if perlu else 0.0, delta * (6.0 if perlu else 1.5))

	func _draw() -> void:
		var p: Node2D = _pemain() as Node2D
		if p == null or _alpha <= 0.01:
			return
		var titik: Vector2 = p.get_global_transform_with_canvas() * Vector2(0, DI_ATAS_KEPALA)
		var r := Rect2(titik.x - LEBAR * 0.5, titik.y - TINGGI, LEBAR, TINGGI)
		# tepi gelap 1 px + dasar gelap supaya bar terbaca di latar apa pun
		kotak(r.grow(1.0), Color(TEPI, 0.8 * _alpha), 3)
		# jalur kosong: abu hangat; saat habis jadi merah tua supaya langsung terbaca
		var jalur: Color = Color(0.4, 0.09, 0.07) if p.energi_habis else Color(0.27, 0.24, 0.2)
		kotak(r, Color(jalur, 0.9 * _alpha), 2)
		var warna: Color
		if p.energi_habis:
			# habis: merah berdenyut sampai terisi 30% (baru boleh lari lagi)
			warna = Color(MERAH_HABIS, 0.75 + 0.25 * sin(_kedip * 9.0))
		elif p.is_sprinting:
			warna = Color(AMBER, 1.0)
		else:
			warna = Color(AMBER_ISI, 0.85)  # mengisi: sedikit lebih pucat, tetap kelihatan
		var isi: float = LEBAR * clampf(float(p.energi), 0.0, 1.0)
		if isi >= 1.0:
			kotak(Rect2(r.position, Vector2(isi, TINGGI)), Color(warna.r, warna.g, warna.b, warna.a * _alpha), 2)
		if p.energi_habis:
			# garis tipis di 30%: batas boleh lari lagi
			var x: float = r.position.x + LEBAR * BATAS_LARI
			draw_line(Vector2(x, r.position.y - 1.0), Vector2(x, r.end.y + 1.0), Color(1, 1, 1, 0.8 * _alpha), 1.0)


# ======================================================= PENANDA ITEM BANGKIT
class _PenandaBangkit extends _Widget:
	# Garis busur tipis hijau di tepi lingkaran pandang (seperti radar) yang
	# menunjuk ke Item Bangkit; setelah item diambil, menunjuk ke kurungan
	# teman. Mekanismenya sama dengan pertanda Satpam (arah + makin dekat
	# makin jelas, tembus tembok), tapi digambar sebagai garis di atas
	# kegelapan, jadi lantai tidak ikut berwarna. Hanya untuk pemain yang
	# bebas; tujuannya diambil dari level.get_tujuan_bangkit().
	# Kelas yang sama dipakai lagi untuk busur biru muda penunjuk komputer
	# security (warna & metode diganti, lihat _ready HudMalam).
	const HIJAU_BUSUR: Color = Color(0.27, 1.0, 0.47)
	const BIRU_KOMPUTER: Color = Color(0.45, 0.78, 1.0)
	const RADIUS_DUNIA: float = 50.0  # px dunia dari tengah pemain (±1,6 tile = tepi lingkaran pandang)
	const JARAK_PENUH: float = 48.0  # <= 1,5 tile: busur paling panjang & terang
	const JARAK_JAUH: float = 512.0  # >= 16 tile: busur paling pendek & tipis
	const KEKUATAN_MIN: float = 0.3  # walau jauh tetap kelihatan sedikit
	const TEBAL: float = 5.0  # px layar
	var warna: Color = HIJAU_BUSUR
	var metode: String = "get_tujuan_bangkit"  # fungsi level yang memberi {"ada", "pos"}
	var _waktu: float = 0.0
	var _alpha: float = 0.0
	var _kekuatan: float = 0.0
	var _sudut: float = 0.0

	func _atur_posisi(vp: Vector2) -> void:
		size = vp
		position = Vector2.ZERO

	func _process(delta: float) -> void:
		_atur_posisi(get_viewport().get_visible_rect().size)
		queue_redraw()
		_waktu += delta
		var p: Node2D = _pemain() as Node2D
		var tujuan: Dictionary = {}
		if hud != null and hud.level != null and hud.level.has_method(metode):
			var hasil: Variant = hud.level.call(metode)
			if hasil is Dictionary:
				tujuan = hasil
		var tampil: bool = p != null and bool(tujuan.get("ada", false)) and not p.is_hidden \
			and not p.minigame_open and not _ada_layar_penuh()
		if tampil:
			var arah: Vector2 = (tujuan["pos"] as Vector2) - p.global_position
			var t: float = clampf(1.0 - (arah.length() - JARAK_PENUH) / (JARAK_JAUH - JARAK_PENUH), 0.0, 1.0)
			_kekuatan = KEKUATAN_MIN + (1.0 - KEKUATAN_MIN) * pow(t, 1.2)
			if arah.length() > 1.0:
				if _alpha <= 0.01:
					_sudut = arah.angle()  # baru muncul: langsung ke arah yang benar
				else:
					_sudut = lerp_angle(_sudut, arah.angle(), minf(1.0, delta * 10.0))
		_alpha = move_toward(_alpha, 1.0 if tampil else 0.0, delta * 3.0)

	func get_kekuatan() -> float:
		# Untuk smoke test & debug (0 = tidak tampil).
		return _kekuatan * _alpha

	func _draw() -> void:
		var p: Node2D = _pemain() as Node2D
		if p == null or _alpha <= 0.01:
			return
		var xf: Transform2D = p.get_global_transform_with_canvas()
		var pusat: Vector2 = xf.origin
		var r: float = RADIUS_DUNIA * xf.get_scale().x
		# makin dekat makin panjang: setengah busur 10° (jauh) s/d 32° (dekat)
		var setengah: float = deg_to_rad(10.0 + 22.0 * _kekuatan)
		var napas: float = 0.82 + 0.18 * sin(_waktu * 2.5)  # denyut pelan (merah Satpam berdenyut cepat)
		var a: float = (0.3 + 0.7 * _kekuatan) * napas * _alpha
		var mulai: float = _sudut - setengah
		var akhir: float = _sudut + setengah
		# garis tepi gelap dulu supaya terbaca di lantai terang maupun gelap
		draw_arc(pusat, r, mulai, akhir, 32, Color(0, 0, 0, 0.6 * a), TEBAL * 2.0, true)
		draw_arc(pusat, r, mulai, akhir, 32, Color(warna, a), TEBAL, true)
		for ujung: float in [mulai, akhir]:
			draw_circle(pusat + Vector2.from_angle(ujung) * r, TEBAL * 0.5, Color(warna, a))
