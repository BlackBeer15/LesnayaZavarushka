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

var inventory: Array = GameData.starter_inventory()
var weapon_index := 0
var ammo := 12
var reloading := false
var reload_timer := 0.0
var fire_timer := 0.0
var ammo_type := 0
var reserves: Array[int] = [72, 24, 36]

var aiming := false
var crouching := false
var swimming := false
var stamina := 100.0
var exhausted := false
var bleeding := 0.0
var last_bleed_sync := 0
var noise_radius := 6.0
var noise_boost := 0.0
var shot_streak := 0
var streak_timer := 0.0
var aim_punch := Vector2.ZERO
var shake_amount := 0.0

var vm_slide: Node3D = null
var vm_bolt: Node3D = null
var vm_pump: Node3D = null
var vm_mag: Node3D = null
var vm_slide_z := 0.0
var vm_bolt_z := 0.0
var vm_pump_z := 0.0
var vm_mag_y := 0.0

var base_speed := 7.2
var gravity := 24.0
var jump_speed := 8.0

var viewmodel: Node3D = null
var tp_weapon_anchor: Node3D = null
var tp_weapon: Node3D = null
var body_model: Node3D = null
var upper_body: Node3D = null
var leg_pivots: Array[Node3D] = []
var walk_phase := 0.0
var remote_speed := 0.0
var _last_remote_pos := Vector3.ZERO
var _last_remote_time := 0
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
	_add("aim", -1, MOUSE_BUTTON_RIGHT)
	_add("reload", KEY_R)
	_add("sprint", KEY_SHIFT)
	_add("crouch", KEY_CTRL)
	_add("next_ammo", KEY_Q)
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
	noise_boost = maxf(0.0, noise_boost - delta)
	streak_timer = maxf(0.0, streak_timer - delta)
	if streak_timer <= 0.0:
		shot_streak = 0
	if bleeding > 0.0:
		bleeding -= delta
		health -= 2.2 * delta
		if health <= 0.0:
			take_damage(0.0, global_position)
		elif int(Time.get_ticks_msec() / 500) != last_bleed_sync:
			last_bleed_sync = int(Time.get_ticks_msec() / 500)
			Net.rpc("health_update", peer, health)

	# Плавание в озере
	var lake_center := Vector2(-82.0, 74.0)
	swimming = Vector2(global_position.x, global_position.z).distance_to(lake_center) < 21.0
	if swimming:
		var water_y: float = GameState.world.ground_height(lake_center.x, lake_center.y) - 0.30
		global_position.y = lerpf(global_position.y, water_y, clampf(delta * 4.0, 0.0, 1.0))
		velocity.y = 0.0

	var want_sprint := Input.is_action_pressed(_action("sprint")) and not aiming and not crouching and not swimming
	if want_sprint and (Input.get_action_strength(_action("move_fwd")) > 0.1 or velocity.length() > 1.0):
		stamina = maxf(0.0, stamina - delta * 18.0)
	else:
		stamina = minf(100.0, stamina + delta * 12.0)
	exhausted = stamina <= 0.5
	if Input.is_action_just_pressed(_action("crouch")):
		crouching = not crouching

	var f := Input.get_action_strength(_action("move_fwd")) - Input.get_action_strength(_action("move_back"))
	var r := Input.get_action_strength(_action("move_right")) - Input.get_action_strength(_action("move_left"))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move := forward * f + right * r
	if move.length_squared() > 1.0:
		move = move.normalized()
	var speed := base_speed
	if want_sprint and not exhausted:
		speed *= 1.55
	elif crouching:
		speed *= 0.48
	elif aiming:
		speed *= 0.62
	if swimming:
		speed *= 0.65
	velocity.x = lerp(velocity.x, move.x * speed, clampf(delta * 14.0, 0.0, 1.0))
	velocity.z = lerp(velocity.z, move.z * speed, clampf(delta * 14.0, 0.0, 1.0))
	if not swimming:
		velocity.y -= gravity * delta
		if is_on_floor() and Input.is_action_just_pressed(_action("jump")):
			velocity.y = jump_speed
	move_and_slide()

	noise_radius = 5.0 + move.length() * 4.0
	if want_sprint and velocity.length() > 1.0:
		noise_radius = 20.0
	elif crouching:
		noise_radius = 2.0
	elif aiming:
		noise_radius = 4.0
	if noise_boost > 0.0:
		noise_radius = maxf(noise_radius, 38.0)

	report_timer -= delta
	if report_timer <= 0.0 and not Net.is_host:
		report_timer = 0.05
		Net.rpc("report_transform", global_position, yaw, pitch)

