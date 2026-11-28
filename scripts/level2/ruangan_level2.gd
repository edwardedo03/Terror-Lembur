extends RefCounted
## Data ruangan Level 2 untuk DENAH (charger) dan layar komputer security.
## Posisi dalam TILE: Rect2i(kolom kiri, baris atas, lebar, tinggi).
## Urutan penting: ruangan kecil yang ada DI DALAM ruangan besar (R. Tunggu
## di dalam Atrium) ditulis lebih dulu, supaya pemain yang berdiri di sana
## tercatat di ruangan kecilnya.
## Koridor (Selasar, jalan ke kafe di kiri bawah atrium) sengaja tidak
## dimasukkan: denah hanya kotak ruangan.
## Kalau map diubah, cukup sesuaikan angka di sini.

const DAFTAR: Array = [
	{"nama": "Ruang Tunggu Tamu", "pendek": "R. Tunggu", "kotak": Rect2i(53, 13, 8, 6)},
	{"nama": "Tangga Darurat", "pendek": "Tangga", "kotak": Rect2i(1, 3, 8, 9)},
	{"nama": "Ruang Surat", "pendek": "R. Surat", "kotak": Rect2i(10, 3, 9, 9)},
	{"nama": "Resepsionis", "pendek": "Resepsionis", "kotak": Rect2i(20, 3, 10, 9)},
	{"nama": "Vestibul Kaca", "pendek": "Vestibul", "kotak": Rect2i(31, 1, 10, 11)},
	{"nama": "R. Security", "pendek": "Security", "kotak": Rect2i(42, 3, 10, 9)},
	{"nama": "Ruang IT", "pendek": "R. IT", "kotak": Rect2i(53, 3, 9, 9)},
	{"nama": "Lorong Servis", "pendek": "Servis", "kotak": Rect2i(63, 3, 8, 9)},
	{"nama": "Lobi Lift", "pendek": "Lobi Lift", "kotak": Rect2i(1, 13, 10, 9)},
	{"nama": "Galeri", "pendek": "Galeri", "kotak": Rect2i(12, 12, 8, 12)},
	{"nama": "Atrium Lobi Utama", "pendek": "Atrium", "kotak": Rect2i(20, 12, 41, 18)},
	{"nama": "Coworking", "pendek": "Coworking", "kotak": Rect2i(62, 13, 9, 17)},
	{"nama": "Kafe & Game", "pendek": "Kafe", "kotak": Rect2i(1, 25, 15, 20)},
	{"nama": "Area Acara", "pendek": "Area Acara", "kotak": Rect2i(17, 30, 18, 15)},
	{"nama": "R. Rapat Tamu", "pendek": "R. Rapat", "kotak": Rect2i(36, 31, 9, 14)},
	{"nama": "Pojok Baca", "pendek": "Pojok Baca", "kotak": Rect2i(46, 31, 9, 14)},
	{"nama": "Gudang & Janitor", "pendek": "Gudang", "kotak": Rect2i(56, 31, 15, 14)},
]


## Indeks ruangan di sel tile ini, -1 kalau di koridor / luar ruangan.
static func indeks_di(sel: Vector2i) -> int:
	for i: int in range(DAFTAR.size()):
		var k: Rect2i = DAFTAR[i]["kotak"]
		if k.has_point(sel):
			return i
	return -1
