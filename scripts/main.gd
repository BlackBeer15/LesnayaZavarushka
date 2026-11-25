extends Node

## Точка входа LAN-версии: меню подключения, один полноэкранный вид,
## хост-авторитет и синхронизация через Net.

var stage: Node3D = null
var camera: Camera3D = null
var hud: HUD = null
var world: WorldGen = null
var effects: Effects = null
var world_ready := false

var menu_layer: CanvasLayer = null
var name_edit: LineEdit = null
var ip_edit: LineEdit = null
var settings_panel: Control = null
var volume_slider: HSlider = null
var volume_value_label: Label = null
var sensitivity_value_label: Label = null
var status_label: Label = null
var server_list: Label = null

var player_nodes := {} # peer -> Player
var animal_id_counter := 0
var coin_id_counter := 0
var snapshot_timer := 0.0
var killcam: Dictionary = {}
var bullet_node: MeshInstance3D = null
var cinematic := false
var debug_state := false
var debug_timer := 0.0
var test_spin := false
var test_spin_timer := 5.0
var test_fire := false
var test_fire_timer := 3.0
var test_casino := false
var test_casino_timer := 5.0
var last_ability_sound := 0
var debug_look_down := false
var debug_look_done := false
var test_inventory := false
var test_inventory_timer := 6.0
var debug_args: Array = []
var debug_weapon_done := false

func _ready() -> void:
	Settings.apply_video() # окно/разрешение/VSync/MSAA по сохранённым настройкам
	Net.main = self
	Net.game_message.connect(_on_net_message)
	Net.connected_as.connect(_on_connected_as)
	Net.player_list_changed.connect(_refresh_server_list)
	_build_menu()
	GameState.running = false
	# Быстрый старт из командной строки: --host  или  --join 192.168.1.5
	var args := OS.get_cmdline_user_args()
	# Тестовые флаги доступны только в debug-сборке; --host/--join работают всегда.
	debug_args = args if OS.is_debug_build() else []
	debug_state = GameData.debug_arg("--debug-state")
	test_spin = GameData.debug_arg("--test-spin")
	test_fire = GameData.debug_arg("--test-fire")
	test_casino = GameData.debug_arg("--test-casino")
	debug_look_down = GameData.debug_arg("--look-down")
	test_inventory = GameData.debug_arg("--test-inventory")
	if args.has("--host"):
		_on_host_pressed()
	elif args.size() >= 2 and args[0] == "--join":
		ip_edit.text = args[1]
		_on_join_pressed()

# ------------------------------------------------------------------ МЕНЮ ---

func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 100
	add_child(menu_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.02, 0.90)
	menu_layer.add_child(shade)

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390, -270)
	panel.size = Vector2(780, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.05, 0.97)
	sb.border_color = Color(0.35, 0.70, 0.38)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	menu_layer.add_child(panel)

	_label(panel, Vector2(0, 22), Vector2(780, 52), "ЛЕСНАЯ ЗАВАРУШКА", Color(0.60, 1.0, 0.55), 40, true)
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_label(panel, Vector2(0, 72), Vector2(780, 30), "охота по локальной сети  ·  v%s" % version, Color(0.80, 0.86, 0.78), 20, true)

	_label(panel, Vector2(50, 122), Vector2(220, 30), "Ваше имя:", Color.WHITE, 17)
	name_edit = LineEdit.new()
	name_edit.position = Vector2(240, 118)
	name_edit.size = Vector2(480, 38)
	name_edit.text = "Охотник"
	name_edit.max_length = 18
	panel.add_child(name_edit)

	_label(panel, Vector2(50, 172), Vector2(220, 30), "IP сервера:", Color.WHITE, 17)
	ip_edit = LineEdit.new()
	ip_edit.position = Vector2(240, 168)
	ip_edit.size = Vector2(480, 38)
	ip_edit.text = "127.0.0.1"
	panel.add_child(ip_edit)

	var host_btn := Button.new()
	host_btn.text = "СОЗДАТЬ СЕРВЕР"
	host_btn.position = Vector2(50, 228)
	host_btn.size = Vector2(325, 52)
	host_btn.add_theme_font_size_override("font_size", 21)
	host_btn.pressed.connect(_on_host_pressed)
	panel.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "ПОДКЛЮЧИТЬСЯ"
	join_btn.position = Vector2(395, 228)
	join_btn.size = Vector2(325, 52)
	join_btn.add_theme_font_size_override("font_size", 21)
	join_btn.pressed.connect(_on_join_pressed)
	panel.add_child(join_btn)

	var settings_btn := Button.new()
	settings_btn.text = "НАСТРОЙКИ"
	settings_btn.position = Vector2(610, 18)
	settings_btn.size = Vector2(150, 38)
	settings_btn.add_theme_font_size_override("font_size", 17)
	settings_btn.pressed.connect(_open_settings)
	panel.add_child(settings_btn)

	status_label = _label(panel, Vector2(50, 296), Vector2(670, 30), "", Color(1.0, 0.82, 0.30), 17)
	server_list = _label(panel, Vector2(50, 334), Vector2(670, 92), "", Color(0.78, 0.90, 0.80), 16)

	_label(panel, Vector2(50, 436), Vector2(670, 92),
		"Управление: WASD — движение, мышь — обзор, ЛКМ — выстрел, ПКМ — прицел,\n"
		+ "R — перезарядка, Q — патроны, Shift — спринт, Ctrl — присед, Пробел — прыжок,\n"
		+ "V — камера, E — казино, F — спин, Tab — инвентарь, 1-8 — оружие, Esc — меню",
		Color(0.72, 0.78, 0.72), 14)
	_build_settings_panel()

