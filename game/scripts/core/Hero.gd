extends RefCounted

## The player's single hero: levels, attribute points, equipment and wounds.

const T := preload("res://game/scripts/core/Tables.gd")

## A hero marching with the army lifts the whole force.
const BASE_ARMY_BONUS := 0.20
const REVIVE_SECONDS := 3600.0


static func new_hero() -> Dictionary:
	return {
		"level": 1,
		"xp": 0.0,
		"points": 0,
		"str": 0,          # attack
		"def": 0,          # defence
		"loot": 0,         # plunder bonus
		"speed": 0,        # march speed
		"equip": {},       # slot -> item id
		"inventory": [],   # item ids
		"away": false,     # currently marching
		"wounded_until": 0.0,
	}


static func is_available(state: Dictionary) -> bool:
	var h: Dictionary = state["hero"]
	if bool(h.get("away", false)):
		return false
	return float(h.get("wounded_until", 0.0)) <= float(state["t"])


static func status_text(state: Dictionary) -> String:
	var h: Dictionary = state["hero"]
	if bool(h.get("away", false)):
		return "В походе"
	var w := float(h.get("wounded_until", 0.0))
	if w > float(state["t"]):
		return "Ранен, в лазарете"
	return "В деревне"


static func _equip_sum(h: Dictionary, key: String) -> float:
	var total := 0.0
	for slot in h["equip"]:
		var item_id: String = h["equip"][slot]
		var it: Dictionary = T.HERO_ITEMS.get(item_id, {})
		total += float(it.get(key, 0.0))
	return total


static func multipliers(state: Dictionary) -> Dictionary:
	var h: Dictionary = state["hero"]
	return {
		"atk": 1.0 + BASE_ARMY_BONUS + int(h["str"]) * 0.005 + _equip_sum(h, "atk"),
		"def": 1.0 + BASE_ARMY_BONUS + int(h["def"]) * 0.005 + _equip_sum(h, "def"),
		"loot": int(h["loot"]) * 0.01 + _equip_sum(h, "loot"),
		"speed": int(h["speed"]) * 0.01 + _equip_sum(h, "speed"),
	}


static func xp_for_next(h: Dictionary) -> float:
	return float(int(h["level"]) * T.HERO_XP_PER_LEVEL)


static func add_xp(state: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var h: Dictionary = state["hero"]
	var bonus := 1.0
	var Sim := load("res://game/scripts/core/Sim.gd")
	for v in state["villages"]:
		if Sim.slot_level(v, "hero_mansion") > 0:
			bonus = 1.10
			break
	h["xp"] = float(h["xp"]) + amount * bonus
	var guard := 0
	while float(h["xp"]) >= xp_for_next(h) and guard < 500:
		guard += 1
		h["xp"] = float(h["xp"]) - xp_for_next(h)
		h["level"] = int(h["level"]) + 1
		h["points"] = int(h["points"]) + T.HERO_POINTS_PER_LEVEL


static func spend_point(state: Dictionary, attribute: String) -> bool:
	var h: Dictionary = state["hero"]
	if int(h["points"]) <= 0:
		return false
	if not ["str", "def", "loot", "speed"].has(attribute):
		return false
	h[attribute] = int(h[attribute]) + 1
	h["points"] = int(h["points"]) - 1
	return true


static func add_item(state: Dictionary, item_id: String) -> void:
	if item_id == "" or not T.HERO_ITEMS.has(item_id):
		return
	state["hero"]["inventory"].append(item_id)


static func equip(state: Dictionary, item_id: String) -> bool:
	var h: Dictionary = state["hero"]
	if not T.HERO_ITEMS.has(item_id):
		return false
	var idx: int = h["inventory"].find(item_id)
	if idx < 0:
		return false
	var slot: String = T.HERO_ITEMS[item_id]["slot"]
	# Anything already in that slot goes back to the bag.
	if h["equip"].has(slot):
		h["inventory"].append(h["equip"][slot])
	h["inventory"].remove_at(idx)
	h["equip"][slot] = item_id
	return true


static func unequip(state: Dictionary, slot: String) -> bool:
	var h: Dictionary = state["hero"]
	if not h["equip"].has(slot):
		return false
	h["inventory"].append(h["equip"][slot])
	h["equip"].erase(slot)
	return true


static func wound(state: Dictionary) -> void:
	var h: Dictionary = state["hero"]
	h["away"] = false
	h["wounded_until"] = float(state["t"]) + REVIVE_SECONDS
