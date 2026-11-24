extends Node

## Глобальное состояние и ссылки, доступные из всех скриптов.

var main: Node = null
var world: Node = null
var effects: Node = null
var players: Array = []
var animals: Array = []

var running := false
var cinematic_active := false
var cinematic_owner = null
var paused := false

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	randomize()

func notify(message: String, color: Color = Color.WHITE) -> void:
	if main != null and main.has_method("broadcast"):
		main.broadcast(message, color)

func nearest_player(pos: Vector3):
	var best = null
	var best_dist := 1.0e9
	for p in players:
		if p == null or not is_instance_valid(p) or not p.alive:
			continue
		var d: float = p.global_position.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = p
	return best

func random_point_in_forest() -> Vector3:
	if world == null:
		return Vector3(randf_range(-100.0, 100.0), 0.0, randf_range(-100.0, 100.0))
	for _i in range(60):
		var x := rng.randf_range(-GameData.MAP_HALF + 12.0, GameData.MAP_HALF - 12.0)
		var z := rng.randf_range(-GameData.MAP_HALF + 12.0, GameData.MAP_HALF - 12.0)
		if Vector2(x, z).length() < GameData.CASINO_RADIUS + 8.0:
			continue
		return Vector3(x, world.ground_height(x, z), z)
	return Vector3(60.0, 0.0, 60.0)