func _build_settings_panel() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-300, -270)
	settings_panel.size = Vector2(600, 540)
	settings_panel.visible = false
	menu_layer.add_child(settings_panel)
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.05, 0.98)
	sb.border_color = Color(0.35, 0.70, 0.38)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	bg.add_theme_stylebox_override("panel", sb)
	settings_panel.add_child(bg)
	_label(settings_panel, Vector2(0, 16), Vector2(600, 50), "НАСТРОЙКИ", Color(0.60, 1.0, 0.55), 32, true)

	_label(settings_panel, Vector2(36, 84), Vector2(190, 28), "Громкость звука:", Color.WHITE, 17)
	volume_slider = _make_slider(settings_panel, Vector2(232, 86), Vector2(260, 24), 0.0, 100.0, 1.0,
		Settings.master_volume * 100.0, _on_volume_changed)
	volume_value_label = _label(settings_panel, Vector2(505, 84), Vector2(60, 28), "", Color(0.60, 1.0, 0.55), 17, true)
	_update_volume_label(Settings.master_volume)

	_label(settings_panel, Vector2(36, 124), Vector2(190, 28), "Чувствительность:", Color.WHITE, 17)
	var sens_slider := _make_slider(settings_panel, Vector2(232, 126), Vector2(260, 24), 10.0, 150.0, 5.0,
		Settings.mouse_sensitivity * 50.0, _on_sensitivity_changed)
	sensitivity_value_label = _label(settings_panel, Vector2(505, 124), Vector2(60, 28), "", Color(0.60, 1.0, 0.55), 17, true)
	_on_sensitivity_changed(sens_slider.value)

	_label(settings_panel, Vector2(36, 164), Vector2(190, 28), "Разрешение:", Color.WHITE, 17)
	var res_opt := OptionButton.new()
	res_opt.position = Vector2(232, 166)
	res_opt.size = Vector2(260, 30)
	for n in Settings.RESOLUTION_NAMES:
		res_opt.add_item(n)
	res_opt.selected = Settings.resolution_index
	res_opt.item_selected.connect(_on_resolution_selected)
	settings_panel.add_child(res_opt)

	_add_check("Полный экран", 206, Settings.fullscreen, _on_fullscreen_toggled)
	_add_check("Вертикальная синхронизация", 246, Settings.vsync, _on_vsync_toggled)
	_add_check("Инверсия оси Y", 326, Settings.invert_y, _on_invert_y_toggled)

	_label(settings_panel, Vector2(36, 286), Vector2(190, 28), "Тени:", Color.WHITE, 17)
	var shadow_opt := OptionButton.new()
	shadow_opt.position = Vector2(232, 288)
	shadow_opt.size = Vector2(260, 30)
	for n in Settings.SHADOW_NAMES:
		shadow_opt.add_item(n)
	shadow_opt.selected = Settings.shadow_quality
	shadow_opt.item_selected.connect(_on_shadow_selected)
	settings_panel.add_child(shadow_opt)

	_label(settings_panel, Vector2(36, 366), Vector2(190, 28), "Сглаживание:", Color.WHITE, 17)
	var msaa_opt := OptionButton.new()
	msaa_opt.position = Vector2(232, 368)
	msaa_opt.size = Vector2(260, 30)
	for n in Settings.MSAA_NAMES:
		msaa_opt.add_item(n)
	msaa_opt.selected = Settings.msaa_index
	msaa_opt.item_selected.connect(_on_msaa_selected)
	settings_panel.add_child(msaa_opt)

	_label(settings_panel, Vector2(36, 414), Vector2(530, 40),
		"Настройки сохраняются автоматически и применяются сразу.", Color(0.70, 0.80, 0.70), 14)

	var back_btn := Button.new()
	back_btn.text = "НАЗАД"
	back_btn.position = Vector2(190, 470)
	back_btn.size = Vector2(220, 46)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_close_settings)
	settings_panel.add_child(back_btn)

