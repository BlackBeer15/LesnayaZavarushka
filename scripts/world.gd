class_name WorldGen
extends Node3D

## Процедурная большая карта: рельеф, биомы, лес, скалы, болото и казино.

var height_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var color_noise := FastNoiseLite.new()

var slot_position := Vector3(0.0, 0.0, 10.5)
var casino_center := Vector3.ZERO

## Деревья, камни и кусты рисуются MultiMesh-ами и не попадают в физику,
## поэтому для камеры киллкама храним упрощённые вертикальные цилиндры.
var camera_occluders: Array = []

const SEGMENTS := 120

func build(seed_value: int) -> void:
	height_noise.seed = seed_value
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height_noise.frequency = 0.0075
	height_noise.fractal_octaves = 4
	height_noise.fractal_gain = 0.52

	detail_noise.seed = seed_value + 17
	detail_noise.frequency = 0.045
	detail_noise.fractal_octaves = 2

	biome_noise.seed = seed_value + 91
	biome_noise.frequency = 0.0042
	biome_noise.fractal_octaves = 2

	color_noise.seed = seed_value + 333
	color_noise.frequency = 0.11

	_build_sky()
	_build_terrain()
	_build_forest()
	_build_rocks()
	_build_bushes()
	_build_lake()
	_build_casino()
	_build_landmarks()

func ground_height(x: float, z: float) -> float:
	var h := height_noise.get_noise_2d(x, z) * 13.0
	h += detail_noise.get_noise_2d(x, z) * 2.0
	var d := Vector2(x, z).length()
	var flatten := 1.0 - smoothstep(9.0, GameData.CASINO_RADIUS, d)
	h = lerp(h, 0.0, flatten)
	return h

## Первый параметр t (0..1) пересечения отрезка from->to с деревом, камнем,
## кустом или рельефом. -1, если препятствий нет.
func occluder_hit_t(from: Vector3, to: Vector3) -> float:
	var min_x := minf(from.x, to.x) - 3.0
	var max_x := maxf(from.x, to.x) + 3.0
	var min_z := minf(from.z, to.z) - 3.0
	var max_z := maxf(from.z, to.z) + 3.0
	var best := 1.0
	var found := false
	for o in camera_occluders:
		var center: Vector3 = o["center"]
		if center.x < min_x or center.x > max_x or center.z < min_z or center.z > max_z:
			continue
		var t: float = _segment_cylinder_t(from, to, center, float(o["radius"]), float(o["height"]))
		if t >= 0.0 and t < best:
			best = t
			found = true
	# Пол: камера не должна уходить под рельеф, даже если рейкаст физики не сработал.
	var steps := 10
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		if p.y < ground_height(p.x, p.z) + 0.35:
			var safe_t := maxf(0.0, t - 1.0 / float(steps))
			if safe_t < best:
				best = safe_t
				found = true
			break
	return best if found else -1.0

func _segment_cylinder_t(from: Vector3, to: Vector3, center: Vector3, radius: float, height: float) -> float:
	var d := to - from
	var ox := from.x - center.x
	var oz := from.z - center.z
	var a := d.x * d.x + d.z * d.z
	var c := ox * ox + oz * oz - radius * radius
	var y_low := center.y - height * 0.5
	var y_high := center.y + height * 0.5
	if a < 0.000001:
		if c > 0.0 or absf(d.y) < 0.000001:
			return -1.0
		var ty1 := (y_low - from.y) / d.y
		var ty2 := (y_high - from.y) / d.y
		if from.y >= y_low and from.y <= y_high:
			var exit_t := ty2 if d.y > 0.0 else ty1
			return exit_t if exit_t >= 0.0 and exit_t <= 1.0 else -1.0
		var lo := minf(ty1, ty2)
		var hi := maxf(ty1, ty2)
		return clampf(lo, 0.0, 1.0) if hi >= 0.0 and lo <= 1.0 else -1.0
	var b := 2.0 * (ox * d.x + oz * d.z)
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	var t1 := (-b - sq) / (2.0 * a)
	var t2 := (-b + sq) / (2.0 * a)
	if t1 >= 0.0 and t1 <= 1.0:
		var y1 := from.y + d.y * t1
		if y1 >= y_low and y1 <= y_high:
			return t1
	if t2 >= 0.0 and t2 <= 1.0:
		var y2 := from.y + d.y * t2
		if y2 >= y_low and y2 <= y_high:
			return t2
	# Пуля может лететь внутри кроны: ищем выход через верх или низ цилиндра.
	if c < 0.0 and from.y >= y_low and from.y <= y_high:
		if d.y > 0.0 and to.y > y_high:
			var up_t := (y_high - from.y) / d.y
			return up_t if up_t <= 1.0 else -1.0
		if d.y < 0.0 and to.y < y_low:
			var down_t := (y_low - from.y) / d.y
			return down_t if down_t <= 1.0 else -1.0
	return -1.0

