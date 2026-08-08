extends RefCounted

## The world simulation.
##
## Everything is driven by one function: `advance_to(state, t)`. It walks the
## world forward event by event — build completions, troop training, army
## arrivals, bot turns, starvation — accruing resources linearly between
## events, where production is by definition constant.
##
## Because live play and offline catch-up both go through `advance_to`, eight
## hours spent playing and eight hours spent with the app closed produce
## exactly the same world. There is no second, divergent "offline" code path.
##
## State is a plain Dictionary/Array/float/String tree so it round-trips
## through JSON with no serialisation layer and no type surprises.

const T := preload("res://game/scripts/core/Tables.gd")
const Combat := preload("res://game/scripts/core/Combat.gd")

const SAVE_VERSION := 1
const MAX_REPORTS := 200
const MAX_OFFLINE_HOURS := 72.0
const STARVE_KILL_INTERVAL := 600.0     # a unit dies every 10 game-minutes of famine
const BOT_TICK_INTERVAL := 1800.0       # bots take a turn every 30 game-minutes
const CAMP_RESPAWN := 8.0 * 3600.0
const MAX_EVENTS_PER_ADVANCE := 40000

# ---------------------------------------------------------------------------
# Deterministic RNG (seeded, JSON-safe, survives save/load)
# ---------------------------------------------------------------------------

static func rand_unit(state: Dictionary) -> float:
	var s := int(state.get("rng", 12345))
	s = (s * 1103515245 + 12345) & 0x7FFFFFFF
	state["rng"] = s
	return float(s) / 2147483647.0


static func rand_range(state: Dictionary, lo: float, hi: float) -> float:
	return lo + (hi - lo) * rand_unit(state)