func _add_check(text: String, y: int, pressed: bool, callback: Callable) -> void:
	var chk := CheckButton.new()
	chk.text = text
	chk.position = Vector2(36, y)
	chk.size = Vector2(460, 30)
	chk.button_pressed = pressed
	chk.toggled.connect(callback)
	settings_panel.add_child(chk)

func _make_slider(parent: Control, pos: Vector2, size: Vector2, min_v: float, max_v: float,
		step: float, value: float, callback: Callable) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = size
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.value_changed.connect(callback)
	parent.add_child(s)
	return s

func _label(parent: Control, pos: Vector2, size: Vector2, text: String, color: Color, fs: int, center: bool = false) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _on_volume_changed(value: float) -> void:
	var fraction := value / 100.0
	Settings.set_master_volume(fraction)
	_update_volume_label(fraction)

func _update_volume_label(fraction: float) -> void:
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % roundi(fraction * 100.0)

func _open_settings() -> void:
	if settings_panel != null:
		settings_panel.visible = true

func _close_settings() -> void:
	if settings_panel != null:
		settings_panel.visible = false

func _on_sensitivity_changed(value: float) -> void:
	var sens := value / 50.0
	Settings.set_sensitivity(sens)
	if sensitivity_value_label != null:
		sensitivity_value_label.text = "x%.1f" % sens

func _on_resolution_selected(index: int) -> void:
	Settings.set_resolution(index)

func _on_fullscreen_toggled(value: bool) -> void:
	Settings.set_fullscreen(value)

func _on_vsync_toggled(value: bool) -> void:
	Settings.set_vsync(value)

func _on_shadow_selected(index: int) -> void:
	Settings.set_shadow_quality(index)

func _on_msaa_selected(index: int) -> void:
	Settings.set_msaa(index)

func _on_invert_y_toggled(value: bool) -> void:
	Settings.set_invert_y(value)

func _on_host_pressed() -> void:
	var pname: String = name_edit.text.strip_edges()
	if pname.is_empty():
		pname = "Охотник"
	if Net.host_game(pname):
		status_label.text = "Сервер создан. Сообщите друзьям свой IP. Порт %d." % Net.PORT
		_begin_session(Net.world_seed)

func _on_join_pressed() -> void:
	var pname: String = name_edit.text.strip_edges()
	if pname.is_empty():
		pname = "Охотник"
	var ip: String = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	status_label.text = "Подключение к %s:%d..." % [ip, Net.PORT]
	Net.join_game(ip, pname)

func _on_connected_as(_peer: int, seed_value: int) -> void:
	_begin_session(seed_value)
	status_label.text = "Подключено! Вы — игрок #%d" % Net.local_peer

func _begin_session(seed_value: int) -> void:
	if world_ready:
		return
	GameLog.info("Начало сессии: peer=%d seed=%d хост=%s" % [Net.local_peer, seed_value, str(Net.is_host)])
	world_ready = true
	menu_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.running = true
	_build_scene(seed_value)
	for peer in Net.players.keys():
		ensure_player(peer)
	if Net.is_host:
		_spawn_initial_animals()