func _process(delta: float) -> void:
	_update_body(delta)
	if not is_local or camera == null or not is_instance_valid(camera):
		return
	if cinematic_mode:
		return
	aiming = Input.is_action_pressed(_action("aim")) and alive
	aim_punch = aim_punch.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	shake_amount = maxf(0.0, shake_amount - delta * 2.2)
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
	if Input.is_action_just_pressed(_action("next_ammo")):
		ammo_type = (ammo_type + 1) % GameData.AMMO_TYPES.size()
		reloading = false
		ammo = int(GameData.WEAPONS[current_weapon_id()]["mag"])
		if hud != null:
			hud.message("Патроны: %s" % GameData.AMMO_TYPES[ammo_type]["name"], GameData.AMMO_TYPES[ammo_type]["color"])
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

func _update_body(delta: float) -> void:
	if body_model == null or not is_instance_valid(body_model):
		return
	body_model.rotation.y = yaw
	if upper_body != null:
		upper_body.rotation.x = clampf(pitch, -1.3, 1.3)
	var speed := 0.0
	if is_local:
		speed = clampf(Vector2(velocity.x, velocity.z).length(), 0.0, 12.0)
	else:
		if _last_remote_time > 0 and Time.get_ticks_msec() - _last_remote_time > 250:
			remote_speed = 0.0
		speed = clampf(remote_speed, 0.0, 12.0)
	if speed > 0.2:
		walk_phase += delta * (2.5 + speed * 1.25)
	else:
		walk_phase = lerpf(walk_phase, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	var amplitude := clampf(speed / 8.0, 0.0, 1.0) * 0.55
	for i in range(leg_pivots.size()):
		var pivot: Node3D = leg_pivots[i]
		if is_instance_valid(pivot):
			pivot.rotation.x = sin(walk_phase + float(i) * PI) * amplitude

func apply_remote_state(st: Dictionary) -> void:
	if is_local:
		return
	var p: Vector3 = st.get("pos", global_position)
	var now := Time.get_ticks_msec()
	if _last_remote_time > 0:
		var dt := float(now - _last_remote_time) / 1000.0
		if dt > 0.004 and dt < 1.0:
			var instant := clampf(_last_remote_pos.distance_to(p) / dt, 0.0, 12.0)
			remote_speed = lerpf(remote_speed, instant, 0.5)
	_last_remote_pos = p
	_last_remote_time = now
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
	var eye_h := 1.05 if crouching else 1.62
	var eye := global_position + Vector3(0.0, eye_h, 0.0)
	var aim_pitch := pitch + aim_punch.y
	var aim_yaw := yaw + aim_punch.x
	var fwd := Vector3(-sin(aim_yaw) * cos(aim_pitch), sin(aim_pitch), -cos(aim_yaw) * cos(aim_pitch))
	if third_person:
		camera.global_position = eye - fwd * 4.2 + Vector3(0.0, 0.65, 0.0)
		camera.look_at(eye + fwd * 12.0)
	else:
		camera.global_position = eye
		camera.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
	if shake_amount > 0.0:
		camera.global_position += Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		) * shake_amount * 0.06
		camera.rotation.x += randf_range(-1.0, 1.0) * shake_amount * 0.025
	camera.fov = lerpf(camera.fov, 42.0 if (aiming and not third_person) else 75.0, 0.25)

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
	# Корень поворачивается по yaw, верхняя часть — по pitch, ноги остаются вертикальными.
	upper_body = Node3D.new()
	upper_body.name = "UpperBody"
	body_model.add_child(upper_body)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.34, 0.22) if peer % 2 == 1 else Color(0.24, 0.26, 0.48)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34
	cap.height = 1.25
	torso.mesh = cap
	torso.position = Vector3(0.0, 1.0, 0.0)
	torso.material_override = mat
	upper_body.add_child(torso)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.23
	sph.height = 0.46 # SphereMesh.height по умолчанию 1.0 — без этого голова — игла
	head.mesh = sph
	head.position = Vector3(0.0, 1.82, 0.0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.61, 0.45)
	head.material_override = skin
	upper_body.add_child(head)

	# Руки тянутся от плеч к рукояти оружия и наклоняются вместе со взглядом.
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = _sleeve_color()
	for sx in [-1.0, 1.0]:
		_bone(upper_body, Vector3(0.30 * sx, 1.44, 0.02), Vector3(0.22 * sx, 1.28, -0.22), 0.12, sleeve)
		_bone(upper_body, Vector3(0.22 * sx, 1.28, -0.22), Vector3(0.16 * sx, 1.14, -0.34), 0.10, sleeve)

	leg_pivots.clear()
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.16, 0.18, 0.14)
	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.09, 0.08, 0.07)
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.16 * sx, 0.75, 0.0)
		body_model.add_child(pivot)
		leg_pivots.append(pivot)
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.12
		leg_mesh.height = 0.72
		leg.mesh = leg_mesh
		leg.position = Vector3(0.0, -0.36, 0.0)
		leg.material_override = pants
		pivot.add_child(leg)
		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.22, 0.12, 0.30)
		boot.mesh = boot_mesh
		boot.position = Vector3(0.0, -0.70, -0.06)
		boot.material_override = boot_mat
		pivot.add_child(boot)

	tp_weapon_anchor = Node3D.new()
	tp_weapon_anchor.name = "TPWeaponAnchor"
	tp_weapon_anchor.position = Vector3(0.20, 1.18, -0.30)
	tp_weapon_anchor.rotation_degrees = Vector3(-6.0, -8.0, 0.0)
	tp_weapon_anchor.scale = Vector3(0.52, 0.52, 0.52)
	upper_body.add_child(tp_weapon_anchor)
	_rebuild_third_person_weapon()

	var name_tag := Label3D.new()
	name_tag.text = player_name
	name_tag.font_size = 40
	name_tag.outline_size = 6
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position = Vector3(0.0, 2.35, 0.0)
	body_model.add_child(name_tag)

