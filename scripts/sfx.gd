extends Node

## Звуки выстрелов берутся из MP3-файлов в корне проекта, остальное генерируется.

const RATE := 22050
const SHOT_FILES := {
	"pistol": "res://assets/audio/Pistol.mp3",
	"silver": "res://assets/audio/revolver.mp3",
	"shotgun": "res://assets/audio/shotgun.mp3",
	"sniper": "res://assets/audio/sniper.mp3",
	"legend": "res://assets/audio/laser.mp3",
}
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0

func _ready() -> void:
	for weapon_id in SHOT_FILES.keys():
		var stream := ResourceLoader.load(SHOT_FILES[weapon_id], "AudioStream")
		if stream != null:
			streams["shot_" + weapon_id] = stream
	for _i in range(12):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		voices.append(p)
	streams["shot"] = _make_noise(0.16, 0.9, 220.0)
	streams["crit"] = _make_boom(0.65)
	streams["coin"] = _make_chirp(0.22, 760.0, 1480.0)
	streams["hit"] = _make_noise(0.09, 0.6, 900.0)
	streams["spin"] = _make_chirp(0.10, 380.0, 560.0)
	streams["hurt"] = _make_boom(0.28)
	streams["ability"] = _make_chirp(0.42, 180.0, 640.0)
	streams["reload"] = _make_reload()
	if GameData.debug_arg("--debug-state"):
		print("[SFX] streams=", streams.keys())

func play(name: String, volume: float = 0.7) -> void:
	if not streams.has(name) or voices.is_empty():
		return
	var p := voices[voice_index % voices.size()]
	voice_index += 1
	p.stream = streams[name]
	p.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	p.play()

func play_shot(weapon_id: String, volume: float = 0.8) -> void:
	if streams.has("shot_" + weapon_id):
		play("shot_" + weapon_id, volume)
	else:
		play("shot", volume)

func _make_noise(duration: float, decay: float, tone: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(RATE * duration)
	var last := 0.0
	for i in range(count):
		var t := float(i) / float(RATE)
		var env := pow(1.0 - float(i) / float(count), decay * 8.0)
		var noise := randf_range(-1.0, 1.0)
		last = lerp(last, noise, clampf(tone / 1000.0, 0.05, 0.95))
		var v := (noise * 0.7 + sin(t * 90.0) * 0.3) * env
		_append_sample(data, v)
	return _stream(data)

func _make_boom(duration: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(RATE * duration)
	for i in range(count):
		var t := float(i) / float(RATE)
		var env := pow(1.0 - float(i) / float(count), 3.0)
		var v := (sin(t * 74.0) * 0.6 + sin(t * 121.0) * 0.3 + randf_range(-0.3, 0.3)) * env
		_append_sample(data, v)
	return _stream(data)

func _make_reload() -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(RATE * 0.32)
	for i in range(count):
		var t := float(i) / float(RATE)
		var click1: float = exp(-pow((t - 0.03) * 60.0, 2.0))
		var click2: float = exp(-pow((t - 0.19) * 45.0, 2.0))
		var v := (randf_range(-0.5, 0.5) + sin(t * 900.0) * 0.4) * (click1 + click2) * 0.8
		_append_sample(data, v)
	return _stream(data)

func _make_chirp(duration: float, f0: float, f1: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(RATE * duration)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		var f := lerpf(f0, f1, t)
		phase += TAU * f / float(RATE)
		var env := sin(t * PI) * 0.7
		_append_sample(data, sin(phase) * env)
	return _stream(data)

func _append_sample(data: PackedByteArray, value: float) -> void:
	var v := int(clampf(value, -1.0, 1.0) * 30000.0)
	data.append(v & 0xFF)
	data.append((v >> 8) & 0xFF)

func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
