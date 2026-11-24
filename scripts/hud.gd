class_name HUD
extends CanvasLayer

class Minimap extends Control:
	var player = null
	var radius := 120.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.03, 0.55))
		draw_circle(c, s, Color(0.10, 0.22, 0.12, 0.65))
		draw_arc(c, s, 0.0, TAU, 40, Color(0.50, 0.80, 0.45, 0.8), 2.0)
		if player == null or not is_instance_valid(player):
			return
		var scale := s / radius
		if GameState.world != null:
			var casino: Vector3 = GameState.world.slot_position
			var dx: float = (casino.x - player.global_position.x) * scale
			var dy: float = (casino.z - player.global_position.z) * scale
			if Vector2(dx, dy).length() < s:
				draw_rect(Rect2(c + Vector2(dx, dy) - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.75, 0.15))
		for a in GameState.animals:
			if a == null or not is_instance_valid(a):
				continue
			var dx: float = (a.global_position.x - player.global_position.x) * scale
			var dy: float = (a.global_position.z - player.global_position.z) * scale
			if Vector2(dx, dy).length() > s:
				continue
			var col := Color(0.45, 0.95, 0.45) if not bool(a.data["predator"]) else Color(1.0, 0.30, 0.22)
			if a.ability_active:
				col = Color(1.0, 0.9, 0.2)
			draw_circle(c + Vector2(dx, dy), 2.6 if a.scale.x < 1.0 else 4.0, col)
		draw_circle(c, 3.5, Color.WHITE)
		var fwd := Vector2(-sin(player.yaw), -cos(player.yaw)) * 12.0
		draw_line(c, c + fwd, Color.WHITE, 2.0)

var player = null
var casino = null
var inventory = null

var root: Control
var hp_fill: ColorRect
var hp_label: Label
var coin_label: Label
var weapon_label: Label
var ammo_label: Label
var message_label: Label
var crosshair_label: Label
var hit_marker_label: Label
var stamina_fill: ColorRect
var status_label: Label
var damage_overlay: ColorRect
var cinematic_bar_top: ColorRect
var cinematic_bar_bottom: ColorRect
var cinematic_label: Label
var minimap: Minimap

var message_timer := 0.0
var damage_alpha := 0.0
var hit_marker_timer := 0.0

func setup(p, casino_ui) -> void:
	player = p
	casino = casino_ui
	if casino != null:
		casino.hud = self
	inventory = InventoryUI.new()
	inventory.hud = self
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var info := _make_panel(Vector2(12, 12), Vector2(292, 118))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pid: int = 1 if p == null else int(p.id)
	var title := Label.new()
	title.text = "ИГРОК %d" % pid
	title.position = Vector2(12, 8)
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.60) if pid == 1 else Color(0.60, 0.75, 1.0))
	title.add_theme_font_size_override("font_size", 19)
	info.add_child(title)

	hp_label = _make_label(info, Vector2(12, 34), Vector2(260, 22), "ЗДОРОВЬЕ 100", Color.WHITE, 16)
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(12, 59)
	hp_bg.size = Vector2(260, 13)
	hp_bg.color = Color(0.10, 0.10, 0.10, 0.9)
	info.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.position = Vector2(12, 59)
	hp_fill.size = Vector2(260, 13)
	hp_fill.color = Color(0.28, 0.85, 0.35)
	info.add_child(hp_fill)

	coin_label = _make_label(info, Vector2(12, 79), Vector2(260, 22), "МОНЕТЫ: 0", Color(1.0, 0.82, 0.2), 17)
	weapon_label = _make_label(info, Vector2(12, 98), Vector2(260, 20), "Оружие: Егерь П-9", Color.WHITE, 14)

	var ammo_panel := _make_panel(Vector2(-12, 12), Vector2(190, 60))
	ammo_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	ammo_panel.position = Vector2(-202, 12)
	ammo_label = _make_label(ammo_panel, Vector2(12, 8), Vector2(170, 40), "12 / 12", Color.WHITE, 28)

	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	minimap.position = Vector2(-172, 84)
	minimap.size = Vector2(160, 160)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.player = p
	root.add_child(minimap)

	crosshair_label = Label.new()
	crosshair_label.text = "+"
	crosshair_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair_label.position -= Vector2(9, 13)
	crosshair_label.add_theme_font_size_override("font_size", 28)
	crosshair_label.add_theme_color_override("font_color", Color(0.95, 0.98, 0.95, 0.85))
	crosshair_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair_label)

	hit_marker_label = Label.new()
	hit_marker_label.text = "X"
	hit_marker_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hit_marker_label.position -= Vector2(10, 16)
	hit_marker_label.add_theme_font_size_override("font_size", 34)
	hit_marker_label.add_theme_color_override("font_color", Color.WHITE)
	hit_marker_label.visible = false
	hit_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hit_marker_label)

	var stamina_bg := ColorRect.new()
	stamina_bg.position = Vector2(12, 140)
	stamina_bg.size = Vector2(260, 9)
	stamina_bg.color = Color(0.08, 0.08, 0.09, 0.8)
	root.add_child(stamina_bg)
	stamina_fill = ColorRect.new()
	stamina_fill.position = Vector2(12, 140)
	stamina_fill.size = Vector2(260, 9)
	stamina_fill.color = Color(0.30, 0.70, 0.95)
	root.add_child(stamina_fill)

	status_label = _make_label(root, Vector2(12, 154), Vector2(300, 24), "", Color(1.0, 0.5, 0.35), 15)

	message_label = _make_label(root, Vector2(16, -46), Vector2(600, 30), "", Color.WHITE, 18)
	message_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	message_label.position = Vector2(16, -46)

	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.75, 0.0, 0.0, 0.0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)

	cinematic_bar_top = ColorRect.new()
	cinematic_bar_top.anchor_right = 1.0
	cinematic_bar_top.offset_bottom = 78.0
	cinematic_bar_top.color = Color.BLACK
	cinematic_bar_top.visible = false
	cinematic_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cinematic_bar_top)
	cinematic_bar_bottom = ColorRect.new()
	cinematic_bar_bottom.anchor_right = 1.0
	cinematic_bar_bottom.anchor_top = 1.0
	cinematic_bar_bottom.anchor_bottom = 1.0
	cinematic_bar_bottom.offset_top = -78.0
	cinematic_bar_bottom.color = Color.BLACK
	cinematic_bar_bottom.visible = false
	cinematic_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cinematic_bar_bottom)
	cinematic_label = _make_label(root, Vector2(0, -125), Vector2(600, 40), "КРИТИЧЕСКОЕ ПОПАДАНИЕ", Color(1.0, 0.25, 0.18), 26)
	cinematic_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cinematic_label.position = Vector2(-300, -125)
	cinematic_label.visible = false

	if casino != null:
		root.add_child(casino)
	if inventory != null:
		root.add_child(inventory)