static func rand_int(state: Dictionary, lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + int(rand_unit(state) * (hi - lo + 1)) % (hi - lo + 1)


static func rand_pick(state: Dictionary, arr: Array):
	if arr.is_empty():
		return null
	return arr[rand_int(state, 0, arr.size() - 1)]

# ---------------------------------------------------------------------------
# Village queries — always derived, never stored, so they cannot desync
# ---------------------------------------------------------------------------

static func slot_level(v: Dictionary, building_id: String) -> int:
	var best := 0
	for s in v["slots"]:
		if s["id"] == building_id and int(s["lvl"]) > best:
			best = int(s["lvl"])
	return best


static func has_building(v: Dictionary, building_id: String) -> bool:
	return slot_level(v, building_id) > 0


static func storage(v: Dictionary) -> Array:
	## [warehouse capacity, granary capacity]
	var wh := 800.0
	var gr := 800.0
	for s in v["slots"]:
		var lvl := int(s["lvl"])
		if lvl <= 0:
			continue
		if s["id"] == "warehouse":
			wh += T.storage_capacity(lvl) - 800.0
		elif s["id"] == "granary":
			gr += T.storage_capacity(lvl) - 800.0
	return [max(800.0, wh), max(800.0, gr)]


static func capacity_for(v: Dictionary, r: int) -> float:
	var st := storage(v)
	return st[1] if r == T.CR else st[0]


static func cranny_capacity(v: Dictionary) -> float:
	var factor: float = T.TRIBES[v["tribe"]]["cranny_factor"]
	var total := 0.0
	for s in v["slots"]:
		if s["id"] == "cranny" and int(s["lvl"]) > 0:
			total += T.cranny_capacity(int(s["lvl"]), factor)
	return total


static func oasis_bonus(state: Dictionary, v: Dictionary) -> Array:
	## Per-resource multiplier contributed by annexed oases.
	var out := [0.0, 0.0, 0.0, 0.0]
	for o in state["oases"]:
		if int(o.get("owner", -1)) == int(v["id"]):
			out[int(o["res"])] += float(o["pct"])
	return out


static func production(state: Dictionary, v: Dictionary) -> Array:
	## Gross hourly output of the four resources, before crop upkeep.
	var out := T.res_zero()
	for i in range(18):
		var res: int = T.FIELD_LAYOUT[i]["res"]
		out[res] += T.field_production(res, int(v["fields"][i]))

	# Bonus buildings: percentage of the raw field output.
	var bonus := [0.0, 0.0, 0.0, 0.0]
	for s in v["slots"]:
		var lvl := int(s["lvl"])
		if lvl <= 0:
			continue
		var b: Dictionary = T.building(s["id"])
		if b.has("bonus_res"):
			bonus[int(b["bonus_res"])] += lvl * float(b["bonus_per_level"])

	var oas := oasis_bonus(state, v)
	for r in range(4):
		out[r] = out[r] * (1.0 + bonus[r] + oas[r])
	return out


static func population(v: Dictionary) -> int:
	var pop := 0
	for i in range(18):
		pop += T.field_pop_total(int(v["fields"][i]))
	for s in v["slots"]:
		if int(s["lvl"]) > 0:
			pop += T.building_pop(s["id"], int(s["lvl"]))
	return pop


static func troop_upkeep(v: Dictionary) -> int:
	var eat := 0
	for id in v["troops"]:
		var u: Dictionary = T.unit(id)
		if not u.is_empty():
			eat += int(v["troops"][id]) * int(u["eat"])
	# Troops currently marching still eat from their home village.
	return eat


static func marching_upkeep(state: Dictionary, village_id: int) -> int:
	var eat := 0
	for m in state["movements"]:
		if m.get("owner", "") != "player":
			continue
		if int(m.get("from_v", -1)) != village_id:
			continue
		for id in m["troops"]:
			var u: Dictionary = T.unit(id)
			if not u.is_empty():
				eat += int(m["troops"][id]) * int(u["eat"])
	return eat


static func crop_net(state: Dictionary, v: Dictionary) -> float:
	var prod := production(state, v)
	return prod[T.CR] - population(v) - troop_upkeep(v) - marching_upkeep(state, int(v["id"]))


static func culture_rate(v: Dictionary) -> float:
	var cp := 0.0
	for s in v["slots"]:
		if int(s["lvl"]) > 0:
			cp += T.building_cp(s["id"], int(s["lvl"]))
	return cp


static func total_culture(state: Dictionary) -> float:
	var cp := 0.0
	for v in state["villages"]:
		cp += float(v["cp"])
	return cp


static func expansion_slots(state: Dictionary) -> int:
	var total := 0
	for v in state["villages"]:
		var res := slot_level(v, "residence")
		var pal := slot_level(v, "palace")
		if res >= 10:
			total += 1
		if res >= 20:
			total += 1
		if pal >= 10:
			total += 1
		if pal >= 15:
			total += 1
		if pal >= 20:
			total += 1
	# Every village beyond the first consumed one slot.
	return total - (state["villages"].size() - 1)


static func merchants_total(v: Dictionary) -> int:
	return T.merchants_for_level(slot_level(v, "marketplace"))


static func merchants_busy(state: Dictionary, village_id: int) -> int:
	var n := 0
	for tr in state["trades"]:
		if int(tr["from_v"]) == village_id:
			n += int(tr["count"])
	return n


static func find_village(state: Dictionary, id: int) -> Dictionary:
	for v in state["villages"]:
		if int(v["id"]) == id:
			return v
	return {}


static func find_bot(state: Dictionary, id: int) -> Dictionary:
	for b in state["bots"]:
		if int(b["id"]) == id:
			return b
	return {}


static func find_camp(state: Dictionary, id: int) -> Dictionary:
	for c in state["camps"]:
		if int(c["id"]) == id:
			return c
	return {}


static func find_oasis(state: Dictionary, id: int) -> Dictionary:
	for o in state["oases"]:
		if int(o["id"]) == id:
			return o
	return {}

# ---------------------------------------------------------------------------
# Troop bookkeeping helpers
# ---------------------------------------------------------------------------

static func troops_add(dst: Dictionary, src: Dictionary) -> void:
	for id in src:
		var n := int(src[id])
		if n <= 0:
			continue
		dst[id] = int(dst.get(id, 0)) + n


static func troops_remove(dst: Dictionary, src: Dictionary) -> bool:
	for id in src:
		if int(dst.get(id, 0)) < int(src[id]):
			return false
	for id in src:
		var left := int(dst.get(id, 0)) - int(src[id])
		if left > 0:
			dst[id] = left
		else:
			dst.erase(id)
	return true


static func troops_count(troops: Dictionary) -> int:
	var n := 0
	for id in troops:
		n += int(troops[id])
	return n


static func slowest_speed(troops: Dictionary) -> float:
	var spd := 999.0
	var any := false
	for id in troops:
		if int(troops[id]) <= 0:
			continue
		var u: Dictionary = T.unit(id)
		if u.is_empty():
			continue
		any = true
		spd = min(spd, float(u["spd"]))
	return spd if any else 6.0


static func distance(ax: float, ay: float, bx: float, by: float) -> float:
	return sqrt(pow(ax - bx, 2.0) + pow(ay - by, 2.0))


static func travel_time(state: Dictionary, troops: Dictionary, ax: float, ay: float,
		bx: float, by: float, hero_speed_bonus: float) -> float:
	var dist := distance(ax, ay, bx, by)
	var spd := slowest_speed(troops) * (1.0 + hero_speed_bonus)
	var speed_mult: float = float(state.get("speed", 1.0))
	return max(30.0, dist / max(spd, 0.1) * 3600.0 / speed_mult)

# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

static func add_report(state: Dictionary, rep: Dictionary) -> void:
	rep["t"] = state["t"]
	rep["read"] = false
	rep["id"] = int(state.get("next_id", 1))
	state["next_id"] = int(state.get("next_id", 1)) + 1
	state["reports"].push_front(rep)
	while state["reports"].size() > MAX_REPORTS:
		state["reports"].pop_back()


static func unread_reports(state: Dictionary) -> int:
	var n := 0
	for r in state["reports"]:
		if not bool(r.get("read", false)):
			n += 1
	return n

# ---------------------------------------------------------------------------
# The clock
# ---------------------------------------------------------------------------

static func _next_event_time(state: Dictionary, t_limit: float) -> float:
	var best := t_limit

	for v in state["villages"]:
		for item in v["build_queue"]:
			best = min(best, float(item["done"]))
		for item in v["train_queue"]:
			best = min(best, float(item["done"]))
		var starve := float(v.get("starve_at", -1.0))
		if starve > 0.0:
			best = min(best, starve)

	for m in state["movements"]:
		best = min(best, float(m["arrive"]))

	for tr in state["trades"]:
		best = min(best, float(tr["arrive"]))

	for b in state["bots"]:
		best = min(best, float(b["next_tick"]))

	for c in state["camps"]:
		if not bool(c["alive"]):
			best = min(best, float(c["respawn_at"]))

	return max(best, float(state["t"]))


## Linear accrual between events. Production is constant across an interval by
## construction, so this is exact rather than an approximation.
static func _accrue(state: Dictionary, dt: float) -> void:
	if dt <= 0.0:
		return
	var hours := dt / 3600.0
	var speed: float = float(state.get("speed", 1.0))
	for v in state["villages"]:
		var prod := production(state, v)
		var upkeep := float(population(v) + troop_upkeep(v) + marching_upkeep(state, int(v["id"])))
		for r in range(4):
			var rate: float = prod[r]
			if r == T.CR:
				rate -= upkeep
			var cap := capacity_for(v, r)
			var val: float = float(v["res"][r]) + rate * hours * speed
			v["res"][r] = clampf(val, 0.0, cap)
		v["cp"] = float(v["cp"]) + culture_rate(v) * hours * speed
		_schedule_starvation(state, v)


## If a village is running a crop deficit, work out when the granary empties so
## the famine becomes a scheduled event rather than a surprise.
static func _schedule_starvation(state: Dictionary, v: Dictionary) -> void:
	var net := crop_net(state, v)
	if net >= 0.0:
		v["starve_at"] = -1.0
		return
	var speed: float = float(state.get("speed", 1.0))
	var stock: float = float(v["res"][T.CR])
	if stock <= 0.5:
		v["starve_at"] = float(state["t"]) + STARVE_KILL_INTERVAL
		return
	var hours_left := stock / (-net * speed)
	v["starve_at"] = float(state["t"]) + hours_left * 3600.0


static func _starve(state: Dictionary, v: Dictionary) -> void:
	## Kill the cheapest-to-replace troops until the village feeds itself again.
	var killed := {}
	var guard := 0
	while crop_net(state, v) < 0.0 and troops_count(v["troops"]) > 0 and guard < 500:
		guard += 1
		var victim := ""
		var worst := -1.0
		for id in v["troops"]:
			if int(v["troops"][id]) <= 0:
				continue
			var u: Dictionary = T.unit(id)
			if u.is_empty():
				continue
			# Prefer eating a lot while costing little.
			var score: float = float(u["eat"]) / max(1.0, T.res_sum(u["cost"]) / 1000.0)
			if score > worst:
				worst = score
				victim = id
		if victim == "":
			break
		v["troops"][victim] = int(v["troops"][victim]) - 1
		killed[victim] = int(killed.get(victim, 0)) + 1
		if int(v["troops"][victim]) <= 0:
			v["troops"].erase(victim)
	if not killed.is_empty():
		add_report(state, {
			"type": "famine",
			"village": v["name"],
			"title": "Голод в %s" % v["name"],
			"troops": killed,
			"text": "Зерно кончилось. Погибло войск: %d." % troops_count(killed),
		})
	_schedule_starvation(state, v)


static func _fire_events(state: Dictionary, t: float) -> void:
	const EPS := 0.001

	for v in state["villages"]:
		# --- construction ---
		var bq: Array = v["build_queue"]
		for i in range(bq.size() - 1, -1, -1):
			if float(bq[i]["done"]) <= t + EPS:
				_finish_build(state, v, bq[i])
				bq.remove_at(i)
		# --- training ---
		var tq: Array = v["train_queue"]
		for i in range(tq.size() - 1, -1, -1):
			var item: Dictionary = tq[i]
			var guard := 0
			while float(item["done"]) <= t + EPS and int(item["left"]) > 0 and guard < 5000:
				guard += 1
				item["left"] = int(item["left"]) - 1
				troops_add(v["troops"], {item["unit"]: 1})
				if int(item["left"]) > 0:
					item["done"] = float(item["done"]) + float(item["each"])
				else:
					break
			if int(item["left"]) <= 0:
				add_report(state, {
					"type": "training",
					"village": v["name"],
					"title": "Обучение завершено",
					"troops": {item["unit"]: int(item["total"])},
					"text": "В %s готовы войска." % v["name"],
				})
				tq.remove_at(i)
		# --- famine ---
		var starve := float(v.get("starve_at", -1.0))
		if starve > 0.0 and starve <= t + EPS:
			_starve(state, v)

	# --- armies ---
	var mv: Array = state["movements"]
	for i in range(mv.size() - 1, -1, -1):
		var m: Dictionary = mv[i]
		if float(m["arrive"]) > t + EPS:
			continue
		if bool(m.get("returning", false)):
			_finish_return(state, m)
			mv.remove_at(i)
		else:
			_resolve_arrival(state, m, i)

	# --- merchants ---
	var trs: Array = state["trades"]
	for i in range(trs.size() - 1, -1, -1):
		var tr: Dictionary = trs[i]
		if float(tr["arrive"]) > t + EPS:
			continue
		if bool(tr.get("returning", false)):
			trs.remove_at(i)
		else:
			var dst := find_village(state, int(tr["to_v"]))
			if not dst.is_empty():
				for r in range(4):
					var cap := capacity_for(dst, r)
					dst["res"][r] = min(cap, float(dst["res"][r]) + float(tr["res"][r]))
				add_report(state, {
					"type": "trade",
					"title": "Товар доставлен",
					"village": dst["name"],
					"res": tr["res"].duplicate(),
					"text": "Караван прибыл в %s." % dst["name"],
				})
			tr["returning"] = true
			tr["arrive"] = t + (float(tr["arrive"]) - float(tr["depart"]))

	# --- robber camps respawning ---
	for c in state["camps"]:
		if not bool(c["alive"]) and float(c["respawn_at"]) <= t + EPS:
			c["alive"] = true
			c["troops"] = _camp_troops(state, int(c["level"]))

	# --- AI opponents ---
	# The tick rate is fixed in game time; game speed scales what a bot gets
	# done per tick instead. Ticking faster would make a 72h catch-up on a 10x
	# world walk hundreds of thousands of events for no extra fidelity.
	var bots_due := false
	for b in state["bots"]:
		if float(b["next_tick"]) <= t + EPS:
			bots_due = true
			break
	if bots_due:
		var Bots := load("res://game/scripts/core/Bots.gd")
		for b in state["bots"]:
			if float(b["next_tick"]) <= t + EPS:
				Bots.take_turn(state, b)
				b["next_tick"] = t + BOT_TICK_INTERVAL


## Advance the world to `t_target` (unix seconds, UTC).
static func advance_to(state: Dictionary, t_target: float) -> void:
	var guard := 0
	while float(state["t"]) < t_target and guard < MAX_EVENTS_PER_ADVANCE:
		guard += 1
		var t_next := _next_event_time(state, t_target)
		_accrue(state, t_next - float(state["t"]))
		state["t"] = t_next
		if t_next >= t_target:
			break
		_fire_events(state, t_next)
	state["t"] = max(float(state["t"]), t_target)


## Catch up after the app was closed. Clamped so that moving the phone clock
## forward cannot mint resources, and moving it backwards cannot corrupt state.
static func catch_up(state: Dictionary, now_unix: float) -> float:
	var last := float(state["t"])
	var delta := now_unix - last
	if delta < 0.0:
		# Clock moved backwards: hold the world still, keep the newer timestamp.
		state["t"] = now_unix
		return 0.0
	var capped: float = min(delta, MAX_OFFLINE_HOURS * 3600.0)
	advance_to(state, last + capped)
	state["t"] = now_unix
	return capped

# ---------------------------------------------------------------------------
# Build / train completion
# ---------------------------------------------------------------------------

static func _finish_build(state: Dictionary, v: Dictionary, item: Dictionary) -> void:
	if item["kind"] == "field":
		var idx := int(item["index"])
		v["fields"][idx] = int(item["level"])
		add_report(state, {
			"type": "build",
			"village": v["name"],
			"title": "Поле улучшено",
			"text": "%s: поле %s достигло %d ур." % [
				v["name"], T.RES_LABELS[int(T.FIELD_LAYOUT[idx]["res"])], int(item["level"])],
		})
	else:
		var slot: Dictionary = v["slots"][int(item["index"])]
		slot["id"] = item["id"]
		slot["lvl"] = int(item["level"])
		add_report(state, {
			"type": "build",
			"village": v["name"],
			"title": "Строительство завершено",
			"text": "%s: %s — %d ур." % [
				v["name"], T.building(item["id"]).get("label", item["id"]), int(item["level"])],
		})
	_schedule_starvation(state, v)

# ---------------------------------------------------------------------------
# Combat arrival
# ---------------------------------------------------------------------------

static func _hero_multipliers(state: Dictionary, with_hero: bool) -> Dictionary:
	if not with_hero:
		return {"atk": 1.0, "def": 1.0, "loot": 0.0, "speed": 0.0}
	var Hero := load("res://game/scripts/core/Hero.gd")
	return Hero.multipliers(state)


static func _defender_params(state: Dictionary, defender: Dictionary, is_village: bool) -> Dictionary:
	if not is_village:
		return {"armoury": 0, "wall_level": 0, "wall_factor": 0.0, "wall_mult": 1.0, "residence": 0}
	var tribe: String = defender["tribe"]
	var wall_id: String = T.wall_id_for(tribe)
	var mult := T.GAUL_WALL_DEF_MULT if tribe == T.TRIBE_GAULS else 1.0
	return {
		"armoury": slot_level(defender, "armoury"),
		"wall_level": slot_level(defender, wall_id),
		"wall_factor": float(T.TRIBES[tribe]["wall_factor"]),
		"wall_mult": mult,
		"residence": max(slot_level(defender, "residence"), slot_level(defender, "palace")),
	}


static func _resolve_arrival(state: Dictionary, m: Dictionary, index: int) -> void:
	var is_player: bool = m.get("owner", "player") == "player"
	var kind: String = m["kind"]

	if kind == "settle":
		_resolve_settle(state, m, index)
		return

	if kind == "reinforce":
		var dst := find_village(state, int(m["to_id"]))
		if not dst.is_empty():
			troops_add(dst["troops"], m["troops"])
			add_report(state, {
				"type": "reinforce", "village": dst["name"],
				"title": "Подкрепление прибыло",
				"troops": m["troops"].duplicate(),
				"text": "Войска усилили %s." % dst["name"],
			})
		state["movements"].remove_at(index)
		return

	# Work out who is defending.
	var target_kind: String = m["to_kind"]
	var defenders := {}
	var def_params := {}
	var stock := T.res_zero()
	var cranny := 0.0
	var defender_name := "неизвестно"
	var defender_ref: Dictionary = {}

	match target_kind:
		"camp":
			defender_ref = find_camp(state, int(m["to_id"]))
			if defender_ref.is_empty() or not bool(defender_ref["alive"]):
				_bounce_home(state, m, "Лагерь уже разорён.")
				return
			defenders = defender_ref["troops"]
			def_params = _defender_params(state, {}, false)
			stock = defender_ref["reward"].duplicate()
			defender_name = "Лагерь разбойников ур.%d" % int(defender_ref["level"])
		"oasis":
			defender_ref = find_oasis(state, int(m["to_id"]))
			if defender_ref.is_empty():
				_bounce_home(state, m, "Оазис не найден.")
				return
			defenders = defender_ref["troops"]
			def_params = _defender_params(state, {}, false)
			stock = [200.0, 200.0, 200.0, 200.0]
			defender_name = "Оазис"
		"bot":
			defender_ref = find_bot(state, int(m["to_id"]))
			if defender_ref.is_empty():
				_bounce_home(state, m, "Деревня исчезла.")
				return
			defenders = defender_ref["troops"]
			def_params = {
				"armoury": int(defender_ref.get("armoury", 0)),
				"wall_level": int(defender_ref.get("wall", 0)),
				"wall_factor": float(T.TRIBES[defender_ref["tribe"]]["wall_factor"]),
				"wall_mult": T.GAUL_WALL_DEF_MULT if defender_ref["tribe"] == T.TRIBE_GAULS else 1.0,
				"residence": int(defender_ref.get("residence", 0)),
			}
			stock = defender_ref["res"].duplicate()
			cranny = T.cranny_capacity(int(defender_ref.get("cranny", 0)),
					float(T.TRIBES[defender_ref["tribe"]]["cranny_factor"]))
			defender_name = defender_ref["name"]
		"village":
			defender_ref = find_village(state, int(m["to_id"]))
			if defender_ref.is_empty():
				_bounce_home(state, m, "Деревня не найдена.")
				return
			defenders = defender_ref["troops"]
			def_params = _defender_params(state, defender_ref, true)
			stock = defender_ref["res"].duplicate()
			cranny = cranny_capacity(defender_ref)
			defender_name = defender_ref["name"]
		_:
			_bounce_home(state, m, "Цель недостижима.")
			return

	var attacker_tribe: String = m.get("tribe", state["player"]["tribe"])
	var hero := _hero_multipliers(state, bool(m.get("hero", false)))
	var params := {
		"attack_type": kind,
		"smithy": int(m.get("smithy", 0)),
		"hero_atk_mult": hero["atk"],
		"hero_def_mult": 1.0,
		"roll": rand_range(state, 0.9, 1.1),
	}
	params.merge(def_params, true)

	var result := Combat.resolve(m["troops"], defenders, params)

	# Loot
	var loot := T.res_zero()
	if result["attacker_won"] and kind != "scout":
		var ignores: bool = bool(T.TRIBES[attacker_tribe]["ignores_cranny"])
		var cap: float = float(result["carry"]) * (1.0 + hero["loot"]
				+ float(T.TRIBES[attacker_tribe]["raid_bonus"]))
		loot = Combat.split_loot(stock, cranny, cap, ignores)

	# Apply consequences to the defender
	var xp := 0
	var item_found := ""
	match target_kind:
		"camp":
			if result["attacker_won"]:
				defender_ref["alive"] = false
				defender_ref["respawn_at"] = float(state["t"]) + CAMP_RESPAWN
				defender_ref["troops"] = {}
				xp = int(defender_ref["xp"])
				# The reward is still bounded by what the survivors can carry.
				var camp_cap: float = float(result["carry"]) * (1.0 + hero["loot"]
						+ float(T.TRIBES[attacker_tribe]["raid_bonus"]))
				loot = Combat.split_loot(defender_ref["reward"], 0.0, camp_cap, true)
				item_found = String(defender_ref.get("item", ""))
			else:
				defender_ref["troops"] = result["def_survivors"]
		"oasis":
			defender_ref["troops"] = result["def_survivors"]
			if result["attacker_won"] and troops_count(result["def_survivors"]) == 0:
				xp = 60
		"bot":
			defender_ref["troops"] = result["def_survivors"]
			for r in range(4):
				defender_ref["res"][r] = max(0.0, float(defender_ref["res"][r]) - loot[r])
			if result["wall_damage"] > 0:
				defender_ref["wall"] = max(0, int(defender_ref["wall"]) - int(result["wall_damage"]))
			defender_ref["anger"] = float(defender_ref.get("anger", 0.0)) + (0.35 if kind == "attack" else 0.15)
			xp = int(Combat.army_size(result["def_losses"]) * 2)
		"village":
			defender_ref["troops"] = result["def_survivors"]
			for r in range(4):
				defender_ref["res"][r] = max(0.0, float(defender_ref["res"][r]) - loot[r])
			_apply_siege(state, defender_ref, result)

	if is_player:
		var Hero := load("res://game/scripts/core/Hero.gd")
		if xp > 0:
			Hero.add_xp(state, xp)
		if item_found != "":
			Hero.add_item(state, item_found)
		if bool(m.get("hero", false)) and not result["attacker_won"]:
			Hero.wound(state)

	# Phrase the headline from the player's side: a bot "winning" its attack is
	# bad news for you, and must not read as a victory in your report list.
	var headline := ""
	if is_player:
		headline = ("Победа" if result["attacker_won"] else "Поражение") + " — " + defender_name
	else:
		var raider := String(m.get("owner_name", "Противник"))
		if result["attacker_won"]:
			headline = "Нас разграбил %s — %s" % [raider, defender_name]
		else:
			headline = "Отбили атаку: %s — %s" % [raider, defender_name]

	add_report(state, {
		"type": "battle",
		"title": headline,
		"attacker": "Ты" if is_player else String(m.get("owner_name", "Противник")),
		"defender": defender_name,
		"player_is_attacker": is_player,
		"won": result["attacker_won"],
		"kind": kind,
		"att_losses": result["att_losses"].duplicate(),
		"def_losses": result["def_losses"].duplicate(),
		"att_sent": m["troops"].duplicate(),
		"loot": loot.duplicate(),
		"xp": xp,
		"item": item_found,
		"wall_damage": int(result["wall_damage"]),
		"ratio": float(result["ratio"]),
		"text": "",
	})

	# Send the survivors home.
	var survivors: Dictionary = result["att_survivors"]
	if troops_count(survivors) == 0:
		state["movements"].remove_at(index)
		return
	m["troops"] = survivors
	m["loot"] = loot
	m["returning"] = true
	var leg: float = float(m["arrive"]) - float(m["depart"])
	m["depart"] = float(state["t"])
	m["arrive"] = float(state["t"]) + leg


static func _apply_siege(state: Dictionary, v: Dictionary, result: Dictionary) -> void:
	var wd := int(result["wall_damage"])
	if wd > 0:
		var wall_id := T.wall_id_for(v["tribe"])
		for s in v["slots"]:
			if s["id"] == wall_id and int(s["lvl"]) > 0:
				s["lvl"] = max(0, int(s["lvl"]) - wd)
				break
	var hits := int(result["building_hits"])
	if hits > 0:
		var candidates: Array = []
		for i in range(v["slots"].size()):
			if i == T.SLOT_MAIN:
				continue
			if int(v["slots"][i]["lvl"]) > 0:
				candidates.append(i)
		if not candidates.is_empty():
			var idx: int = rand_pick(state, candidates)
			var s: Dictionary = v["slots"][idx]
			s["lvl"] = max(0, int(s["lvl"]) - hits)
			if int(s["lvl"]) == 0:
				s["id"] = ""


static func _bounce_home(state: Dictionary, m: Dictionary, why: String) -> void:
	m["returning"] = true
	var leg: float = float(m["arrive"]) - float(m["depart"])
	m["depart"] = float(state["t"])
	m["arrive"] = float(state["t"]) + leg
	m["loot"] = T.res_zero()
	if m.get("owner", "player") == "player":
		add_report(state, {"type": "info", "title": "Поход отменён", "text": why})


static func _finish_return(state: Dictionary, m: Dictionary) -> void:
	if m.get("owner", "player") != "player":
		var b := find_bot(state, int(m.get("bot_id", -1)))
		if not b.is_empty():
			troops_add(b["troops"], m["troops"])
			for r in range(4):
				b["res"][r] = float(b["res"][r]) + float(m["loot"][r])
		return
	var v := find_village(state, int(m["from_v"]))
	if v.is_empty():
		return
	troops_add(v["troops"], m["troops"])
	var gained := T.res_zero()
	for r in range(4):
		var cap := capacity_for(v, r)
		var before: float = float(v["res"][r])
		v["res"][r] = min(cap, before + float(m["loot"][r]))
		gained[r] = float(v["res"][r]) - before
	if bool(m.get("hero", false)):
		state["hero"]["away"] = false
	_schedule_starvation(state, v)


static func _resolve_settle(state: Dictionary, m: Dictionary, index: int) -> void:
	var World := load("res://game/scripts/core/World.gd")
	var ok: bool = World.found_village(state, int(m["to_x"]), int(m["to_y"]))
	if ok:
		add_report(state, {
			"type": "settle", "title": "Основана новая деревня",
			"text": "Поселенцы обжили (%d, %d)." % [int(m["to_x"]), int(m["to_y"])],
		})
		state["movements"].remove_at(index)
	else:
		_bounce_home(state, m, "Место занято, поселенцы возвращаются.")

# ---------------------------------------------------------------------------
# Robber camp composition
# ---------------------------------------------------------------------------

static func _camp_troops(state: Dictionary, level: int) -> Dictionary:
	var out := {}
	var l: int = clampi(level, 1, 15)
	if l <= 2:
		out["rat"] = 8 * l + rand_int(state, 0, 5)
	elif l <= 4:
		out["rat"] = 10 + l
		out["spider"] = 6 * l
	elif l <= 6:
		out["spider"] = 10 + l * 2
		out["snake"] = 6 * l
	elif l <= 8:
		out["snake"] = 12 + l * 3
		out["bat"] = 5 * l
	elif l <= 10:
		out["boar"] = 10 * l
		out["wolf"] = 4 * l
	elif l <= 12:
		out["wolf"] = 12 * l
		out["bear"] = 3 * l
	elif l <= 14:
		out["bear"] = 8 * l
		out["tiger"] = 4 * l
	else:
		out["robber"] = 220
		out["robber_chief"] = 40
		out["crocodile"] = 30
		out["elephant"] = 12
	return out
