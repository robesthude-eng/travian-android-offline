extends RefCounted

## Every player command, with its validation in one place.
##
## Each `can_*` returns {"ok": bool, "reason": String, ...} so the UI can grey a
## button out AND explain why, without duplicating any rules.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const World := preload("res://game/scripts/core/World.gd")

## Buildings that may legitimately appear more than once in a village.
const REPEATABLE := ["warehouse", "granary", "cranny"]

const SETTLERS_NEEDED := 3

# ---------------------------------------------------------------------------
# Build queues
# ---------------------------------------------------------------------------

static func queue_lanes(state: Dictionary, v: Dictionary) -> Dictionary:
	var fields := 0
	var slots := 0
	for item in v["build_queue"]:
		if item["kind"] == "field":
			fields += 1
		else:
			slots += 1
	return {"fields": fields, "slots": slots}


static func _lane_free(state: Dictionary, v: Dictionary, is_field: bool) -> bool:
	var lanes := queue_lanes(state, v)
	var double: bool = bool(T.TRIBES[v["tribe"]]["double_queue"])
	if double:
		return (lanes["fields"] if is_field else lanes["slots"]) < 1
	return lanes["fields"] + lanes["slots"] < 1


static func _queue_start_time(v: Dictionary, is_field: bool, double: bool) -> float:
	var latest := 0.0
	for item in v["build_queue"]:
		if double and (item["kind"] == "field") != is_field:
			continue
		latest = max(latest, float(item["done"]))
	return latest


static func can_upgrade_field(state: Dictionary, v: Dictionary, index: int) -> Dictionary:
	var level := int(v["fields"][index])
	var res: int = T.FIELD_LAYOUT[index]["res"]
	# A level already queued must be accounted for.
	for item in v["build_queue"]:
		if item["kind"] == "field" and int(item["index"]) == index:
			return {"ok": false, "reason": "Уже строится", "cost": T.res_zero(), "time": 0.0, "level": level}
	var target := level + 1
	if target > 20:
		return {"ok": false, "reason": "Максимальный уровень", "cost": T.res_zero(), "time": 0.0, "level": level}
	var cost := T.field_cost(res, target)
	var time := T.field_time(target, Sim.slot_level(v, "main"), float(state["speed"]))
	if not _lane_free(state, v, true):
		return {"ok": false, "reason": "Очередь занята", "cost": cost, "time": time, "level": target}
	if not T.res_covers(v["res"], cost):
		return {"ok": false, "reason": "Не хватает ресурсов", "cost": cost, "time": time, "level": target}
	return {"ok": true, "reason": "", "cost": cost, "time": time, "level": target}


static func upgrade_field(state: Dictionary, v: Dictionary, index: int) -> bool:
	var check := can_upgrade_field(state, v, index)
	if not check["ok"]:
		return false
	v["res"] = T.res_sub(v["res"], check["cost"])
	var double: bool = bool(T.TRIBES[v["tribe"]]["double_queue"])
	var start: float = max(float(state["t"]), _queue_start_time(v, true, double))
	v["build_queue"].append({
		"kind": "field",
		"index": index,
		"id": "field",
		"level": int(check["level"]),
		"done": start + float(check["time"]),
	})
	return true


static func building_count(v: Dictionary, id: String) -> int:
	var n := 0
	for s in v["slots"]:
		if s["id"] == id and int(s["lvl"]) > 0:
			n += 1
	return n


