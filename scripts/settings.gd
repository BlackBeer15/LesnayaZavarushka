extends Node

## Настройки игры. Сохраняются в user://settings.cfg и применяются сразу.

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "audio"
const DEFAULT_VOLUME := 0.8

var master_volume := DEFAULT_VOLUME

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		master_volume = clampf(float(cfg.get_value(SECTION, "master_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	apply()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply()
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.save(CONFIG_PATH)

func apply() -> void:
	# linear_to_db(0) даёт -бесконечность, поэтому нулевая громкость = mute.
	var muted := master_volume <= 0.001
	AudioServer.set_bus_volume_db(0, -80.0 if muted else linear_to_db(master_volume))
	AudioServer.set_bus_mute(0, muted)
