extends Node

## Optional Claude-driven rivals.
##
## The model never touches the simulation directly. It returns a *policy* —
## how aggressive to be, what to focus on, and a line of in-character trash
## talk — which is cached on the bot. `Bots.take_turn` then executes that
## policy deterministically.
##
## Consequences of that split, all of them deliberate:
##   * the game stays fully playable with no network and no key;
##   * offline catch-up is still deterministic and instant;
##   * a slow or failed API call degrades to the heuristic bot, never a stall.
##
## Note: the key is stored in the local save on the device. That is fine for a
## personal build; do not ship this to a store with a shared key.

signal policy_updated(bot_name: String, message: String)

const API_URL := "https://api.anthropic.com/v1/messages"
const API_VERSION := "2023-06-01"
const REFRESH_INTERVAL := 900.0     # ask the model at most once per 15 real minutes per rival
const REQUEST_TIMEOUT := 20.0

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Bots := preload("res://game/scripts/core/Bots.gd")

var _http: HTTPRequest
var _busy := false
var _pending_bot_id := -1
var _state: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_response)


func is_configured(state: Dictionary) -> bool:
	var s: Dictionary = state.get("settings", {})
	return bool(s.get("llm_enabled", false)) and String(s.get("llm_key", "")).strip_edges() != ""


## Mark the strongest N rivals as LLM-driven; the rest stay heuristic.
func assign_rivals(state: Dictionary) -> void:
	var want := int(state["settings"].get("llm_rivals", 2))
	var ranked: Array = state["bots"].duplicate()
	ranked.sort_custom(func(a, b): return Bots.power(a) > Bots.power(b))
	for i in range(ranked.size()):
		ranked[i]["llm"] = i < want


## Called on a timer by Game. Picks one stale rival and refreshes its policy.
func tick(state: Dictionary) -> void:
	if _busy or not is_configured(state):
		return
	_state = state
	var now := Time.get_unix_time_from_system()
	for b in state["bots"]:
		if not bool(b.get("llm", false)):
			continue
		if now - float(b.get("policy_at", 0.0)) < REFRESH_INTERVAL:
			continue
		_request_policy(state, b)
		return


func _build_prompt(state: Dictionary, bot: Dictionary) -> String:
	var player_v: Dictionary = state["villages"][0]
	var dist := Sim.distance(float(bot["x"]), float(bot["y"]),
			float(player_v["x"]), float(player_v["y"]))
	var lines: Array = []
	lines.append("Ты — %s, вождь племени %s в игре про античные войны."
			% [bot["name"], T.TRIBES[bot["tribe"]]["label"]])
	lines.append("Твоя деревня: (%d, %d). Характер: %s."
			% [int(bot["x"]), int(bot["y"]), String(bot.get("personality", "economic"))])
	lines.append("Твоя армия: %d воинов. Стена: %d. Экономика: %.1f."
			% [Sim.troops_count(bot["troops"]), int(bot.get("wall", 0)), float(bot["eco"])])
	lines.append("")
	lines.append("Противник — игрок «%s» (%s), столица (%d, %d), в %.0f полях от тебя."
			% [state["player"]["name"], T.TRIBES[state["player"]["tribe"]]["label"],
			int(player_v["x"]), int(player_v["y"]), dist])
	lines.append("Его армия дома: %d воинов. Население: %d."
			% [Sim.troops_count(player_v["troops"]), Sim.population(player_v)])
	lines.append("Его защита оценивается в %.0f очков."
			% Bots.player_defence_estimate(state, player_v))
	lines.append("Твоя злость на игрока: %.2f (растёт, когда он тебя грабит)."
			% float(bot.get("anger", 0.0)))
	lines.append("")
	lines.append("Выбери стратегию на ближайшие часы и брось игроку короткую реплику в характере.")
	return "\n".join(lines)


const SYSTEM_PROMPT := """Ты играешь за соперника-вождя в оффлайновой стратегии в духе Travian.
Отвечай ТОЛЬКО валидным JSON-объектом, без markdown и пояснений, строго в формате:
{"aggression": <число 0.0-1.0>, "focus": "aggressive"|"economic"|"defensive", "message": "<до 140 символов, по-русски, в характере вождя>"}
aggression - насколько активно нападать на игрока. focus - на что тратить ресурсы.
Учитывай баланс сил: не бросайся в атаку, если защита игрока заметно сильнее твоей армии."""


func _request_policy(state: Dictionary, bot: Dictionary) -> void:
	var key: String = String(state["settings"].get("llm_key", "")).strip_edges()
	if key == "":
		return
	var body := {
		"model": String(state["settings"].get("llm_model", "claude-sonnet-5")),
		"max_tokens": 300,
		"system": SYSTEM_PROMPT,
		"messages": [{"role": "user", "content": _build_prompt(state, bot)}],
	}
	var headers := [
		"content-type: application/json",
		"x-api-key: " + key,
		"anthropic-version: " + API_VERSION,
	]
	_busy = true
	_pending_bot_id = int(bot["id"])
	bot["policy_at"] = Time.get_unix_time_from_system()
	var err := _http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_busy = false
		_pending_bot_id = -1
		push_warning("[LLM] request failed to start: %d" % err)


func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var bot_id := _pending_bot_id
	_pending_bot_id = -1
	if _state.is_empty():
		return
	var bot := Sim.find_bot(_state, bot_id)
	if bot.is_empty():
		return

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# Silent degradation: the heuristic policy keeps playing.
		push_warning("[LLM] http result=%d code=%d" % [result, code])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var content = parsed.get("content", [])
	if typeof(content) != TYPE_ARRAY or content.is_empty():
		return
	var text := String(content[0].get("text", "")).strip_edges()
	# Models sometimes fence JSON despite instructions.
	text = text.trim_prefix("```json").trim_prefix("```").trim_suffix("```").strip_edges()

	var policy = JSON.parse_string(text)
	if typeof(policy) != TYPE_DICTIONARY:
		return

	var focus := String(policy.get("focus", "economic"))
	if not ["aggressive", "economic", "defensive"].has(focus):
		focus = "economic"
	bot["policy"] = {
		"aggression": clampf(float(policy.get("aggression", 0.35)), 0.0, 1.0),
		"focus": focus,
	}

	var message := String(policy.get("message", "")).strip_edges()
	if message != "":
		if message.length() > 200:
			message = message.substr(0, 200)
		bot["chat"].append({"t": Time.get_unix_time_from_system(), "text": message})
		while bot["chat"].size() > 10:
			bot["chat"].pop_front()
		Sim.add_report(_state, {
			"type": "message",
			"title": "Послание от %s" % bot["name"],
			"text": message,
		})
		policy_updated.emit(String(bot["name"]), message)