static func requirements_met(state: Dictionary, v: Dictionary, id: String) -> Dictionary:
	var b: Dictionary = T.building(id)
	if b.is_empty():
		return {"ok": false, "reason": "Неизвестное здание"}
	var only: String = b.get("tribe", "")
	if only != "" and only != v["tribe"]:
		return {"ok": false, "reason": "Недоступно твоему племени"}
	for req_id in b.get("needs", {}):
		var need_lvl := int(b["needs"][req_id])
		if Sim.slot_level(v, req_id) < need_lvl:
			return {"ok": false, "reason": "Нужно: %s %d ур." % [
				T.building(req_id).get("label", req_id), need_lvl]}
	if b.has("needs_field"):
		var res: int = int(b["needs_field"][0])
		var lvl := int(b["needs_field"][1])
		for i in range(18):
			if int(T.FIELD_LAYOUT[i]["res"]) == res and int(v["fields"][i]) < lvl:
				return {"ok": false, "reason": "Нужны все поля «%s» %d ур." % [
					T.RES_LABELS[res], lvl]}
	if id == "palace":
		for other in state["villages"]:
			if Sim.slot_level(other, "palace") > 0 and int(other["id"]) != int(v["id"]):
				return {"ok": false, "reason": "Дворец уже есть в другой деревне"}
	return {"ok": true, "reason": ""}


static func can_build(state: Dictionary, v: Dictionary, slot_index: int, id: String) -> Dictionary:
	var slot: Dictionary = v["slots"][slot_index]
	var current := int(slot["lvl"])
	var is_upgrade: bool = slot["id"] == id and current > 0
	var b: Dictionary = T.building(id)
	if b.is_empty():
		return {"ok": false, "reason": "Неизвестное здание", "cost": T.res_zero(), "time": 0.0, "level": 0}

	for item in v["build_queue"]:
		if item["kind"] == "slot" and int(item["index"]) == slot_index:
			return {"ok": false, "reason": "Уже строится", "cost": T.res_zero(), "time": 0.0, "level": current}

	var target := current + 1 if is_upgrade else 1
	if target > int(b["max"]):
		return {"ok": false, "reason": "Максимальный уровень", "cost": T.res_zero(), "time": 0.0, "level": current}

	if not is_upgrade:
		if slot["id"] != "" and current > 0:
			return {"ok": false, "reason": "Слот занят", "cost": T.res_zero(), "time": 0.0, "level": 0}
		if not REPEATABLE.has(id) and building_count(v, id) > 0:
			return {"ok": false, "reason": "Уже построено", "cost": T.res_zero(), "time": 0.0, "level": 0}
		var req := requirements_met(state, v, id)
		if not req["ok"]:
			return {"ok": false, "reason": req["reason"], "cost": T.res_zero(), "time": 0.0, "level": 0}

	var cost := T.building_cost(id, target)
	var time := T.building_time(id, target, Sim.slot_level(v, "main"), float(state["speed"]))
	if not _lane_free(state, v, false):
		return {"ok": false, "reason": "Очередь занята", "cost": cost, "time": time, "level": target}
	if not T.res_covers(v["res"], cost):
		return {"ok": false, "reason": "Не хватает ресурсов", "cost": cost, "time": time, "level": target}
	return {"ok": true, "reason": "", "cost": cost, "time": time, "level": target}


static func build(state: Dictionary, v: Dictionary, slot_index: int, id: String) -> bool:
	var check := can_build(state, v, slot_index, id)
	if not check["ok"]:
		return false
	v["res"] = T.res_sub(v["res"], check["cost"])
	var double: bool = bool(T.TRIBES[v["tribe"]]["double_queue"])
	var start: float = max(float(state["t"]), _queue_start_time(v, false, double))
	v["build_queue"].append({
		"kind": "slot",
		"index": slot_index,
		"id": id,
		"level": int(check["level"]),
		"done": start + float(check["time"]),
	})
	return true


## Instantly cancel a queued build and refund it.
static func cancel_build(state: Dictionary, v: Dictionary, queue_index: int) -> bool:
	if queue_index < 0 or queue_index >= v["build_queue"].size():
		return false
	var item: Dictionary = v["build_queue"][queue_index]
	var cost: Array
	if item["kind"] == "field":
		cost = T.field_cost(int(T.FIELD_LAYOUT[int(item["index"])]["res"]), int(item["level"]))
	else:
		cost = T.building_cost(item["id"], int(item["level"]))
	for r in range(4):
		var cap := Sim.capacity_for(v, r)
		v["res"][r] = min(cap, float(v["res"][r]) + cost[r])
	v["build_queue"].remove_at(queue_index)
	return true

# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------

static func can_train(state: Dictionary, v: Dictionary, unit_id: String, count: int) -> Dictionary:
	var u: Dictionary = T.unit(unit_id)
	if u.is_empty() or u["tribe"] != v["tribe"]:
		return {"ok": false, "reason": "Недоступно", "cost": T.res_zero(), "time": 0.0}
	var from: String = u["from"]
	var from_level := Sim.slot_level(v, from)
	if from_level <= 0:
		return {"ok": false, "reason": "Нужно здание: %s" % T.building(from).get("label", from),
			"cost": T.res_zero(), "time": 0.0}
	for req_id in u.get("needs", {}):
		if Sim.slot_level(v, req_id) < int(u["needs"][req_id]):
			return {"ok": false, "reason": "Нужно: %s %d ур." % [
				T.building(req_id).get("label", req_id), int(u["needs"][req_id])],
				"cost": T.res_zero(), "time": 0.0}
	if count <= 0:
		return {"ok": false, "reason": "Укажи количество", "cost": T.res_zero(), "time": 0.0}

	var cost := T.res_scale(u["cost"], count)
	var each: float = float(u["time"]) * pow(0.9, from_level - 1) / max(0.001, float(state["speed"]))
	if not T.res_covers(v["res"], cost):
		return {"ok": false, "reason": "Не хватает ресурсов", "cost": cost, "time": each * count}
	return {"ok": true, "reason": "", "cost": cost, "time": each * count, "each": each}


static func max_affordable(state: Dictionary, v: Dictionary, unit_id: String) -> int:
	var u: Dictionary = T.unit(unit_id)
	if u.is_empty():
		return 0
	var n := 9999
	for r in range(4):
		if float(u["cost"][r]) > 0.0:
			n = min(n, int(float(v["res"][r]) / float(u["cost"][r])))
	return max(0, n)


static func train(state: Dictionary, v: Dictionary, unit_id: String, count: int) -> bool:
	var check := can_train(state, v, unit_id, count)
	if not check["ok"]:
		return false
	v["res"] = T.res_sub(v["res"], check["cost"])
	var u: Dictionary = T.unit(unit_id)
	var building: String = u["from"]
	var each: float = float(check["each"])
	# Each training building has its own serial queue.
	var start := float(state["t"])
	for item in v["train_queue"]:
		if item["building"] == building:
			start = max(start, float(item["done"]) + float(item["each"]) * (int(item["left"]) - 1))
	v["train_queue"].append({
		"unit": unit_id,
		"building": building,
		"left": count,
		"total": count,
		"each": each,
		"done": start + each,
	})
	return true

# ---------------------------------------------------------------------------
# Armies
# ---------------------------------------------------------------------------

static func can_send(state: Dictionary, v: Dictionary, troops: Dictionary, kind: String,
		with_hero: bool) -> Dictionary:
	if Sim.slot_level(v, "rally_point") <= 0:
		return {"ok": false, "reason": "Нужен пункт сбора"}
	if Sim.troops_count(troops) <= 0 and not with_hero:
		return {"ok": false, "reason": "Выбери войска"}
	for id in troops:
		if int(v["troops"].get(id, 0)) < int(troops[id]):
			return {"ok": false, "reason": "Столько войск нет дома"}
	if with_hero and not Hero.is_available(state):
		return {"ok": false, "reason": "Герой недоступен"}
	if kind == "scout":
		var has_scout := false
		for id in troops:
			if T.unit(id).get("kind", "") == "scout":
				has_scout = true
		if not has_scout:
			return {"ok": false, "reason": "Для разведки нужны разведчики"}
	return {"ok": true, "reason": ""}


