extends RefCounted

## New-game setup, map generation and village founding.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")

const MAP_RADIUS := 60          # playable band, -60..60 on both axes
const BOT_COUNT := 24
const CAMP_COUNT := 90
const OASIS_COUNT := 40

const BOT_NAMES := [
	"Бренн", "Верцингеторикс", "Амбиорикс", "Арминий", "Марбод", "Сегест",
	"Луций Красс", "Гай Марий", "Тиберий", "Друз", "Оргеторикс", "Думнориг",
	"Ариовист", "Хариетто", "Радагайс", "Аларих", "Катуальда", "Ингвиомер",
	"Публий Сципион", "Квинт Фабий", "Гней Помпей", "Секст Юлий",
	"Кельтилл", "Литавик", "Коммий", "Индутиомар",
]

const VILLAGE_SUFFIX := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]

const PERSONALITIES := ["aggressive", "economic", "defensive"]


static func new_game(player_name: String, tribe: String, speed: float, seed_value: int) -> Dictionary:
	var state := {
		"version": Sim.SAVE_VERSION,
		"rng": max(1, seed_value),
		"seed": seed_value,
		"speed": speed,
		"t": 0.0,
		"created": 0.0,
		"next_id": 1,
		"player": {"name": player_name, "tribe": tribe},
		"hero": Hero.new_hero(),
		"villages": [],
		"bots": [],
		"camps": [],
		"oases": [],
		"movements": [],
		"trades": [],
		"reports": [],
		"settings": {
			"llm_enabled": false,
			"llm_key": "",
			"llm_model": "claude-sonnet-5",
			"llm_rivals": 2,
		},
	}

	var first := make_village(state, 0, "%s I" % _tribe_home(tribe), 0, 0, tribe, true)
	state["villages"].append(first)

	_generate_bots(state, tribe)
	_generate_camps(state)
	_generate_oases(state)

	Sim.add_report(state, {
		"type": "info",
		"title": "Добро пожаловать, %s" % player_name,
		"text": "Твоя деревня основана. Качай поля, строй склад и амбар, "
			+ "потом пункт сбора и казарму. Разбойничьи лагеря рядом — лёгкая добыча.",
	})
	return state


static func _tribe_home(tribe: String) -> String:
	match tribe:
		T.TRIBE_GAULS: return "Галлия"
		T.TRIBE_GERMANS: return "Германия"
		_: return "Рим"


static func make_village(state: Dictionary, id: int, name: String, x: int, y: int,
		tribe: String, capital: bool) -> Dictionary:
	var fields: Array = []
	for i in range(18):
		fields.append(2 if capital else 0)

	var slots: Array = []
	for i in range(T.SLOT_COUNT):
		slots.append({"id": "", "lvl": 0})
	slots[T.SLOT_MAIN] = {"id": "main", "lvl": 1}
	slots[T.SLOT_RALLY] = {"id": "rally_point", "lvl": 1}
	slots[T.SLOT_WALL] = {"id": T.wall_id_for(tribe), "lvl": 0}
	if capital:
		slots[2] = {"id": "warehouse", "lvl": 1}
		slots[3] = {"id": "granary", "lvl": 1}

	return {
		"id": id,
		"name": name,
		"x": x,
		"y": y,
		"tribe": tribe,
		"capital": capital,
		"res": [750.0, 750.0, 750.0, 750.0],
		"fields": fields,
		"slots": slots,
		"troops": {},
		"cp": 0.0,
		"loyalty": 100.0,
		"build_queue": [],
		"train_queue": [],
		"starve_at": -1.0,
	}


# ---------------------------------------------------------------------------
# Map population
# ---------------------------------------------------------------------------

