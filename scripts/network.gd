extends Node

## LAN-мультиплеер через встроенный ENet. Хост авторитетен за мир, зверей,
## монеты, урон и казино. Клиенты управляют своим игроком и получают снапшоты.

const PORT := 7777

signal connected_as(peer: int, seed_value: int)
signal player_list_changed()
signal game_message(text: String, color: Color)

var main = null
var local_peer := 0
var is_host := false
var local_name := "Охотник"
var world_seed := 424242
var players := {} # peer -> state dictionary
var last_report_ms := {}
var last_report_pos := {}
var last_shot_ms := {}
var client_latency := {}
var want_reconnect := false
var reconnect_ip := ""
var reconnect_name := ""
var reconnect_attempts := 0
var reconnect_at := 0

func _ready() -> void:
	pass

func _new_state(peer: int, pname: String) -> Dictionary:
	return {
		"peer": peer,
		"name": pname,
		"pos": Vector3(-6.0 + float(peer % 3) * 6.0, 0.0, 13.0),
		"yaw": 0.0,
		"pitch": 0.0,
		"coins": 30,
		"health": 100.0,
		"kills": 0,
		"inventory": GameData.starter_inventory(),
		"weapon_index": 0,
		"alive": true,
	}

func host_game(pname: String) -> bool:
	local_name = pname
	is_host = true
	local_peer = 1
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 8)
	if err != OK:
		var text := "Не удалось открыть порт %d (код %d). Возможно, он занят другой программой." % [PORT, err]
		GameLog.show_error("Не удалось создать сервер", text)
		game_message.emit(text, Color(1.0, 0.3, 0.3))
		return false
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	players[1] = _new_state(1, pname)
	connected_as.emit(1, world_seed)
	player_list_changed.emit()
	game_message.emit("Сервер запущен. Порт %d" % PORT, Color(0.6, 1.0, 0.6))
	return true

func join_game(ip: String, pname: String) -> bool:
	local_name = pname
	reconnect_ip = ip
	reconnect_name = pname
	is_host = false
	local_peer = 0
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		var text := "Не удалось подключиться к %s:%d (код %d). Проверьте IP и брандмауэр." % [ip, PORT, err]
		GameLog.show_error("Ошибка подключения", text)
		game_message.emit(text, Color(1.0, 0.3, 0.3))
		return false
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	game_message.emit("Подключаемся к %s:%d..." % [ip, PORT], Color(0.8, 0.9, 1.0))
	return true

func disconnect_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	local_peer = 0
	want_reconnect = false

func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server() -> void:
	want_reconnect = false
	reconnect_attempts = 0
	rpc("register_player", local_name)

func _start_reconnect() -> void:
	if is_host or reconnect_ip.is_empty():
		return
	want_reconnect = true
	reconnect_attempts = 0
	reconnect_at = Time.get_ticks_msec() + 2000
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	game_message.emit("Соединение потеряно, пробуем переподключиться...", Color(1.0, 0.75, 0.35))

func _process(_delta: float) -> void:
	if not want_reconnect or Time.get_ticks_msec() < reconnect_at:
		return
	if multiplayer.multiplayer_peer != null:
		return
	want_reconnect = false
	reconnect_attempts += 1
	if reconnect_attempts > 3:
		game_message.emit("Не удалось переподключиться. Вернитесь в меню.", Color(1.0, 0.3, 0.3))
		return
	join_game(reconnect_ip, reconnect_name)

func _on_connection_failed() -> void:
	GameLog.error("Не удалось подключиться к серверу")
	game_message.emit("Не удалось подключиться к серверу", Color(1.0, 0.3, 0.3))
	_start_reconnect()

func _on_server_disconnected() -> void:
	GameLog.warn("Сервер отключился")
	game_message.emit("Сервер отключился", Color(1.0, 0.3, 0.3))
	_start_reconnect()

func _on_peer_connected(peer: int) -> void:
	pass

func _on_peer_disconnected(peer: int) -> void:
	if is_host:
		players.erase(peer)
		rpc("player_left", peer)
		player_list_changed.emit()
		game_message.emit("Игрок %d отключился" % peer, Color(1.0, 0.75, 0.4))

# ---------------------------------------------------------------- RPC ---

@rpc("any_peer", "reliable")
func register_player(pname: String) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = _new_state(sender, pname)
	# Клиенты создают узел игрока в welcome, а хост должен сделать это сам —
	# иначе подключившегося игрока нет в сцене, хотя его состояние уже есть.
	if main != null:
		main.ensure_player(sender)
	rpc("welcome", sender, world_seed, pname)
	player_list_changed.emit()
	GameLog.info("Игрок #%d (%s) вошёл в лес" % [sender, pname])
	game_message.emit("%s вошёл в лес" % pname, Color(0.6, 1.0, 0.6))

