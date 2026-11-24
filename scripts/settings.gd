extends Node

## Настройки игры. Сохраняются в user://settings.cfg и применяются сразу.

const CONFIG_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_VIDEO := "video"
const SECTION_INPUT := "input"

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const RESOLUTION_NAMES := ["1280x720", "1600x900", "1920x1080"]
const SHADOW_NAMES := ["Выключены", "Низкие", "Средние", "Высокие"]
const MSAA_NAMES := ["Выкл", "2x", "4x"]
const MSAA_VALUES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

var master_volume := 0.8
var fullscreen := true
var resolution_index := 0
var vsync := true
var shadow_quality := 2
var msaa_index := 1
var mouse_sensitivity := 1.0
var invert_y := false

func _ready() -> void:
	_load()
	apply_all()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value(SECTION_AUDIO, "master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value(SECTION_VIDEO, "fullscreen", fullscreen))
	resolution_index = clampi(int(cfg.get_value(SECTION_VIDEO, "resolution", resolution_index)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(cfg.get_value(SECTION_VIDEO, "vsync", vsync))
	shadow_quality = clampi(int(cfg.get_value(SECTION_VIDEO, "shadows", shadow_quality)), 0, SHADOW_NAMES.size() - 1)
	msaa_index = clampi(int(cfg.get_value(SECTION_VIDEO, "msaa", msaa_index)), 0, MSAA_VALUES.size() - 1)
	mouse_sensitivity = clampf(float(cfg.get_value(SECTION_INPUT, "sensitivity", mouse_sensitivity)), 0.2, 3.0)
	invert_y = bool(cfg.get_value(SECTION_INPUT, "invert_y", invert_y))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION_AUDIO, "master_volume", master_volume)
	cfg.set_value(SECTION_VIDEO, "fullscreen", fullscreen)
	cfg.set_value(SECTION_VIDEO, "resolution", resolution_index)
	cfg.set_value(SECTION_VIDEO, "vsync", vsync)
	cfg.set_value(SECTION_VIDEO, "shadows", shadow_quality)
	cfg.set_value(SECTION_VIDEO, "msaa", msaa_index)
	cfg.set_value(SECTION_INPUT, "sensitivity", mouse_sensitivity)
	cfg.set_value(SECTION_INPUT, "invert_y", invert_y)
	cfg.save(CONFIG_PATH)

func apply_all() -> void:
	apply_audio()
	apply_video()

# ------------------------------------------------------------------ звук ---

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	_save()

func apply_audio() -> void:
	# linear_to_db(0) даёт -бесконечность, поэтому нулевая громкость = mute.
	var muted := master_volume <= 0.001
	AudioServer.set_bus_volume_db(0, -80.0 if muted else linear_to_db(master_volume))
	AudioServer.set_bus_mute(0, muted)

# --------------------------------------------------------------- графика ---

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_video()
	_save()

func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	apply_video()
	_save()

func set_vsync(value: bool) -> void:
	vsync = value
	apply_video()
	_save()

func set_shadow_quality(index: int) -> void:
	shadow_quality = clampi(index, 0, SHADOW_NAMES.size() - 1)
	apply_shadows()
	_save()

func set_msaa(index: int) -> void:
	msaa_index = clampi(index, 0, MSAA_VALUES.size() - 1)
	apply_video()
	_save()

func apply_video() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Vector2i = RESOLUTIONS[resolution_index]
		DisplayServer.window_set_size(res)
		var screen_pos := DisplayServer.screen_get_position()
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position(screen_pos + (screen_size - res) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = MSAA_VALUES[msaa_index]
	apply_shadows()

func apply_shadows() -> void:
	if GameState.world != null and GameState.world.has_method("apply_shadow_quality"):
		GameState.world.apply_shadow_quality(shadow_quality)

# ----------------------------------------------------------------- ввод ---

func set_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.2, 3.0)
	_save()

func set_invert_y(value: bool) -> void:
	invert_y = value
	_save()
