class_name Player
extends CharacterBody3D

## Игрок в LAN-версии. Локальный игрок управляется владельцем клиента,
## остальные — сетевые прокси, получающие позиции от хоста.

var peer := 1
var player_name := "Охотник"
var is_local := false
var camera: Camera3D = null
var hud = null

var coins := 30
var health := 100.0
var kills := 0
var alive := true
var respawn_timer := 0.0
var invuln := 0.0
var report_timer := 0.0

var yaw := 0.0
var pitch := 0.0
var third_person := false
var cinematic_mode := false

var inventory: Array = ["pistol", "", "", "", "", "", "", ""]
var weapon_index := 0
var ammo := 12
var reloading := false
var reload_timer := 0.0
var fire_timer := 0.0

var base_speed := 7.2
var gravity := 24.0
var jump_speed := 8.0

var viewmodel: Node3D = null
var body_model: Node3D = null
var muzzle_flash: OmniLight3D = null
var flash_timer := 0.0
var spawn_point := Vector3(-6.0, 0.0, 13.0)

func setup(peer_id: int, pname: String, cam: Camera3D, hud_ref, local: bool) -> void:
	peer = peer_id
	player_name = pname
	is_local = local
	camera = cam
	hud = hud_ref
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	add_to_group("players")
	name = "Player_%d" % peer_id
	spawn_point = position
	ammo = int(GameData.WEAPONS["pistol"]["mag"])
	_build_body()
	body_model.visible = not local
	if local:
		_setup_actions()
		_build_viewmodel()

func _setup_actions() -> void:
	_add("move_fwd", KEY_W)
	_add("move_back", KEY_S)
	_add("move_left", KEY_A)
	_add("move_right", KEY_D)
	_add("fire", -1, MOUSE_BUTTON_LEFT)
	_add("reload", KEY_R)
	_add("interact", KEY_E)
	_add("camera", KEY_V)
	_add("jump", KEY_SPACE)
	_add("spin", KEY_F)
	_add("inventory", KEY_TAB)
	for i in range(8):
		_add("equip%d" % (i + 1), KEY_1 + i)

func _add(action: String, key: int, mouse: int = -1) -> void:
	var full := "local_" + action
	if not InputMap.has_action(full):
		InputMap.add_action(full)
	if key >= 0:
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(full, e)
	if mouse >= 0:
		var m := InputEventMouseButton.new()
		m.button_index = mouse
		InputMap.action_add_event(full, m)

func _action(base: String) -> String:
	return "local_" + base

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	if not GameState.running or cinematic_mode:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if hud != null and hud.inventory != null and hud.inventory.is_open:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if not alive:
		if Net.is_host:
			respawn_timer -= delta
			if respawn_timer <= 0.0:
				_respawn()
		return
	invuln = maxf(0.0, invuln - delta)

	var f := Input.get_action_strength(_action("move_fwd")) - Input.get_action_strength(_action("move_back"))
	var r := Input.get_action_strength(_action("move_right")) - Input.get_action_strength(_action("move_left"))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move := forward * f + right * r
	if move.length_squared() > 1.0:
		move = move.normalized()
	velocity.x = lerp(velocity.x, move.x * base_speed, clampf(delta * 14.0, 0.0, 1.0))
	velocity.z = lerp(velocity.z, move.z * base_speed, clampf(delta * 14.0, 0.0, 1.0))
	velocity.y -= gravity * delta
	if is_on_floor() and Input.is_action_just_pressed(_action("jump")):
		velocity.y = jump_speed
	move_and_slide()

	report_timer -= delta
	if report_timer <= 0.0 and not Net.is_host:
		report_timer = 0.05
		Net.rpc("report_transform", global_position, yaw, pitch)

func _process(delta: float) -> void:
	if not is_local or camera == null or not is_instance_valid(camera):
		return
	if cinematic_mode:
		return
	_update_camera()
	_update_weapon()
	if not GameState.running or not alive:
		return

	fire_timer -= delta
	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
	if flash_timer > 0.0:
		flash_timer -= delta
		if muzzle_flash != null:
			muzzle_flash.light_energy = 0.0

	if Input.is_action_just_pressed(_action("camera")):
		_toggle_camera()
	if Input.is_action_just_pressed(_action("interact")):
		_interact()
	if Input.is_action_just_pressed(_action("reload")):
		start_reload()
	if Input.is_action_just_pressed(_action("spin")):
		Net.rpc("spin_request")
	if Input.is_action_just_pressed(_action("inventory")) and hud != null and hud.inventory != null:
		if hud.casino != null and hud.casino.is_open:
			hud.casino.close()
		hud.inventory.toggle(self)
	for i in range(8):
		if Input.is_action_just_pressed(_action("equip%d" % (i + 1))):
			equip(i)
	if hud != null and ((hud.casino != null and hud.casino.is_open) or (hud.inventory != null and hud.inventory.is_open)):
		return
	var w: Dictionary = GameData.WEAPONS[current_weapon_id()]
	if Input.is_action_pressed(_action("fire")) and (bool(w["auto"]) or Input.is_action_just_pressed(_action("fire"))):
		if fire_timer <= 0.0 and not reloading:
			_shoot(w)

