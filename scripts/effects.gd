class_name Effects
extends Node3D

## Кровь, обломки, монеты, трассеры и ударные волны — всё процедурное.

class Chunk extends RefCounted:
	var node: MeshInstance3D
	var vel: Vector3
	var spin: Vector3
	var life: float = 0.0
	var max_life: float = 2.0
	var base_scale: Vector3 = Vector3.ONE
	var bounce: bool = true

var chunks: Array[Chunk] = []
var coins: Array = []
var decals: Array = []
var rings: Array = []
var tweens: Array = []
var decoys: Array = []
var tracers: Array = []

func _track(t: Tween) -> Tween:
	tweens.append(t)
	return t

func _exit_tree() -> void:
	for t in tweens:
		if t != null and t.is_valid():
			t.kill()

var blood_mesh: SphereMesh
var debris_mesh: BoxMesh
var limb_mesh: BoxMesh
var coin_mesh: CylinderMesh
var blood_mat: StandardMaterial3D
var gold_mat: StandardMaterial3D
var bullet_mesh: SphereMesh
var bullet_mat: StandardMaterial3D
var casing_mesh: CylinderMesh
var smoke_mat: StandardMaterial3D
var brass_mat: StandardMaterial3D

func _ready() -> void:
	blood_mesh = SphereMesh.new()
	blood_mesh.radius = 0.085
	blood_mesh.height = 0.17
	blood_mesh.radial_segments = 6
	blood_mesh.rings = 4
	debris_mesh = BoxMesh.new()
	debris_mesh.size = Vector3(0.22, 0.16, 0.22)
	limb_mesh = BoxMesh.new()
	limb_mesh.size = Vector3(0.20, 0.72, 0.20)
	coin_mesh = CylinderMesh.new()
	coin_mesh.top_radius = 0.24
	coin_mesh.bottom_radius = 0.24
	coin_mesh.height = 0.07
	coin_mesh.radial_segments = 14

	blood_mat = _flat_mat(Color(0.48, 0.015, 0.02), 0.15)
	gold_mat = _flat_mat(Color(1.0, 0.72, 0.10), 0.35)
	gold_mat.metallic = 0.7
	bullet_mesh = SphereMesh.new()
	bullet_mesh.radius = 0.20
	bullet_mesh.height = 0.40
	bullet_mesh.radial_segments = 10
	bullet_mesh.rings = 6
	bullet_mat = _flat_mat(Color(1.0, 0.92, 0.55), 2.5)
	casing_mesh = CylinderMesh.new()
	casing_mesh.top_radius = 0.018
	casing_mesh.bottom_radius = 0.018
	casing_mesh.height = 0.055
	casing_mesh.radial_segments = 8
	smoke_mat = _flat_mat(Color(0.55, 0.56, 0.55), 0.0)
	brass_mat = _flat_mat(Color(0.82, 0.62, 0.18), 0.15)