func _build_scene(seed_value: int) -> void:
	stage = Node3D.new()
	stage.name = "Stage"
	add_child(stage)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.fov = 75.0
	camera.near = 0.06
	camera.far = 500.0
	add_child(camera)

	world = WorldGen.new()
	world.name = "Forest"
	stage.add_child(world)
	world.build(seed_value)
	GameState.world = world

	effects = Effects.new()
	effects.name = "Effects"
	stage.add_child(effects)
	GameState.effects = effects

	var pickups := Pickups.new()
	pickups.name = "Pickups"
	stage.add_child(pickups)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(null, CasinoUI.new())

func _spawn_initial_animals() -> void:
	var pool := ["rabbit", "rabbit", "rabbit", "rabbit", "deer", "deer", "deer", "boar", "boar", "fox", "fox", "wolf", "wolf", "bear"]
	for _i in range(78):
		_spawn_animal(pool[randi_range(0, pool.size() - 1)])

func _spawn_animal(species: String):
	if not Net.is_host:
		return null
	animal_id_counter += 1
	var pos := GameState.random_point_in_forest()
	var a := Animal.new()
	a.setup(animal_id_counter, species, pos)
	stage.add_child(a)
	return a

# --------------------------------------------------------------- ИГРОКИ ---

func ensure_player(peer: int) -> void:
	if player_nodes.has(peer) or world == null:
		return
	var st: Dictionary = Net.players.get(peer, {})
	var p := Player.new()
	var pname: String = st.get("name", "Охотник")
	var is_local := (peer == Net.local_peer)
	p.setup(peer, pname, camera if is_local else null, hud if is_local else null, is_local)
	var pos: Vector3 = st.get("pos", Vector3(-6.0, 0.0, 13.0))
	p.position = Vector3(pos.x, world.ground_height(pos.x, pos.z) + 0.15, pos.z)
	p.spawn_point = p.position
	p.yaw = float(st.get("yaw", 0.0))
	p.pitch = float(st.get("pitch", 0.0))
	p.set_state(
		int(st.get("coins", 30)), float(st.get("health", 100.0)),
		int(st.get("kills", 0)), st.get("inventory", ["pistol"]),
		int(st.get("weapon_index", 0))
	)
	stage.add_child(p)
	player_nodes[peer] = p
	GameState.players.append(p)
	if debug_state:
		print("[DBG] player node peer=%d local=%s name=%s" % [peer, str(is_local), pname])
	if is_local:
		hud.player = p
		hud.minimap.player = p
		camera.global_position = p.global_position + Vector3.UP * 1.6
	_refresh_server_list()

func remove_player(peer: int) -> void:
	if not player_nodes.has(peer):
		return
	var p = player_nodes[peer]
	GameState.players.erase(p)
	player_nodes.erase(peer)
	if is_instance_valid(p):
		p.queue_free()
	_refresh_server_list()

func update_remote_player(peer: int, st: Dictionary) -> void:
	if not player_nodes.has(peer):
		ensure_player(peer)
		return
	var p = player_nodes[peer]
	if is_instance_valid(p):
		p.apply_remote_state(st)

func get_player_node(peer: int):
	return player_nodes.get(peer, null)

func _refresh_server_list() -> void:
	if server_list == null:
		return
	var lines := ["ИГРОКИ В СЕТИ:"]
	for peer in Net.players.keys():
		var st: Dictionary = Net.players[peer]
		lines.append("#%d  %s  — %d монет, %d убийств" % [peer, st.get("name", "?"), st.get("coins", 0), st.get("kills", 0)])
	server_list.text = "\n".join(lines)

# --------------------------------------------------------------- ЗВЕРИ ---

var _animal_seen := {}
var _animal_frame := -1

func update_animal_proxies(data: Array, frame: int, last_chunk: bool) -> void:
	if not world_ready:
		return
	if frame != _animal_frame:
		_animal_frame = frame
		_animal_seen.clear()
	for e in data:
		var aid := int(e[0])
		_animal_seen[aid] = true
		var node = _find_animal(aid)
		if node == null:
			node = Animal.new()
			node.setup(aid, str(e[1]), Vector3(float(e[2]), float(e[3]), float(e[4])), true)
			stage.add_child(node)
		node.apply_remote(
			Vector3(float(e[2]), float(e[3]), float(e[4])),
			float(e[5]), bool(e[6]), int(e[7])
		)
	if last_chunk:
		for a in GameState.animals.duplicate():
			if a == null or not is_instance_valid(a):
				continue
			if not _animal_seen.has(a.animal_id):
				GameState.animals.erase(a)
				a.queue_free()
		_animal_seen.clear()

