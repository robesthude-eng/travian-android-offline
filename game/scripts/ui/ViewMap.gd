extends Control

## World map: a pannable window onto the world, and the place you launch
## attacks, raids, scouting runs and settlers from.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const World := preload("res://game/scripts/core/World.gd")
const Bots := preload("res://game/scripts/core/Bots.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

const VIEW := 11        # tiles across (odd, so there is a centre tile)

var _root: Control
var _centre := Vector2i.ZERO
var _tiles: Array = []
var _coord_label: Label
var _moves_box: VBoxContainer


func setup(root: Control) -> void:
	_root = root


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_tiles.clear()

	var v := G.village()
	if not v.is_empty():
		_centre = Vector2i(int(v["x"]), int(v["y"]))

	var col := Style.vbox(10)

	var nav := Style.hbox(6)
	_coord_label = Style.label("", Style.FONT_S, Style.TEXT_DIM)
	_coord_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_coord_label)
	var home := Style.button("⌂ К деревне", Style.FONT_S, false)
	home.pressed.connect(func():
		var vv := G.village()
		_centre = Vector2i(int(vv["x"]), int(vv["y"]))
		_update_tiles())
	nav.add_child(home)
	col.add_child(nav)

	var grid := GridContainer.new()
	grid.columns = VIEW
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for i in range(VIEW * VIEW):
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.add_theme_font_size_override("font_size", Style.FONT_S)
		b.clip_text = true
		var idx := i
		b.pressed.connect(func(): _tap_tile(idx))
		grid.add_child(b)
		_tiles.append(b)
	col.add_child(grid)

	var pad := Style.hbox(6)
	for spec in [["◀", Vector2i(-4, 0)], ["▲", Vector2i(0, -4)],
			["▼", Vector2i(0, 4)], ["▶", Vector2i(4, 0)]]:
		var b := Style.button(String(spec[0]), Style.FONT_M, false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var delta: Vector2i = spec[1]
		b.pressed.connect(func():
			_centre += delta
			_centre.x = clampi(_centre.x, -World.MAP_RADIUS, World.MAP_RADIUS)
			_centre.y = clampi(_centre.y, -World.MAP_RADIUS, World.MAP_RADIUS)
			_update_tiles())
		pad.add_child(b)
	col.add_child(pad)

	col.add_child(Style.separator())
	col.add_child(Style.label("Походы", Style.FONT_M, Style.ACCENT))
	_moves_box = Style.vbox(6)
	col.add_child(_moves_box)

	add_child(Style.scroll(Style.margin(col, 12)))
	_update_tiles()
	refresh()


func _object_at(x: int, y: int) -> Dictionary:
	for v in G.state["villages"]:
		if int(v["x"]) == x and int(v["y"]) == y:
			return {"kind": "village", "ref": v}
	for b in G.state["bots"]:
		if int(b["x"]) == x and int(b["y"]) == y:
			return {"kind": "bot", "ref": b}
	for c in G.state["camps"]:
		if int(c["x"]) == x and int(c["y"]) == y and bool(c["alive"]):
			return {"kind": "camp", "ref": c}
	for o in G.state["oases"]:
		if int(o["x"]) == x and int(o["y"]) == y:
			return {"kind": "oasis", "ref": o}
	return {}


func _update_tiles() -> void:
	if _tiles.is_empty():
		return
	var half := VIEW / 2
	for i in range(_tiles.size()):
		var gx := i % VIEW
		var gy := i / VIEW
		var x := _centre.x + gx - half
		var y := _centre.y + gy - half
		var b: Button = _tiles[i]

		var obj := _object_at(x, y)
		var fill := Color("2b3a24")
		var text := ""
		if abs(x) > World.MAP_RADIUS or abs(y) > World.MAP_RADIUS:
			fill = Color("1a1a1a")
			text = ""
		elif obj.is_empty():
			text = ""
		else:
			match obj["kind"]:
				"village":
					text = "🏛️"
					fill = Style.ACCENT.darkened(0.5)
				"bot":
					text = "🏚️"
					fill = Color("5a3a2a")
				"camp":
					text = "💀"
					fill = Color("4a2a2a")
				"oasis":
					var o: Dictionary = obj["ref"]
					text = T.RES_ICONS[int(o["res"])]
					fill = Color("2a4a3a")
					if int(o.get("owner", -1)) >= 0:
						fill = Color("3a5a2a")
		b.text = text
		b.add_theme_stylebox_override("normal", Style.flat(fill, 6, 1, fill.lightened(0.2)))
		b.add_theme_stylebox_override("hover", Style.flat(fill.lightened(0.15), 6, 1, Style.ACCENT))
		b.add_theme_stylebox_override("pressed", Style.flat(fill.darkened(0.2), 6))
		b.add_theme_color_override("font_color", Style.TEXT)
	_coord_label.text = "Центр обзора: (%d | %d)" % [_centre.x, _centre.y]


func refresh() -> void:
	if _moves_box == null:
		return
	for c in _moves_box.get_children():
		c.queue_free()

	var any := false
	for m in G.state["movements"]:
		var mine: bool = m.get("owner", "") == "player"
		var incoming: bool = not mine and String(m["to_kind"]) == "village"
		if not mine and not incoming:
			continue
		any = true
		var eta: float = float(m["arrive"]) - float(G.state["t"])
		var panel := Style.panel(
			Style.PANEL_LIGHT if mine else Color("4a2424"), 10)
		var col := Style.vbox(2)
		var head := ""
		if mine:
			var verb := {"raid": "Набег", "attack": "Атака", "scout": "Разведка",
				"settle": "Поселенцы", "reinforce": "Подкрепление"}.get(String(m["kind"]), "Поход")
			if bool(m.get("returning", false)):
				verb = "Возвращение"
			head = "%s → (%d|%d)" % [verb, int(m["to_x"]), int(m["to_y"])]
		else:
			head = "⚠ %s идёт на тебя" % String(m.get("owner_name", "Враг"))
		col.add_child(Style.label(head, Style.FONT_S,
				Style.TEXT if mine else Style.BAD))
		col.add_child(Style.label("Прибытие через %s   •   %d воинов" % [
			G.fmt_time(eta), Sim.troops_count(m["troops"])], Style.FONT_S, Style.TEXT_DIM))
		panel.add_child(col)
		_moves_box.add_child(panel)

	for tr in G.state["trades"]:
		any = true
		var eta2: float = float(tr["arrive"]) - float(G.state["t"])
		var panel2 := Style.panel(Style.PANEL_LIGHT, 10)
		var lbl := "🚚 Караван" + (" (возврат)" if bool(tr.get("returning", false)) else "")
		var col2 := Style.vbox(2)
		col2.add_child(Style.label(lbl, Style.FONT_S))
		col2.add_child(Style.label("Через %s" % G.fmt_time(eta2), Style.FONT_S, Style.TEXT_DIM))
		panel2.add_child(col2)
		_moves_box.add_child(panel2)

	if not any:
		_moves_box.add_child(Style.label("Никто никуда не идёт.", Style.FONT_S, Style.TEXT_DIM))


# ---------------------------------------------------------------------------
# Tile interaction
# ---------------------------------------------------------------------------

func _tap_tile(index: int) -> void:
	var half := VIEW / 2
	var x := _centre.x + (index % VIEW) - half
	var y := _centre.y + (index / VIEW) - half
	if abs(x) > World.MAP_RADIUS or abs(y) > World.MAP_RADIUS:
		return
	var obj := _object_at(x, y)
	var v := G.village()
	var dist := Sim.distance(float(v["x"]), float(v["y"]), float(x), float(y))

	var body := Style.vbox(8)
	body.add_child(Style.label("Клетка (%d | %d)" % [x, y], Style.FONT_M))
	body.add_child(Style.label("Расстояние от %s: %.1f полей" % [v["name"], dist],
			Style.FONT_S, Style.TEXT_DIM))

	var title := "Пустая земля"
	var target := {"kind": "pos", "x": x, "y": y, "id": -1}
	var can_attack := false

	if obj.is_empty():
		body.add_child(Style.wrapped("Здесь можно основать деревню, если есть поселенцы.",
				Style.FONT_S, Style.TEXT_DIM))
	else:
		var ref: Dictionary = obj["ref"]
		target["id"] = int(ref.get("id", -1))
		match obj["kind"]:
			"village":
				title = String(ref["name"])
				target["kind"] = "village"
				body.add_child(Style.label("Твоя деревня. Население %d." % Sim.population(ref),
						Style.FONT_S, Style.GOOD))
			"bot":
				title = String(ref["name"])
				target["kind"] = "bot"
				can_attack = true
				body.add_child(Style.wrapped(Bots.describe(ref), Style.FONT_S))
				var chat: Array = ref.get("chat", [])
				if not chat.is_empty():
					body.add_child(Style.separator())
					body.add_child(Style.wrapped("«%s»" % String(chat[-1]["text"]),
							Style.FONT_S, Style.ACCENT))
			"camp":
				title = "Лагерь разбойников ур.%d" % int(ref["level"])
				target["kind"] = "camp"
				can_attack = true
				body.add_child(Style.label("Награда: примерно %s" % _fmt_res(ref["reward"]),
						Style.FONT_S, Style.GOOD))
				body.add_child(Style.label("Опыт герою: %d" % int(ref["xp"]),
						Style.FONT_S, Style.TEXT_DIM))
				body.add_child(Style.label("Защитники: %s" % _fmt_troops(ref["troops"]),
						Style.FONT_S, Style.TEXT_DIM))
			"oasis":
				title = "Оазис +%d%% %s" % [int(float(ref["pct"]) * 100.0),
						T.RES_LABELS[int(ref["res"])]]
				target["kind"] = "oasis"
				can_attack = true
				var owner := int(ref.get("owner", -1))
				body.add_child(Style.label(
					"Свободен" if owner < 0 else "Принадлежит тебе",
					Style.FONT_S, Style.TEXT_DIM if owner < 0 else Style.GOOD))
				body.add_child(Style.label("Стража: %s" % _fmt_troops(ref["troops"]),
						Style.FONT_S, Style.TEXT_DIM))

	var buttons := [{"text": "Закрыть"}]
	if can_attack:
		buttons.append({"text": "Отправить войска", "primary": true, "action": func():
			_root.close_modal()
			_open_send_dialog(target)})
	elif obj.is_empty():
		var settle_check := Actions.can_settle(G.state, v)
		buttons.append({"text": "Основать", "primary": true,
			"disabled": not settle_check["ok"], "action": func():
				var r := Actions.send_settlers(G.state, G.village(), x, y)
				_root.close_modal()
				if r["ok"]:
					G.save()
					_root.toast("Поселенцы в пути: %s" % G.fmt_time(float(r["eta"])))
				else:
					_root.toast(String(r["reason"]))})

	_root.show_modal(title, body, buttons)


func _fmt_res(res: Array) -> String:
	var parts: Array = []
	for r in range(4):
		if float(res[r]) > 0.0:
			parts.append("%s%d" % [T.RES_ICONS[r], int(res[r])])
	return " ".join(parts)


func _fmt_troops(troops: Dictionary) -> String:
	var parts: Array = []
	for id in troops:
		var u: Dictionary = T.unit(id)
		parts.append("%d %s" % [int(troops[id]), u.get("label", id)])
	return ", ".join(parts) if not parts.is_empty() else "никого"


# ---------------------------------------------------------------------------
# Sending an army
# ---------------------------------------------------------------------------

func _open_send_dialog(target: Dictionary) -> void:
	var v := G.village()
	var body := Style.vbox(8)
	var spins := {}

	if v["troops"].is_empty():
		body.add_child(Style.wrapped("Дома нет войск. Обучи их в казарме.",
				Style.FONT_S, Style.BAD))
	else:
		body.add_child(Style.label("Сколько отправить:", Style.FONT_S, Style.TEXT_DIM))
		var ids: Array = v["troops"].keys()
		ids.sort()
		for id in ids:
			var have := int(v["troops"][id])
			if have <= 0:
				continue
			var u: Dictionary = T.unit(id)
			var row := Style.hbox(8)
			row.add_child(Style.label("%s (%d)" % [u.get("label", id), have], Style.FONT_S))
			row.add_child(Style.spacer())
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = have
			spin.step = 1
			spin.value = 0
			spin.custom_minimum_size = Vector2(110, 0)
			row.add_child(spin)
			var all_btn := Style.button("Все", Style.FONT_S, false)
			all_btn.custom_minimum_size = Vector2(48, 32)
			var s := spin
			var h := have
			all_btn.pressed.connect(func(): s.value = h)
			row.add_child(all_btn)
			body.add_child(row)
			spins[id] = spin

	var hero_check := CheckBox.new()
	hero_check.text = "Взять героя (%s)" % Hero.status_text(G.state)
	hero_check.disabled = not Hero.is_available(G.state)
	body.add_child(hero_check)

	var collect := func() -> Dictionary:
		var out := {}
		for id in spins:
			var n := int(spins[id].value)
			if n > 0:
				out[id] = n
		return out

	var launch := func(kind: String):
		var troops: Dictionary = collect.call()
		var result := Actions.send_army(G.state, G.village(), target, troops, kind,
				hero_check.button_pressed)
		_root.close_modal()
		if result["ok"]:
			G.save()
			_root.toast("Войска в пути. Прибытие через %s" % G.fmt_time(float(result["eta"])))
			rebuild()
		else:
			_root.toast(String(result["reason"]))

	_root.show_modal("Отправка войск", body, [
		{"text": "Отмена"},
		{"text": "🔍 Разведка", "action": func(): launch.call("scout")},
		{"text": "💰 Набег", "primary": true, "action": func(): launch.call("raid")},
		{"text": "⚔️ Атака", "action": func(): launch.call("attack")},
	])
