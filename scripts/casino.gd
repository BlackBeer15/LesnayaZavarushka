class_name CasinoUI
extends Control

## Казино 2.0: слот, рулетка, дартс, магазин и статистика. Всё управляется мышью.

var player = null
var hud = null
var is_open := false
var active_tab := 0

var panel: Panel
var coins_label: Label
var tabs: Array[Button] = []
var pages: Array[Control] = []

var reels: Array[Label] = []
var slot_result: Label
var spin_button: Button
var arsenal_label: Label

var roulette_number: Label
var roulette_result: Label
var dart_result: Label
var dart_throws := 0
var dart_total := 0
var stats_label: Label

func _ready() -> void:
	_build()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func _build() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = Vector2(720, 540)
	call_deferred("_place")

	panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.02, 0.06, 0.97)
	sb.border_color = Color(0.95, 0.72, 0.18)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_label(panel, Vector2(24, 14), Vector2(520, 42), "★ КАЗИНО «ТАЁЖНОЕ» ★", 28, Color(1.0, 0.80, 0.25))
	coins_label = _label(panel, Vector2(24, 58), Vector2(470, 28), "МОНЕТЫ: 0", 18, Color(1.0, 0.85, 0.3))

	var close_btn := Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.position = Vector2(560, 18)
	close_btn.size = Vector2(140, 38)
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)

	var names := ["СЛОТ", "РУЛЕТКА", "ДАРТС", "МАГАЗИН", "СТАТИСТИКА"]
	for i in range(names.size()):
		var b := Button.new()
		b.text = names[i]
		b.position = Vector2(24 + float(i) * 138, 100)
		b.size = Vector2(130, 36)
		b.pressed.connect(_select_tab.bind(i))
		panel.add_child(b)
		tabs.append(b)

	for i in range(names.size()):
		var page := Control.new()
		page.position = Vector2(24, 146)
		page.size = Vector2(672, 350)
		panel.add_child(page)
		pages.append(page)

	_build_slot(pages[0])
	_build_roulette(pages[1])
	_build_darts(pages[2])
	_build_shop(pages[3])
	_build_stats(pages[4])
	_select_tab(0)