func _find_animal(aid: int):
	for a in GameState.animals:
		if a != null and is_instance_valid(a) and a.animal_id == aid:
			return a
	return null

func host_fire(sender: int, origin: Vector3, dir: Vector3, weapon_id: String, ammo_type: int) -> Array:
	if not Net.is_host:
		return []
	var w: Dictionary = GameData.WEAPONS.get(weapon_id, GameData.WEAPONS["pistol"])
	var ammo: Dictionary = GameData.AMMO_TYPES[clampi(ammo_type, 0, GameData.AMMO_TYPES.size() - 1)]
	var to := origin + dir * 320.0
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	var shooter = get_player_node(sender)
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	query.collision_mask = 1 | 2
	var hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return []
	var hit_pos: Vector3 = hit["position"]
	var animal_id := -1
	var crit_type := ""
	var damage := 0.0
	var animal_name := ""
	var collider = hit["collider"]
	if collider is Animal and not collider.remote_proxy:
		animal_id = collider.animal_id
		animal_name = collider.data["name"]
		crit_type = collider.get_critical_type(hit_pos, origin, dir, bool(ammo["pierce"]))
		damage = float(w["damage"]) * float(ammo["damage"])
		if crit_type == "heart":
			damage *= 3.0
		elif crit_type != "":
			damage *= 1.8
		collider.take_damage(damage, hit_pos, sender, crit_type, bool(ammo["pierce"]))
		if crit_type != "heart":
			collider.flinch(origin)
			if bool(ammo.get("bleed", false)):
				collider.apply_bleed(4.0, sender)
	return [hit_pos, animal_id, crit_type, damage, animal_name]

func on_shoot_result(shooter: int, hit_pos: Vector3, animal_id: int, critical_type: String, muzzle: Vector3, damage: float, animal_name: String) -> void:
	if debug_state:
		print("[DBG] shot animal=%d crit=%s dmg=%.1f" % [animal_id, critical_type, damage])
	if effects != null:
		_spawn_tracer(muzzle, hit_pos, critical_type != "")
		if animal_id < 0:
			effects.spawn_hit(hit_pos, Color(0.75, 0.70, 0.55), 5, 2.0)
		else:
			effects.spawn_hit(hit_pos, Color(0.55, 0.02, 0.02), 12 if critical_type == "" else 20, 4.5)
			effects.spawn_damage_number(hit_pos, int(round(damage)), critical_type)
			Sfx.play("hit", 0.55 if critical_type == "" else 0.8)
	if shooter == Net.local_peer and hud != null:
		hud.hit_marker(critical_type != "", critical_type == "heart")
		shake(0.35 if critical_type == "heart" else 0.18)
	if critical_type != "" and shooter == Net.local_peer:
		_start_killcam(muzzle, hit_pos)

func _spawn_tracer(from: Vector3, to: Vector3, critical: bool) -> void:
	if effects == null:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := from.distance_to(to)
	box.size = Vector3(0.025, 0.025, maxf(0.1, length))
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.25)
	mat.emission_energy = 1.5
	mi.material_override = mat
	mi.look_at_from_position((from + to) * 0.5, to)
	effects.add_tracer(mi, 0.09)

func on_animal_died(animal_id: int, pos: Vector3, species: String, critical: bool, shooter: int, coin_value: int) -> void:
	if debug_state:
		print("[DBG] died animal=%d crit=%s shooter=%d" % [animal_id, str(critical), shooter])
	var node = _find_animal(animal_id)
	if node != null and is_instance_valid(node):
		GameState.animals.erase(node)
		node.queue_free()
	if effects != null:
		var sc: float = float(GameData.SPECIES[species]["scale"])
		effects.spawn_gore(pos, sc, GameData.SPECIES[species]["color"], critical)
	if Net.is_host:
		var n := randi_range(3, 6)
		for _i in range(n):
			coin_id_counter += 1
			Net.rpc("spawn_coins", coin_id_counter, pos + Vector3(randf_range(-0.8, 0.8), 0.2, randf_range(-0.8, 0.8)), maxi(1, int(round(float(coin_value) / float(n)))))
	if shooter == Net.local_peer:
		var killer = get_player_node(shooter)
		if killer != null:
			killer.kills += 1
			hud.message("%s повержен%s" % [GameData.SPECIES[species]["name"], " — КРИТ!" if critical else ""], Color(1.0, 0.4, 0.3))