@rpc("reliable")
func welcome(peer: int, seed_value: int, pname: String) -> void:
	world_seed = seed_value
	if not players.has(peer):
		players[peer] = _new_state(peer, pname)
	if not is_host and peer == multiplayer.get_unique_id():
		local_peer = peer
		connected_as.emit(peer, seed_value)
	if main != null:
		main.ensure_player(peer)
	player_list_changed.emit()

@rpc("reliable")
func player_left(peer: int) -> void:
	players.erase(peer)
	if main != null:
		main.remove_player(peer)
	player_list_changed.emit()

@rpc("any_peer", "unreliable")
func report_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		return
	# Античит: отбрасываем телепорты и скорость выше возможной.
	var now := Time.get_ticks_msec()
	var prev_ms := int(last_report_ms.get(sender, 0))
	var prev_pos: Vector3 = last_report_pos.get(sender, pos)
	var dt := float(now - prev_ms) / 1000.0
	if prev_ms > 0 and dt > 0.01 and dt < 2.0:
		var dist := pos.distance_to(prev_pos)
		if dist < 30.0 and dist / dt > 18.0:
			return
	last_report_ms[sender] = now
	last_report_pos[sender] = pos
	players[sender]["pos"] = pos
	players[sender]["yaw"] = yaw
	players[sender]["pitch"] = pitch
	# Хост не получает собственные снапшоты, поэтому применяет отчёт клиента сам.
	if main != null:
		main.update_remote_player(sender, players[sender])

@rpc("unreliable")
func snapshot_players(data: Array) -> void:
	for e in data:
		var peer := int(e[0])
		if not players.has(peer):
			players[peer] = _new_state(peer, "Охотник")
		var st: Dictionary = players[peer]
		st["pos"] = Vector3(float(e[1]) / 100.0, float(e[2]) / 100.0, float(e[3]) / 100.0)
		st["yaw"] = float(e[4]) / 1000.0
		st["pitch"] = float(e[5]) / 1000.0
		if main != null and peer != multiplayer.get_unique_id():
			main.update_remote_player(peer, st)

@rpc("unreliable")
func snapshot_animals(data: Array, frame: int, last_chunk: bool) -> void:
	if main != null:
		main.update_animal_proxies(data, frame, last_chunk)

