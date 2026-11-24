class_name CasinoUI
extends Control

## Автомат в казино. Крутка авторитетна на хосте (Net.spin_request),
## клиент только показывает результат.

var player = null
var hud = null
var is_open := false

var panel: Panel
var coins_label: Label
var result_label: Label
var inventory_label: Label
var reels: Array[Label] = []
var spin_button: Button

func _ready() -> void:
	_build()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func _build() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = Vector2(600, 450)
	call_deferred("_place")
	panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.02, 0.06, 0.96)
	sb.border_color = Color(0.95, 0.72, 0.18)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var title := Label.new()
	title.text = "★ КАЗИНО «ТАЁЖНОЕ» ★"
	title.position = Vector2(30, 18)
	title.size = Vector2(540, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.25))
	panel.add_child(title)

	coins_label = _label(panel, Vector2(30, 62), Vector2(540, 26), "МОНЕТЫ: 0", Color(1.0, 0.85, 0.3), 19)

	var reel_bg := ColorRect.new()
	reel_bg.position = Vector2(30, 100)
	reel_bg.size = Vector2(540, 110)
	reel_bg.color = Color(0.02, 0.02, 0.04, 0.95)
	panel.add_child(reel_bg)
	for i in range(3):
		var l := Label.new()
		l.position = Vector2(42 + i * 176, 108)
		l.size = Vector2(160, 92)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 62)
		l.text = "?"
		panel.add_child(l)
		reels.append(l)

	spin_button = Button.new()
	spin_button.text = "КРУТИТЬ (10 монет)"
	spin_button.position = Vector2(30, 226)
	spin_button.size = Vector2(260, 44)
	spin_button.add_theme_font_size_override("font_size", 19)
	spin_button.pressed.connect(spin)
	panel.add_child(spin_button)

	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.position = Vector2(310, 226)
	close_button.size = Vector2(260, 44)
	close_button.add_theme_font_size_override("font_size", 19)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	result_label = _label(panel, Vector2(30, 282), Vector2(540, 60), "Три одинаковых символа = оружие!", Color(0.85, 0.90, 0.85), 18)
	inventory_label = _label(panel, Vector2(30, 345), Vector2(540, 92), "", Color(0.75, 0.85, 0.78), 15)
	_label(panel, Vector2(30, 418), Vector2(540, 25), "Закрыть — кнопка или E. Цифры 1-8 — взять оружие в руки.", Color(0.55, 0.65, 0.58), 13)

func _label(parent: Control, pos: Vector2, size: Vector2, text: String, color: Color, fs: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _place() -> void:
	var vp := get_viewport_rect().size
	position = (vp - size) * 0.5

func open(p) -> void:
	player = p
	if hud != null and hud.inventory != null and hud.inventory.is_open:
		hud.inventory.close()
	is_open = true
	_place()
	visible = true
	result_label.text = "Три одинаковых символа = оружие!"
	result_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.85))
	_refresh()
	if hud != null:
		hud.update_mouse_mode()

func close() -> void:
	is_open = false
	visible = false
	player = null
	if hud != null:
		hud.update_mouse_mode()

func spin() -> void:
	if not is_open:
		return
	Net.rpc("spin_request")

func show_result(roll: Array, text: String, weapon_id: String) -> void:
	if not is_open:
		return
	for i in range(3):
		if i < roll.size():
			var r := int(roll[i])
			reels[i].text = GameData.REEL_SYMBOLS[r]
			reels[i].modulate = GameData.RARITY_COLORS[r]
		else:
			reels[i].text = "-"
			reels[i].modulate = Color.WHITE
	result_label.text = text
	result_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25) if weapon_id != "" else Color(0.85, 0.90, 0.85))
	_refresh()

func _process(_delta: float) -> void:
	if is_open and player != null:
		_refresh()

func _refresh() -> void:
	if player == null:
		return
	coins_label.text = "МОНЕТЫ: %d   (крутка = %d)" % [player.coins, GameData.COIN_COST]
	var lines := ["АРСЕНАЛ (цифры 1-5):"]
	for i in range(player.inventory.size()):
		var id: String = player.inventory[i]
		if id == "":
			continue
		var w: Dictionary = GameData.WEAPONS[id]
		var mark := "▶" if i == player.weapon_index else " "
		lines.append("%s%d. %s — %s" % [mark, i + 1, w["name"], GameData.RARITY_NAMES[int(w["rarity"])]])
	inventory_label.text = "\n".join(lines)