func apply_remote_state(st: Dictionary) -> void:
	if is_local:
		return
	var p: Vector3 = st.get("pos", global_position)
	position = p
	yaw = float(st.get("yaw", yaw))
	pitch = float(st.get("pitch", pitch))
	health = float(st.get("health", health))
	coins = int(st.get("coins", coins))
	kills = int(st.get("kills", kills))
	inventory = _normalize_inventory(st.get("inventory", inventory))
	alive = health > 0.0
	body_model.visible = true

func _normalize_inventory(inv: Array) -> Array:
	var result: Array = []
	for i in range(8):
		result.append(inv[i] if i < inv.size() else "")
	return result

func set_state(new_coins: int, new_health: float, new_kills: int, inv: Array, index: int) -> void:
	coins = new_coins
	health = new_health
	kills = new_kills
	inventory = _normalize_inventory(inv)
	weapon_index = clampi(index, 0, maxi(0, inventory.size() - 1))
	alive = health > 0.0
	if is_local:
		_rebuild_weapon_model()
		if hud != null and hud.inventory != null:
			hud.inventory.refresh()

func look(mouse_relative: Vector2) -> void:
	if not GameState.running or cinematic_mode or not alive:
		return
	yaw -= mouse_relative.x * 0.0022
	pitch -= mouse_relative.y * 0.0022
	pitch = clampf(pitch, -1.45, 1.45)

func _update_camera() -> void:
	if camera == null:
		return
	var eye := global_position + Vector3(0.0, 1.62, 0.0)
	var fwd := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	if third_person:
		camera.global_position = eye - fwd * 4.2 + Vector3(0.0, 0.65, 0.0)
		camera.look_at(eye + fwd * 12.0)
	else:
		camera.global_position = eye
		camera.rotation = Vector3(pitch, yaw, 0.0)

func _toggle_camera() -> void:
	third_person = not third_person
	if viewmodel != null:
		viewmodel.visible = not third_person
	body_model.visible = third_person
	if hud != null:
		hud.message("Камера: %s" % ("3-е лицо" if third_person else "1-е лицо"))

func _build_body() -> void:
	body_model = Node3D.new()
	body_model.name = "BodyModel"
	add_child(body_model)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34
	cap.height = 1.25
	torso.mesh = cap
	torso.position = Vector3(0.0, 1.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.34, 0.22) if peer % 2 == 1 else Color(0.24, 0.26, 0.48)
	torso.material_override = mat
	body_model.add_child(torso)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.23
	head.mesh = sph
	head.position = Vector3(0.0, 1.82, 0.0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.61, 0.45)
	head.material_override = skin
	body_model.add_child(head)
	var name_tag := Label3D.new()
	name_tag.text = player_name
	name_tag.font_size = 40
	name_tag.outline_size = 6
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position = Vector3(0.0, 2.35, 0.0)
	body_model.add_child(name_tag)

func _build_viewmodel() -> void:
	if camera == null:
		return
	viewmodel = Node3D.new()
	viewmodel.name = "ViewModel"
	camera.add_child(viewmodel)
	viewmodel.position = Vector3(0.30, -0.28, -0.62)
	_rebuild_weapon_model()
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color(1.0, 0.72, 0.25)
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 8.0
	muzzle_flash.position = Vector3(0.0, 0.0, -1.0)
	viewmodel.add_child(muzzle_flash)

func _rebuild_weapon_model() -> void:
	if viewmodel == null:
		return
	for c in viewmodel.get_children():
		if c != muzzle_flash:
			c.queue_free()
	if inventory.is_empty():
		return
	var w: Dictionary = GameData.WEAPONS[current_weapon_id()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = w["color"]
	mat.metallic = 0.65
	mat.roughness = 0.35
	var rc: Color = GameData.RARITY_COLORS[int(w["rarity"])]
	mat.emission_enabled = int(w["rarity"]) >= 2
	mat.emission = rc
	mat.emission_energy = 0.35
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.13, 0.15, 0.55)
	body.mesh = box
	body.position = Vector3(0.0, 0.0, -0.15)
	body.material_override = mat
	viewmodel.add_child(body)
	var barrel := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(0.07, 0.07, 0.42)
	barrel.mesh = b2
	barrel.position = Vector3(0.0, 0.02, -0.6)
	barrel.material_override = mat
	viewmodel.add_child(barrel)
	var grip := MeshInstance3D.new()
	var g := BoxMesh.new()
	g.size = Vector3(0.09, 0.28, 0.11)
	grip.mesh = g
	grip.position = Vector3(0.0, -0.18, 0.07)
	grip.rotation_degrees.x = -18.0
	grip.material_override = mat
	viewmodel.add_child(grip)
	if int(w["rarity"]) >= 3:
		var scope := MeshInstance3D.new()
		var s := CylinderMesh.new()
		s.top_radius = 0.045
		s.bottom_radius = 0.045
		s.height = 0.28
		scope.mesh = s
		scope.rotation_degrees.x = 90.0
		scope.position = Vector3(0.0, 0.13, -0.25)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.05, 0.05, 0.06)
		scope.material_override = sm
		viewmodel.add_child(scope)

