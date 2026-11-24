class_name Animal
extends CharacterBody3D

## Хищные и травоядные звери. На хосте живёт ИИ и урон, на клиентах —
## сетевые прокси, которые только интерполируют позицию и ability-эффект.

enum State { WANDER, FLEE, CHASE, CHARGE }

var animal_id := 0
var species_id := "rabbit"
var data: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var state: int = State.WANDER
var target = null
var dead := false
var frozen := false
var remote_proxy := false

var ability := ""
var ability_active := false
var ability_timer := 0.0
var ability_end := 0
var attack_cd := 0.0
var think_cd := 0.0
var wander_dir := Vector3.FORWARD

var fur_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var ability_label: Label3D
var visual: Node3D

func setup(id: int, species: String, pos: Vector3, proxy: bool = false) -> void:
	animal_id = id
	species_id = species
	remote_proxy = proxy
	data = GameData.SPECIES[species]
	max_hp = float(data["hp"])
	hp = max_hp
	position = pos
	scale = Vector3.ONE * float(data["scale"])
	collision_layer = 2
	collision_mask = 1 | 2
	add_to_group("animals")
	name = "Animal_%d_%s" % [id, species]
	ability = data["ability"]
	ability_timer = randf_range(4.0, 11.0)
	wander_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_build_body()
	if not proxy:
		_build_collision()
	GameState.animals.append(self)

func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	fur_mat = StandardMaterial3D.new()
	fur_mat.albedo_color = data["color"]
	fur_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	fur_mat.roughness = 0.95
	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = data["eye_color"]
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	eye_mat.emission_enabled = true
	eye_mat.emission = data["eye_color"]
	eye_mat.emission_energy = 2.2
	_add_sphere("Body", Vector3.ZERO, Vector3(0.40, 0.38, 0.72), fur_mat)
	_add_sphere("Head", Vector3(0.0, 0.18, -0.68), Vector3(0.27, 0.26, 0.26), fur_mat)
	_add_sphere("Snout", Vector3(0.0, 0.08, -0.89), Vector3(0.14, 0.11, 0.18), fur_mat)
	_add_sphere("EyeL", Vector3(-0.13, 0.24, -0.82), Vector3(0.055, 0.055, 0.055), eye_mat)
	_add_sphere("EyeR", Vector3(0.13, 0.24, -0.82), Vector3(0.055, 0.055, 0.055), eye_mat)
	_add_sphere("Tail", Vector3(0.0, 0.10, 0.70), Vector3(0.13, 0.13, 0.28), fur_mat)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.075
			cyl.bottom_radius = 0.06
			cyl.height = 0.55
			cyl.radial_segments = 6
			leg.mesh = cyl
			leg.position = Vector3(0.24 * sx, -0.34, 0.42 * sz)
			leg.material_override = fur_mat
			visual.add_child(leg)
	match data.get("ear", "long"):
		"long":
			for sx in [-1.0, 1.0]:
				_add_cone("Ear", Vector3(0.13 * sx, 0.46, -0.62), Vector3(0.09, 0.36, 0.09), fur_mat)
		"horns":
			for sx in [-1.0, 1.0]:
				_add_cone("Horn", Vector3(0.16 * sx, 0.52, -0.62), Vector3(0.07, 0.55, 0.07), fur_mat)
				_add_cone("HornTip", Vector3(0.27 * sx, 0.85, -0.58), Vector3(0.05, 0.28, 0.05), fur_mat)
		"tusks":
			for sx in [-1.0, 1.0]:
				_add_cone("Tusk", Vector3(0.15 * sx, -0.02, -0.92), Vector3(0.055, 0.28, 0.055), eye_mat)
		"round":
			for sx in [-1.0, 1.0]:
				_add_sphere("Ear", Vector3(0.22 * sx, 0.42, -0.58), Vector3(0.13, 0.13, 0.06), fur_mat)
	ability_label = Label3D.new()
	ability_label.font_size = 42
	ability_label.outline_size = 6
	ability_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ability_label.position = Vector3(0.0, 1.35, 0.0)
	ability_label.visible = false
	add_child(ability_label)

