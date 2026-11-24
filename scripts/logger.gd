extends Node

## Простой лог файл в user://logs/game.log и окно с понятным сообщением об ошибке.

const LOG_DIR := "user://logs"
const LOG_FILE := "user://logs/game.log"

var _file: FileAccess = null
var _error_layer: CanvasLayer = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	info("Игра запущена")

func _exit_tree() -> void:
	if _file != null and _file.is_open():
		_file.flush()
		_file.close()

func info(text: String) -> void:
	_write("INFO", text)

func warn(text: String) -> void:
	_write("WARN", text)

func error(text: String) -> void:
	_write("ERROR", text)

func _write(level: String, text: String) -> void:
	var line := "[%s][%s] %s" % [Time.get_datetime_string_from_system(), level, text]
	print(line)
	if _file != null and _file.is_open():
		_file.store_line(line)
		_file.flush()

func show_error(title: String, text: String) -> void:
	error("%s: %s" % [title, text])
	if _error_layer != null and is_instance_valid(_error_layer):
		_error_layer.queue_free()
	_error_layer = CanvasLayer.new()
	_error_layer.layer = 200
	add_child(_error_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.75)
	_error_layer.add_child(shade)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-320, -130)
	panel.size = Vector2(640, 260)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.30, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_error_layer.add_child(panel)
	_add_label(panel, Vector2(30, 24), Vector2(580, 44), title, Color(1.0, 0.40, 0.32), 27)
	_add_label(panel, Vector2(30, 82), Vector2(580, 90), text, Color.WHITE, 18)
	var close := Button.new()
	close.text = "Понятно"
	close.position = Vector2(220, 190)
	close.size = Vector2(200, 46)
	close.pressed.connect(_close_error)
	panel.add_child(close)

func _add_label(parent: Control, pos: Vector2, size: Vector2, text: String, color: Color, fs: int) -> void:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func _close_error() -> void:
	if _error_layer != null and is_instance_valid(_error_layer):
		_error_layer.queue_free()
	_error_layer = null
