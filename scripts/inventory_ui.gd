class_name InventoryUI
extends Control

## Инвентарь по TAB. Оружие перетаскивается мышью между ячейками,
## порядок отправляется хосту и рассинхронизируется всем игрокам.

class Slot extends Panel:
	var ui = null
	var index := 0

	func _get_drag_data(_at_position: Vector2) -> Variant:
		return ui.get_drag(index)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return ui.can_drop(data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		ui.drop(index, data)

var player = null
var hud = null
var is_open := false

var slots: Array[Slot] = []
var panel: Panel
var hint_label: Label

const SLOT_COUNT := 8

func _ready() -> void:
	_build()
	visible = false

func _build() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = Vector2(560, 330)
	call_deferred("_place")
	mouse_filter = Control.MOUSE_FILTER_STOP

	panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.97)
	sb.border_color = Color(0.35, 0.70, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.position = Vector2(24, 14)
	title.size = Vector2(500, 36)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.60, 0.85, 1.0))
	panel.add_child(title)

	var grid := GridContainer.new()
	grid.position = Vector2(24, 62)
	grid.columns = 4
	grid.add_theme_constant_override("hseparation", 10)
	grid.add_theme_constant_override("vseparation", 10)
	panel.add_child(grid)
	for i in range(SLOT_COUNT):
		var s := Slot.new()
		s.ui = self
		s.index = i
		s.custom_minimum_size = Vector2(120, 74)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
		style.border_color = Color(0.32, 0.38, 0.45)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		s.add_theme_stylebox_override("panel", style)
		var idx_label := Label.new()
		idx_label.text = str(i + 1)
		idx_label.position = Vector2(6, 3)
		idx_label.add_theme_font_size_override("font_size", 13)
		idx_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
		s.add_child(idx_label)
		var name_label := Label.new()
		name_label.name = "WeaponName"
		name_label.position = Vector2(8, 26)
		name_label.size = Vector2(106, 42)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(name_label)
		grid.add_child(s)
		slots.append(s)

	hint_label = Label.new()
	hint_label.position = Vector2(24, 288)
	hint_label.size = Vector2(520, 30)
	hint_label.text = "Перетащите оружие мышью в нужную ячейку. Цифры 1-8 — взять в руки."
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.78))
	panel.add_child(hint_label)

func _place() -> void:
	var vp := get_viewport_rect().size
	position = (vp - size) * 0.5

func open(p) -> void:
	player = p
	is_open = true
	_place()
	refresh()
	visible = true
	if hud != null:
		hud.update_mouse_mode()

func close() -> void:
	is_open = false
	visible = false
	if hud != null:
		hud.update_mouse_mode()

func toggle(p) -> void:
	if is_open:
		close()
	else:
		open(p)

func refresh() -> void:
	if player == null:
		return
	for i in range(slots.size()):
		var s: Slot = slots[i]
		var label: Label = s.get_node("WeaponName")
		if i < player.inventory.size() and player.inventory[i] != "":
			var id: String = player.inventory[i]
			var w: Dictionary = GameData.WEAPONS[id]
			label.text = w["name"]
			label.add_theme_color_override("font_color", GameData.RARITY_COLORS[int(w["rarity"])])
			var style: StyleBoxFlat = s.get_theme_stylebox("panel") as StyleBoxFlat
			if style != null:
				style.border_color = GameData.RARITY_COLORS[int(w["rarity"])] if i == player.weapon_index else Color(0.32, 0.38, 0.45)
		else:
			label.text = "— пусто —"
			label.add_theme_color_override("font_color", Color(0.30, 0.34, 0.38))

func get_drag(index: int) -> Variant:
	if player == null or index >= player.inventory.size() or player.inventory[index] == "":
		return null
	var data := {"from": index, "id": player.inventory[index]}
	var preview := Label.new()
	preview.text = GameData.WEAPONS[player.inventory[index]]["name"]
	preview.add_theme_font_size_override("font_size", 14)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
	set_drag_preview(preview)
	return data

func can_drop(data: Variant) -> bool:
	return data is Dictionary and data.has("from") and player != null

func drop(to_index: int, data: Variant) -> void:
	if player == null or to_index >= SLOT_COUNT:
		return
	var from_index := int(data["from"])
	if from_index >= player.inventory.size() or to_index >= player.inventory.size():
		return
	var tmp: String = player.inventory[to_index]
	player.inventory[to_index] = player.inventory[from_index]
	player.inventory[from_index] = tmp
	if from_index == player.weapon_index:
		player.weapon_index = to_index
	elif to_index == player.weapon_index:
		player.weapon_index = from_index
	Net.rpc("set_inventory_order", player.inventory)
	refresh()
	if player.is_local:
		player.rebuild_viewmodel()