func biome_at(x: float, z: float) -> int:
	if Vector2(x, z).length() < GameData.CASINO_RADIUS + 2.0:
		return 4 # поляна казино
	var b := biome_noise.get_noise_2d(x, z)
	if b > 0.34:
		return 2 # скалы
	if b < -0.30:
		return 3 # болото
	if color_noise.get_noise_2d(x * 0.2, z * 0.2) > 0.35:
		return 1 # поляна
	return 0 # лес

func _build_sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.31, 0.50)
	sky_mat.sky_horizon_color = Color(0.45, 0.62, 0.66)
	sky_mat.ground_bottom_color = Color(0.08, 0.13, 0.09)
	sky_mat.ground_horizon_color = Color(0.16, 0.24, 0.16)
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.47, 0.59, 0.55)
	env.fog_density = 0.0032
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.shadow_bias = 0.04
	add_child(sun)

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := GameData.MAP_SIZE
	var step := size / float(SEGMENTS)
	var half := size * 0.5
	var forest_col := Color(0.16, 0.27, 0.14)
	var meadow_col := Color(0.34, 0.43, 0.18)
	var rock_col := Color(0.38, 0.39, 0.37)
	var swamp_col := Color(0.20, 0.25, 0.16)
	var town_col := Color(0.46, 0.40, 0.29)

	for j in range(SEGMENTS + 1):
		var z := -half + float(j) * step
		for i in range(SEGMENTS + 1):
			var x := -half + float(i) * step
			var h := ground_height(x, z)
			var biome := biome_at(x, z)
			var base_col := forest_col
			match biome:
				1: base_col = meadow_col
				2: base_col = rock_col
				3: base_col = swamp_col
				4: base_col = town_col
			var tint := color_noise.get_noise_2d(x * 1.5, z * 1.5) * 0.10
			var c := Color(
				clampf(base_col.r + tint, 0.0, 1.0),
				clampf(base_col.g + tint, 0.0, 1.0),
				clampf(base_col.b + tint * 0.5, 0.0, 1.0)
			)
			st.set_color(c)
			st.add_vertex(Vector3(x, h, z))

	for j in range(SEGMENTS):
		for i in range(SEGMENTS):
			var a := j * (SEGMENTS + 1) + i
			var b := a + 1
			var c := a + (SEGMENTS + 1)
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)

	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.96
	mat.metallic = 0.0

	var ground := MeshInstance3D.new()
	ground.name = "Terrain"
	ground.mesh = mesh
	ground.material_override = mat
	add_child(ground)

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	var hshape := HeightMapShape3D.new()
	hshape.map_width = SEGMENTS + 1
	hshape.map_depth = SEGMENTS + 1
	var heights := PackedFloat32Array()
	for j in range(SEGMENTS + 1):
		var z := -half + float(j) * step
		for i in range(SEGMENTS + 1):
			var x := -half + float(i) * step
			heights.append(ground_height(x, z))
	hshape.map_data = heights
	var shape := CollisionShape3D.new()
	shape.shape = hshape
	body.add_child(shape)
	# HeightMapShape3D имеет шаг 1 юнит, растягиваем его до шага сетки.
	body.scale = Vector3(step, 1.0, step)
	add_child(body)
	if GameData.debug_arg("--debug-state"):
		print("[WORLD] heightmap=", hshape.map_width, "x", hshape.map_depth, " data=", heights.size())