func update_mouse_mode() -> void:
	if not GameState.running:
		return
	var ui_open: bool = (casino != null and casino.is_open) or (inventory != null and inventory.is_open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_open else Input.MOUSE_MODE_CAPTURED

func _make_panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.03, 0.62)
	sb.border_color = Color(0.25, 0.45, 0.28, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	root.add_child(p)
	return p

func _make_label(parent: Control, pos: Vector2, size: Vector2, text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	hp_label.text = "ЗДОРОВЬЕ %d" % int(player.health)
	var frac := clampf(player.health / 100.0, 0.0, 1.0)
	hp_fill.size.x = 260.0 * frac
	hp_fill.color = Color(0.85, 0.20, 0.18) if frac < 0.3 else (Color(0.90, 0.75, 0.15) if frac < 0.6 else Color(0.28, 0.85, 0.35))
	coin_label.text = "МОНЕТЫ: %d   УБИЙСТВ: %d" % [player.coins, player.kills]
	var w: Dictionary = GameData.WEAPONS[player.current_weapon_id()]
	weapon_label.text = "Оружие: %s" % w["name"]
	var atype: Dictionary = GameData.AMMO_TYPES[player.ammo_type]
	ammo_label.text = "%d / %d\n%s ×%d" % [player.ammo, int(w["mag"]), atype["name"], player.reserves[player.ammo_type]]
	var rc: Color = GameData.RARITY_COLORS[int(w["rarity"])]
	ammo_label.add_theme_color_override("font_color", rc)

	if message_timer > 0.0:
		message_timer -= delta
		message_label.modulate.a = clampf(message_timer, 0.0, 1.0)
	else:
		message_label.text = ""
	if damage_alpha > 0.0:
		damage_alpha = maxf(0.0, damage_alpha - delta * 1.4)
		damage_overlay.color.a = damage_alpha
	if hit_marker_timer > 0.0:
		hit_marker_timer -= delta
		if hit_marker_timer <= 0.0:
			hit_marker_label.visible = false
	crosshair_label.text = "." if player.aiming else "+"
	crosshair_label.add_theme_font_size_override("font_size", 16 if player.aiming else 28)
	stamina_fill.size.x = 260.0 * clampf(player.stamina / 100.0, 0.0, 1.0)
	var status := ""
	if player.bleeding > 0.0:
		status = "КРОВОТЕЧЕНИЕ"
	elif player.crouching:
		status = "ПРИСЕД"
	elif player.swimming:
		status = "ПЛАВАНИЕ"
	status_label.text = status
	if inventory != null and inventory.is_open:
		inventory.refresh()

func message(text: String, color: Color = Color.WHITE) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_timer = 3.0
	message_label.modulate.a = 1.0

func hit_marker(critical: bool, heart: bool = false) -> void:
	hit_marker_label.visible = true
	hit_marker_label.text = "X"
	hit_marker_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18) if heart else (Color(1.0, 0.85, 0.25) if critical else Color.WHITE))
	hit_marker_timer = 0.18

func flash_damage() -> void:
	damage_alpha = 0.42
	damage_overlay.color.a = damage_alpha

func set_cinematic(value: bool) -> void:
	cinematic_bar_top.visible = value
	cinematic_bar_bottom.visible = value
	cinematic_label.visible = value