func _label(parent: Control, pos: Vector2, size: Vector2, text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Control, text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _place() -> void:
	var vp := get_viewport_rect().size
	position = (vp - size) * 0.5

func _select_tab(index: int) -> void:
	active_tab = index
	for i in range(pages.size()):
		pages[i].visible = i == index
		tabs[i].modulate = Color(1.0, 0.85, 0.3) if i == index else Color.WHITE
	if is_open and index == 4:
		Net.rpc("request_stats")

func _build_slot(page: Control) -> void:
	var bg := ColorRect.new()
	bg.position = Vector2(0, 0)
	bg.size = Vector2(672, 120)
	bg.color = Color(0.02, 0.02, 0.04, 0.95)
	page.add_child(bg)
	for i in range(3):
		var l := _label(page, Vector2(20 + i * 220, 12), Vector2(200, 96), "?", 62, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reels.append(l)
	spin_button = _button(page, "КРУТИТЬ (10)", Vector2(0, 136), Vector2(220, 44), spin)
	slot_result = _label(page, Vector2(0, 196), Vector2(660, 50), "Три одинаковых = оружие!", 18, Color(0.85, 0.90, 0.85))
	arsenal_label = _label(page, Vector2(0, 246), Vector2(660, 104), "", 13, Color(0.75, 0.85, 0.78))
	_label(page, Vector2(0, 352), Vector2(660, 20), "Цифры 1-8 — взять оружие в руки.", 12, Color(0.55, 0.65, 0.58))

func _build_roulette(page: Control) -> void:
	roulette_number = _label(page, Vector2(0, 8), Vector2(660, 80), "-", 64, Color.WHITE)
	roulette_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(page, Vector2(0, 96), Vector2(660, 28), "Ставка 15 монет. Красное/чёрное — x2, зеро забирает банк.", 15, Color(0.75, 0.82, 0.78))
	_button(page, "КРАСНОЕ", Vector2(60, 150), Vector2(240, 52), _bet_red)
	_button(page, "ЧЁРНОЕ", Vector2(372, 150), Vector2(240, 52), _bet_black)
	_button(page, "СТАВКА НА ОХОТУ (20)", Vector2(60, 226), Vector2(552, 46), _bet_hunt_prey)
	roulette_result = _label(page, Vector2(0, 300), Vector2(660, 40), "", 18, Color(0.85, 0.90, 0.85))

func _build_darts(page: Control) -> void:
	_label(page, Vector2(0, 8), Vector2(660, 32), "Три броска по мишени. Сумма 45+ — выигрыш 25 монет. Вход 10.", 16, Color(0.85, 0.90, 0.85))
	_button(page, "БРОСИТЬ ДАРТУ", Vector2(180, 70), Vector2(312, 54), _throw_dart)
	dart_result = _label(page, Vector2(0, 150), Vector2(660, 60), "Броски: 0", 22, Color.WHITE)
	_button(page, "НАЧАТЬ ЗАНОВО", Vector2(220, 232), Vector2(232, 42), _reset_darts)

func _build_shop(page: Control) -> void:
	_button(page, "ПАТРОНЫ ×24 — 12", Vector2(0, 8), Vector2(320, 46), _buy_ammo)
	_button(page, "АПТЕЧКА +45 — 18", Vector2(352, 8), Vector2(320, 46), _buy_medkit)
	_button(page, "СКИН «ЛЕСНОЙ» — 45", Vector2(0, 72), Vector2(320, 46), _buy_forest)
	_button(page, "СКИН «НЕОНОВЫЙ» — 80", Vector2(352, 72), Vector2(320, 46), _buy_neon)
	_button(page, "СКИН «ЗОЛОТОЙ» — 140", Vector2(0, 136), Vector2(320, 46), _buy_gold)
	_button(page, "ОБНОВИТЬ", Vector2(352, 136), Vector2(320, 46), refresh_all)
	_label(page, Vector2(0, 210), Vector2(660, 120), "Скины применяются к текущему оружию и меняют цвет и свечение.".replace(".", ".\n"), 15, Color(0.75, 0.82, 0.78))

func _build_stats(page: Control) -> void:
	stats_label = _label(page, Vector2(0, 8), Vector2(660, 280), "Загрузка...", 17, Color(0.85, 0.90, 0.85))
	_button(page, "ОБНОВИТЬ ТАБЛИЦУ", Vector2(180, 300), Vector2(312, 44), _request_stats)

func open(p) -> void:
	player = p
	is_open = true
	_place()
	visible = true
	refresh_all()
	if hud != null:
		hud.update_mouse_mode()

func close() -> void:
	is_open = false
	visible = false
	player = null
	if hud != null:
		hud.update_mouse_mode()

func refresh_all() -> void:
	if player == null:
		return
	coins_label.text = "МОНЕТЫ: %d   УРОВЕНЬ %d   СЕРИЯ %d" % [player.coins, player.level, player.streak]
	var lines := ["АРСЕНАЛ (цифры 1-8):"]
	for i in range(player.inventory.size()):
		var id: String = player.inventory[i]
		if id == "":
			continue
		var w: Dictionary = GameData.WEAPONS[id]
		var mark := "▶" if i == player.weapon_index else " "
		var skin_name: String = GameData.SKINS.get(player.skins[i], GameData.SKINS["default"])["name"]
		lines.append("%s%d. %s [%s]" % [mark, i + 1, w["name"], skin_name])
	arsenal_label.text = "\n".join(lines)
	if not stats_label.text.is_empty() and active_tab == 4:
		Net.rpc("request_stats")

func spin() -> void:
	if is_open:
		Net.rpc("spin_request")

func show_result(roll: Array, text: String, weapon_id: String) -> void:
	for i in range(3):
		if i < roll.size():
			var r := int(roll[i])
			reels[i].text = GameData.REEL_SYMBOLS[r]
			reels[i].modulate = GameData.RARITY_COLORS[r]
		else:
			reels[i].text = "-"
	slot_result.text = text
	Sfx.play("crit" if weapon_id != "" else "spin", 0.7)
	refresh_all()

func show_roulette(number: int, color: String, win: bool, coins: int, bank: int) -> void:
	roulette_number.text = str(number)
	roulette_number.modulate = Color(0.9, 0.15, 0.15) if color == "red" else (Color(0.15, 0.2, 0.25) if color == "black" else Color(0.1, 0.7, 0.2))
	roulette_result.text = ("ПОБЕДА! +30" if win else "ПРОИГРЫШ") + ("  |  БАНК %d" % bank if bank > 0 else "")
	refresh_all()

func show_stats(arr: Array) -> void:
	var lines := ["ИГРОК                 УБ-ВА  МОНЕТ  УР  ЛУЧШИЙ КРИТ"]
	for e in arr:
		var d: Array = e
		if str(d[0]) == "JACKPOT":
			lines.append("БАНК КАЗИНО: %d" % int(d[1]))
			continue
		lines.append("%-20s %4d  %5d  %2d  %.0f м" % [str(d[0]), int(d[1]), int(d[2]), int(d[3]), float(d[4])])
	stats_label.text = "\n".join(lines)

func _bet_red() -> void:
	Net.rpc("roulette", Net.local_peer, "red")

func _bet_black() -> void:
	Net.rpc("roulette", Net.local_peer, "black")

func _bet_hunt_prey() -> void:
	Net.rpc("hunt_bet", "herbivore")

func _throw_dart() -> void:
	if player == null:
		return
	if player.coins < 10:
		dart_result.text = "Не хватает монет"
		return
	if dart_throws >= 3:
		_reset_darts()
	Net.rpc("spend_coins", 10)
	dart_throws += 1
	dart_total += randi_range(1, 20)
	dart_result.text = "Броски: %d/3   Сумма: %d" % [dart_throws, dart_total]
	if dart_throws == 3:
		if dart_total >= 45:
			Net.rpc("grant_coins", 25)
			dart_result.text += "  ПОБЕДА! +25"
			Sfx.play("coin", 0.7)
		else:
			dart_result.text += "  Мимо"
		dart_throws = 0
		dart_total = 0
	refresh_all()

func _reset_darts() -> void:
	dart_throws = 0
	dart_total = 0
	dart_result.text = "Броски: 0"

func _buy_ammo() -> void: Net.rpc("buy_item", "ammo")
func _buy_medkit() -> void: Net.rpc("buy_item", "medkit")
func _buy_forest() -> void: Net.rpc("buy_item", "skin_forest")
func _buy_neon() -> void: Net.rpc("buy_item", "skin_neon")
func _buy_gold() -> void: Net.rpc("buy_item", "skin_gold")
func _request_stats() -> void: Net.rpc("request_stats")

func _process(_delta: float) -> void:
	if is_open and player != null:
		coins_label.text = "МОНЕТЫ: %d   УРОВЕНЬ %d   СЕРИЯ %d" % [player.coins, player.level, player.streak]
