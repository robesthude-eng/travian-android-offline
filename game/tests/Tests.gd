extends SceneTree

## Headless self-test. CI runs this before exporting the APK, so a logic
## regression fails the build instead of shipping.
##
##   godot --headless --script res://game/tests/Tests.gd

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Combat := preload("res://game/scripts/core/Combat.gd")
const World := preload("res://game/scripts/core/World.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const Bots := preload("res://game/scripts/core/Bots.gd")
const SaveIO := preload("res://game/scripts/core/SaveIO.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Travian Offline self-test ===")
	_test_tables()
	_test_formulas()
	_test_combat()
	_test_loot()
	_test_new_game()
	_test_production_and_caps()
	_test_offline_equals_online()
	_test_build_queue()
	_test_training()
	_test_starvation()
	_test_movement_and_camp()
	_test_bots_long_run()
	_test_settling_rules()
	_test_save_round_trip()
	_test_clock_tampering()

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: %s" % label)


func near(a: float, b: float, eps := 1.0) -> bool:
	return absf(a - b) <= eps


# ---------------------------------------------------------------------------

func _test_tables() -> void:
	for id in T.BUILDINGS:
		var b: Dictionary = T.BUILDINGS[id]
		check(b.has("cost") and (b["cost"] as Array).size() == 4, "building %s cost" % id)
		check(b.has("time") and b.has("pop") and b.has("max") and b.has("label"),
				"building %s fields" % id)
		check(b.has("art"), "building %s art" % id)
	for id in T.UNITS:
		var u: Dictionary = T.UNITS[id]
		check((u["cost"] as Array).size() == 4, "unit %s cost" % id)
		for key in ["atk", "di", "dc", "spd", "carry", "eat", "kind", "tribe", "label"]:
			check(u.has(key), "unit %s has %s" % [id, key])

	# Every tribe must be able to field a full roster.
	for tribe in [T.TRIBE_ROMANS, T.TRIBE_GAULS, T.TRIBE_GERMANS]:
		check(T.units_of_tribe(tribe).size() == 10, "%s has 10 units" % tribe)
		check(not T.units_from_building(tribe, "barracks").is_empty(),
				"%s has barracks units" % tribe)
		check(T.wall_id_for(tribe) != "", "%s has a wall" % tribe)

	check(T.FIELD_LAYOUT.size() == 18, "18 resource fields")
	check(T.SLOT_LAYOUT.size() == T.SLOT_COUNT, "22 building slots")

	# The classic 4-4-4-6 split.
	var counts := [0, 0, 0, 0]
	for f in T.FIELD_LAYOUT:
		counts[int(f["res"])] += 1
	check(counts == [4, 4, 4, 6], "field layout is 4-4-4-6, got %s" % str(counts))


func _test_formulas() -> void:
	check(T.building_cost("main", 1)[0] == 70, "main lvl1 wood cost")
	check(T.building_cost("main", 5)[0] > T.building_cost("main", 4)[0], "cost grows")
	check(T.storage_capacity(10) > T.storage_capacity(5), "storage grows")
	check(T.field_production(T.CR, 10) > T.field_production(T.W, 10), "crop out-yields wood")
	check(T.field_production(T.W, 0) == 2.0, "level 0 field still trickles")

	# Build time must fall as the main building rises, and never below the floor.
	var slow := T.building_time("warehouse", 5, 0, 1.0)
	var fast := T.building_time("warehouse", 5, 20, 1.0)
	check(fast < slow, "main building speeds up construction")
	check(T.building_time("main", 1, 20, 100.0) >= T.MIN_BUILD_TIME, "build time floor")

	# Game speed must actually speed things up.
	check(T.building_time("warehouse", 5, 0, 3.0) < slow, "game speed shortens builds")


func _test_combat() -> void:
	var big := {"legionnaire": 500}
	var small := {"phalanx": 10}
	var params := {"attack_type": "attack", "roll": 1.0, "wall_factor": 0.03}

	var r1 := Combat.resolve(big, small, params)
	check(r1["attacker_won"], "overwhelming attack wins")
	check(Sim.troops_count(r1["def_survivors"]) == 0, "loser is wiped in a real attack")
	check(Sim.troops_count(r1["att_survivors"]) > 400, "winner keeps most troops")

	var r2 := Combat.resolve(small, big, params)
	check(not r2["attacker_won"], "hopeless attack loses")
	check(Sim.troops_count(r2["att_survivors"]) == 0, "hopeless attacker is wiped")
	check(Sim.troops_count(r2["def_survivors"]) > 400, "defender barely scratched")

	# Raids are cheaper for both sides than a full attack.
	var raid := Combat.resolve(big, {"phalanx": 300},
			{"attack_type": "raid", "roll": 1.0, "wall_factor": 0.03})
	var attack := Combat.resolve(big, {"phalanx": 300},
			{"attack_type": "attack", "roll": 1.0, "wall_factor": 0.03})
	check(Sim.troops_count(raid["att_losses"]) <= Sim.troops_count(attack["att_losses"]),
			"raids cost the attacker less")
	check(Sim.troops_count(raid["def_losses"]) < Sim.troops_count(attack["def_losses"]),
			"raids cost the defender less")

	# Determinism: same inputs, same output.
	var a := Combat.resolve(big, {"phalanx": 200}, params)
	var b := Combat.resolve(big, {"phalanx": 200}, params)
	check(a["ratio"] == b["ratio"] and a["att_losses"] == b["att_losses"],
			"combat is deterministic for a fixed roll")

	# Walls matter.
	var no_wall := Combat.resolve({"legionnaire": 200}, {"phalanx": 100},
			{"attack_type": "attack", "roll": 1.0, "wall_level": 0, "wall_factor": 0.03})
	var walled := Combat.resolve({"legionnaire": 200}, {"phalanx": 100},
			{"attack_type": "attack", "roll": 1.0, "wall_level": 20, "wall_factor": 0.03})
	check(walled["def_points"] > no_wall["def_points"], "wall raises defence")

	# Cavalry-heavy attacks should be met by anti-cavalry defence.
	var vs_cav := Combat.defence_points({"spearman": 100}, 0.0, 0, 1.0)
	var vs_inf := Combat.defence_points({"spearman": 100}, 1.0, 0, 1.0)
	check(vs_cav > vs_inf, "spearmen defend better against cavalry")

	# Scouting only involves scouts.
	var scouted := Combat.resolve({"eq_legati": 20}, {"pathfinder": 1},
			{"attack_type": "scout", "roll": 1.0})
	check(scouted["attacker_won"], "many scouts beat one")
	var caught := Combat.resolve({"eq_legati": 1}, {"pathfinder": 50},
			{"attack_type": "scout", "roll": 1.0})
	check(not caught["attacker_won"], "outnumbered scouts fail")

	# A siege stack should actually dent a wall.
	var siege := Combat.resolve({"legionnaire": 2000, "ram_rome": 60}, {"phalanx": 10},
			{"attack_type": "attack", "roll": 1.0, "wall_level": 10, "wall_factor": 0.03})
	check(int(siege["wall_damage"]) > 0, "rams damage the wall")


func _test_loot() -> void:
	var stock := [1000.0, 1000.0, 1000.0, 1000.0]
	var loot := Combat.split_loot(stock, 0.0, 400.0, false)
	check(near(T.res_sum(loot), 400.0, 4.0), "loot respects carry capacity")

	var protected := Combat.split_loot([500.0, 0.0, 0.0, 0.0], 500.0, 9999.0, false)
	check(T.res_sum(protected) == 0.0, "cranny protects everything below its capacity")

	var germans := Combat.split_loot([500.0, 0.0, 0.0, 0.0], 500.0, 9999.0, true)
	check(T.res_sum(germans) > 0.0, "germans ignore the cranny")

	var proportional := Combat.split_loot([3000.0, 1000.0, 0.0, 0.0], 0.0, 2000.0, false)
	check(proportional[0] > proportional[1], "loot is proportional to what is there")


func _test_new_game() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 42)
	check(s["villages"].size() == 1, "one starting village")
	check(s["bots"].size() == World.BOT_COUNT, "bots generated")
	check(s["camps"].size() == World.CAMP_COUNT, "camps generated")
	check(s["oases"].size() == World.OASIS_COUNT, "oases generated")

	var v: Dictionary = s["villages"][0]
	check((v["fields"] as Array).size() == 18, "18 fields")
	check((v["slots"] as Array).size() == 22, "22 slots")
	check(Sim.slot_level(v, "main") == 1, "main building present")
	check(Sim.slot_level(v, "rally_point") == 1, "rally point present")

	# Nobody should spawn on top of the player.
	for b in s["bots"]:
		check(Sim.distance(0, 0, float(b["x"]), float(b["y"])) >= 5.0,
				"bot %s is not adjacent to spawn" % b["name"])

	# Same seed, same world.
	var s2 := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 42)
	check(str(s["bots"][0]["x"]) == str(s2["bots"][0]["x"]), "world generation is deterministic")