func _build_forest() -> void:
	var trunk_t := PackedVector3Array()
	var dark_t := PackedVector3Array()
	var light_t := PackedVector3Array()
	var trunk_rot := PackedFloat32Array()
	var foliage_rot := PackedFloat32Array()

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var attempts := 0
	while trunk_t.size() < 1150 and attempts < 12000:
		attempts += 1
		var x := rng.randf_range(-GameData.MAP_HALF + 8.0, GameData.MAP_HALF - 8.0)
		var z := rng.randf_range(-GameData.MAP_HALF + 8.0, GameData.MAP_HALF - 8.0)
		var d := Vector2(x, z).length()
		if d < GameData.CASINO_RADIUS + 3.0:
			continue
		var biome := biome_at(x, z)
		if biome == 1 and rng.randf() < 0.75:
			continue
		if biome == 2 and rng.randf() < 0.85:
			continue
		if biome == 3 and rng.randf() < 0.62:
			continue
		var h := ground_height(x, z)
		var hx := ground_height(x + 1.5, z) - ground_height(x - 1.5, z)
		var hz := ground_height(x, z + 1.5) - ground_height(x, z - 1.5)
		if absf(hx) > 2.4 or absf(hz) > 2.4:
			continue
		var s := rng.randf_range(0.75, 1.55)
		if biome == 3:
			s *= 0.8
		trunk_t.append(Vector3(x, h + 0.9 * s, z))
		trunk_rot.append(rng.randf_range(0.0, TAU))
		var fpos := Vector3(x, h + 2.55 * s, z)
		if rng.randf() < 0.58:
			dark_t.append(fpos)
		else:
			light_t.append(fpos)
		foliage_rot.append(rng.randf_range(0.0, TAU))
		# Ствол вместе с кроной: снизу верхнего конуса и до его вершины.
		camera_occluders.append({
			"center": Vector3(x, h + 2.1 * s, z),
			"radius": 0.95 * s,
			"height": 4.4 * s,
		})

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 2.0
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.19, 0.11)
	trunk_mat.roughness = 1.0
	_make_multimesh("Trunks", trunk_mesh, trunk_t, trunk_rot, trunk_mat, 1.0)

	var cone := CylinderMesh.new()
	cone.radial_segments = 7
	cone.rings = 1
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 3.1
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.09, 0.24, 0.11)
	dark_mat.roughness = 1.0
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(0.17, 0.38, 0.15)
	light_mat.roughness = 1.0
	_make_multimesh("FoliageDark", cone, dark_t, foliage_rot, dark_mat, 1.0)
	_make_multimesh("FoliageLight", cone, light_t, foliage_rot, light_mat, 1.0)

func _make_multimesh(name: String, mesh: Mesh, positions: PackedVector3Array, rots: PackedFloat32Array, mat: Material, scale_mul: float) -> void:
	if positions.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in range(positions.size()):
		var b := Basis().rotated(Vector3.UP, rots[i])
		var s := scale_mul * (0.85 + 0.3 * float(i % 7) / 7.0)
		b = b.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, positions[i]))
	var mi := MultiMeshInstance3D.new()
	mi.name = name
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var positions := PackedVector3Array()
	var rots := PackedFloat32Array()
	var scales := PackedFloat32Array()
	for _i in range(260):
		var x := rng.randf_range(-GameData.MAP_HALF + 5.0, GameData.MAP_HALF - 5.0)
		var z := rng.randf_range(-GameData.MAP_HALF + 5.0, GameData.MAP_HALF - 5.0)
		if Vector2(x, z).length() < GameData.CASINO_RADIUS + 2.0:
			continue
		var s := rng.randf_range(0.4, 2.2)
		positions.append(Vector3(x, ground_height(x, z) + 0.25 * s, z))
		rots.append(rng.randf_range(0.0, TAU))
		scales.append(s)
		camera_occluders.append({
			"center": Vector3(x, ground_height(x, z) + 0.25 * s, z),
			"radius": 1.05 * s,
			"height": 0.7 * s,
		})
	var sphere := SphereMesh.new()
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.37, 0.35)
	mat.roughness = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = positions.size()
	for i in range(positions.size()):
		var s := scales[i]
		var b := Basis().rotated(Vector3.UP, rots[i]).scaled(Vector3(s, s * 0.7, s))
		mm.set_instance_transform(i, Transform3D(b, positions[i]))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Rocks"
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)

func _build_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var positions := PackedVector3Array()
	var rots := PackedFloat32Array()
	var scales := PackedFloat32Array()
	for _i in range(360):
		var x := rng.randf_range(-GameData.MAP_HALF + 6.0, GameData.MAP_HALF - 6.0)
		var z := rng.randf_range(-GameData.MAP_HALF + 6.0, GameData.MAP_HALF - 6.0)
		if Vector2(x, z).length() < GameData.CASINO_RADIUS + 1.0:
			continue
		var s := rng.randf_range(0.4, 1.0)
		positions.append(Vector3(x, ground_height(x, z) + 0.25 * s, z))
		rots.append(rng.randf_range(0.0, TAU))
		scales.append(s)
		camera_occluders.append({
			"center": Vector3(x, ground_height(x, z) + 0.25 * s, z),
			"radius": 0.85 * s,
			"height": 0.6 * s,
		})
	var sphere := SphereMesh.new()
	sphere.height = 2.0
	sphere.radial_segments = 5
	sphere.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.30, 0.13)
	mat.roughness = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = positions.size()
	for i in range(positions.size()):
		var s := scales[i]
		var b := Basis().rotated(Vector3.UP, rots[i]).scaled(Vector3(s, s * 0.6, s))
		mm.set_instance_transform(i, Transform3D(b, positions[i]))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Bushes"
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)