func _bone(parent: Node3D, a: Vector3, b: Vector3, thickness: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, a.distance_to(b))
	mi.mesh = box
	mi.material_override = mat
	var z_axis := (a - b).normalized()
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	var y_axis := z_axis.cross(x_axis)
	mi.transform = Transform3D(Basis(x_axis, y_axis, z_axis), (a + b) * 0.5)
	parent.add_child(mi)

func _sleeve_color() -> Color:
	return Color(0.20, 0.34, 0.22) if peer % 2 == 1 else Color(0.24, 0.26, 0.48)

func _rebuild_third_person_weapon() -> void:
	if tp_weapon_anchor == null:
		return
	if tp_weapon != null and is_instance_valid(tp_weapon):
		tp_weapon.queue_free()
	tp_weapon = WeaponModels.build(current_weapon_id(), _sleeve_color())
	tp_weapon_anchor.add_child(tp_weapon)

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
	var model := WeaponModels.build(current_weapon_id(), _sleeve_color())
	viewmodel.add_child(model)
	var muzzle: Vector3 = model.get_meta("muzzle", Vector3(0.0, 0.0, -0.5))
	viewmodel.set_meta("muzzle", muzzle)
	if muzzle_flash != null:
		muzzle_flash.position = muzzle
	vm_slide = model.find_child("Slide", true, false)
	vm_bolt = model.find_child("BoltHandle", true, false)
	vm_pump = model.find_child("Pump", true, false)
	vm_mag = model.find_child("Magazine", true, false)
	vm_slide_z = vm_slide.position.z if vm_slide != null else 0.0
	vm_bolt_z = vm_bolt.position.z if vm_bolt != null else 0.0
	vm_pump_z = vm_pump.position.z if vm_pump != null else 0.0
	vm_mag_y = vm_mag.position.y if vm_mag != null else 0.0
	_rebuild_third_person_weapon()

