extends Control

## World map — pannable 11x11 with art icons, parchment подложка

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const World := preload("res://game/scripts/core/World.gd")
const Bots := preload("res://game/scripts/core/Bots.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

const VIEW := 11

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

	# Header card
	var header := Style.parchment(12)
	var head_inner := Style.vbox(6)
	var nav := Style.hbox(6)
	_coord_label = Style.label("", Style.FONT_S, Style.TEXT_DIM)
	_coord_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_coord_label)
	var home := Style.button("⌂ К деревне", Style.FONT_S, false)
	home.custom_minimum_size = Vector2(96, 32)
	home.pressed.connect(func():
		var vv := G.village()
		_centre = Vector2i(int(vv["x"]), int(vv["y"]))
		_update_tiles())
	nav.add_child(home)
	head_inner.add_child(nav)
	head_inner.add_child(Style.wrapped("Исследуй мир: синие — оазисы, красные — лагеря, коричневые — соперники. Нажав — отправишь войска.", Style.FONT_XXS, Style.TEXT_DIM))
	header.add_child(Style.margin(head_inner, 12))
	col.add_child(header)

	# Map card with wood frame
	var map_card := Style.parchment(14)
	var map_inner := Style.vbox(8)
	var grid := GridContainer.new()
	grid.columns = VIEW
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in range(VIEW * VIEW):
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.add_theme_font_size_override("font_size", Style.FONT_M)
		b.clip_text = true
		b.expand_icon = true
		var idx := i
		b.pressed.connect(func(): _tap_tile(idx))
		grid.add_child(b)
		_tiles.append(b)
	map_inner.add_child(grid)
	# D-pad
	var pad := Style.hbox(6)
	for spec in [["◀", Vector2i(-4, 0)], ["▲", Vector2i(0, -4)],
			["▼", Vector2i(0, 4)], ["▶", Vector2i(4, 0)]]:
		var b := Style.outline_button(String(spec[0]), Style.FONT_M)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		var delta: Vector2i = spec[1]
		b.pressed.connect(func():
			_centre += delta
			_centre.x = clampi(_centre.x, -World.MAP_RADIUS, World.MAP_RADIUS)
			_centre.y = clampi(_centre.y, -World.MAP_RADIUS, World.MAP_RADIUS)
			_update_tiles())
		pad.add_child(b)
	map_inner.add_child(pad)
	map_card.add_child(Style.margin(map_inner, 10))
	col.add_child(map_card)

	# Movements card
	var moves_card := Style.parchment(12)
	var moves_inner := Style.vbox(6)
	moves_inner.add_child(Style.label("Походы", Style.FONT_M, Style.ACCENT))
	_moves_box = Style.vbox(6)
	moves_inner.add_child(_moves_box)
	moves_card.add_child(Style.margin(moves_inner, 12))
	col.add_child(moves_card)

	add_child(Style.scroll(Style.margin(col, 12)))
	_update_tiles()
	refresh()