func _test_production_and_caps() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 7)
	var v: Dictionary = s["villages"][0]

	var prod := Sim.production(s, v)
	for r in range(4):
		check(prod[r] > 0.0, "produces %s" % T.RES_NAMES[r])

	# A bonus building must actually add output.
	var before: float = Sim.production(s, v)[T.W]
	v["slots"][5] = {"id": "sawmill", "lvl": 5}
	var after: float = Sim.production(s, v)[T.W]
	check(after > before, "sawmill raises wood output")
	check(near(after, before * 1.25, before * 0.02), "sawmill lvl5 is +25%")

	# Storage must cap.
	v["res"] = [99999.0, 0.0, 0.0, 0.0]
	Sim._accrue(s, 3600.0)
	check(float(v["res"][0]) <= Sim.capacity_for(v, 0) + 0.01, "warehouse caps wood")

	# Empty granary must never go negative.
	v["res"][T.CR] = 0.0
	v["troops"] = {"legionnaire": 400}
	Sim._accrue(s, 3600.0)
	check(float(v["res"][T.CR]) >= 0.0, "crop never goes negative")


func _test_offline_equals_online() -> void:
	## The property the whole architecture exists to guarantee.
	var a := World.new_game("A", T.TRIBE_ROMANS, 1.0, 99)
	var b := World.new_game("A", T.TRIBE_ROMANS, 1.0, 99)

	var horizon := 12.0 * 3600.0

	# One big jump, as if the app had been closed for twelve hours.
	Sim.advance_to(a, horizon)

	# The same twelve hours lived a minute at a time.
	var t := 0.0
	while t < horizon:
		t = min(t + 60.0, horizon)
		Sim.advance_to(b, t)

	var va: Dictionary = a["villages"][0]
	var vb: Dictionary = b["villages"][0]
	for r in range(4):
		check(near(float(va["res"][r]), float(vb["res"][r]), 2.0),
				"offline == online for %s (%.1f vs %.1f)" % [
					T.RES_NAMES[r], float(va["res"][r]), float(vb["res"][r])])
	check(near(float(va["cp"]), float(vb["cp"]), 2.0), "culture matches")
	check(a["bots"].size() == b["bots"].size(), "same bot count")

	var pa := 0.0
	var pb := 0.0
	for bot in a["bots"]:
		pa += Bots.power(bot)
	for bot in b["bots"]:
		pb += Bots.power(bot)
	check(near(pa, pb, max(1.0, pa * 0.001)),
			"bots grow identically offline (%.0f vs %.0f)" % [pa, pb])