func _update_weapon() -> void:
	if viewmodel == null or not viewmodel.visible:
		return
	var bob := sin(Time.get_ticks_msec() * 0.009) * 0.008 * clampf(velocity.length() / 6.0, 0.0, 1.0)
	var ads_offset := -0.10 if aiming else 0.0
	viewmodel.position.x = lerpf(viewmodel.position.x, 0.30 + ads_offset, 0.25)
	viewmodel.position.y = -0.28 + bob - (0.035 if aiming else 0.0)
	viewmodel.position.z = -0.62 + (flash_timer * 0.45 if flash_timer > 0.0 else 0.0)
	viewmodel.rotation_degrees.x = -flash_timer * 55.0
	viewmodel.rotation_degrees.z = sin(reload_timer * 9.0) * 18.0 if reloading else 0.0
	var kick := clampf(flash_timer / 0.09, 0.0, 1.0)
	if vm_slide != null:
		vm_slide.position.z = vm_slide_z + kick * 0.08
	if vm_bolt != null:
		vm_bolt.position.z = vm_bolt_z + kick * 0.10
	if vm_pump != null:
		vm_pump.position.z = vm_pump_z + kick * 0.14
	if vm_mag != null:
		var drop := 0.0
		if reloading:
			var w: Dictionary = GameData.WEAPONS[current_weapon_id()]
			var prog := 1.0 - clampf(reload_timer / float(w["reload"]), 0.0, 1.0)
			drop = sin(prog * PI) * 0.22
		vm_mag.position.y = vm_mag_y - drop

func _shoot(w: Dictionary) -> void:
	if ammo <= 0:
		start_reload()
		return
	var wid := current_weapon_id()
	var spread := float(w["spread"])
	if aiming:
		spread *= 0.35
	spread *= 1.0 + float(shot_streak) * 0.12
	if velocity.length() > 1.0:
		spread *= 1.4
	if crouching:
		spread *= 0.7
	var pellets := int(w["pellets"])
	var muzzle := get_muzzle_position()
	for _i in range(pellets):
		var dir := (
			-camera.global_basis.z
			+ camera.global_basis.x * randf_range(-spread, spread)
			+ camera.global_basis.y * randf_range(-spread, spread)
		).normalized()
		Net.rpc("request_shoot", camera.global_position, dir, wid, muzzle, ammo_type)
	ammo -= 1
	fire_timer = float(w["rate"])
	flash_timer = 0.09
	if muzzle_flash != null:
		muzzle_flash.light_energy = 3.0
	Sfx.play_shot(wid, 0.85)
	var recoil: Vector2 = GameData.WEAPON_RECOIL.get(wid, Vector2(1.0, 0.3))
	aim_punch.y += recoil.x * (0.55 if aiming else 1.0) * deg_to_rad(1.0)
	aim_punch.x += randf_range(-recoil.y, recoil.y) * deg_to_rad(1.0)
	shot_streak += 1
	streak_timer = 0.45
	noise_boost = 0.35
	Net.rpc("make_noise", global_position, 42.0)
	if GameState.effects != null:
		GameState.effects.spawn_muzzle_flash(muzzle)
		GameState.effects.spawn_smoke(muzzle)
		GameState.effects.spawn_casing(camera.global_position + camera.global_basis.x * 0.25, camera.global_basis.x)

func start_reload() -> void:
	var w: Dictionary = GameData.WEAPONS[current_weapon_id()]
	if reloading or ammo >= int(w["mag"]):
		return
	if reserves[ammo_type] <= 0:
		if hud != null:
			hud.message("Нет патронов этого типа!", Color(1.0, 0.4, 0.3))
		return
	reloading = true
	reload_timer = float(w["reload"])
	if hud != null:
		hud.message("Перезарядка: %s" % GameData.AMMO_TYPES[ammo_type]["name"])

func _finish_reload() -> void:
	reloading = false
	var w: Dictionary = GameData.WEAPONS[current_weapon_id()]
	var need := int(w["mag"]) - ammo
	var take := mini(need, reserves[ammo_type])
	ammo += take
	reserves[ammo_type] -= take

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
	if amount >= 4.0:
		bleeding = 6.0
	add_shake(0.5)
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

func add_shake(amount: float) -> void:
	shake_amount = minf(1.2, shake_amount + amount)

func collect_pickup(kind: String) -> void:
	if not is_local:
		return
	match kind:
		"medkit":
			bleeding = 0.0
			Net.rpc("heal", peer, 45.0)
			if hud != null:
				hud.message("Аптечка: +45 здоровья", Color(0.4, 1.0, 0.5))
		"ammo_normal", "ammo_ap", "ammo_hp":
			var idx := 0
			if kind == "ammo_ap":
				idx = 1
			elif kind == "ammo_hp":
				idx = 2
			reserves[idx] += 18
			if hud != null:
				hud.message("%s: +18" % GameData.AMMO_TYPES[idx]["name"], GameData.AMMO_TYPES[idx]["color"])

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
	if viewmodel != null and viewmodel.has_meta("muzzle"):
		return viewmodel.to_global(viewmodel.get_meta("muzzle"))
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