func _flat_mat(color: Color, emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy = emission
	return m

func _process(delta: float) -> void:
	_update_chunks(delta)
	_update_coins(delta)
	_update_decals(delta)
	_update_rings(delta)
	_update_decoys(delta)
	_update_tracers(delta)

func _update_chunks(delta: float) -> void:
	for i in range(chunks.size() - 1, -1, -1):
		var c: Chunk = chunks[i]
		if not is_instance_valid(c.node):
			chunks.remove_at(i)
			continue
		c.life += delta
		c.vel.y -= 22.0 * delta
		c.node.position += c.vel * delta
		c.node.rotate_x(c.spin.x * delta)
		c.node.rotate_y(c.spin.y * delta)
		c.node.rotate_z(c.spin.z * delta)
		var ground := 0.0
		if GameState.world != null:
			ground = GameState.world.ground_height(c.node.position.x, c.node.position.z)
		if c.bounce and c.node.position.y < ground + 0.08:
			c.node.position.y = ground + 0.08
			c.vel.y = absf(c.vel.y) * 0.32
			c.vel.x *= 0.72
			c.vel.z *= 0.72
		var remain := 1.0 - c.life / c.max_life
		if remain < 0.3:
			c.node.scale = c.base_scale * clampf(remain / 0.3, 0.0, 1.0)
		if c.life >= c.max_life:
			c.node.queue_free()
			chunks.remove_at(i)

func _update_coins(delta: float) -> void:
	for i in range(coins.size() - 1, -1, -1):
		var entry: Dictionary = coins[i]
		var node: Area3D = entry["node"]
		if not is_instance_valid(node):
			coins.remove_at(i)
			continue
		entry["t"] = float(entry["t"]) + delta
		entry["life"] = float(entry["life"]) - delta
		node.rotation.y += delta * 2.8
		node.position.y = float(entry["base_y"]) + sin(float(entry["t"]) * 3.4) * 0.16
		var taken := false
		if bool(entry.get("authoritative", false)) and Net.is_host:
			for p in GameState.players:
				if p == null or not is_instance_valid(p) or not p.alive:
					continue
				if p.global_position.distance_squared_to(node.global_position) < 3.2:
					Net.rpc("coin_pickup_for", p.peer, int(entry["id"]), int(entry["value"]))
					spawn_hit(node.global_position, Color(1.0, 0.85, 0.25), 8, 2.5)
					Sfx.play("coin", 0.4)
					taken = true
					break
		if taken or float(entry["life"]) <= 0.0:
			node.queue_free()
			coins.remove_at(i)

func _update_decals(delta: float) -> void:
	for i in range(decals.size() - 1, -1, -1):
		var e: Dictionary = decals[i]
		var node: MeshInstance3D = e["node"]
		if not is_instance_valid(node):
			decals.remove_at(i)
			continue
		e["life"] = float(e["life"]) - delta
		if float(e["life"]) < 3.0:
			node.scale.x = maxf(0.01, node.scale.x - delta * 0.12)
			node.scale.z = maxf(0.01, node.scale.z - delta * 0.12)
		if float(e["life"]) <= 0.0:
			node.queue_free()
			decals.remove_at(i)

func _update_rings(delta: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		var e: Dictionary = rings[i]
		var node: MeshInstance3D = e["node"]
		if not is_instance_valid(node):
			rings.remove_at(i)
			continue
		e["t"] = float(e["t"]) + delta
		var t := float(e["t"])
		var s := 0.3 + t * 7.0
		node.scale = Vector3(s, s, s)
		node.global_position.y += delta * 0.6
		if t > 0.75:
			node.queue_free()
			rings.remove_at(i)

func add_tracer(node: Node3D, life: float = 0.09) -> void:
	add_child(node)
	tracers.append({"node": node, "life": life})

func _update_tracers(delta: float) -> void:
	for i in range(tracers.size() - 1, -1, -1):
		var e: Dictionary = tracers[i]
		e["life"] = float(e["life"]) - delta
		var node: Node3D = e["node"]
		if float(e["life"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			tracers.remove_at(i)

func add_decoy(node: Node3D, target: Vector3) -> void:
	add_child(node)
	decoys.append({"node": node, "target": target, "t": 0.0})

func _update_decoys(delta: float) -> void:
	for i in range(decoys.size() - 1, -1, -1):
		var e: Dictionary = decoys[i]
		var node: Node3D = e["node"]
		if not is_instance_valid(node):
			decoys.remove_at(i)
			continue
		e["t"] = float(e["t"]) + delta
		node.position = node.position.lerp(e["target"], clampf(delta * 0.8, 0.0, 1.0))
		if float(e["t"]) > 4.5:
			node.queue_free()
			decoys.remove_at(i)

func _add_chunk(mesh: Mesh, mat: Material, pos: Vector3, vel: Vector3, max_life: float, scale: Vector3, bounce: bool = true) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	add_child(mi)
	var c := Chunk.new()
	c.node = mi
	c.vel = vel
	c.spin = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
	c.max_life = max_life
	c.base_scale = scale
	c.bounce = bounce
	chunks.append(c)

func spawn_gore(pos: Vector3, animal_scale: float, fur_color: Color, critical: bool) -> void:
	var fur_mat := _flat_mat(fur_color * 0.75, 0.0)
	var dark_blood := _flat_mat(Color(0.30, 0.01, 0.015), 0.0)
	var count := 30 if critical else 12
	for _i in range(count):
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.05, 1.0), randf_range(-1.0, 1.0)).normalized()
		var speed := randf_range(3.5, 11.0) * (1.4 if critical else 1.0)
		var s := animal_scale * randf_range(0.7, 1.5)
		_add_chunk(
			debris_mesh,
			blood_mat if randf() < 0.62 else dark_blood,
			pos + Vector3(0.0, 0.35 * animal_scale, 0.0),
			dir * speed,
			randf_range(2.2, 3.6),
			Vector3(s, s, s)
		)
	if critical:
		for _i in range(5):
			var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.35, 1.0), randf_range(-1.0, 1.0)).normalized()
			var s := animal_scale * randf_range(0.8, 1.25)
			_add_chunk(
				limb_mesh, fur_mat,
				pos + Vector3(randf_range(-0.3, 0.3), 0.4 * animal_scale, randf_range(-0.3, 0.3)),
				dir * randf_range(5.0, 10.0), randf_range(3.0, 4.5),
				Vector3(s, s, s)
			)
	for _i in range(48 if critical else 16):
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
		var s := animal_scale * randf_range(0.35, 0.8)
		_add_chunk(
			blood_mesh, blood_mat, pos, dir * randf_range(2.0, 9.0),
			randf_range(1.4, 2.4), Vector3(s, s, s), false
		)
	spawn_decal(pos, animal_scale)
	Sfx.play("crit" if critical else "hit", 0.9 if critical else 0.5)