func _test_build_queue() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 5)
	var v: Dictionary = s["villages"][0]
	v["res"] = [5000.0, 5000.0, 5000.0, 5000.0]

	var before := int(v["fields"][0])
	check(Actions.upgrade_field(s, v, 0), "field upgrade enqueued")
	check(v["build_queue"].size() == 1, "queued once")
	check(not Actions.upgrade_field(s, v, 1), "second field blocked by the queue")

	# Romans may build a centre slot at the same time as a field.
	check(Actions.build(s, v, 6, "cranny"), "romans build in parallel")

	Sim.advance_to(s, 100000.0)
	check(int(v["fields"][0]) == before + 1, "field level applied")
	check(Sim.slot_level(v, "cranny") == 1, "building applied")
	check(v["build_queue"].is_empty(), "queue drained")

	# Non-Romans get a single lane.
	var g := World.new_game("Т", T.TRIBE_GAULS, 1.0, 5)
	var gv: Dictionary = g["villages"][0]
	gv["res"] = [5000.0, 5000.0, 5000.0, 5000.0]
	check(Actions.upgrade_field(g, gv, 0), "gaul field queued")
	check(not Actions.build(g, gv, 6, "cranny"), "gauls have one queue")

	# Requirements are enforced.
	var s2 := World.new_game("Т", T.TRIBE_ROMANS, 1.0, 5)
	var v2: Dictionary = s2["villages"][0]
	v2["res"] = [99999.0, 99999.0, 99999.0, 99999.0]
	check(not Actions.build(s2, v2, 7, "workshop"), "workshop needs an academy")

	# Cancelling refunds.
	var s3 := World.new_game("Т", T.TRIBE_ROMANS, 1.0, 5)
	var v3: Dictionary = s3["villages"][0]
	v3["res"] = [5000.0, 5000.0, 5000.0, 5000.0]
	var wood_before := float(v3["res"][0])
	Actions.build(s3, v3, 6, "cranny")
	check(float(v3["res"][0]) < wood_before, "building costs resources")
	Actions.cancel_build(s3, v3, 0)
	check(near(float(v3["res"][0]), wood_before, 1.0), "cancelling refunds")