static func _free_spot(state: Dictionary, min_r: int, max_r: int, min_gap: int) -> Vector2i:
	for attempt in range(400):
		var ang := Sim.rand_range(state, 0.0, TAU)
		var rad := Sim.rand_range(state, float(min_r), float(max_r))
		var p := Vector2i(int(round(cos(ang) * rad)), int(round(sin(ang) * rad)))
		if abs(p.x) > MAP_RADIUS or abs(p.y) > MAP_RADIUS:
			continue
		if _occupied_within(state, p, min_gap):
			continue
		return p
	return Vector2i(min_r + 3, min_r + 3)


static func _occupied_within(state: Dictionary, p: Vector2i, gap: int) -> bool:
	var g := float(gap)
	for v in state["villages"]:
		if Sim.distance(p.x, p.y, float(v["x"]), float(v["y"])) < g:
			return true
	for b in state["bots"]:
		if Sim.distance(p.x, p.y, float(b["x"]), float(b["y"])) < g:
			return true
	for c in state["camps"]:
		if Sim.distance(p.x, p.y, float(c["x"]), float(c["y"])) < g:
			return true
	for o in state["oases"]:
		if Sim.distance(p.x, p.y, float(o["x"]), float(o["y"])) < g:
			return true
	return false


static func _generate_bots(state: Dictionary, player_tribe: String) -> void:
	var names := BOT_NAMES.duplicate()
	var tribes := [T.TRIBE_ROMANS, T.TRIBE_GAULS, T.TRIBE_GERMANS]
	for i in range(BOT_COUNT):
		var p := _free_spot(state, 9 + i / 2, 16 + i * 2, 5)
		var name: String = "Вождь %d" % (i + 1)
		if not names.is_empty():
			var ni := Sim.rand_int(state, 0, names.size() - 1)
			name = names[ni]
			names.remove_at(ni)
		var personality: String = PERSONALITIES[Sim.rand_int(state, 0, 2)]
		var dist := Sim.distance(0, 0, p.x, p.y)
		# Difficulty scales with distance from the player's capital.
		var strength: float = clampf(dist / 45.0, 0.15, 1.0)
		state["bots"].append({
			"id": 1000 + i,
			"name": name,
			"tribe": tribes[Sim.rand_int(state, 0, 2)],
			"x": p.x,
			"y": p.y,
			"personality": personality,
			"res": [400.0, 400.0, 400.0, 400.0],
			"eco": 1.0 + strength * 3.0,     # abstract economy score, grows over time
			"troops": {},
			"wall": int(strength * 3.0),
			"residence": 0,
			"cranny": 1 + int(strength * 3.0),
			"smithy": 0,
			"armoury": 0,
			"pop": 40 + int(strength * 120.0),
			"anger": 0.0,
			"next_tick": Sim.rand_range(state, 60.0, Sim.BOT_TICK_INTERVAL),
			"llm": false,
			"chat": [],
		})


static func _generate_camps(state: Dictionary) -> void:
	for i in range(CAMP_COUNT):
		var p := _free_spot(state, 4, 50, 2)
		var dist := Sim.distance(0, 0, p.x, p.y)
		var level: int = clampi(1 + int(dist / 3.5) + Sim.rand_int(state, -1, 1), 1, 15)
		state["camps"].append({
			"id": 2000 + i,
			"x": p.x,
			"y": p.y,
			"level": level,
			"alive": true,
			"troops": Sim._camp_troops(state, level),
			"reward": [
				float(level * 350), float(level * 320), float(level * 300), float(level * 180)],
			"xp": level * 55,
			"item": _camp_item(state, level),
			"respawn_at": 0.0,
		})


static func _camp_item(state: Dictionary, level: int) -> String:
	if level < 3:
		return ""
	var tier: int = 2 if level >= 9 else 1
	var pool: Array = []
	for id in T.HERO_ITEMS:
		if int(T.HERO_ITEMS[id]["tier"]) == tier:
			pool.append(id)
	if pool.is_empty():
		return ""
	if Sim.rand_unit(state) > 0.45:
		return ""
	return pool[Sim.rand_int(state, 0, pool.size() - 1)]