func _add_sphere(n: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var sph := SphereMesh.new()
	sph.radial_segments = 10
	sph.rings = 6
	mi.mesh = sph
	mi.position = pos
	mi.scale = size
	mi.material_override = mat
	visual.add_child(mi)

func _add_cone(n: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 6
	cyl.top_radius = 0.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	mi.mesh = cyl
	mi.position = pos
	mi.scale = size
	mi.material_override = mat
	visual.add_child(mi)

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.5
	cs.shape = cap
	cs.rotation_degrees.x = 90.0
	add_child(cs)

func apply_remote(pos: Vector3, yaw: float, active: bool, _ability_index: int) -> void:
	if not remote_proxy:
		return
	position = pos
	rotation.y = yaw
	if active != ability_active:
		_set_ability_visual(active)

func _physics_process(delta: float) -> void:
	if remote_proxy or dead or not Net.is_host:
		return
	if frozen or not GameState.running:
		velocity = Vector3.ZERO
		return
	attack_cd -= delta
	think_cd -= delta
	ability_timer -= delta
	if ability_timer <= 0.0:
		_activate_ability()
		ability_timer = randf_range(7.0, 15.0)
	if ability_active and Time.get_ticks_msec() > ability_end:
		_deactivate_ability()
	if think_cd <= 0.0:
		think_cd = randf_range(0.25, 0.5)
		target = GameState.nearest_player(global_position)
		_think()
	var dir := Vector3.ZERO
	var speed := float(data["speed"])
	match state:
		State.WANDER:
			dir = wander_dir
			speed *= 0.32
			if randf() < 0.004:
				wander_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		State.FLEE:
			if target != null:
				dir = (global_position - target.global_position).normalized()
				dir += Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
				dir = dir.normalized()
			speed *= 1.15
		State.CHASE, State.CHARGE:
			if target != null:
				dir = target.global_position - global_position
				dir.y = 0.0
				dir = dir.normalized()
			speed *= 2.25 if state == State.CHARGE else 1.05
			if target != null and global_position.distance_to(target.global_position) < 1.9 * scale.x and attack_cd <= 0.0:
				_attack(target)
	if ability_active:
		match ability:
			"blink", "vampire", "berserk":
				speed *= 1.4
			"shield":
				speed *= 0.85
	var center_dist := Vector2(global_position.x, global_position.z).length()
	if center_dist > GameData.MAP_HALF - 12.0:
		dir = (dir + Vector3(-global_position.x, 0.0, -global_position.z).normalized() * 2.0).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0
	move_and_slide()
	if GameState.world != null:
		global_position.y = GameState.world.ground_height(global_position.x, global_position.z) + 0.68 * scale.x
	if dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 9.0, 0.0, 1.0))

func _think() -> void:
	if target == null:
		state = State.WANDER
		return
	var d := global_position.distance_to(target.global_position)
	if bool(data["predator"]):
		state = State.CHASE if d < float(data["detect"]) else State.WANDER
	else:
		state = State.FLEE if d < float(data["detect"]) else State.WANDER
	if ability_active and ability == "charge" and state == State.CHASE:
		state = State.CHARGE

func _attack(player) -> void:
	attack_cd = 0.75 if (ability_active and ability == "berserk") else 1.15
	var dmg := float(data["damage"])
	if ability_active and ability == "berserk":
		dmg *= 2.0
	player.take_damage(dmg, global_position)
	if ability_active and ability == "vampire":
		hp = minf(max_hp, hp + dmg * 0.8)

func _activate_ability() -> void:
	ability_active = true
	ability_end = Time.get_ticks_msec() + int(randf_range(3500.0, 6000.0))
	_set_ability_visual(true)
	if GameState.main != null:
		GameState.main.try_ability_sound(global_position)
	match ability:
		"blink":
			global_position += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(4.0, 8.0)
		"charge":
			state = State.CHARGE

func _deactivate_ability() -> void:
	ability_active = false
	_set_ability_visual(false)
	if state == State.CHARGE:
		state = State.WANDER

func _set_ability_visual(active: bool) -> void:
	ability_active = active
	var col: Color = GameData.ABILITY_COLORS.get(ability, Color.WHITE)
	fur_mat.emission_enabled = active
	if active:
		fur_mat.emission = col
		fur_mat.emission_energy = 1.3
	ability_label.text = data["ability_name"] if active else ""
	ability_label.modulate = col
	ability_label.visible = active

func is_critical(hit_pos: Vector3) -> bool:
	var local := to_local(hit_pos)
	for eye in data["weak_eyes"]:
		if local.distance_to(eye) < 0.16:
			return true
	return local.distance_to(data["weak_heart"]) < 0.24

## Пуля попадает в жизненно важную точку, если её траектория проходит рядом
## с сердцем или глазом — даже если контакт произошёл с поверхностью туловища.
func is_critical_ray(from_world: Vector3, dir_world: Vector3) -> bool:
	var a := to_local(from_world)
	var b := to_local(from_world + dir_world * 8.0)
	for eye in data["weak_eyes"]:
		if eye.distance_to(Geometry3D.get_closest_point_to_segment(eye, a, b)) < 0.15:
			return true
	var heart: Vector3 = data["weak_heart"]
	return heart.distance_to(Geometry3D.get_closest_point_to_segment(heart, a, b)) < 0.23

func take_damage(amount: float, hit_pos: Vector3, shooter_peer: int, known_critical: bool = false) -> void:
	if dead or remote_proxy or not Net.is_host:
		return
	var critical := known_critical or is_critical(hit_pos)
	if critical:
		hp = 0.0
		dead = true
		frozen = true
		set_physics_process(false)
		# Небольшая задержка, чтобы пуля долетела в слоу-мо до разрыва туши.
		var timer := get_tree().create_timer(0.9, true, false, true)
		timer.timeout.connect(func(): if is_instance_valid(self): perform_death(shooter_peer, critical))
		return
	hp -= amount
	if hp <= 0.0:
		perform_death(shooter_peer, false)

func perform_death(shooter_peer: int, critical: bool) -> void:
	if not is_instance_valid(self) or not Net.is_host:
		return
	dead = true
	GameState.animals.erase(self)
	Net.rpc("animal_died", animal_id, global_position, species_id, critical, shooter_peer, int(data["coins"]))
	queue_free()