func _test_training() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 11)
	var v: Dictionary = s["villages"][0]
	v["res"] = [99999.0, 99999.0, 99999.0, 99999.0]
	v["slots"][6] = {"id": "barracks", "lvl": 3}

	check(Actions.train(s, v, "legionnaire", 5), "training enqueued")
	check(not Actions.train(s, v, "eq_caesaris", 1), "cavalry needs a stable")

	Sim.advance_to(s, 100000.0)
	check(int(v["troops"].get("legionnaire", 0)) == 5,
			"5 legionnaires trained, got %d" % int(v["troops"].get("legionnaire", 0)))
	check(v["train_queue"].is_empty(), "training queue drained")

	# Higher barracks levels must train faster.
	var slow := Actions.can_train(s, v, "legionnaire", 10)
	v["slots"][6]["lvl"] = 15
	var fast := Actions.can_train(s, v, "legionnaire", 10)
	check(float(fast["time"]) < float(slow["time"]), "barracks level speeds training")


func _test_starvation() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 13)
	var v: Dictionary = s["villages"][0]
	v["troops"] = {"legionnaire": 3000}
	v["res"][T.CR] = 50.0

	check(Sim.crop_net(s, v) < 0.0, "3000 legionnaires starve the village")
	Sim.advance_to(s, 20.0 * 3600.0)
	var left := int(v["troops"].get("legionnaire", 0))
	check(left < 3000, "famine kills troops (%d left)" % left)
	check(left > 0, "famine stops once the village feeds itself")
	check(Sim.crop_net(s, v) >= -0.01, "famine restores the crop balance")


func _test_movement_and_camp() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 17)
	var v: Dictionary = s["villages"][0]
	v["troops"] = {"legionnaire": 800}

	# Find a weak camp to farm.
	var camp: Dictionary = {}
	for c in s["camps"]:
		if int(c["level"]) <= 2 and bool(c["alive"]):
			camp = c
			break
	check(not camp.is_empty(), "found a low level camp")
	if camp.is_empty():
		return

	var target := {"kind": "camp", "id": int(camp["id"]),
			"x": int(camp["x"]), "y": int(camp["y"])}
	var result := Actions.send_army(s, v, target, {"legionnaire": 400}, "raid", false)
	check(result["ok"], "raid launched: %s" % String(result.get("reason", "")))
	check(int(v["troops"]["legionnaire"]) == 400, "troops left the village")
	check(s["movements"].size() == 1, "movement created")

	var xp_before := float(s["hero"]["xp"]) + float(s["hero"]["level"]) * 1000.0
	Sim.advance_to(s, 200000.0)

	check(s["movements"].is_empty(), "movement resolved and returned")
	check(int(v["troops"].get("legionnaire", 0)) > 400, "survivors came home")
	check(not bool(camp["alive"]), "camp was cleared")
	var xp_after := float(s["hero"]["xp"]) + float(s["hero"]["level"]) * 1000.0
	check(xp_after > xp_before, "hero gained experience")

	var has_battle := false
	for r in s["reports"]:
		if String(r.get("type", "")) == "battle":
			has_battle = true
	check(has_battle, "battle report written")

	# Camps come back.
	Sim.advance_to(s, 200000.0 + Sim.CAMP_RESPAWN + 60.0)
	check(bool(camp["alive"]), "camp respawned")