static func _generate_oases(state: Dictionary) -> void:
	for i in range(OASIS_COUNT):
		var p := _free_spot(state, 3, 45, 2)
		var res := Sim.rand_int(state, 0, 3)
		var pct: float = 0.25 if Sim.rand_unit(state) < 0.7 else 0.50
		var guard_level: int = 1 + Sim.rand_int(state, 0, 8)
		state["oases"].append({
			"id": 3000 + i,
			"x": p.x,
			"y": p.y,
			"res": res,
			"pct": pct,
			"owner": -1,
			"troops": Sim._camp_troops(state, guard_level),
		})


# ---------------------------------------------------------------------------
# Founding new villages
# ---------------------------------------------------------------------------

static func tile_is_free(state: Dictionary, x: int, y: int) -> bool:
	if abs(x) > MAP_RADIUS or abs(y) > MAP_RADIUS:
		return false
	for v in state["villages"]:
		if int(v["x"]) == x and int(v["y"]) == y:
			return false
	for b in state["bots"]:
		if int(b["x"]) == x and int(b["y"]) == y:
			return false
	for c in state["camps"]:
		if int(c["x"]) == x and int(c["y"]) == y and bool(c["alive"]):
			return false
	for o in state["oases"]:
		if int(o["x"]) == x and int(o["y"]) == y:
			return false
	return true


static func found_village(state: Dictionary, x: int, y: int) -> bool:
	if not tile_is_free(state, x, y):
		return false
	var idx: int = state["villages"].size()
	var tribe: String = state["player"]["tribe"]
	var suffix: String = VILLAGE_SUFFIX[clampi(idx, 0, VILLAGE_SUFFIX.size() - 1)]
	var name := "%s %s" % [_tribe_home(tribe), suffix]
	var v := make_village(state, int(state["next_id"]) + 100, name, x, y, tribe, false)
	state["next_id"] = int(state["next_id"]) + 1
	state["villages"].append(v)
	return true


## Somewhere sensible for the player to settle next.
static func suggest_settle_spot(state: Dictionary) -> Vector2i:
	var home: Dictionary = state["villages"][0]
	for radius in range(6, 40):
		for attempt in range(30):
			var ang := Sim.rand_range(state, 0.0, TAU)
			var p := Vector2i(
				int(home["x"]) + int(round(cos(ang) * radius)),
				int(home["y"]) + int(round(sin(ang) * radius)))
			if tile_is_free(state, p.x, p.y):
				return p
	return Vector2i(9999, 9999)


## Everything worth showing on the map inside a bounding box.
static func objects_in_rect(state: Dictionary, x0: int, y0: int, x1: int, y1: int) -> Array:
	var out: Array = []
	for v in state["villages"]:
		if int(v["x"]) >= x0 and int(v["x"]) <= x1 and int(v["y"]) >= y0 and int(v["y"]) <= y1:
			out.append({"kind": "village", "ref": v, "x": int(v["x"]), "y": int(v["y"])})
	for b in state["bots"]:
		if int(b["x"]) >= x0 and int(b["x"]) <= x1 and int(b["y"]) >= y0 and int(b["y"]) <= y1:
			out.append({"kind": "bot", "ref": b, "x": int(b["x"]), "y": int(b["y"])})
	for c in state["camps"]:
		if not bool(c["alive"]):
			continue
		if int(c["x"]) >= x0 and int(c["x"]) <= x1 and int(c["y"]) >= y0 and int(c["y"]) <= y1:
			out.append({"kind": "camp", "ref": c, "x": int(c["x"]), "y": int(c["y"])})
	for o in state["oases"]:
		if int(o["x"]) >= x0 and int(o["x"]) <= x1 and int(o["y"]) >= y0 and int(o["y"]) <= y1:
			out.append({"kind": "oasis", "ref": o, "x": int(o["x"]), "y": int(o["y"])})
	return out