func _update_weapon() -> void:
	if viewmodel == null or not viewmodel.visible:
		return
	var bob := sin(Time.get_ticks_msec() * 0.009) * 0.008 * clampf(velocity.length() / 6.0, 0.0, 1.0)
	viewmodel.position.y = -0.28 + bob
	viewmodel.position.z = -0.62 + (flash_timer * 0.45 if flash_timer > 0.0 else 0.0)
	viewmodel.rotation_degrees.z = sin(reload_timer * 9.0) * 18.0 if reloading else 0.0

func _shoot(w: Dictionary) -> void:
	if ammo <= 0:
		start_reload()
		return
	var spread := float(w["spread"])
	var pellets := int(w["pellets"])
	for _i in range(pellets):
		var dir := (
			-camera.global_basis.z
			+ camera.global_basis.x * randf_range(-spread, spread)
			+ camera.global_basis.y * randf_range(-spread, spread)
		).normalized()
		Net.rpc("request_shoot", camera.global_position, dir, current_weapon_id(), get_muzzle_position())
	ammo -= 1
	fire_timer = float(w["rate"])
	flash_timer = 0.09
	if muzzle_flash != null:
		muzzle_flash.light_energy = 3.0
	Sfx.play("shot", 0.65)

func start_reload() -> void:
	var w: Dictionary = GameData.WEAPONS[current_weapon_id()]
	if reloading or ammo >= int(w["mag"]):
		return
	reloading = true
	reload_timer = float(w["reload"])
	if hud != null:
		hud.message("Перезарядка...")

func _finish_reload() -> void:
	reloading = false
	ammo = int(GameData.WEAPONS[current_weapon_id()]["mag"])

func _interact() -> void:
	if GameState.world == null or hud == null or hud.casino == null:
		return
	if hud.inventory != null and hud.inventory.is_open:
		hud.inventory.close()
		return
	if hud.casino.is_open:
		hud.casino.close()
		return
	if global_position.distance_to(GameState.world.slot_position) < 4.5:
		hud.casino.open(self)
	else:
		hud.message("Подойдите к игровому автомату в казино")

func take_damage(amount: float, from_pos: Vector3) -> void:
	if not Net.is_host or not alive or invuln > 0.0:
		return
	health -= amount
	invuln = 0.45
	Net.rpc("health_update", peer, health)
	if health <= 0.0:
		health = 0.0
		alive = false
		respawn_timer = 3.0
		coins = int(coins * 0.8)
		Net.rpc("coins_update", peer, coins)
		if hud != null:
			hud.message("Вы пали... возрождение через 3 сек. Потеря 20% монет", Color(1.0, 0.3, 0.25))

func _respawn() -> void:
	alive = true
	health = 100.0
	invuln = 2.0
	global_position = spawn_point + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	velocity = Vector3.ZERO
	Net.rpc("health_update", peer, health)
	if hud != null:
		hud.message("Вы вернулись в строй", Color(0.5, 1.0, 0.5))

func rebuild_viewmodel() -> void:
	if is_local:
		_rebuild_weapon_model()

func set_inventory_order(order: Array) -> void:
	inventory = _normalize_inventory(order)
	weapon_index = clampi(weapon_index, 0, maxi(0, inventory.size() - 1))
	if is_local:
		_rebuild_weapon_model()
		if hud != null and hud.inventory != null:
			hud.inventory.refresh()

func equip(index: int) -> void:
	if index < 0 or index >= inventory.size() or inventory[index] == "":
		return
	weapon_index = index
	reloading = false
	ammo = int(GameData.WEAPONS[inventory[index]]["mag"])
	fire_timer = 0.15
	_rebuild_weapon_model()

func get_muzzle_position() -> Vector3:
	if camera == null:
		return global_position + Vector3.UP
	return camera.to_global(Vector3(0.3, -0.22, -0.9))

func set_cinematic(value: bool) -> void:
	cinematic_mode = value
	if viewmodel != null:
		viewmodel.visible = not value and not third_person
	if hud != null:
		hud.set_cinematic(value)

func current_weapon_id() -> String:
	var id: String = inventory[clampi(weapon_index, 0, maxi(0, inventory.size() - 1))]
	return id if id != "" else "pistol"