func _build_lake() -> void:
	var lake_pos := Vector3(-82.0, ground_height(-82.0, 74.0) - 0.55, 74.0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 22.0
	cyl.bottom_radius = 22.0
	cyl.height = 0.12
	cyl.radial_segments = 40
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.38, 0.48, 0.78)
	mat.metallic = 0.25
	mat.roughness = 0.18
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = lake_pos
	add_child(mi)

func _build_casino() -> void:
	var root := Node3D.new()
	root.name = "Casino"
	add_child(root)
	var wall := Color(0.30, 0.16, 0.14)
	var trim := Color(0.12, 0.08, 0.08)
	var gold := Color(0.95, 0.70, 0.16)

	_box(root, Vector3(16.0, 1.0, 13.0), Vector3(0.0, 0.5, 0.0), trim)
	_box(root, Vector3(16.0, 0.8, 13.0), Vector3(0.0, 6.6, 0.0), trim)
	_box(root, Vector3(16.0, 6.0, 0.7), Vector3(0.0, 3.5, -6.2), wall)
	_box(root, Vector3(0.7, 6.0, 13.0), Vector3(-7.7, 3.5, 0.0), wall)
	_box(root, Vector3(0.7, 6.0, 13.0), Vector3(7.7, 3.5, 0.0), wall)
	_box(root, Vector3(5.5, 6.0, 0.7), Vector3(-5.2, 3.5, 6.2), wall)
	_box(root, Vector3(5.5, 6.0, 0.7), Vector3(5.2, 3.5, 6.2), wall)
	_box(root, Vector3(5.0, 1.0, 0.7), Vector3(0.0, 6.0, 6.2), wall)

	var sign := Label3D.new()
	sign.name = "CasinoSign"
	sign.text = "КАЗИНО / CASINO"
	sign.font_size = 110
	sign.outline_size = 12
	sign.outline_modulate = Color(0.15, 0.03, 0.02)
	sign.modulate = Color(1.0, 0.82, 0.25)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0.0, 8.0, 6.2)
	root.add_child(sign)

	for i in range(6):
		var lamp := OmniLight3D.new()
		lamp.light_color = gold
		lamp.light_energy = 1.4
		lamp.omni_range = 11.0
		lamp.position = Vector3(-6.0 + float(i) * 2.4, 5.6, 5.0)
		root.add_child(lamp)

	# Игровой автомат перед входом.
	var machine := Node3D.new()
	machine.name = "SlotMachine"
	machine.position = slot_position
	root.add_child(machine)
	_box(machine, Vector3(1.9, 2.3, 1.1), Vector3(0.0, 1.15, 0.0), Color(0.45, 0.06, 0.10))
	_box(machine, Vector3(1.5, 0.85, 0.08), Vector3(0.0, 1.65, 0.56), Color(0.04, 0.06, 0.09), false)
	_box(machine, Vector3(0.12, 0.75, 0.12), Vector3(0.82, 1.15, 0.62), Color(0.85, 0.85, 0.88), false)
	var screen := Label3D.new()
	screen.text = "10 МОНЕТ = СПИН"
	screen.font_size = 18
	screen.outline_size = 6
	screen.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	screen.modulate = Color(0.55, 1.0, 0.70)
	screen.position = Vector3(0.0, 1.65, 0.66)
	machine.add_child(screen)
	slot_position = Vector3(0.0, ground_height(0.0, 10.5), 10.5)
	machine.position = slot_position

func _build_landmarks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for _i in range(9):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(45.0, 120.0)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var h := ground_height(x, z)
		var t := Node3D.new()
		t.position = Vector3(x, h, z)
		add_child(t)
		_box(t, Vector3(0.45, 7.0, 0.45), Vector3(-1.1, 3.5, -1.1), Color(0.30, 0.20, 0.12))
		_box(t, Vector3(0.45, 7.0, 0.45), Vector3(1.1, 3.5, -1.1), Color(0.30, 0.20, 0.12))
		_box(t, Vector3(0.45, 7.0, 0.45), Vector3(-1.1, 3.5, 1.1), Color(0.30, 0.20, 0.12))
		_box(t, Vector3(0.45, 7.0, 0.45), Vector3(1.1, 3.5, 1.1), Color(0.30, 0.20, 0.12))
		_box(t, Vector3(3.0, 0.35, 3.0), Vector3(0.0, 7.2, 0.0), Color(0.34, 0.22, 0.13))
		_box(t, Vector3(3.4, 0.25, 3.4), Vector3(0.0, 7.65, 0.0), Color(0.22, 0.14, 0.09))

func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, collision: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	parent.add_child(mi)
	if collision:
		var sb := StaticBody3D.new()
		sb.position = pos
		sb.collision_layer = 1
		sb.collision_mask = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		parent.add_child(sb)
	return mi
