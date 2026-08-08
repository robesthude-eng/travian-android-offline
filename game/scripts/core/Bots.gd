extends RefCounted

## AI opponents.
##
## A bot is deliberately NOT a full village simulation — it is an abstract
## economy score plus a real army. That keeps 24 rivals cheap enough to
## simulate through a 72-hour offline catch-up, while their armies stay real
## objects that fight through exactly the same Combat code the player uses.
##
## When an LLM rival is enabled, the model does not act directly. It writes a
## *policy* (aggression, focus, a line of trash talk) onto the bot, and this
## deterministic code executes that policy. The game therefore plays identically
## offline; the model only changes what the opponent is trying to do.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")

const ECON_PER_ECO_HOUR := 55.0     # resources/hour per point of economy score
const ECO_UPGRADE_COST := 900.0
const GRACE_PERIOD := 3.0 * 3600.0  # bots leave a new player alone this long
const MAX_RAID_DISTANCE := 42.0


static func power(bot: Dictionary) -> float:
	## A single comparable number for the UI and for target selection.
	var p := 0.0
	for id in bot["troops"]:
		var u: Dictionary = T.unit(id)
		if u.is_empty():
			continue
		p += int(bot["troops"][id]) * (float(u["atk"]) + float(u["di"]) + float(u["dc"])) / 3.0
	return p


static func defence_estimate(bot: Dictionary) -> float:
	var d := 0.0
	for id in bot["troops"]:
		var u: Dictionary = T.unit(id)
		if u.is_empty():
			continue
		d += int(bot["troops"][id]) * (float(u["di"]) + float(u["dc"])) / 2.0
	d += 10.0 + int(bot.get("residence", 0)) * int(bot.get("residence", 0)) * 2.0
	var tribe: String = bot["tribe"]
	var mult: float = T.GAUL_WALL_DEF_MULT if tribe == T.TRIBE_GAULS else 1.0
	return d * (1.0 + int(bot.get("wall", 0)) * float(T.TRIBES[tribe]["wall_factor"]) * mult)


static func player_defence_estimate(state: Dictionary, v: Dictionary) -> float:
	var d := 0.0
	for id in v["troops"]:
		var u: Dictionary = T.unit(id)
		if u.is_empty():
			continue
		d += int(v["troops"][id]) * (float(u["di"]) + float(u["dc"])) / 2.0
	var res_lvl: int = max(Sim.slot_level(v, "residence"), Sim.slot_level(v, "palace"))
	d += 10.0 + res_lvl * res_lvl * 2.0
	var tribe: String = v["tribe"]
	var wall := Sim.slot_level(v, T.wall_id_for(tribe))
	var mult: float = T.GAUL_WALL_DEF_MULT if tribe == T.TRIBE_GAULS else 1.0
	d *= (1.0 + wall * float(T.TRIBES[tribe]["wall_factor"]) * mult)
	d *= (1.0 + Sim.slot_level(v, "armoury") * 0.015)
	return d


static func _policy(bot: Dictionary) -> Dictionary:
	var default_aggr := 0.35
	match bot.get("personality", "economic"):
		"aggressive": default_aggr = 0.75
		"defensive": default_aggr = 0.15
		_: default_aggr = 0.30
	var p: Dictionary = bot.get("policy", {})
	return {
		"aggression": clampf(float(p.get("aggression", default_aggr)), 0.0, 1.0),
		"focus": String(p.get("focus", bot.get("personality", "economic"))),
	}


## One bot turn. Called from the simulation clock, so it also runs during
## offline catch-up — the world keeps moving while the app is closed.
static func take_turn(state: Dictionary, bot: Dictionary) -> void:
	var pol := _policy(bot)
	# Game speed scales what a bot achieves per tick, mirroring how it scales
	# the player's production, rather than making bots tick more often.
	var hours: float = Sim.BOT_TICK_INTERVAL / 3600.0 * float(state.get("speed", 1.0))

	# --- economy ---
	var income: float = float(bot["eco"]) * ECON_PER_ECO_HOUR * hours
	for r in range(4):
		bot["res"][r] = float(bot["res"][r]) + income

	# --- spending ---
	_spend(state, bot, pol)

	# --- aggression ---
	_maybe_attack(state, bot, pol)


static func _spend(state: Dictionary, bot: Dictionary, pol: Dictionary) -> void:
	var focus: String = pol["focus"]
	var res: Array = bot["res"]
	var pool := T.res_sum(res)

	# Everyone keeps growing their economy; economists grow it harder.
	var eco_share := 0.45
	if focus == "economic":
		eco_share = 0.70
	elif focus == "aggressive":
		eco_share = 0.30

	if pool > ECO_UPGRADE_COST * 1.2 and Sim.rand_unit(state) < eco_share:
		for r in range(4):
			bot["res"][r] = max(0.0, float(bot["res"][r]) - ECO_UPGRADE_COST / 4.0)
		bot["eco"] = float(bot["eco"]) + 0.35
		bot["pop"] = int(bot["pop"]) + Sim.rand_int(state, 2, 6)
		# Infrastructure creeps up alongside the economy.
		if Sim.rand_unit(state) < 0.35:
			bot["cranny"] = min(20, int(bot["cranny"]) + 1)
		if Sim.rand_unit(state) < 0.25:
			bot["smithy"] = min(20, int(bot["smithy"]) + 1)
		return

	if focus == "defensive" and Sim.rand_unit(state) < 0.35:
		if pool > 1200.0:
			for r in range(4):
				bot["res"][r] = max(0.0, float(bot["res"][r]) - 300.0)
			bot["wall"] = min(20, int(bot["wall"]) + 1)
			bot["armoury"] = min(20, int(bot["armoury"]) + 1)
			return

	_train(state, bot, focus)


