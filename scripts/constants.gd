class_name GameData
extends RefCounted

## Все балансовые данные игры в одном месте.

const MAP_SIZE := 360.0
const MAP_HALF := 180.0
const CASINO_RADIUS := 24.0
const COIN_COST := 10

const RARITY_NAMES := ["Обычное", "Необычное", "Редкое", "Эпическое", "Легендарное"]
const RARITY_COLORS := [
	Color(0.72, 0.74, 0.76),
	Color(0.36, 0.83, 0.46),
	Color(0.30, 0.62, 1.00),
	Color(0.75, 0.38, 1.00),
	Color(1.00, 0.76, 0.18),
]
## Шансы выпадения rarity-тира в казино (в процентах).
const RARITY_WEIGHTS := [50.0, 28.0, 15.0, 6.0, 1.0]
const REEL_SYMBOLS := ["7", "X", "R", "E", "L"]

const WEAPONS := {
	"pistol": {
		"name": "Егерь П-9", "rarity": 0, "damage": 24.0,
		"rate": 0.24, "mag": 12, "reload": 1.15, "spread": 0.016,
		"pellets": 1, "auto": false, "color": Color(0.24, 0.26, 0.30),
		"desc": "Надёжный стартовый пистолет.",
	},
	"silver": {
		"name": "Серебряный Кольт", "rarity": 1, "damage": 34.0,
		"rate": 0.19, "mag": 14, "reload": 1.05, "spread": 0.011,
		"pellets": 1, "auto": false, "color": Color(0.82, 0.86, 0.92),
		"desc": "Лёгкий, быстрый, смертоносный.",
	},
	"shotgun": {
		"name": "Гром Т-12", "rarity": 2, "damage": 13.0,
		"rate": 0.78, "mag": 6, "reload": 1.9, "spread": 0.085,
		"pellets": 8, "auto": false, "color": Color(0.42, 0.25, 0.12),
		"desc": "Восемь зарядов картечи на ближней дистанции.",
	},
	"sniper": {
		"name": "Око Тайги", "rarity": 3, "damage": 95.0,
		"rate": 1.15, "mag": 5, "reload": 2.1, "spread": 0.0015,
		"pellets": 1, "auto": false, "color": Color(0.16, 0.20, 0.18),
		"desc": "Далекий прицельный выстрел. Идеален для сердца.",
	},
	"legend": {
		"name": "Солнце Леса", "rarity": 4, "damage": 78.0,
		"rate": 0.105, "mag": 36, "reload": 1.6, "spread": 0.006,
		"pellets": 1, "auto": true, "color": Color(1.0, 0.68, 0.13),
		"desc": "Легендарный плазменный автомат. Всё или ничего.",
	},
}

const WEAPON_ORDER := ["pistol", "silver", "shotgun", "sniper", "legend"]

## Вертикальный/горизонтальный разброс отдачи в градусах.
const WEAPON_RECOIL := {
	"pistol": Vector2(1.1, 0.35),
	"silver": Vector2(1.5, 0.55),
	"shotgun": Vector2(3.8, 1.1),
	"sniper": Vector2(4.6, 1.4),
	"legend": Vector2(0.55, 0.22),
}

const AMMO_TYPES := [
	{"id": "normal", "name": "Обычные", "damage": 1.0, "pierce": false, "color": Color(0.85, 0.78, 0.45)},
	{"id": "ap", "name": "Бронебойные", "damage": 1.35, "pierce": true, "color": Color(0.45, 0.75, 1.0)},
	{"id": "hp", "name": "Экспансивные", "damage": 1.15, "pierce": false, "color": Color(1.0, 0.42, 0.35)},
]

