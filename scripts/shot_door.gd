extends Node
## Potret sekali jalan: buka Level 1, taruh pemain di depan Pintu A,
## simpan tangkapan layar viewport ke PNG.
## Dijalankan dengan tampilan virtual (bukan headless):
##   xvfb-run -a godot shot_door.tscn -- --mode=vert|horiz|open
## (JANGAN dijalankan dengan --headless: tidak ada gambar yang dirender.)
## Mode: vert = pintu vertikal tertutup (default),
##       horiz = pintu horizontal tertutup,
##       open = pintu vertikal terbuka.

var out_path: String = "/tmp/door_shot.png"


func _ready() -> void:
	var mode: String = "vert"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.trim_prefix("--mode=")
	if mode == "horiz":
		out_path = "/tmp/door_horiz.png"
	elif mode == "open":
		out_path = "/tmp/door_open.png"
	var level_scene: PackedScene = load("res://scenes/level_1.tscn")
	var level: Node = level_scene.instantiate()
	var door_a: Node = level.get_node("Doors/DoorA")
	if mode == "horiz":
		# Dicentang SEBELUM level masuk tree supaya _ready pintu
		# membangun visual horizontal.
		door_a.set("horizontal", true)
	add_child(level)
	for i in range(40):
		await get_tree().process_frame
	if mode == "open":
		door_a.open_door()
		for i in range(10):
			await get_tree().process_frame
	var players: Dictionary = level.get("_players")
	if players.is_empty():
		print("SHOT GAGAL: tidak ada pemain")
		get_tree().quit(1)
		return
	var pid: int = (players.keys() as Array)[0]
	var p: Node = players[pid]
	# Berdiri di depan Pintu A (304,864), menghadap pintu.
	(p as Node2D).global_position = Vector2(304, 905)
	for i in range(40):
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out_path)
	print("SHOT: ", out_path, " err=", err, " ukuran=", img.get_size())
	get_tree().quit()
