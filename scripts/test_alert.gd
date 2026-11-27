extends SceneTree
## Tes matematika alert tepi layar (mirror dari _update_enemy_alert di
## hud.gd — rumus yang sama persis, disalin ke sini karena hud.gd tidak
## bisa di-load di mode -s: ia merujuk autoload NetworkManager).
## Dijalankan: godot --headless -s test_alert.gd

const ALERT_RANGE: float = 320.0
const ALERT_MAX_ALPHA: float = 0.55

var _failures: Array[String] = []


func _alphas(d: Vector2, chasing: bool, t: float) -> Dictionary:
	var a := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var dist: float = d.length()
	if dist < ALERT_RANGE and dist > 1.0:
		var k: float = 1.0 - dist / ALERT_RANGE
		var ax: float = absf(d.x)
		var ay: float = absf(d.y)
		var s: float = ax + ay
		if s > 0.0:
			var w: float = k * ALERT_MAX_ALPHA
			if d.x > 0.0:
				a["right"] = w * ax / s
			elif d.x < 0.0:
				a["left"] = w * ax / s
			if d.y > 0.0:
				a["bottom"] = w * ay / s
			elif d.y < 0.0:
				a["top"] = w * ay / s
			if chasing:
				var pulse: float = 0.85 + 0.15 * sin(t * 6.0)
				for key: String in a.keys():
					a[key] = (a[key] as float) * pulse
	return a


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: ", msg)
	else:
		_failures.append(msg)
		print("FAIL: ", msg)


func _init() -> void:
	# 1. Musuh di luar jangkauan (400px) -> semua 0.
	var a1: Dictionary = _alphas(Vector2(400, 0), false, 0.0)
	_check(a1["right"] == 0.0 and a1["top"] == 0.0, "400px kanan: alert mati")

	# 2. Musuh 160px di kanan (setengah jangkauan) -> kanan 0.275, sisanya 0.
	var a2: Dictionary = _alphas(Vector2(160, 0), false, 0.0)
	_check(absf((a2["right"] as float) - 0.275) < 0.001 and (a2["left"] as float) == 0.0 and (a2["top"] as float) == 0.0 and (a2["bottom"] as float) == 0.0, "160px kanan: kanan=0.275, lain 0 (dapat %.3f)" % (a2["right"] as float))

	# 3. Musuh 80px di kiri -> kiri ~0.4125.
	var a3: Dictionary = _alphas(Vector2(-80, 0), false, 0.0)
	_check(absf((a3["left"] as float) - 0.4125) < 0.001, "80px kiri: kiri=0.4125 (dapat %.4f)" % (a3["left"] as float))

	# 4. Musuh diagonal 100px kanan-bawah (100,100): jarak ~141px, t~0.558,
	#    kanan & bawah masing-masing ~0.153.
	var a4: Dictionary = _alphas(Vector2(100, 100), false, 0.0)
	_check(absf((a4["right"] as float) - 0.1534) < 0.002 and absf((a4["bottom"] as float) - 0.1534) < 0.002 and (a4["top"] as float) == 0.0 and (a4["left"] as float) == 0.0, "diagonal kanan-bawah: kanan=bawah~0.153 (dapat %.4f/%.4f)" % [(a4["right"] as float), (a4["bottom"] as float)])

	# 5. Musuh 32px di atas -> atas ~0.495 (maksimal mendekati 0.55).
	var a5: Dictionary = _alphas(Vector2(0, -32), false, 0.0)
	_check(absf((a5["top"] as float) - 0.495) < 0.001 and (a5["bottom"] as float) == 0.0, "32px atas: atas=0.495 (dapat %.4f)" % (a5["top"] as float))

	# 6. CHASE: denyut 0.85 + 0.15*sin -> tetap dalam 0.70..1.00 dari nilai dasar.
	var base: Dictionary = _alphas(Vector2(160, 0), false, 0.0)
	var lo: float = 1.0
	var hi: float = 0.0
	for i in range(21):
		var ap: Dictionary = _alphas(Vector2(160, 0), true, float(i) * 0.2)
		lo = minf(lo, (ap["right"] as float) / (base["right"] as float))
		hi = maxf(hi, (ap["right"] as float) / (base["right"] as float))
	_check(lo >= 0.699 and hi <= 1.001, "denyut CHASE dalam 0.70..1.00 (dapat %.3f..%.3f)" % [lo, hi])

	# 7. Musuh tepat di pemain (dist 0) -> guard, alert mati.
	var a7: Dictionary = _alphas(Vector2.ZERO, false, 0.0)
	_check((a7["right"] as float) == 0.0 and (a7["top"] as float) == 0.0, "dist 0: alert mati (guard)")

	if _failures.is_empty():
		print("SEMUA TES ALERT LULUS")
		quit(0)
	else:
		print("GAGAL: ", _failures.size(), " kegagalan")
		quit(1)