func on_spawn_coin(coin_id: int, pos: Vector3, value: int) -> void:
	if effects != null:
		effects.spawn_coin(coin_id, pos, value, Net.is_host)

func on_coin_taken(coin_id: int) -> void:
	if effects != null:
		effects.remove_coin(coin_id)

func on_coins_update(peer: int, total: int) -> void:
	if player_nodes.has(peer):
		player_nodes[peer].coins = total
	if peer == Net.local_peer and hud != null:
		hud.message("Монеты: %d" % total, Color(1.0, 0.82, 0.2))

func on_health_update(peer: int, health: float) -> void:
	if player_nodes.has(peer):
		var p = player_nodes[peer]
		p.health = health
		p.alive = health > 0.0
		if peer == Net.local_peer:
			if health <= 0.0:
				p.respawn_timer = 3.0
			if hud != null:
				hud.flash_damage()

func on_inventory_order(peer: int, order: Array) -> void:
	if debug_state:
		print("[DBG] inventory_order peer=%d order=%s" % [peer, str(order)])
	if player_nodes.has(peer):
		player_nodes[peer].set_inventory_order(order)

func on_spin_result(peer: int, reels: Array, text: String, weapon_id: String, coins: int, inventory: Array) -> void:
	if debug_state:
		print("[DBG] spin peer=%d coins=%d weapon=%s text=%s" % [peer, coins, weapon_id, text])
	if player_nodes.has(peer):
		player_nodes[peer].set_state(coins, player_nodes[peer].health, player_nodes[peer].kills, inventory, player_nodes[peer].weapon_index)
	if peer == Net.local_peer and hud != null and hud.casino != null:
		hud.casino.show_result(reels, text, weapon_id)
		Sfx.play("crit" if weapon_id != "" else "spin", 0.7)

func _on_net_message(text: String, color: Color) -> void:
	if status_label != null and menu_layer.visible:
		status_label.text = text
	if hud != null:
		hud.message(text, color)

# ---------------------------------------------------------------- СЕТЬ ---