static func send_army(state: Dictionary, v: Dictionary, target: Dictionary, troops: Dictionary,
		kind: String, with_hero: bool) -> Dictionary:
	var check := can_send(state, v, troops, kind, with_hero)
	if not check["ok"]:
		return check
	if not Sim.troops_remove(v["troops"], troops):
		return {"ok": false, "reason": "Столько войск нет дома"}

	var hero_speed := 0.0
	if with_hero:
		hero_speed = float(Hero.multipliers(state)["speed"])
		state["hero"]["away"] = true

	var travel := Sim.travel_time(state, troops, float(v["x"]), float(v["y"]),
			float(target["x"]), float(target["y"]), hero_speed)
	state["movements"].append({
		"id": int(state["next_id"]),
		"kind": kind,
		"owner": "player",
		"owner_name": state["player"]["name"],
		"tribe": v["tribe"],
		"from_v": int(v["id"]),
		"from_x": int(v["x"]),
		"from_y": int(v["y"]),
		"to_kind": String(target["kind"]),
		"to_id": int(target.get("id", -1)),
		"to_x": int(target["x"]),
		"to_y": int(target["y"]),
		"troops": troops.duplicate(),
		"hero": with_hero,
		"smithy": Sim.slot_level(v, "smithy"),
		"depart": float(state["t"]),
		"arrive": float(state["t"]) + travel,
		"returning": false,
		"loot": T.res_zero(),
	})
	state["next_id"] = int(state["next_id"]) + 1
	Sim._schedule_starvation(state, v)
	return {"ok": true, "reason": "", "eta": travel}

# ---------------------------------------------------------------------------
# Settling
# ---------------------------------------------------------------------------

static func settler_ids(tribe: String) -> Array:
	var out: Array = []
	for id in T.UNITS:
		var u: Dictionary = T.UNITS[id]
		if u["tribe"] == tribe and u["kind"] == "settler":
			out.append(id)
	return out


static func settlers_at_home(v: Dictionary) -> int:
	var n := 0
	for id in settler_ids(v["tribe"]):
		n += int(v["troops"].get(id, 0))
	return n


static func can_settle(state: Dictionary, v: Dictionary) -> Dictionary:
	var needed := T.cp_needed(state["villages"].size())
	var have := Sim.total_culture(state)
	if have < needed:
		return {"ok": false, "reason": "Культура: %d / %d" % [int(have), needed]}
	if Sim.expansion_slots(state) <= 0:
		return {"ok": false, "reason": "Нет слота расширения — нужна Резиденция 10 или Дворец"}
	if settlers_at_home(v) < SETTLERS_NEEDED:
		return {"ok": false, "reason": "Нужно %d поселенца (есть %d)" % [
			SETTLERS_NEEDED, settlers_at_home(v)]}
	return {"ok": true, "reason": ""}


static func send_settlers(state: Dictionary, v: Dictionary, x: int, y: int) -> Dictionary:
	var check := can_settle(state, v)
	if not check["ok"]:
		return check
	if not World.tile_is_free(state, x, y):
		return {"ok": false, "reason": "Клетка занята"}

	var send := {}
	var left := SETTLERS_NEEDED
	for id in settler_ids(v["tribe"]):
		if left <= 0:
			break
		var take: int = min(left, int(v["troops"].get(id, 0)))
		if take > 0:
			send[id] = take
			left -= take
	if not Sim.troops_remove(v["troops"], send):
		return {"ok": false, "reason": "Поселенцы не найдены"}

	var travel := Sim.travel_time(state, send, float(v["x"]), float(v["y"]), float(x), float(y), 0.0)
	state["movements"].append({
		"id": int(state["next_id"]),
		"kind": "settle",
		"owner": "player",
		"owner_name": state["player"]["name"],
		"tribe": v["tribe"],
		"from_v": int(v["id"]),
		"from_x": int(v["x"]),
		"from_y": int(v["y"]),
		"to_kind": "pos",
		"to_id": -1,
		"to_x": x,
		"to_y": y,
		"troops": send,
		"hero": false,
		"smithy": 0,
		"depart": float(state["t"]),
		"arrive": float(state["t"]) + travel,
		"returning": false,
		"loot": T.res_zero(),
	})
	state["next_id"] = int(state["next_id"]) + 1
	return {"ok": true, "reason": "", "eta": travel}

