extends Control

## The village centre: 22 slots arranged in the classic two rings plus the wall.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

var _root: Control
var _ring: Control
var _slot_buttons: Array = []
var _summary: Label


func setup(root: Control) -> void:
	_root = root


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_slot_buttons.clear()

	var col := Style.vbox(10)

	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(0, 420)
	_ring.resized.connect(_layout_ring)
	col.add_child(_ring)

	for i in range(T.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 62)
		b.expand_icon = true
		b.add_theme_font_size_override("font_size", Style.FONT_S)
		b.clip_text = true
		var idx := i
		b.pressed.connect(func(): _open_slot(idx))
		_ring.add_child(b)
		_slot_buttons.append(b)

	_summary = Style.wrapped("", Style.FONT_S, Style.TEXT_DIM)
	col.add_child(_summary)

	var actions_row := Style.hbox(8)
	var festival := Style.button("🎪 Праздник", Style.FONT_S, false)
	festival.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	festival.pressed.connect(_open_festival)
	actions_row.add_child(festival)
	var settle := Style.button("🚩 Основать деревню", Style.FONT_S, false)
	settle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settle.pressed.connect(_open_settle)
	actions_row.add_child(settle)
	col.add_child(actions_row)

	add_child(Style.scroll(Style.margin(col, 12)))
	_layout_ring()
	refresh()


func _layout_ring() -> void:
	if _ring == null or _slot_buttons.is_empty():
		return
	var rect := _ring.size
	if rect.x <= 0.0:
		return
	var centre := rect * 0.5
	var radius: float = min(rect.x, rect.y) * 0.46

	for i in range(T.SLOT_COUNT):
		var spec: Dictionary = T.SLOT_LAYOUT[i]
		var ang: float = deg_to_rad(float(spec["ang"]))
		var r: float = radius * float(spec["r"])
		var b: Button = _slot_buttons[i]
		b.position = centre + Vector2(cos(ang), sin(ang)) * r - b.custom_minimum_size * 0.5


func refresh() -> void:
	var v := G.village()
	if v.is_empty() or _slot_buttons.is_empty():
		return

	var queued := {}
	for item in v["build_queue"]:
		if item["kind"] == "slot":
			queued[int(item["index"])] = int(item["level"])

	for i in range(T.SLOT_COUNT):
		var slot: Dictionary = v["slots"][i]
		var b: Button = _slot_buttons[i]
		var id: String = slot["id"]
		var lvl := int(slot["lvl"])

		var border := Style.ACCENT_DIM
		var fill := Style.PANEL_LIGHT
		if queued.has(i):
			border = Style.WARN
			fill = Style.WARN.darkened(0.55)

		if id == "" or lvl == 0:
			b.icon = Art.construction_site() if queued.has(i) else null
			b.text = "🔨" if not queued.has(i) else ""
			b.tooltip_text = "Свободный слот %d" % i
			if i == T.SLOT_WALL:
				b.text = "🧱"
				b.tooltip_text = T.TRIBES[v["tribe"]]["wall_label"]
		else:
			b.icon = Art.building(id, lvl)
			b.text = str(lvl)
			b.tooltip_text = "%s — %d ур." % [T.building(id).get("label", id), lvl]
			if b.icon == null:
				b.text = "%s\n%d" % [T.building(id).get("icon", "🏠"), lvl]

		b.add_theme_stylebox_override("normal", Style.flat(fill, 10, 2, border))
		b.add_theme_stylebox_override("hover", Style.flat(fill.lightened(0.12), 10, 2, border))
		b.add_theme_stylebox_override("pressed", Style.flat(fill.darkened(0.15), 10, 2, border))
		b.add_theme_color_override("font_color", Style.TEXT)

	var cp := Sim.culture_rate(v) * G.speed()
	var slots_free := Sim.expansion_slots(G.state)
	_summary.text = "Население %d   •   Культура %d (+%d/ч)   •   Слотов расширения: %d\nКультура всего: %d / %d для следующей деревни" % [
		Sim.population(v), int(v["cp"]), int(cp), slots_free,
		int(Sim.total_culture(G.state)), T.cp_needed(G.village_count())]


# ---------------------------------------------------------------------------
# Slot interaction
# ---------------------------------------------------------------------------

func _open_slot(index: int) -> void:
	var v := G.village()
	var slot: Dictionary = v["slots"][index]
	if slot["id"] != "" and int(slot["lvl"]) > 0:
		_show_upgrade(index, String(slot["id"]))
	elif index == T.SLOT_WALL:
		_show_upgrade(index, T.wall_id_for(v["tribe"]))
	else:
		_show_picker(index)


func _show_upgrade(index: int, id: String) -> void:
	var v := G.village()
	var b: Dictionary = T.building(id)
	var level := int(v["slots"][index]["lvl"])
	var check := Actions.can_build(G.state, v, index, id)

	var body := Style.vbox(8)
	var head := Style.hbox(10)
	var tex := Art.building(id, max(1, level))
	if tex:
		head.add_child(Style.texture(tex, Vector2(72, 72)))
	var head_col := Style.vbox(2)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_child(Style.label("%s — %d ур." % [b.get("label", id), level], Style.FONT_M))
	head_col.add_child(Style.wrapped(String(b.get("desc", "")), Style.FONT_S, Style.TEXT_DIM))
	head.add_child(head_col)
	body.add_child(head)

	body.add_child(Style.separator())
	if level < int(b["max"]):
		body.add_child(Style.label("Улучшение до %d ур.:" % int(check["level"]), Style.FONT_S))
		body.add_child(Style.cost_row(check["cost"], v["res"]))
		body.add_child(Style.label("Время: %s   •   Население: +%d" % [
			G.fmt_time(float(check["time"])), int(b["pop"])], Style.FONT_S, Style.TEXT_DIM))
	else:
		body.add_child(Style.label("Максимальный уровень.", Style.FONT_S, Style.GOOD))

	if not check["ok"] and String(check["reason"]) != "":
		body.add_child(Style.wrapped(String(check["reason"]), Style.FONT_S, Style.BAD))

	var buttons := [{"text": "Закрыть"}]
	buttons.append({"text": "Строить", "primary": true, "disabled": not check["ok"],
		"action": func():
			if Actions.build(G.state, G.village(), index, id):
				G.save()
				_root.close_modal()
				rebuild()})
	_root.show_modal(String(b.get("label", id)), body, buttons)