@rpc("any_peer", "call_local", "reliable")
func request_shoot(origin: Vector3, dir: Vector3, weapon_id: String, muzzle: Vector3, ammo_type: int, sent_msec: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if not is_host or main == null:
		return
	var now := Time.get_ticks_msec()
	var last := int(last_shot_ms.get(sender, 0))
	var rate := float(GameData.WEAPONS.get(weapon_id, GameData.WEAPONS["pistol"])["rate"])
	if now - last < int(rate * 500.0):
		return
	last_shot_ms[sender] = now
	client_latency[sender] = clampi(now - sent_msec, 0, 300)
	var st: Dictionary = players.get(sender, {})
	if sender != multiplayer.get_unique_id() and st.has("pos") and st["pos"].distance_to(origin) > 8.0:
		return
	var result: Array = main.host_fire(sender, origin, dir, weapon_id, ammo_type, client_latency[sender])
	if result.is_empty():
		return
	rpc("shoot_result", sender, result[0], result[1], result[2], muzzle, result[3], result[4])

@rpc("call_local", "reliable")
func shoot_result(shooter: int, hit_pos: Vector3, animal_id: int, critical_type: String, muzzle: Vector3, damage: float, animal_name: String) -> void:
	if main != null:
		main.on_shoot_result(shooter, hit_pos, animal_id, critical_type, muzzle, damage, animal_name)

@rpc("any_peer", "call_local", "reliable")
func make_noise(pos: Vector3, radius: float) -> void:
	if not is_host:
		return
	for a in GameState.animals:
		if a != null and is_instance_valid(a) and not a.remote_proxy:
			a.hear_noise(pos, radius)

const QUICK_MESSAGES := ["Здесь зверь!", "Нужны патроны!", "Мне нужна помощь!", "Я здесь!"]

@rpc("any_peer", "call_local", "reliable")
func quick_message(index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if index < 0 or index >= QUICK_MESSAGES.size() or not players.has(sender):
		return
	var text := "%s: %s" % [players[sender].get("name", "Игрок"), QUICK_MESSAGES[index]]
	rpc("remote_message", text, Color(0.7, 0.9, 1.0))

@rpc("any_peer", "call_local", "reliable")
func heal(peer: int, amount: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if not is_host or not players.has(peer):
		return
	players[peer]["health"] = minf(100.0, float(players[peer]["health"]) + amount)
	rpc("health_update", peer, players[peer]["health"])

@rpc("call_local", "reliable")
func animal_died(animal_id: int, pos: Vector3, species: String, critical: bool, shooter: int, coin_value: int) -> void:
	if main != null:
		main.on_animal_died(animal_id, pos, species, critical, shooter, coin_value)

@rpc("call_local", "reliable")
func spawn_coins(coin_id: int, pos: Vector3, value: int) -> void:
	if main != null:
		main.on_spawn_coin(coin_id, pos, value)

@rpc("any_peer", "call_local", "reliable")
func coin_pickup_for(peer: int, coin_id: int, value: int) -> void:
	if not is_host or not players.has(peer):
		return
	players[peer]["coins"] = int(players[peer]["coins"]) + value
	rpc("coin_taken", coin_id, peer)
	rpc("coins_update", peer, players[peer]["coins"])

@rpc("call_local", "reliable")
func coin_taken(coin_id: int, peer: int) -> void:
	if main != null:
		main.on_coin_taken(coin_id)

@rpc("call_local", "reliable")
func coins_update(peer: int, total: int) -> void:
	if main != null:
		main.on_coins_update(peer, total)

@rpc("call_local", "reliable")
func health_update(peer: int, health: float) -> void:
	if main != null:
		main.on_health_update(peer, health)

@rpc("any_peer", "call_local", "reliable")
func spin_request() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if not is_host or not players.has(sender):
		return
	var st: Dictionary = players[sender]
	if int(st["coins"]) < GameData.COIN_COST:
		rpc("spin_result", sender, [], "Не хватает монет! Охотьтесь.", "", st["coins"], st["inventory"])
		return
	st["coins"] = int(st["coins"]) - GameData.COIN_COST
	var reels: Array[int] = [
		GameData.weight_to_rarity(randf()),
		GameData.weight_to_rarity(randf()),
		GameData.weight_to_rarity(randf()),
	]
	var text := "Мимо... утешительные 2 монеты"
	var weapon_id := ""
	if reels[0] == reels[1] and reels[1] == reels[2]:
		var r := reels[0]
		if r == 0:
			st["coins"] = int(st["coins"]) + 50
			text = "Тройка 7! +50 монет"
		else:
			weapon_id = GameData.weapon_for_rarity(r)
			var inv: Array = st["inventory"]
			if inv.has(weapon_id):
				st["coins"] = int(st["coins"]) + 30 * (r + 1)
				text = "Уже есть! +%d монет" % (30 * (r + 1))
				weapon_id = ""
			else:
				var slot := -1
				for i in range(inv.size()):
					if inv[i] == "":
						slot = i
						break
				if slot < 0:
					st["coins"] = int(st["coins"]) + 30 * (r + 1)
					text = "Инвентарь полон! +%d монет" % (30 * (r + 1))
					weapon_id = ""
				else:
					inv[slot] = weapon_id
					text = "ДЖЕКПОТ! %s" % GameData.WEAPONS[weapon_id]["name"]
	else:
		var pair := -1
		if reels[0] == reels[1] or reels[0] == reels[2]:
			pair = reels[0]
		elif reels[1] == reels[2]:
			pair = reels[1]
		if pair >= 0:
			var payout := 8 * (pair + 1)
			st["coins"] = int(st["coins"]) + payout
			text = "Два символа! +%d монет" % payout
	rpc("spin_result", sender, reels, text, weapon_id, st["coins"], st["inventory"])

@rpc("call_local", "reliable")
func spin_result(peer: int, reels: Array, text: String, weapon_id: String, coins: int, inventory: Array) -> void:
	if main != null:
		main.on_spin_result(peer, reels, text, weapon_id, coins, inventory)

@rpc("any_peer", "call_local", "reliable")
func set_inventory_order(order: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_local_pid()
	if not is_host or not players.has(sender):
		return
	players[sender]["inventory"] = order
	rpc("inventory_order", sender, order)

@rpc("call_local", "reliable")
func inventory_order(peer: int, order: Array) -> void:
	if main != null:
		main.on_inventory_order(peer, order)

@rpc("any_peer", "reliable")
func request_name_change(pname: String) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		players[sender]["name"] = pname
		rpc("name_changed", sender, pname)

@rpc("call_local", "reliable")
func name_changed(peer: int, pname: String) -> void:
	if players.has(peer):
		players[peer]["name"] = pname

func broadcast_message(text: String, color: Color = Color.WHITE) -> void:
	rpc("remote_message", text, color)

@rpc("call_local", "reliable")
func remote_message(text: String, color: Color) -> void:
	game_message.emit(text, color)

var _snapshot_frame := 0

func snapshot_tick(player_arr: Array, animal_arr: Array) -> void:
	if not is_host:
		return
	_snapshot_frame += 1
	rpc("snapshot_players", player_arr)
	var chunk_size := 12
	var chunks: Array = []
	for i in range(0, animal_arr.size(), chunk_size):
		chunks.append(animal_arr.slice(i, i + chunk_size))
	if chunks.is_empty():
		chunks.append([])
	for i in range(chunks.size()):
		rpc("snapshot_animals", chunks[i], _snapshot_frame, i == chunks.size() - 1)