# ---------------------------------------------------------------------------
# Trade
# ---------------------------------------------------------------------------

static func can_trade(state: Dictionary, from_v: Dictionary, to_id: int, res: Array) -> Dictionary:
	if Sim.slot_level(from_v, "marketplace") <= 0:
		return {"ok": false, "reason": "Нужен рынок"}
	if int(from_v["id"]) == to_id:
		return {"ok": false, "reason": "Это та же деревня"}
	if T.res_sum(res) <= 0.0:
		return {"ok": false, "reason": "Нечего отправлять"}
	if not T.res_covers(from_v["res"], res):
		return {"ok": false, "reason": "Не хватает ресурсов"}
	var carry: float = float(T.TRIBES[from_v["tribe"]]["merchant_carry"])
	carry *= 1.0 + Sim.slot_level(from_v, "trade_office") * 0.10
	var need: int = int(ceil(T.res_sum(res) / carry))
	var free: int = Sim.merchants_total(from_v) - Sim.merchants_busy(state, int(from_v["id"]))
	if need > free:
		return {"ok": false, "reason": "Нужно торговцев: %d, свободно %d" % [need, free]}
	return {"ok": true, "reason": "", "count": need}


static func send_trade(state: Dictionary, from_v: Dictionary, to_id: int, res: Array) -> Dictionary:
	var check := can_trade(state, from_v, to_id, res)
	if not check["ok"]:
		return check
	var to_v := Sim.find_village(state, to_id)
	if to_v.is_empty():
		return {"ok": false, "reason": "Деревня не найдена"}
	from_v["res"] = T.res_sub(from_v["res"], res)

	var speed: float = float(T.TRIBES[from_v["tribe"]]["merchant_speed"])
	speed *= 1.0 + Sim.slot_level(from_v, "trade_office") * 0.10
	var dist := Sim.distance(float(from_v["x"]), float(from_v["y"]), float(to_v["x"]), float(to_v["y"]))
	var travel: float = max(30.0, dist / speed * 3600.0 / float(state["speed"]))

	state["trades"].append({
		"id": int(state["next_id"]),
		"from_v": int(from_v["id"]),
		"to_v": to_id,
		"res": res.duplicate(),
		"count": int(check["count"]),
		"depart": float(state["t"]),
		"arrive": float(state["t"]) + travel,
		"returning": false,
	})
	state["next_id"] = int(state["next_id"]) + 1
	return {"ok": true, "reason": "", "eta": travel}

# ---------------------------------------------------------------------------
# Town hall festivals
# ---------------------------------------------------------------------------

static func festival_cost(big: bool) -> Array:
	if big:
		return [29700.0, 33250.0, 32000.0, 37000.0]
	return [6400.0, 6650.0, 5940.0, 8400.0]


static func can_celebrate(state: Dictionary, v: Dictionary, big: bool) -> Dictionary:
	var hall := Sim.slot_level(v, "town_hall")
	if hall <= 0:
		return {"ok": false, "reason": "Нужна ратуша"}
	if big and hall < 10:
		return {"ok": false, "reason": "Большой праздник — ратуша 10 ур."}
	var cost := festival_cost(big)
	if not T.res_covers(v["res"], cost):
		return {"ok": false, "reason": "Не хватает ресурсов"}
	return {"ok": true, "reason": "", "cost": cost}


static func celebrate(state: Dictionary, v: Dictionary, big: bool) -> bool:
	var check := can_celebrate(state, v, big)
	if not check["ok"]:
		return false
	v["res"] = T.res_sub(v["res"], check["cost"])
	v["cp"] = float(v["cp"]) + (2000.0 if big else 500.0)
	Sim.add_report(state, {
		"type": "info",
		"title": "Праздник в %s" % v["name"],
		"text": "Культура выросла на %d." % (2000 if big else 500),
	})
	return true
