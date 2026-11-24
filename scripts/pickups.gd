class_name Pickups
extends Node3D

## Аптечки и патроны, разбросанные по карте. Подбираются локальным игроком.

class Item extends RefCounted:
	var node: Node3D
	var kind: String
	var base_y: float
	var t: float

var items: Array[Item] = []

func _ready() -> void:
	_spawn_all()

func _spawn_all() -> void:
	var spots := [
		Vector2(9.0, 12.0), Vector2(-9.0, 12.0), Vector2(0.0, -9.0),
		Vector2(30.0, 8.0), Vector2(-28.0, -6.0), Vector2(12.0, -34.0),
		Vector2(-46.0, 22.0), Vector2(58.0, -18.0), Vector2(-70.0, -40.0),
		Vector2(80.0, 46.0), Vector2(-95.0, 65.0), Vector2(110.0, -70.0),
	]
	for i in range(spots.size()):
		var p: Vector2 = spots[i]
		var kind := "ammo_normal"
		match i % 4:
			0: kind = "medkit"
			1: kind = "ammo_ap"
			2: kind = "ammo_hp"
			3: kind = "ammo_normal"
		spawn(kind, Vector3(p.x, GameState.world.ground_height(p.x, p.y), p.y))

func spawn(kind: String, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Pickup_" + kind
	var mesh_mat := StandardMaterial3D.new()
	if kind == "medkit":
		mesh_mat.albedo_color = Color(0.92, 0.94, 0.95)
		mesh_mat.emission_enabled = true
		mesh_mat.emission = Color(0.2, 0.9, 0.3)
		mesh_mat.emission_energy = 0.35
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.34, 0.22, 0.28)
		body.mesh = box
		body.material_override = mesh_mat
		root.add_child(body)
		var cross_h := MeshInstance3D.new()
		var ch := BoxMesh.new()
		ch.size = Vector3(0.22, 0.06, 0.02)
		cross_h.mesh = ch
		cross_h.position = Vector3(0.0, 0.0, 0.15)
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.9, 0.1, 0.1)
		cross_h.material_override = red
		root.add_child(cross_h)
		var cross_v := MeshInstance3D.new()
		var cv := BoxMesh.new()
		cv.size = Vector3(0.06, 0.16, 0.02)
		cross_v.mesh = cv
		cross_v.position = Vector3(0.0, 0.0, 0.15)
		cross_v.material_override = red
		root.add_child(cross_v)
	else:
		var col: Color = GameData.AMMO_TYPES[0]["color"]
		if kind == "ammo_ap":
			col = GameData.AMMO_TYPES[1]["color"]
		elif kind == "ammo_hp":
			col = GameData.AMMO_TYPES[2]["color"]
		mesh_mat.albedo_color = col
		mesh_mat.metallic = 0.6
		mesh_mat.emission_enabled = true
		mesh_mat.emission = col
		mesh_mat.emission_energy = 0.4
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.16, 0.20)
		body.mesh = box
		body.material_override = mesh_mat
		root.add_child(body)
		for i in range(3):
			var bullet := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.025
			cyl.bottom_radius = 0.025
			cyl.height = 0.12
			bullet.mesh = cyl
			bullet.position = Vector3(-0.08 + float(i) * 0.08, 0.13, 0.0)
			bullet.material_override = mesh_mat
			root.add_child(bullet)
	var y := pos.y + 0.35
	root.position = Vector3(pos.x, y, pos.z)
	add_child(root)
	var item := Item.new()
	item.node = root
	item.kind = kind
	item.base_y = y
	item.t = randf_range(0.0, 6.0)
	items.append(item)

func _process(delta: float) -> void:
	if GameState.main == null:
		return
	var lp = GameState.main.get_player_node(Net.local_peer)
	if lp == null or not is_instance_valid(lp):
		return
	for i in range(items.size() - 1, -1, -1):
		var it: Item = items[i]
		if not is_instance_valid(it.node):
			items.remove_at(i)
			continue
		it.t += delta
		it.node.rotation.y += delta * 1.4
		it.node.position.y = it.base_y + sin(it.t * 3.0) * 0.12
		if lp.global_position.distance_squared_to(it.node.global_position) < 3.0:
			lp.collect_pickup(it.kind)
			if GameState.effects != null:
				GameState.effects.spawn_hit(it.node.global_position, Color(1.0, 0.9, 0.4), 8, 2.0)
			it.node.queue_free()
			items.remove_at(i)