func _process(delta: float) -> void:
	if debug_state and world_ready:
		debug_timer -= delta
		if debug_timer <= 0.0:
			debug_timer = 2.0
			var p = player_nodes.get(Net.local_peer, null)
			if p != null:

				print("[DBG] player=%s ground=%.2f floor=%s animals=%d coins=%d nodes=%d inv=%s" % [
					str(p.global_position), world.ground_height(p.global_position.x, p.global_position.z),
					str(p.is_on_floor()), GameState.animals.size(), p.coins, player_nodes.size(), str(p.inventory)])
	if not world_ready:
		return
	if debug_args.has("--test-weapon") and not debug_weapon_done:
		var lpw = player_nodes.get(Net.local_peer, null)
		var widx := debug_args.find("--test-weapon")
		if lpw != null and widx >= 0 and widx + 1 < debug_args.size():
			var wid: String = debug_args[widx + 1]
			if GameData.WEAPONS.has(wid):
				if not lpw.inventory.has(wid):
					for si in range(lpw.inventory.size()):
						if lpw.inventory[si] == "":
							lpw.inventory[si] = wid
							break
				lpw.equip(lpw.inventory.find(wid))
				debug_weapon_done = true
	if debug_look_down and not debug_look_done:
		var lp0 = player_nodes.get(Net.local_peer, null)
		if lp0 != null:
			lp0.pitch = -0.95
			debug_look_done = true
	if test_inventory:
		test_inventory_timer -= delta
		if test_inventory_timer <= 0.0:
			test_inventory = false
			var lp2 = player_nodes.get(Net.local_peer, null)
			if lp2 != null and hud != null:
				lp2.inventory = ["pistol", "silver", "shotgun", "sniper", "", "", "", ""]
				hud.inventory.open(lp2)
				print("[DBG] inventory opened visible=%s mouse=%d" % [str(hud.inventory.visible), Input.mouse_mode])
				if debug_args.has("--test-reorder"):
					var new_order := ["shotgun", "silver", "pistol", "sniper", "", "", "", ""]
					Net.rpc("set_inventory_order", new_order)
					print("[DBG] reorder local=%s host=%s" % [
						str(lp2.inventory), str(Net.players.get(Net.local_peer, {}).get("inventory", []))])
	if test_casino:
		test_casino_timer -= delta
		if test_casino_timer <= 0.0:
			test_casino = false
			var lp = player_nodes.get(Net.local_peer, null)
			if lp != null and hud != null and hud.casino != null:
				hud.casino.open(lp)
				print("[DBG] casino opened visible=%s inside=%s pos=%s size=%s rect=%s panelrect=%s" % [
					str(hud.casino.visible), str(hud.casino.is_inside_tree()),
					str(hud.casino.position), str(hud.casino.size),
					str(hud.casino.get_global_rect()), str(hud.casino.panel.get_global_rect())])
	if test_spin:
		test_spin_timer -= delta
		if test_spin_timer <= 0.0:
			test_spin = false
			Net.rpc("spin_request")
	if test_fire and camera != null:
		test_fire_timer -= delta
		if test_fire_timer <= 0.0:
			test_fire_timer = 2.0
			if not Net.is_host:
				Net.rpc("request_shoot", camera.global_position, -camera.global_basis.z, "pistol", camera.global_position, 1)
				return
			var nearest = null
			var best := 1.0e9
			for a in GameState.animals:
				if a == null or not is_instance_valid(a) or a.remote_proxy:
					continue
				var d: float = a.global_position.distance_squared_to(camera.global_position)
				if d < best:
					best = d
					nearest = a
			if nearest != null:
				var target: Vector3 = nearest.to_global(nearest.data["weak_heart"])
				var origin: Vector3 = nearest.to_global(Vector3(0.0, 0.2, -2.5))
				var dir := (target - origin).normalized()
				Net.rpc("request_shoot", origin, dir, "sniper", origin, 0)
	if Net.is_host:
		snapshot_timer -= delta
		if snapshot_timer <= 0.0:
			snapshot_timer = 0.09
			_send_snapshots()
		if GameState.animals.size() < 80 and randf() < delta * 0.35:
			var pool := ["rabbit", "rabbit", "deer", "boar", "fox", "wolf", "bear"]
			_spawn_animal(pool[randi_range(0, pool.size() - 1)])
	_update_killcam()

func _send_snapshots() -> void:
	var pdata := []
	for peer in player_nodes.keys():
		var p = player_nodes[peer]
		if not is_instance_valid(p):
			continue
		# Состояние хоста тоже должно быть актуальным (например, для списка игроков).
		var st: Dictionary = Net.players.get(peer, {})
		if not st.is_empty():
			st["pos"] = p.global_position
			st["yaw"] = p.yaw
			st["pitch"] = p.pitch
		pdata.append([peer, p.global_position.x, p.global_position.y, p.global_position.z, p.yaw, p.pitch])
	var adata := []
	for a in GameState.animals:
		if a == null or not is_instance_valid(a) or a.remote_proxy:
			continue
		adata.append([a.animal_id, a.species_id, a.global_position.x, a.global_position.y, a.global_position.z, a.rotation.y, a.ability_active, int(a.ability_end > Time.get_ticks_msec())])
	Net.snapshot_tick(pdata, adata)

# ------------------------------------------------------------- КИЛЛКАМ ---

func _start_killcam(muzzle: Vector3, hit: Vector3) -> void:
	if cinematic:
		return
	cinematic = true
	Engine.time_scale = 0.16
	var shooter = player_nodes.get(Net.local_peer, null)
	if shooter != null and is_instance_valid(shooter):
		shooter.set_cinematic(true)
	bullet_node = effects.spawn_bullet(muzzle)
	killcam = {"t0": Time.get_ticks_msec(), "muzzle": muzzle, "hit": hit}
	hud.set_cinematic(true)
	broadcast("КРИТ! Замедление времени...", Color(1.0, 0.3, 0.22))

