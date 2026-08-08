extends RefCounted

## Save/load. The state tree is already plain JSON types, so there is no
## serialisation layer that could silently drop dictionaries or timestamps.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.backup.json"


static func save(state: Dictionary) -> bool:
	var json := JSON.stringify(state)
	if json == "":
		push_error("[Save] serialisation produced nothing")
		return false

	# Keep the previous save as a backup before overwriting.
	if FileAccess.file_exists(SAVE_PATH):
		var old := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old:
			var prev := old.get_as_text()
			old.close()
			if prev.length() > 0:
				var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
				if bak:
					bak.store_string(prev)
					bak.close()

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Save] cannot open %s: %d" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(json)
	f.close()
	return true


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func load_state() -> Dictionary:
	var state := _read(SAVE_PATH)
	if state.is_empty():
		state = _read(BACKUP_PATH)
		if not state.is_empty():
			push_warning("[Save] main save unreadable, restored from backup")
	if state.is_empty():
		return {}
	return migrate(state)


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


static func erase() -> void:
	for p in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Fill in anything a save from an older build is missing, so updating the app
## never wipes a game.
static func migrate(state: Dictionary) -> Dictionary:
	var defaults := {
		"version": 1, "rng": 12345, "seed": 1, "speed": 3.0, "t": 0.0,
		"next_id": 1, "villages": [], "bots": [], "camps": [], "oases": [],
		"movements": [], "trades": [], "reports": [],
	}
	for k in defaults:
		if not state.has(k):
			state[k] = defaults[k]

	if not state.has("settings"):
		state["settings"] = {}
	var s: Dictionary = state["settings"]
	for k in {"llm_enabled": false, "llm_key": "", "llm_model": "claude-sonnet-5", "llm_rivals": 2}:
		if not s.has(k):
			s[k] = {"llm_enabled": false, "llm_key": "", "llm_model": "claude-sonnet-5",
				"llm_rivals": 2}[k]

	for v in state["villages"]:
		for k in {"build_queue": [], "train_queue": [], "troops": {}, "cp": 0.0,
				"loyalty": 100.0, "starve_at": -1.0}:
			if not v.has(k):
				v[k] = {"build_queue": [], "train_queue": [], "troops": {}, "cp": 0.0,
					"loyalty": 100.0, "starve_at": -1.0}[k]

	for b in state["bots"]:
		for k in {"anger": 0.0, "chat": [], "llm": false, "policy": {}}:
			if not b.has(k):
				b[k] = {"anger": 0.0, "chat": [], "llm": false, "policy": {}}[k]

	return state
