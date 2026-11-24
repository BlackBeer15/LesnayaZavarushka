class_name WeaponModels
extends RefCounted

## Детальные процедурные модели оружия и рук без внешних ассетов.
## Все модели смотрят в -Z. Корень имеет meta "muzzle" —本地 точка вылета пули.

static func build(weapon_id: String, sleeve_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponModel_" + weapon_id
	var w: Dictionary = GameData.WEAPONS[weapon_id]
	var rarity := int(w["rarity"])
	var rc: Color = GameData.RARITY_COLORS[rarity]

	var metal := _mat(w["color"], 0.85, 0.28)
	var dark := _mat(Color(0.055, 0.062, 0.072), 0.55, 0.45)
	var black := _mat(Color(0.02, 0.022, 0.026), 0.25, 0.7)
	var grip := _mat(Color(0.11, 0.10, 0.095), 0.05, 0.92)
	var wood := _mat(Color(0.34, 0.19, 0.085), 0.0, 0.75)
	var steel := _mat(Color(0.55, 0.58, 0.62), 0.95, 0.18)
	var accent := _mat(rc, 0.55, 0.3, rc, 0.25 if rarity >= 2 else 0.0)
	var glass := _mat(Color(0.05, 0.12, 0.18), 0.4, 0.1, Color(0.2, 0.7, 1.0), 0.5)

	match weapon_id:
		"pistol":
			_build_pistol(root, metal, dark, black, grip, steel, accent)
			root.set_meta("muzzle", Vector3(0.0, 0.055, -0.56))
		"silver":
			_build_revolver(root, metal, dark, wood, steel, accent)
			root.set_meta("muzzle", Vector3(0.0, 0.05, -0.66))
		"shotgun":
			_build_shotgun(root, metal, dark, black, wood, steel, accent)
			root.set_meta("muzzle", Vector3(0.0, 0.045, -0.92))
		"sniper":
			_build_sniper(root, metal, dark, wood, steel, accent, glass)
			root.set_meta("muzzle", Vector3(0.0, 0.035, -1.02))
		"legend":
			_build_legend(root, metal, dark, black, accent, glass)
			root.set_meta("muzzle", Vector3(0.0, 0.02, -0.86))
		_:
			root.set_meta("muzzle", Vector3(0.0, 0.0, -0.5))
	return root

# ------------------------------------------------------------------ helpers ---

static func _mat(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy = energy
	return m

static func _box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.name = name
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node, name: String, top: float, bottom: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, radial: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = radial
	m.rings = 1
	mi.mesh = m
	mi.name = name
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node, name: String, radius: float, pos: Vector3, mat: Material, scale_vec: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.radial_segments = 10
	m.rings = 6
	mi.mesh = m
	mi.name = name
	mi.position = pos
	mi.scale = scale_vec
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _capsule(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 4
	mi.mesh = m
	mi.name = name
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _ring(parent: Node, name: String, inner: float, outer: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 14
	m.ring_segments = 8
	mi.mesh = m
	mi.name = name
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _screw(parent: Node, pos: Vector3, mat: Material) -> void:
	_cyl(parent, "Screw", 0.012, 0.012, 0.006, pos, mat, Vector3(0.0, 0.0, 90.0), 8)

static func _sights(parent: Node, front_z: float, rear_z: float, y: float, dark: Material, accent: Material) -> void:
	_box(parent, "FrontSight", Vector3(0.012, 0.035, 0.018), Vector3(0.0, y + 0.02, front_z), dark)
	_box(parent, "RearSightL", Vector3(0.018, 0.025, 0.02), Vector3(-0.035, y + 0.015, rear_z), dark)
	_box(parent, "RearSightR", Vector3(0.018, 0.025, 0.02), Vector3(0.035, y + 0.015, rear_z), dark)
	_box(parent, "SightMark", Vector3(0.008, 0.008, 0.006), Vector3(0.0, y + 0.045, front_z), accent)

static func _trigger_guard(parent: Node, y: float, z: float, dark: Material) -> void:
	_box(parent, "GuardTop", Vector3(0.075, 0.012, 0.012), Vector3(0.0, y, z - 0.05), dark)
	_box(parent, "GuardFront", Vector3(0.012, 0.075, 0.012), Vector3(0.036, y - 0.035, z - 0.075), dark)
	_box(parent, "GuardBack", Vector3(0.012, 0.075, 0.012), Vector3(-0.036, y - 0.035, z + 0.015), dark)
	_box(parent, "GuardBottom", Vector3(0.075, 0.012, 0.09), Vector3(0.0, y - 0.072, z - 0.03), dark)
	_box(parent, "Trigger", Vector3(0.012, 0.055, 0.012), Vector3(0.0, y - 0.03, z - 0.02), dark, Vector3(-12.0, 0.0, 0.0))

# ------------------------------------------------------------------- pistols ---

static func _build_pistol(root: Node, metal: Material, dark: Material, black: Material, grip: Material, steel: Material, accent: Material) -> void:
	_box(root, "Slide", Vector3(0.105, 0.095, 0.40), Vector3(0.0, 0.055, -0.20), metal)
	_box(root, "SlideTop", Vector3(0.09, 0.012, 0.38), Vector3(0.0, 0.108, -0.20), dark)
	_box(root, "Frame", Vector3(0.095, 0.075, 0.26), Vector3(0.0, -0.01, -0.08), dark)
	_cyl(root, "Barrel", 0.032, 0.032, 0.20, Vector3(0.0, 0.055, -0.44), steel, Vector3(90.0, 0.0, 0.0), 14)
	_ring(root, "MuzzleRing", 0.025, 0.038, Vector3(0.0, 0.055, -0.54), black, Vector3(90.0, 0.0, 0.0))
	_box(root, "EjectionPort", Vector3(0.006, 0.035, 0.09), Vector3(0.053, 0.075, -0.18), black)
	_box(root, "Grip", Vector3(0.082, 0.22, 0.10), Vector3(0.0, -0.16, 0.045), grip, Vector3(-14.0, 0.0, 0.0))
	_box(root, "GripBase", Vector3(0.09, 0.025, 0.115), Vector3(0.0, -0.275, 0.065), dark)
	for i in range(5):
		_box(root, "GripGroove%d" % i, Vector3(0.086, 0.006, 0.085), Vector3(0.0, -0.11 - i * 0.03, 0.055 + i * 0.005), black, Vector3(-14.0, 0.0, 0.0))
	_trigger_guard(root, -0.055, -0.02, dark)
	_sights(root, -0.37, -0.04, 0.105, dark, accent)
	_screw(root, Vector3(0.054, 0.05, -0.30), steel)
	_screw(root, Vector3(0.054, 0.03, -0.05), steel)

static func _build_revolver(root: Node, metal: Material, dark: Material, wood: Material, steel: Material, accent: Material) -> void:
	_box(root, "Frame", Vector3(0.10, 0.10, 0.26), Vector3(0.0, 0.02, -0.08), metal)
	_cyl(root, "Cylinder", 0.075, 0.075, 0.115, Vector3(0.0, 0.035, -0.20), steel, Vector3(90.0, 0.0, 0.0), 16)
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		_cyl(root, "Chamber%d" % i, 0.017, 0.017, 0.12,
			Vector3(cos(a) * 0.045, 0.035 + sin(a) * 0.045, -0.20), dark, Vector3(90.0, 0.0, 0.0), 8)
	_cyl(root, "Barrel", 0.038, 0.038, 0.34, Vector3(0.0, 0.055, -0.46), steel, Vector3(90.0, 0.0, 0.0), 16)
	_box(root, "BarrelRib", Vector3(0.025, 0.018, 0.32), Vector3(0.0, 0.095, -0.46), metal)
	_ring(root, "MuzzleRing", 0.03, 0.045, Vector3(0.0, 0.055, -0.63), dark, Vector3(90.0, 0.0, 0.0))
	_box(root, "Grip", Vector3(0.085, 0.23, 0.105), Vector3(0.0, -0.17, 0.07), wood, Vector3(-18.0, 0.0, 0.0))
	_box(root, "GripCap", Vector3(0.09, 0.022, 0.11), Vector3(0.0, -0.29, 0.09), steel)
	_box(root, "Hammer", Vector3(0.03, 0.055, 0.03), Vector3(0.0, 0.10, 0.045), dark, Vector3(-20.0, 0.0, 0.0))
	_trigger_guard(root, -0.05, -0.01, dark)
	_sights(root, -0.59, -0.06, 0.10, dark, accent)
	for i in range(3):
		_box(root, "Engrave%d" % i, Vector3(0.004, 0.006, 0.07), Vector3(0.052, 0.03 + i * 0.02, -0.10), accent)

# -------------------------------------------------------------------- long guns ---

static func _build_shotgun(root: Node, metal: Material, dark: Material, black: Material, wood: Material, steel: Material, accent: Material) -> void:
	_box(root, "Stock", Vector3(0.10, 0.15, 0.30), Vector3(0.0, -0.07, 0.34), wood, Vector3(4.0, 0.0, 0.0))
	_box(root, "Butt", Vector3(0.11, 0.17, 0.025), Vector3(0.0, -0.08, 0.50), dark)
	_box(root, "Receiver", Vector3(0.13, 0.15, 0.26), Vector3(0.0, 0.0, 0.04), metal)
	_box(root, "ReceiverTop", Vector3(0.10, 0.015, 0.24), Vector3(0.0, 0.082, 0.04), dark)
	for sx in [-1.0, 1.0]:
		_cyl(root, "Barrel%s" % sx, 0.042, 0.042, 0.78,
			Vector3(sx * 0.046, 0.035, -0.49), steel, Vector3(90.0, 0.0, 0.0), 14)
		_ring(root, "Muzzle%s" % sx, 0.028, 0.046, Vector3(sx * 0.046, 0.035, -0.88), dark, Vector3(90.0, 0.0, 0.0))
	_cyl(root, "MagTube", 0.052, 0.052, 0.62, Vector3(0.0, -0.045, -0.47), dark, Vector3(90.0, 0.0, 0.0), 12)
	_box(root, "Pump", Vector3(0.145, 0.105, 0.26), Vector3(0.0, -0.045, -0.42), wood)
	for i in range(6):
		_box(root, "PumpRidge%d" % i, Vector3(0.15, 0.012, 0.012), Vector3(0.0, -0.045, -0.53 + i * 0.045), dark)
	_box(root, "Ejection", Vector3(0.007, 0.045, 0.12), Vector3(0.067, 0.025, 0.02), black)
	_box(root, "TriggerGuard", Vector3(0.075, 0.012, 0.10), Vector3(0.0, -0.09, -0.04), dark)
	_box(root, "Trigger", Vector3(0.012, 0.05, 0.012), Vector3(0.0, -0.06, -0.02), steel, Vector3(-10.0, 0.0, 0.0))
	_sphere(root, "Bead", 0.012, Vector3(0.0, 0.085, -0.86), accent)
	_box(root, "SlingLoop", Vector3(0.02, 0.035, 0.015), Vector3(0.0, -0.13, -0.70), dark)

static func _build_sniper(root: Node, metal: Material, dark: Material, wood: Material, steel: Material, accent: Material, glass: Material) -> void:
	_box(root, "Stock", Vector3(0.105, 0.14, 0.40), Vector3(0.0, -0.055, 0.32), wood, Vector3(3.0, 0.0, 0.0))
	_box(root, "CheekRest", Vector3(0.09, 0.055, 0.26), Vector3(0.0, 0.035, 0.30), wood)
	_box(root, "Butt", Vector3(0.115, 0.16, 0.03), Vector3(0.0, -0.06, 0.53), dark)
	_box(root, "Receiver", Vector3(0.125, 0.13, 0.32), Vector3(0.0, 0.0, -0.02), metal)
	_box(root, "ReceiverPort", Vector3(0.007, 0.05, 0.12), Vector3(0.064, 0.02, -0.04), dark)
	_cyl(root, "BoltHandle", 0.018, 0.018, 0.075, Vector3(0.085, 0.03, 0.04), steel, Vector3(0.0, 0.0, 75.0), 10)
	_sphere(root, "BoltKnob", 0.024, Vector3(0.115, 0.06, 0.04), steel)
	_cyl(root, "Barrel", 0.033, 0.033, 0.82, Vector3(0.0, 0.015, -0.58), steel, Vector3(90.0, 0.0, 0.0), 16)
	_cyl(root, "MuzzleBrake", 0.05, 0.05, 0.11, Vector3(0.0, 0.015, -1.00), dark, Vector3(90.0, 0.0, 0.0), 16)
	for i in range(3):
		_ring(root, "BrakeSlot%d" % i, 0.036, 0.05, Vector3(0.0, 0.015, -0.96 - i * 0.03), accent, Vector3(90.0, 0.0, 0.0))
	_box(root, "Magazine", Vector3(0.075, 0.12, 0.10), Vector3(0.0, -0.12, -0.02), dark)
	_box(root, "TriggerGuard", Vector3(0.075, 0.012, 0.10), Vector3(0.0, -0.08, -0.10), dark)
	_box(root, "Trigger", Vector3(0.012, 0.045, 0.012), Vector3(0.0, -0.055, -0.09), steel)
	# Прицел
	_box(root, "ScopeMount1", Vector3(0.03, 0.05, 0.03), Vector3(0.0, 0.11, 0.08), dark)
	_box(root, "ScopeMount2", Vector3(0.03, 0.05, 0.03), Vector3(0.0, 0.11, -0.20), dark)
	_cyl(root, "ScopeTube", 0.038, 0.038, 0.34, Vector3(0.0, 0.17, -0.06), dark, Vector3(90.0, 0.0, 0.0), 16)
	_cyl(root, "ScopeLensFront", 0.042, 0.042, 0.012, Vector3(0.0, 0.17, -0.235), glass, Vector3(90.0, 0.0, 0.0), 16)
	_cyl(root, "ScopeLensBack", 0.042, 0.042, 0.012, Vector3(0.0, 0.17, 0.115), glass, Vector3(90.0, 0.0, 0.0), 16)
	_cyl(root, "ScopeTurret", 0.02, 0.02, 0.035, Vector3(0.0, 0.215, -0.06), steel, Vector3(0.0, 0.0, 0.0), 12)
	# Сошки
	for sx in [-1.0, 1.0]:
		_cyl(root, "Bipod%d" % sx, 0.012, 0.012, 0.28, Vector3(sx * 0.07, -0.16, -0.83), dark,
			Vector3(0.0, 0.0, sx * 22.0), 8)
		_box(root, "BipodFoot%d" % sx, Vector3(0.035, 0.012, 0.05), Vector3(sx * 0.12, -0.29, -0.83), dark)

static func _build_legend(root: Node, metal: Material, dark: Material, black: Material, accent: Material, glass: Material) -> void:
	_box(root, "Core", Vector3(0.13, 0.14, 0.42), Vector3(0.0, 0.01, -0.12), metal)
	_box(root, "Upper", Vector3(0.10, 0.035, 0.40), Vector3(0.0, 0.095, -0.12), dark)
	_box(root, "Lower", Vector3(0.10, 0.04, 0.36), Vector3(0.0, -0.075, -0.10), dark)
	_box(root, "Stock", Vector3(0.09, 0.11, 0.20), Vector3(0.0, -0.02, 0.20), metal)
	_box(root, "StockPad", Vector3(0.10, 0.12, 0.025), Vector3(0.0, -0.02, 0.31), accent)
	_cyl(root, "Barrel", 0.035, 0.035, 0.42, Vector3(0.0, 0.015, -0.52), dark, Vector3(90.0, 0.0, 0.0), 16)
	for i in range(4):
		_ring(root, "Coil%d" % i, 0.034, 0.052, Vector3(0.0, 0.015, -0.60 - i * 0.06), accent, Vector3(90.0, 0.0, 0.0))
	_cyl(root, "Muzzle", 0.045, 0.045, 0.09, Vector3(0.0, 0.015, -0.84), dark, Vector3(90.0, 0.0, 0.0), 16)
	for sx in [-1.0, 1.0]:
		_box(root, "Vent%d" % sx, Vector3(0.008, 0.07, 0.24), Vector3(sx * 0.068, 0.02, -0.16), black)
		for i in range(4):
			_box(root, "VentSlit%d_%d" % [sx, i], Vector3(0.01, 0.008, 0.03),
				Vector3(sx * 0.072, -0.01 + i * 0.022, -0.12 - i * 0.03), accent)
	# Энергетические ячейки
	for sx in [-1.0, 1.0]:
		_cyl(root, "Cell%d" % sx, 0.028, 0.028, 0.20, Vector3(sx * 0.075, 0.06, -0.30), glass, Vector3(90.0, 0.0, 0.0), 12)
		_ring(root, "CellCap%d" % sx, 0.024, 0.034, Vector3(sx * 0.075, 0.06, -0.40), accent, Vector3(90.0, 0.0, 0.0))
	_box(root, "Magazine", Vector3(0.085, 0.26, 0.11), Vector3(0.0, -0.20, 0.02), dark, Vector3(10.0, 0.0, 0.0))
	for i in range(4):
		_box(root, "MagCell%d" % i, Vector3(0.09, 0.012, 0.09), Vector3(0.0, -0.12 - i * 0.045, 0.03), accent)
	# Голографический прицел
	_box(root, "HoloBase", Vector3(0.06, 0.02, 0.10), Vector3(0.0, 0.125, -0.14), dark)
	_box(root, "HoloGlass", Vector3(0.05, 0.07, 0.008), Vector3(0.0, 0.17, -0.16), glass)
	_ring(root, "HoloReticle", 0.012, 0.018, Vector3(0.0, 0.17, -0.165), accent, Vector3(0.0, 0.0, 0.0))
	_trigger_guard(root, -0.06, -0.01, dark)