## Животные. weak_eye / weak_heart заданы в локальных координатах модели
## (модель смотрит в -Z, масштаб применён к корню зверя).
const SPECIES := {
	"rabbit": {
		"name": "Заяц", "predator": false, "hp": 26.0, "speed": 8.2,
		"damage": 0.0, "scale": 0.52, "coins": 4, "detect": 20.0,
		"ability": "blink", "ability_name": "Фантомный рывок",
		"color": Color(0.74, 0.67, 0.55), "eye_color": Color(1.0, 0.28, 0.20),
		"weak_eyes": [Vector3(-0.13, 0.24, -0.82), Vector3(0.13, 0.24, -0.82)],
		"weak_heart": Vector3(0.0, 0.03, -0.16), "ear": "long",
	},
	"deer": {
		"name": "Олень", "predator": false, "hp": 70.0, "speed": 9.0,
		"damage": 0.0, "scale": 1.05, "coins": 9, "detect": 26.0,
		"ability": "shield", "ability_name": "Дубовый панцирь",
		"color": Color(0.60, 0.40, 0.22), "eye_color": Color(1.0, 0.75, 0.20),
		"weak_eyes": [Vector3(-0.14, 0.24, -0.82), Vector3(0.14, 0.24, -0.82)],
		"weak_heart": Vector3(0.0, 0.02, -0.16), "ear": "horns",
	},
	"boar": {
		"name": "Кабан", "predator": false, "hp": 110.0, "speed": 7.0,
		"damage": 0.0, "scale": 0.92, "coins": 12, "detect": 22.0,
		"ability": "charge", "ability_name": "Бешеный таран",
		"color": Color(0.34, 0.27, 0.22), "eye_color": Color(1.0, 0.35, 0.10),
		"weak_eyes": [Vector3(-0.13, 0.22, -0.82), Vector3(0.13, 0.22, -0.82)],
		"weak_heart": Vector3(0.0, 0.0, -0.16), "ear": "tusks",
	},
	"fox": {
		"name": "Лиса", "predator": true, "hp": 42.0, "speed": 8.8,
		"damage": 7.0, "scale": 0.66, "coins": 7, "detect": 24.0,
		"ability": "decoy", "ability_name": "Лисьи призраки",
		"color": Color(0.86, 0.38, 0.13), "eye_color": Color(0.95, 0.95, 0.25),
		"weak_eyes": [Vector3(-0.13, 0.24, -0.82), Vector3(0.13, 0.24, -0.82)],
		"weak_heart": Vector3(0.0, 0.02, -0.16), "ear": "long",
	},
	"wolf": {
		"name": "Волк", "predator": true, "hp": 80.0, "speed": 9.4,
		"damage": 13.0, "scale": 0.88, "coins": 11, "detect": 32.0,
		"ability": "vampire", "ability_name": "Кровавая луна",
		"color": Color(0.40, 0.44, 0.48), "eye_color": Color(1.0, 0.18, 0.12),
		"weak_eyes": [Vector3(-0.14, 0.24, -0.82), Vector3(0.14, 0.24, -0.82)],
		"weak_heart": Vector3(0.0, 0.02, -0.16), "ear": "long",
	},
	"bear": {
		"name": "Медведь", "predator": true, "hp": 210.0, "speed": 6.2,
		"damage": 26.0, "scale": 1.42, "coins": 22, "detect": 30.0,
		"ability": "berserk", "ability_name": "Берсерк",
		"color": Color(0.25, 0.19, 0.15), "eye_color": Color(1.0, 0.55, 0.10),
		"weak_eyes": [Vector3(-0.14, 0.25, -0.82), Vector3(0.14, 0.25, -0.82)],
		"weak_heart": Vector3(0.0, 0.02, -0.16), "ear": "round",
	},
}

const ABILITY_COLORS := {
	"blink": Color(0.55, 0.85, 1.0),
	"shield": Color(0.95, 0.80, 0.30),
	"charge": Color(1.0, 0.35, 0.12),
	"decoy": Color(0.90, 0.45, 1.0),
	"vampire": Color(1.0, 0.10, 0.18),
	"berserk": Color(1.0, 0.45, 0.05),
}

static func weight_to_rarity(roll: float) -> int:
	var total := 0.0
	for w in RARITY_WEIGHTS:
		total += w
	var x := roll * total
	var acc := 0.0
	for i in range(RARITY_WEIGHTS.size()):
		acc += RARITY_WEIGHTS[i]
		if x <= acc:
			return i
	return RARITY_WEIGHTS.size() - 1

static func weapon_for_rarity(rarity: int) -> String:
	for id in WEAPON_ORDER:
		if WEAPONS[id]["rarity"] == rarity:
			return id
	return "pistol"

## Временный набор для разработки: всё оружие доступно сразу.
static func starter_inventory() -> Array:
	var inv: Array = []
	for id in WEAPON_ORDER:
		inv.append(id)
	while inv.size() < 8:
		inv.append("")
	return inv