func spawn_decal(pos: Vector3, animal_scale: float) -> void:
	var ground := 0.0
	if GameState.world != null:
		ground = GameState.world.ground_height(pos.x, pos.z)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.025
	cyl.radial_segments = 18
	mi.mesh = cyl
	var mat := _flat_mat(Color(0.34, 0.012, 0.012), 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = Vector3(pos.x, ground + 0.04, pos.z)
	mi.scale = Vector3(2.2 * animal_scale, 1.0, 1.8 * animal_scale)
	add_child(mi)
	decals.append({"node": mi, "life": 22.0})

func spawn_track(pos: Vector3, yaw: float) -> void:
	var ground := 0.0
	if GameState.world != null:
		ground = GameState.world.ground_height(pos.x, pos.z)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 0.02
	cyl.radial_segments = 8
	mi.mesh = cyl
	var mat := _flat_mat(Color(0.16, 0.12, 0.08), 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.5
	mi.material_override = mat
	mi.position = Vector3(pos.x, ground + 0.03, pos.z)
	mi.rotation_degrees.y = rad_to_deg(yaw)
	mi.scale = Vector3(1.0, 1.0, 1.8)
	add_child(mi)
	decals.append({"node": mi, "life": 14.0})

func spawn_damage_number(pos: Vector3, amount: int, crit_type: String) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 42 if crit_type == "heart" else 32
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos + Vector3.UP * 0.35
	label.modulate = Color(1.0, 0.25, 0.18) if crit_type == "heart" else (
		Color(1.0, 0.85, 0.25) if crit_type != "" else Color.WHITE)
	add_child(label)
	var t := _track(create_tween())
	t.tween_property(label, "position", label.position + Vector3.UP * 0.9, 0.75)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	t.tween_callback(label.queue_free)

func spawn_muzzle_flash(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.11
	sph.height = 0.22
	sph.radial_segments = 8
	sph.rings = 5
	mi.mesh = sph
	mi.material_override = bullet_mat
	mi.position = pos
	add_child(mi)
	var t := _track(create_tween())
	t.tween_property(mi, "scale", Vector3.ONE * 0.15, 0.09)
	t.tween_callback(mi.queue_free)

func spawn_smoke(pos: Vector3) -> void:
	for _i in range(4):
		_add_chunk(
			blood_mesh, smoke_mat, pos,
			Vector3(randf_range(-0.4, 0.4), randf_range(0.5, 1.2), randf_range(-0.2, 0.6)),
			0.85, Vector3(randf_range(1.2, 2.2), randf_range(1.2, 2.2), randf_range(1.2, 2.2)), false
		)

func spawn_casing(pos: Vector3, right: Vector3) -> void:
	_add_chunk(
		casing_mesh, brass_mat, pos,
		right * randf_range(1.2, 2.2) + Vector3.UP * randf_range(1.5, 2.8),
		1.6, Vector3.ONE, true
	)

func spawn_hit(pos: Vector3, color: Color, count: int = 10, speed: float = 4.0) -> void:
	var mat := _flat_mat(color, 1.0)
	for _i in range(count):
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		_add_chunk(blood_mesh, mat, pos, dir * randf_range(1.0, speed), 0.55, Vector3(0.5, 0.5, 0.5), false)

func spawn_coin(coin_id: int, pos: Vector3, value: int, authoritative: bool = false) -> void:
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	cs.shape = sh
	area.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = coin_mesh
	mi.material_override = gold_mat
	mi.rotation_degrees.x = 90.0
	area.add_child(mi)
	var y := pos.y + 0.55
	area.position = Vector3(pos.x, y, pos.z)
	add_child(area)
	coins.append({
		"id": coin_id, "node": area, "value": value, "base_y": y,
		"t": randf_range(0.0, 6.0), "life": 48.0,
		"authoritative": authoritative,
	})

func remove_coin(coin_id: int) -> void:
	for i in range(coins.size() - 1, -1, -1):
		var e: Dictionary = coins[i]
		if int(e.get("id", -1)) == coin_id:
			var node: Area3D = e["node"]
			if is_instance_valid(node):
				spawn_hit(node.global_position, Color(1.0, 0.85, 0.25), 8, 2.5)
				node.queue_free()
			coins.remove_at(i)
			Sfx.play("coin", 0.45)
			break

func spawn_bullet(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = bullet_mesh
	mi.material_override = bullet_mat
	mi.position = pos
	var trail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.09, 1.8)
	trail.mesh = box
	trail.position = Vector3(0.0, 0.0, 1.0)
	trail.material_override = bullet_mat
	mi.add_child(trail)
	add_child(mi)
	return mi

func spawn_ring(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 1.0
	torus.rings = 26
	torus.ring_segments = 6
	mi.mesh = torus
	var mat := _flat_mat(color, 2.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	rings.append({"node": mi, "t": 0.0})
