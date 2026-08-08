extends RefCounted

## Pure battle resolution. No engine state, no globals, no randomness of its own —
## the caller injects `roll` so battles are reproducible and unit-testable.

const T := preload("res://game/scripts/core/Tables.gd")

## Losses follow Travian's exponent: the weaker side is wiped, the stronger side
## loses (weaker/stronger)^1.5 of its army.
const LOSS_EXPONENT := 1.5

## Raids are skirmishes: both sides take half the casualties of a real attack.
const RAID_LOSS_SCALE := 0.5


## Total attack points of an army, split into the infantry and cavalry shares
## that decide which defence value the defender gets to use.
static func attack_points(troops: Dictionary, smithy_level: int, hero_atk_mult: float) -> Dictionary:
	var inf := 0.0
	var cav := 0.0
	for id in troops:
		var n: int = int(troops[id])
		if n <= 0:
			continue
		var u: Dictionary = T.unit(id)
		if u.is_empty():
			continue
		var p := float(u["atk"]) * n
		if u["kind"] == "cav":
			cav += p
		else:
			inf += p
	var upgrade := 1.0 + smithy_level * 0.015
	inf *= upgrade * hero_atk_mult
	cav *= upgrade * hero_atk_mult
	return {"inf": inf, "cav": cav, "total": inf + cav}


## Defence points weighted by the attacker's infantry/cavalry composition.
static func defence_points(troops: Dictionary, inf_share: float, armoury_level: int,
		hero_def_mult: float) -> float:
	var cav_share := 1.0 - inf_share
	var total := 0.0
	for id in troops:
		var n: int = int(troops[id])
		if n <= 0:
			continue
		var u: Dictionary = T.unit(id)
		if u.is_empty():
			continue
		total += n * (float(u["di"]) * inf_share + float(u["dc"]) * cav_share)
	return total * (1.0 + armoury_level * 0.015) * hero_def_mult


static func count_flagged(troops: Dictionary, flag: String) -> int:
	var n := 0
	for id in troops:
		var u: Dictionary = T.unit(id)
		if not u.is_empty() and u.get(flag, false):
			n += int(troops[id])
	return n


static func carry_capacity(troops: Dictionary) -> float:
	var cap := 0.0
	for id in troops:
		var u: Dictionary = T.unit(id)
		if not u.is_empty():
			cap += int(troops[id]) * float(u["carry"])
	return cap


static func army_size(troops: Dictionary) -> int:
	var n := 0
	for id in troops:
		n += int(troops[id])
	return n


static func _apply_losses(troops: Dictionary, frac: float) -> Dictionary:
	## Returns {"survivors": {...}, "losses": {...}}. Rounds so that a fraction
	## below 1.0 can never wipe a stack that should partially survive.
	var survivors := {}
	var losses := {}
	var f := clampf(frac, 0.0, 1.0)
	for id in troops:
		var n: int = int(troops[id])
		if n <= 0:
			continue
		var lost := int(round(n * f))
		if f >= 1.0:
			lost = n
		elif lost >= n and f < 1.0:
			lost = n - 1
		lost = clampi(lost, 0, n)
		if lost > 0:
			losses[id] = lost
		if n - lost > 0:
			survivors[id] = n - lost
	return {"survivors": survivors, "losses": losses}


## Scouting is resolved separately: scouts only ever fight scouts.
static func resolve_scouting(attackers: Dictionary, defenders: Dictionary,
		wall_level: int, roll: float) -> Dictionary:
	var att_power := 0.0
	for id in attackers:
		var u: Dictionary = T.unit(id)
		if not u.is_empty() and u["kind"] == "scout":
			att_power += int(attackers[id]) * 35.0
	var def_power := 0.0
	for id in defenders:
		var u: Dictionary = T.unit(id)
		if not u.is_empty() and u["kind"] == "scout":
			def_power += int(defenders[id]) * 20.0
	def_power *= (1.0 + wall_level * 0.01)

	var success: bool = att_power * roll > def_power
	var out := {
		"kind": "scout",
		"attacker_won": success,
		"att_survivors": attackers.duplicate() if success else {},
		"att_losses": {} if success else attackers.duplicate(),
		"def_survivors": defenders.duplicate(),
		"def_losses": {},
		"wall_damage": 0,
		"building_hits": 0,
		"ratio": (att_power / def_power) if def_power > 0.0 else 999.0,
		"carry": 0.0,
	}
	return out