func _show_picker(index: int) -> void:
	var v := G.village()
	var body := Style.vbox(6)
	body.add_child(Style.wrapped("Слот %d. Выбери, что построить." % index,
			Style.FONT_S, Style.TEXT_DIM))

	var available: Array = []
	var locked: Array = []
	for id: String in T.buildable_ids(v["tribe"]):
		var check := Actions.can_build(G.state, v, index, id)
		if check["ok"]:
			available.append([id, check])
		else:
			locked.append([id, check])

	for entry in available + locked:
		var id: String = entry[0]
		var check: Dictionary = entry[1]
		var b: Dictionary = T.building(id)
		var panel := Style.panel(Style.PANEL_LIGHT, 10)
		var row := Style.hbox(8)
		var tex := Art.building(id, 1)
		if tex:
			row.add_child(Style.texture(tex, Vector2(48, 48)))
		var info := Style.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Style.label(String(b.get("label", id)), Style.FONT_S))
		info.add_child(Style.cost_row(T.building_cost(id, 1), v["res"]))
		if not check["ok"]:
			info.add_child(Style.label(String(check["reason"]), Style.FONT_S, Style.BAD))
		row.add_child(info)
		var pick := Style.button("＋", Style.FONT_M, check["ok"])
		pick.custom_minimum_size = Vector2(48, 40)
		pick.disabled = not check["ok"]
		var bid := id
		pick.pressed.connect(func():
			if Actions.build(G.state, G.village(), index, bid):
				G.save()
				_root.close_modal()
				rebuild())
		row.add_child(pick)
		panel.add_child(row)
		body.add_child(panel)

	_root.show_modal("Что построить?", body, [{"text": "Закрыть"}])


# ---------------------------------------------------------------------------
# Festivals and settling
# ---------------------------------------------------------------------------

func _open_festival() -> void:
	var v := G.village()
	var body := Style.vbox(8)
	body.add_child(Style.wrapped(
		"Праздники дают культуру разом. Культура нужна, чтобы основывать новые деревни.",
		Style.FONT_S, Style.TEXT_DIM))
	for big: bool in [false, true]:
		var check := Actions.can_celebrate(G.state, v, big)
		var panel := Style.panel(Style.PANEL_LIGHT, 10)
		var col := Style.vbox(4)
		col.add_child(Style.label(
			"Большой праздник (+2000 культуры)" if big else "Малый праздник (+500 культуры)",
			Style.FONT_S))
		col.add_child(Style.cost_row(Actions.festival_cost(big), v["res"]))
		if not check["ok"]:
			col.add_child(Style.label(String(check["reason"]), Style.FONT_S, Style.BAD))
		else:
			var go := Style.button("Праздновать", Style.FONT_S, true)
			var is_big := big
			go.pressed.connect(func():
				if Actions.celebrate(G.state, G.village(), is_big):
					G.save()
					_root.close_modal()
					rebuild())
			col.add_child(go)
		panel.add_child(col)
		body.add_child(panel)
	_root.show_modal("Ратуша", body, [{"text": "Закрыть"}])


func _open_settle() -> void:
	var World := preload("res://game/scripts/core/World.gd")
	var v := G.village()
	var check := Actions.can_settle(G.state, v)
	var body := Style.vbox(8)
	body.add_child(Style.wrapped(
		"Чтобы основать деревню: накопи культуру, построй Резиденцию 10 ур. "
		+ "и обучи 3 поселенцев в ней.", Style.FONT_S, Style.TEXT_DIM))
	body.add_child(Style.label("Культура: %d / %d" % [
		int(Sim.total_culture(G.state)), T.cp_needed(G.village_count())], Style.FONT_S))
	body.add_child(Style.label("Слоты расширения: %d" % Sim.expansion_slots(G.state), Style.FONT_S))
	body.add_child(Style.label("Поселенцев дома: %d / 3" % Actions.settlers_at_home(v), Style.FONT_S))
	if not check["ok"]:
		body.add_child(Style.wrapped(String(check["reason"]), Style.FONT_S, Style.BAD))

	var spot := World.suggest_settle_spot(G.state)
	if check["ok"] and spot.x != 9999:
		body.add_child(Style.label("Свободное место: (%d|%d)" % [spot.x, spot.y],
				Style.FONT_S, Style.GOOD))

	_root.show_modal("Основание деревни", body, [
		{"text": "Закрыть"},
		{"text": "Отправить поселенцев", "primary": true,
		 "disabled": not check["ok"] or spot.x == 9999, "action": func():
			var result := Actions.send_settlers(G.state, G.village(), spot.x, spot.y)
			_root.close_modal()
			if result["ok"]:
				G.save()
				_root.toast("Поселенцы в пути: %s" % G.fmt_time(float(result["eta"])))
			else:
				_root.toast(String(result["reason"]))},
	])