func _object_at(x: int, y: int) -> Dictionary:
	for vil in G.state["villages"]:
		if int(vil["x"]) == x and int(vil["y"]) == y:
			return {"kind": "village", "ref": vil}
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
		var fill := Color("2a3322") # meadow
		var border := Color("1e261a")
		var text := ""
		var tex: Texture2D = null
		b.icon = null
		b.modulate = Color.WHITE

		if abs(x) > World.MAP_RADIUS or abs(y) > World.MAP_RADIUS:
			fill = Color("0f0a06")
			b.disabled = true
		else:
			b.disabled = false
			if obj.is_empty():
				# subtle variation for empty fields
				var noise := ((x*13 + y*37) % 5)
				fill = Color("2b3a24").lightened(noise*0.015 - 0.03)
				text = ""
			else:
				match obj["kind"]:
					"village":
						fill = Color("3d2e0f")
						border = Style.ACCENT
						tex = Art.building("main", 5)
						text = "🏛️" if tex == null else ""
						b.icon = tex
					"bot":
						var bot: Dictionary = obj["ref"]
						var tribe: String = bot.get("tribe", "romans")
						fill = Color("4a2a1a") if tribe == "romans" else Color("3a2e1a")
						border = Style.WARN if int(bot.get("wall",0))>0 else Color("5a3a1a")
						tex = Art.building("wall", max(1, int(bot.get("wall",1))))
						text = "🏚️" if tex==null else ""
						b.icon = tex
					"camp":
						fill = Color("4a1a1a")
						border = Style.BAD
						tex = Art.robber_camp()
						text = "💀" if tex==null else ""
						b.icon = tex
					"oasis":
						var o: Dictionary = obj["ref"]
						var res: int = int(o["res"])
						fill = Style.RES_COLORS[res].darkened(0.6)
						border = Style.RES_COLORS[res]
						tex = Art.oasis()
						if tex:
							b.icon = tex
						else:
							text = T.RES_ICONS[res]
						if int(o.get("owner", -1)) >= 0:
							border = Style.GOOD
							fill = fill.lightened(0.12)
		b.text = text
		# Apply style with rounded corners
		var sb := Style.flat(fill, 6, 1, border)
		sb.shadow_size = 0
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", Style.flat(fill.lightened(0.18), 6, 1, Style.ACCENT))
		b.add_theme_stylebox_override("pressed", Style.flat(fill.darkened(0.2), 6, 1, border))
		b.add_theme_stylebox_override("disabled", Style.flat(Color("0f0a06"), 6, 1, Color("1a1208")))
		b.add_theme_color_override("font_color", Style.TEXT)
		b.add_theme_color_override("font_hover_color", Style.ACCENT_GLOW)
		# Centre tile highlight (your village or centre)
		if x == 0 and y == 0:
			b.add_theme_stylebox_override("normal", Style.flat(Color("3d2e0f").lightened(0.08), 6, 2, Style.ACCENT))

	_coord_label.text = "Центр: (%d | %d)  •  Кликай по клетке" % [_centre.x, _centre.y]

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
		var is_attack := incoming and String(m["kind"]) in ["attack","raid"]
		var panel_col := Color("4a2424") if is_attack else Style.PARCHMENT_LIGHT
		var panel := Style.panel(panel_col, 10, 1 if is_attack else 0)
		if is_attack:
			panel.add_theme_stylebox_override("panel", Style.flat(panel_col, 10, 1, Style.BAD))
		var col := Style.vbox(2)
		var head := ""
		if mine:
			var verb: String = {"raid": "Набег", "attack": "Атака", "scout": "Разведка",
				"settle": "Поселенцы", "reinforce": "Подкрепление"}.get(String(m["kind"]), "Поход")
			if bool(m.get("returning", false)):
				verb = "Возвращение"
			head = "%s → (%d|%d)" % [verb, int(m["to_x"]), int(m["to_y"])]
		else:
			head = "⚠ %s идёт на тебя!" % String(m.get("owner_name", "Враг"))
		col.add_child(Style.label(head, Style.FONT_S,
				Style.BAD if is_attack else Style.TEXT))
		col.add_child(Style.label("Прибытие %s   •   %d воинов" % [
			G.fmt_time(eta), Sim.troops_count(m["troops"])], Style.FONT_S, Style.TEXT_DIM))
		panel.add_child(Style.margin(col, 8))
		_moves_box.add_child(panel)
		if _moves_box.get_child_count() >= 4:
			break
	for tr in G.state["trades"]:
		any = true
		var eta2: float = float(tr["arrive"]) - float(G.state["t"])
		var panel2 := Style.panel(Style.PARCHMENT_LIGHT, 10)
		var lbl := "🚚 Караван" + (" (возврат)" if bool(tr.get("returning", false)) else "")
		var col2 := Style.vbox(2)
		col2.add_child(Style.label(lbl, Style.FONT_S))
		col2.add_child(Style.label("Через %s" % G.fmt_time(eta2), Style.FONT_S, Style.TEXT_DIM))
		panel2.add_child(Style.margin(col2, 8))
		_moves_box.add_child(panel2)
	if not any:
		_moves_box.add_child(Style.label("Никто никуда не идёт. Открой лагеря и оазисы!", Style.FONT_S, Style.TEXT_DIM))

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
	var head := Style.hbox(8)
	# add icon if available
	var title := "Пустая земля"
	var target := {"kind": "pos", "x": x, "y": y, "id": -1}
	var can_attack := false
	if obj.is_empty():
		head.add_child(Style.label("🌿 (%d | %d)" % [x,y], Style.FONT_L, Style.TEXT))
		var dist_label := Style.label("Расстояние %.1f полей" % dist, Style.FONT_S, Style.TEXT_DIM)
		body.add_child(head)
		body.add_child(dist_label)
		body.add_child(Style.wrapped("Здесь можно основать деревню, если есть поселенцы и культура.", Style.FONT_S, Style.TEXT_DIM))
	else:
		var ref: Dictionary = obj["ref"]
		target["id"] = int(ref.get("id", -1))
		match obj["kind"]:
			"village":
				title = String(ref["name"])
				target["kind"] = "village"
				var tex := Art.building("main", 5)
				if tex: head.add_child(Style.texture(tex, Vector2(56,56)))
				head.add_child(Style.label("🏛️ %s" % title, Style.FONT_L, Style.ACCENT))
				body.add_child(head)
				body.add_child(Style.label("Твоя деревня. Население %d." % Sim.population(ref),
						Style.FONT_S, Style.GOOD))
			"bot":
				title = String(ref["name"])
				target["kind"] = "bot"
				can_attack = true
				var tex2 := Art.building("wall", 3)
				if tex2: head.add_child(Style.texture(tex2, Vector2(48,48)))
				head.add_child(Style.label("🏚️ %s" % title, Style.FONT_L, Style.WARN))
				body.add_child(head)
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
				var tex3 := Art.robber_camp()
				if tex3: head.add_child(Style.texture(tex3, Vector2(64,40)))
				head.add_child(Style.label("💀 %s" % title, Style.FONT_L, Style.BAD))
				body.add_child(head)
				body.add_child(Style.label("Награда: %s" % _fmt_res(ref["reward"]),
						Style.FONT_S, Style.GOOD))
				body.add_child(Style.label("Опыт герою: %d" % int(ref["xp"]),
						Style.FONT_S, Style.TEXT_DIM))
				body.add_child(Style.label("Защитники: %s" % _fmt_troops(ref["troops"]),
						Style.FONT_S, Style.TEXT_DIM))
			"oasis":
				var res: int = int(ref["res"])
				title = "Оазис +%d%% %s" % [int(float(ref["pct"]) * 100.0),
						T.RES_LABELS[res]]
				target["kind"] = "oasis"
				can_attack = true
				var tex4 := Art.oasis()
				if tex4: head.add_child(Style.texture(tex4, Vector2(48,48)))
				head.add_child(Style.label("%s %s" % [T.RES_ICONS[res], title], Style.FONT_M, Style.GOOD))
				body.add_child(head)
				var owner := int(ref.get("owner", -1))
				body.add_child(Style.label(
					"Свободен" if owner < 0 else "Принадлежит тебе",
					Style.FONT_S, Style.TEXT_DIM if owner < 0 else Style.GOOD))
				body.add_child(Style.label("Стража: %s" % _fmt_troops(ref["troops"]),
						Style.FONT_S, Style.TEXT_DIM))
		if not obj.is_empty():
			body.add_child(Style.separator())
			body.add_child(Style.label("Расстояние от %s: %.1f полей • Время в пути зависит от войск" % [v["name"], dist],
					Style.FONT_XXS, Style.TEXT_DIM))

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
	_root.show_modal(title if not obj.is_empty() else "Пустая земля (%d|%d)" % [x,y], body, buttons)

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

func _open_send_dialog(target: Dictionary) -> void:
	var v := G.village()
	var body := Style.vbox(8)
	var spins := {}
	if v["troops"].is_empty():
		body.add_child(Style.wrapped("Дома нет войск. Обучи их в казарме (Деревня → Казарма).",
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
			var tex := Art.unit(id)
			if tex:
				row.add_child(Style.texture(tex, Vector2(36,36)))
			row.add_child(Style.label("%s (%d)" % [u.get("label", id), have], Style.FONT_S))
			row.add_child(Style.spacer())
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = have
			spin.step = 1
			spin.value = 0
			spin.custom_minimum_size = Vector2(110, 0)
			row.add_child(spin)
			var all_btn := Style.outline_button("Все", Style.FONT_S)
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