func _test_bots_long_run() -> void:
	## Three days of world time must not explode, stall or corrupt anything.
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 3.0, 23)
	var power_before := 0.0
	for b in s["bots"]:
		power_before += Bots.power(b)

	Sim.advance_to(s, 72.0 * 3600.0)

	var power_after := 0.0
	for b in s["bots"]:
		power_after += Bots.power(b)
		check(float(b["eco"]) > 0.0, "bot economy stays sane")
		for r in range(4):
			check(float(b["res"][r]) >= 0.0, "bot resources never go negative")
	check(power_after > power_before, "bots build armies over time")

	var v: Dictionary = s["villages"][0]
	for r in range(4):
		check(float(v["res"][r]) >= 0.0, "player resources stay valid")
		check(float(v["res"][r]) <= Sim.capacity_for(v, r) + 1.0, "player resources stay capped")
	check(float(s["t"]) >= 72.0 * 3600.0, "clock advanced fully")


func _test_settling_rules() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 29)
	var v: Dictionary = s["villages"][0]

	check(not Actions.can_settle(s, v)["ok"], "cannot settle on day one")

	# Culture alone is not enough without a residence.
	v["cp"] = 99999.0
	check(not Actions.can_settle(s, v)["ok"], "culture alone is not enough")

	# Residence 10 opens exactly one expansion slot.
	v["slots"][8] = {"id": "residence", "lvl": 10}
	check(Sim.expansion_slots(s) == 1, "residence 10 gives one slot")
	check(not Actions.can_settle(s, v)["ok"], "still needs settlers")

	v["troops"] = {"settler_rome": 3}
	check(Actions.can_settle(s, v)["ok"], "all conditions met")

	var spot := World.suggest_settle_spot(s)
	check(spot.x != 9999, "found a free spot")
	var r := Actions.send_settlers(s, v, spot.x, spot.y)
	check(r["ok"], "settlers sent")
	Sim.advance_to(s, 200000.0)
	check(s["villages"].size() == 2, "second village founded")

	# The slot is now spent.
	check(Sim.expansion_slots(s) == 0, "expansion slot consumed")


func _test_save_round_trip() -> void:
	var s := World.new_game("Тест", T.TRIBE_GERMANS, 3.0, 31)
	var v: Dictionary = s["villages"][0]
	v["troops"] = {"clubswinger": 42, "spearman": 7}
	v["res"] = [111.0, 222.0, 333.0, 444.0]
	Sim.advance_to(s, 5000.0)

	var text := JSON.stringify(s)
	var back = JSON.parse_string(text)
	check(typeof(back) == TYPE_DICTIONARY, "state survives JSON")
	if typeof(back) != TYPE_DICTIONARY:
		return
	var restored: Dictionary = SaveIO.migrate(back)
	var rv: Dictionary = restored["villages"][0]

	# The exact failure mode of the old Unity save system: troop dictionaries
	# and timestamps silently vanishing.
	check(int(rv["troops"].get("clubswinger", 0)) == 42, "troops survive the save")
	check(int(rv["troops"].get("spearman", 0)) == 7, "all troop types survive")
	check(near(float(restored["t"]), float(s["t"]), 0.001), "timestamp survives the save")
	check(near(float(rv["res"][2]), float(v["res"][2]), 0.001), "resources survive the save")
	check(restored["bots"].size() == s["bots"].size(), "bots survive the save")

	# And it must keep simulating correctly afterwards.
	Sim.advance_to(restored, float(restored["t"]) + 3600.0)
	check(float(rv["res"][0]) > 0.0, "restored save keeps producing")


func _test_clock_tampering() -> void:
	var s := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 37)
	s["t"] = 1000.0
	var v: Dictionary = s["villages"][0]
	v["res"] = [0.0, 0.0, 0.0, 0.0]

	# Winding the clock a year forward must not mint a year of resources.
	Sim.catch_up(s, 1000.0 + 365.0 * 24.0 * 3600.0)
	var cap := Sim.capacity_for(v, 0)
	check(float(v["res"][0]) <= cap + 1.0, "offline gain is bounded by storage")
	check(near(float(s["t"]), 1000.0 + 365.0 * 24.0 * 3600.0, 1.0),
			"clock still follows the device")

	# Winding it backwards must not corrupt anything.
	var s2 := World.new_game("Тест", T.TRIBE_ROMANS, 1.0, 41)
	s2["t"] = 100000.0
	var before := float(s2["villages"][0]["res"][0])
	var gained := Sim.catch_up(s2, 5000.0)
	check(gained == 0.0, "no production when the clock goes backwards")
	check(near(float(s2["villages"][0]["res"][0]), before, 0.001), "state untouched")
	check(near(float(s2["t"]), 5000.0, 0.001), "clock resynced to the device")