func _update_killcam() -> void:
	if not cinematic or killcam.is_empty():
		return
	var t := (Time.get_ticks_msec() - int(killcam["t0"])) / 1000.0
	var muzzle: Vector3 = killcam["muzzle"]
	var hit: Vector3 = killcam["hit"]
	if t < 0.9:
		var f := clampf(t / 0.9, 0.0, 1.0)
		var bullet_pos := muzzle.lerp(hit, f) + Vector3.UP * sin(f * PI) * 0.25
		if is_instance_valid(bullet_node):
			bullet_node.global_position = bullet_pos
			bullet_node.look_at(hit)
		var dir := (hit - muzzle).normalized()
		var right := dir.cross(Vector3.UP)
		if right.length_squared() < 0.01:
			right = dir.cross(Vector3.RIGHT)
		right = right.normalized()
		var cam_up := right.cross(dir).normalized()
		var angle := f * TAU * 0.95
		var offset := right * cos(angle) * 2.3 + cam_up * sin(angle) * 1.5 - dir * 0.9
		var desired := bullet_pos + offset
		camera.global_position = _safe_cinematic_camera(bullet_pos, desired)
		camera.look_at(bullet_pos + dir * maxf(1.0, bullet_pos.distance_to(hit) * 0.4), cam_up)
		camera.fov = lerpf(75.0, 34.0, f)
	elif t > 1.9:
		_end_killcam()

## Не даём орбитальной камере зайти внутрь геометрии: стены и рельеф проверяем
## рейкастом по физике, деревья/камни/кусты — упрощёнными преградами мира.
func _safe_cinematic_camera(from: Vector3, desired: Vector3) -> Vector3:
	var delta := desired - from
	var dist := delta.length()
	if dist < 0.001:
		return desired
	var dir := delta / dist
	var allowed := dist
	if stage != null and stage.get_world_3d() != null:
		var query := PhysicsRayQueryParameters3D.create(from, desired)
		query.collision_mask = 1 # только статичный мир, не звери
		var shooter = player_nodes.get(Net.local_peer, null)
		if shooter != null and is_instance_valid(shooter):
			query.exclude = [shooter.get_rid()]
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			allowed = minf(allowed, maxf(0.0, from.distance_to(hit["position"]) - 0.3))
	if world != null and world.has_method("occluder_hit_t"):
		var hit_t: float = world.occluder_hit_t(from, desired)
		if hit_t >= 0.0:
			allowed = minf(allowed, maxf(0.0, hit_t * dist - 0.25))
	allowed = maxf(allowed, 0.35) # камера не должна оказаться внутри пули
	return from + dir * allowed

func _end_killcam() -> void:
	cinematic = false
	Engine.time_scale = 1.0
	killcam = {}
	if bullet_node != null and is_instance_valid(bullet_node):
		bullet_node.queue_free()
	bullet_node = null
	camera.fov = 75.0
	var shooter = player_nodes.get(Net.local_peer, null)
	if shooter != null and is_instance_valid(shooter):
		shooter.set_cinematic(false)
	if hud != null:
		hud.set_cinematic(false)

func shake(amount: float) -> void:
	var p = player_nodes.get(Net.local_peer, null)
	if p != null and is_instance_valid(p):
		p.add_shake(amount)

func try_ability_sound(pos: Vector3) -> void:
	var lp = player_nodes.get(Net.local_peer, null)
	if lp == null or not is_instance_valid(lp):
		return
	if lp.global_position.distance_squared_to(pos) > 1400.0:
		return
	var now := Time.get_ticks_msec()
	if now - last_ability_sound < 2200:
		return
	last_ability_sound = now
	Sfx.play("ability", 0.22)

func broadcast(text: String, color: Color = Color.WHITE) -> void:
	if hud != null:
		hud.message(text, color)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and world_ready and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if player_nodes.has(Net.local_peer):
			player_nodes[Net.local_peer].look(event.relative)
	if event is InputEventKey and event.keycode == KEY_ESCAPE and not event.echo:
		if world_ready:
			_toggle_menu()

func _toggle_menu() -> void:
	menu_layer.visible = not menu_layer.visible
	if not menu_layer.visible and settings_panel != null:
		settings_panel.visible = false
	if menu_layer.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.running = false
		status_label.text = "Пауза. Esc — вернуться в игру."
	else:
		GameState.running = true
		if hud != null:
			hud.update_mouse_mode()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