## Full battle.
##
## params:
##   attack_type    "raid" | "attack"
##   smithy         attacker's smithy level
##   armoury        defender's armoury level
##   wall_level     defender's wall level
##   wall_factor    per-level defence factor of the defender's tribe
##   wall_mult      extra multiplier (Gauls get 2.0)
##   residence      defender's residence/palace level (flat base defence)
##   hero_atk_mult  attacker hero multiplier (1.0 = no hero)
##   hero_def_mult  defender hero multiplier
##   roll           luck, typically 0.9..1.1
static func resolve(attackers: Dictionary, defenders: Dictionary, params: Dictionary) -> Dictionary:
	var attack_type: String = params.get("attack_type", "attack")
	if attack_type == "scout":
		return resolve_scouting(attackers, defenders,
				int(params.get("wall_level", 0)), float(params.get("roll", 1.0)))

	var smithy: int = int(params.get("smithy", 0))
	var armoury: int = int(params.get("armoury", 0))
	var wall_level: int = int(params.get("wall_level", 0))
	var wall_factor: float = float(params.get("wall_factor", 0.03))
	var wall_mult: float = float(params.get("wall_mult", 1.0))
	var residence: int = int(params.get("residence", 0))
	var hero_atk_mult: float = float(params.get("hero_atk_mult", 1.0))
	var hero_def_mult: float = float(params.get("hero_def_mult", 1.0))
	var roll: float = float(params.get("roll", 1.0))

	var atk := attack_points(attackers, smithy, hero_atk_mult)
	var atk_total: float = atk["total"]
	var inf_share := 1.0
	if atk_total > 0.0:
		inf_share = atk["inf"] / atk_total

	var def_total := defence_points(defenders, inf_share, armoury, hero_def_mult)
	# Every village defends itself a little, more so with a residence.
	def_total += 10.0 + residence * residence * 2.0
	def_total *= (1.0 + wall_level * wall_factor * wall_mult)

	var ratio := 999.0
	if def_total > 0.0:
		ratio = atk_total / def_total
	ratio *= roll

	var att_frac := 0.0
	var def_frac := 0.0
	var attacker_won := ratio >= 1.0
	if attacker_won:
		att_frac = pow(1.0 / max(ratio, 0.0001), LOSS_EXPONENT)
		def_frac = 1.0
	else:
		att_frac = 1.0
		def_frac = pow(ratio, LOSS_EXPONENT)

	if attack_type == "raid":
		att_frac *= RAID_LOSS_SCALE
		def_frac *= RAID_LOSS_SCALE

	var a := _apply_losses(attackers, att_frac)
	var d := _apply_losses(defenders, def_frac)

	# Siege only matters when the attacker actually took the field.
	var wall_damage := 0
	var building_hits := 0
	if attacker_won and attack_type == "attack":
		var rams := count_flagged(a["survivors"], "ram")
		if rams > 0:
			wall_damage = clampi(int(rams / float(2 + wall_level)), 0, 3)
			wall_damage = clampi(wall_damage, 0, wall_level)
		var catas := count_flagged(a["survivors"], "cata")
		if catas > 0:
			building_hits = clampi(int(catas / 10.0), 0, 3)

	return {
		"kind": attack_type,
		"attacker_won": attacker_won,
		"att_survivors": a["survivors"],
		"att_losses": a["losses"],
		"def_survivors": d["survivors"],
		"def_losses": d["losses"],
		"wall_damage": wall_damage,
		"building_hits": building_hits,
		"ratio": ratio,
		"atk_points": atk_total,
		"def_points": def_total,
		"carry": carry_capacity(a["survivors"]),
	}


## Split the loot the survivors can carry across whatever is actually in the
## village, proportionally to what is there and above the cranny floor.
static func split_loot(stock: Array, cranny: float, capacity: float, tribe_ignores_cranny: bool) -> Array:
	var protected := 0.0 if tribe_ignores_cranny else cranny
	var lootable := T.res_zero()
	var total := 0.0
	for r in range(4):
		var v: float = max(0.0, stock[r] - protected)
		lootable[r] = v
		total += v
	if total <= 0.0 or capacity <= 0.0:
		return T.res_zero()
	var take: float = min(capacity, total)
	var out := T.res_zero()
	for r in range(4):
		out[r] = floor(lootable[r] / total * take)
	return out