static func _train(state: Dictionary, bot: Dictionary, focus: String) -> void:
	var tribe: String = bot["tribe"]
	var pool: Array = []
	for id in T.units_from_building(tribe, "barracks"):
		pool.append(id)
	# Cavalry unlocks once the bot's economy is developed enough.
	if float(bot["eco"]) > 6.0:
		for id in T.units_from_building(tribe, "stable"):
			pool.append(id)

	var best := ""
	var best_score := -1.0
	for id in pool:
		var u: Dictionary = T.unit(id)
		if u["kind"] == "scout" or u["kind"] == "settler" or u["kind"] == "admin":
			continue
		if not T.res_covers(bot["res"], u["cost"]):
			continue
		var score := 0.0
		if focus == "aggressive":
			score = float(u["atk"])
		elif focus == "defensive":
			score = (float(u["di"]) + float(u["dc"])) * 0.5
		else:
			score = (float(u["atk"]) + float(u["di"]) + float(u["dc"])) / 3.0
		score /= max(1.0, T.res_sum(u["cost"]) / 250.0)
		if score > best_score:
			best_score = score
			best = id

	if best == "":
		return
	var u: Dictionary = T.unit(best)
	# Spend up to a third of the treasury in one go.
	var affordable := 999
	for r in range(4):
		if float(u["cost"][r]) > 0.0:
			affordable = min(affordable, int(float(bot["res"][r]) / 3.0 / float(u["cost"][r])))
	var count: int = clampi(affordable, 0, 60)
	if count <= 0:
		return
	for r in range(4):
		bot["res"][r] = max(0.0, float(bot["res"][r]) - float(u["cost"][r]) * count)
	Sim.troops_add(bot["troops"], {best: count})


static func _maybe_attack(state: Dictionary, bot: Dictionary, pol: Dictionary) -> void:
	if float(state["t"]) < GRACE_PERIOD:
		return
	var aggression: float = pol["aggression"] + float(bot.get("anger", 0.0))
	if Sim.rand_unit(state) > aggression * 0.30:
		return
	if Sim.troops_count(bot["troops"]) < 10:
		return

	# Pick the nearest player village within reach.
	var target: Dictionary = {}
	var best_dist := MAX_RAID_DISTANCE
	for v in state["villages"]:
		var d := Sim.distance(float(bot["x"]), float(bot["y"]), float(v["x"]), float(v["y"]))
		if d < best_dist:
			best_dist = d
			target = v
	if target.is_empty():
		return

	# Size the raid against what the player can actually field, so an early
	# game is survivable and a neglected one is punished.
	var player_def := player_defence_estimate(state, target)
	var wanted_power: float = player_def * Sim.rand_range(state, 0.5, 1.35)

	var send := {}
	var sent_power := 0.0
	var ids: Array = bot["troops"].keys()
	ids.sort()
	for id in ids:
		var u: Dictionary = T.unit(id)
		if u.is_empty() or float(u["atk"]) <= 0.0:
			continue
		var have: int = int(bot["troops"][id])
		if have <= 0:
			continue
		var per_unit: float = float(u["atk"])
		var need: int = int(max(0.0, (wanted_power - sent_power) / max(per_unit, 1.0)))
		var take: int = clampi(need, 0, have)
		if take <= 0:
			continue
		send[id] = take
		sent_power += take * per_unit
		if sent_power >= wanted_power:
			break

	if Sim.troops_count(send) < 5:
		return
	if not Sim.troops_remove(bot["troops"], send):
		return

	var kind := "raid" if Sim.rand_unit(state) < 0.75 else "attack"
	var travel := Sim.travel_time(state, send, float(bot["x"]), float(bot["y"]),
			float(target["x"]), float(target["y"]), 0.0)
	state["movements"].append({
		"id": int(state["next_id"]),
		"kind": kind,
		"owner": "bot:%d" % int(bot["id"]),
		"owner_name": bot["name"],
		"bot_id": int(bot["id"]),
		"tribe": bot["tribe"],
		"from_v": -1,
		"from_x": int(bot["x"]),
		"from_y": int(bot["y"]),
		"to_kind": "village",
		"to_id": int(target["id"]),
		"to_x": int(target["x"]),
		"to_y": int(target["y"]),
		"troops": send,
		"hero": false,
		"smithy": int(bot.get("smithy", 0)),
		"depart": float(state["t"]),
		"arrive": float(state["t"]) + travel,
		"returning": false,
		"loot": T.res_zero(),
	})
	state["next_id"] = int(state["next_id"]) + 1
	bot["anger"] = max(0.0, float(bot.get("anger", 0.0)) - 0.2)

	# The player gets advance warning if they built a watchtower.
	if Sim.slot_level(target, "watchtower") > 0:
		Sim.add_report(state, {
			"type": "incoming",
			"title": "Дозор: приближается враг",
			"text": "%s ведёт войска на %s. Прибытие через %s." % [
				bot["name"], target["name"], _fmt_eta(travel)],
		})


static func _fmt_eta(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


## Short public summary of a rival, used by the map panel and the LLM prompt.
static func describe(bot: Dictionary) -> String:
	var personality_label := {
		"aggressive": "агрессор",
		"economic": "экономист",
		"defensive": "оборонщик",
	}.get(bot.get("personality", "economic"), "вождь")
	return "%s (%s, %s) — армия %d, стена %d" % [
		bot["name"], T.TRIBES[bot["tribe"]]["label"], personality_label,
		Sim.troops_count(bot["troops"]), int(bot.get("wall", 0))]
