extends Node

## Autoloaded as `G`. Owns the world state, drives the clock, and persists.

signal state_changed
signal offline_report(seconds: float, gained: Dictionary)
signal rival_spoke(who: String, message: String)

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const SaveIO := preload("res://game/scripts/core/SaveIO.gd")
const World := preload("res://game/scripts/core/World.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const Llm := preload("res://game/scripts/core/Llm.gd")

const TICK_INTERVAL := 1.0
const AUTOSAVE_INTERVAL := 20.0
const LLM_TICK_INTERVAL := 30.0

var state: Dictionary = {}
var current_village_index := 0

var _autosave_accum := 0.0
var _llm_accum := 0.0
var _llm: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_llm = Llm.new()
	_llm.name = "LlmRival"
	add_child(_llm)
	_llm.policy_updated.connect(func(who, msg): rival_spoke.emit(who, msg))

	var timer := Timer.new()
	timer.wait_time = TICK_INTERVAL
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_tick)


func has_save() -> bool:
	return SaveIO.has_save()


func load_game() -> bool:
	var loaded := SaveIO.load_state()
	if loaded.is_empty():
		return false
	state = loaded
	current_village_index = 0

	# Catch up on everything that happened while the app was closed.
	var before := _snapshot_resources()
	var now := Time.get_unix_time_from_system()
	var elapsed := Sim.catch_up(state, now)
	var gained := _resource_delta(before)
	if elapsed > 60.0:
		offline_report.emit(elapsed, gained)
	state_changed.emit()
	return true


func new_game(player_name: String, tribe: String, speed: float) -> void:
	var now := Time.get_unix_time_from_system()
	var seed_value := int(now) ^ hash(player_name)
	state = World.new_game(player_name, tribe, speed, seed_value)
	state["t"] = now
	state["created"] = now
	# Bots were generated with t=0; move their first turn onto the real clock.
	for b in state["bots"]:
		b["next_tick"] = now + float(b["next_tick"])
	for c in state["camps"]:
		c["respawn_at"] = now
	current_village_index = 0
	save()
	state_changed.emit()


func abandon_game() -> void:
	SaveIO.erase()
	state = {}
	current_village_index = 0


func save() -> void:
	if state.is_empty():
		return
	SaveIO.save(state)


func _snapshot_resources() -> Dictionary:
	var out := {}
	for v in state.get("villages", []):
		out[int(v["id"])] = (v["res"] as Array).duplicate()
	return out


func _resource_delta(before: Dictionary) -> Dictionary:
	var total := T.res_zero()
	for v in state.get("villages", []):
		var prev: Array = before.get(int(v["id"]), T.res_zero())
		for r in range(4):
			total[r] += float(v["res"][r]) - float(prev[r])
	return {"res": total}


func _on_tick() -> void:
	if state.is_empty():
		return
	Sim.advance_to(state, Time.get_unix_time_from_system())

	_autosave_accum += TICK_INTERVAL
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		save()

	_llm_accum += TICK_INTERVAL
	if _llm_accum >= LLM_TICK_INTERVAL:
		_llm_accum = 0.0
		if _llm and _llm.is_configured(state):
			_llm.assign_rivals(state)
			_llm.tick(state)

	state_changed.emit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST:
			save()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if not state.is_empty():
				Sim.advance_to(state, Time.get_unix_time_from_system())
				state_changed.emit()

# ---------------------------------------------------------------------------
# Convenience accessors used across the UI
# ---------------------------------------------------------------------------

func village() -> Dictionary:
	if state.is_empty() or state["villages"].is_empty():
		return {}
	current_village_index = clampi(current_village_index, 0, state["villages"].size() - 1)
	return state["villages"][current_village_index]


func village_count() -> int:
	if state.is_empty():
		return 0
	return state["villages"].size()


func select_village(index: int) -> void:
	current_village_index = clampi(index, 0, max(0, village_count() - 1))
	state_changed.emit()


func tribe_info() -> Dictionary:
	return T.TRIBES[state["player"]["tribe"]]


func speed() -> float:
	return float(state.get("speed", 1.0))


func set_speed(value: float) -> void:
	state["speed"] = clampf(value, 1.0, 20.0)
	save()
	state_changed.emit()


func settings() -> Dictionary:
	return state.get("settings", {})


## Rebuild the world's difficulty curve is not supported mid-game; this only
## toggles who the model drives.
func configure_llm(enabled: bool, key: String, model: String, rivals: int) -> void:
	var s: Dictionary = state["settings"]
	s["llm_enabled"] = enabled
	s["llm_key"] = key
	s["llm_model"] = model
	s["llm_rivals"] = clampi(rivals, 0, 8)
	if enabled and _llm:
		_llm.assign_rivals(state)
	save()
	state_changed.emit()


func mark_reports_read() -> void:
	for r in state.get("reports", []):
		r["read"] = true
	state_changed.emit()


static func fmt_time(seconds: float) -> String:
	var s := int(max(0.0, seconds))
	if s >= 86400:
		return "%dд %02d:%02d" % [s / 86400, (s % 86400) / 3600, (s % 3600) / 60]
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


static func fmt_number(value: float) -> String:
	var n := int(round(value))
	if absi(n) < 10000:
		return str(n)
	if absi(n) < 1000000:
		return "%.1fк" % (n / 1000.0)
	return "%.2fм" % (n / 1000000.0)
