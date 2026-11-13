class_name SFX
extends Node

const MIX_RATE := 22050
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 12345
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_all()

func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound_name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	var p0: AudioStreamPlayer = _players[0]
	p0.stream = _streams[sound_name]
	p0.volume_db = volume_db
	p0.pitch_scale = pitch
	p0.play()

func _build_all() -> void:
	_streams["heartbeat"] = _heartbeat()
	_streams["tick"] = _tick()
	_streams["complete"] = _complete()
	_streams["sting"] = _sting()
	_streams["whisper"] = _whisper()
	_streams["alarm"] = _alarm()
	_streams["thud"] = _thud()
	_streams["pickup"] = _pickup()
	_streams["shout"] = _shout()
	_streams["step"] = _step()

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = data
	return wav

func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)

func _heartbeat() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var v := 0.0
		if t < 0.14:
			v += sin(TAU * 55.0 * t) * exp(-28.0 * t)
		if t >= 0.2 and t < 0.34:
			var t2 := t - 0.2
			v += 0.8 * sin(TAU * 50.0 * t2) * exp(-28.0 * t2)
		s[i] = v * 0.9
	return _to_wav(s)

func _tick() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.05)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		s[i] = sin(TAU * 1500.0 * t) * exp(-120.0 * t) * 0.5
	return _to_wav(s)

func _complete() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99]
	var note_dur := 0.15
	var n := int(MIX_RATE * note_dur * 3.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var idx := int(t / note_dur)
		var lt := t - float(idx) * note_dur
		s[i] = sin(TAU * notes[idx] * lt) * exp(-8.0 * lt) * 0.5
	return _to_wav(s)

func _sting() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 110.0 * t) + sin(TAU * 220.0 * t) + sin(TAU * 233.1 * t)
		v *= 0.25 * exp(-4.0 * t)
		if t < 0.1:
			v += _noise() * 0.5 * exp(-30.0 * t)
		s[i] = v
	return _to_wav(s)

func _whisper() -> AudioStreamWAV:
	var n := int(MIX_RATE * 1.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / MIX_RATE
		lp += 0.06 * (_noise() - lp)
		var trem := 0.5 + 0.5 * sin(TAU * 8.0 * t)
		var env := sin(PI * t) * trem
		s[i] = lp * env * 1.6
	return _to_wav(s)

func _alarm() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var f := 440.0 if t < 0.15 else 466.16
		s[i] = sin(TAU * f * t) * exp(-6.0 * t) * 0.5
	return _to_wav(s)

func _thud() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		s[i] = sin(TAU * 70.0 * t) * exp(-18.0 * t) * 0.9
	return _to_wav(s)

func _pickup() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var f := 660.0 if t < 0.09 else 990.0
		var lt := t if t < 0.09 else t - 0.09
		s[i] = sin(TAU * f * lt) * exp(-14.0 * lt) * 0.5
	return _to_wav(s)

func _shout() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 280.0 * t) * 0.5 * exp(-5.0 * t)
		v += _noise() * 0.4 * exp(-12.0 * t)
		s[i] = v
	return _to_wav(s)

func _step() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.07)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / MIX_RATE
		lp += 0.15 * (_noise() - lp)
		s[i] = lp * exp(-60.0 * t) * 1.4
	return _to_wav(s)
