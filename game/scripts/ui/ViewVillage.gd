extends Control

## Village centre — 22 slots over authentic backdrop, real building art

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

var _root: Control
var _ring: Control
var _slot_buttons: Array = []
var _summary: Label
var _bg_texture: TextureRect

func setup(root: Control) -> void:
	_root = root

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_slot_buttons.clear()

	var col := Style.vbox(12)

	# Header card
	var head_card := Style.parchment(14)
	var head_inner := Style.vbox(4)
	head_inner.add_child(Style.label("Деревня — центр", Style.FONT_L, Style.ACCENT))
	head_inner.add_child(Style.wrapped("Строй здания в слотах. Клик по свободному — выбрать постройку, по занятому — улучшить.", Style.FONT_S, Style.TEXT_DIM))
	head_card.add_child(Style.margin(head_inner, 14))
	col.add_child(head_card)

	# Ring holder with backdrop
	var ring_card := Style.parchment(16)
	var ring_holder := Control.new()
	ring_holder.custom_minimum_size = Vector2(0, 440)
	ring_holder.clip_contents = true
	ring_card.add_child(ring_holder)

	# Backdrop village image
	var bg_tex := Art.village_center_bg()
	if bg_tex:
		_bg_texture = Style.texture(bg_tex, Vector2(0,0))
		_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_texture.modulate = Color(1,1,1,0.18)
		_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring_holder.add_child(_bg_texture)
	# wood wall circular overlay
	var wall_ring := ColorRect.new()
	wall_ring.color = Color("3a2a14", 0.0)
	wall_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_holder.add_child(wall_ring)

	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(0, 440)
	_ring.resized.connect(_layout_ring)
	ring_holder.add_child(_ring)

	for i in range(T.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(60, 60)
		b.expand_icon = true
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		var idx := i
		b.pressed.connect(func(): _open_slot(idx))
		_ring.add_child(b)
		_slot_buttons.append(b)

	col.add_child(ring_card)

	# Summary card
	var sum_card := Style.parchment(12)
	var sum_inner := Style.vbox(6)
	_summary = Style.wrapped("", Style.FONT_S, Style.TEXT_DIM)
	sum_inner.add_child(_summary)
	var actions_row := Style.hbox(8)
	var festival := Style.button("🎪 Праздник", Style.FONT_S, false)
	festival.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	festival.pressed.connect(_open_festival)
	actions_row.add_child(festival)
	var settle := Style.button("🚩 Основать деревню", Style.FONT_S, false)
	settle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settle.pressed.connect(_open_settle)
	actions_row.add_child(settle)
	sum_inner.add_child(actions_row)
	sum_card.add_child(Style.margin(sum_inner, 12))
	col.add_child(sum_card)

	add_child(Style.scroll(Style.margin(col, 12)))
	_layout_ring()
	refresh()

func _layout_ring() -> void:
	if _ring == null or _slot_buttons.is_empty():
		return
	var rect := _ring.get_parent().size
	if rect.x <= 0:
		rect = Vector2(360, 440)
	var centre := rect * 0.5
	var radius: float = min(rect.x, rect.y) * 0.46
	for i in range(T.SLOT_COUNT):
		var spec: Dictionary = T.SLOT_LAYOUT[i]
		var ang: float = deg_to_rad(float(spec["ang"]))
		var r: float = radius * float(spec["r"])
		var b: Button = _slot_buttons[i]
		b.position = centre + Vector2(cos(ang), sin(ang)) * r - b.custom_minimum_size * 0.5
		# centre slot is bigger
		if i == T.SLOT_MAIN:
			b.custom_minimum_size = Vector2(72,72)
			b.position = centre - Vector2(36,36)

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
		var border := Style.PANEL_GOLD_BORDER if lvl > 0 else Color("3a2a14")
		var fill := Style.PARCHMENT_LIGHT if lvl > 0 else Color("2e2014")
		if queued.has(i):
			border = Style.WARN
			fill = Style.WARN.darkened(0.6)
		var is_empty := id == "" or lvl == 0
		if is_empty:
			b.icon = Art.construction_site() if queued.has(i) else null
			if queued.has(i):
				b.text = ""
			else:
				b.text = "＋"
				b.add_theme_color_override("font_color", Style.ACCENT_DIM)
			b.tooltip_text = "Свободный слот %d" % i
			if i == T.SLOT_WALL:
				b.text = "🧱"
				b.tooltip_text = T.TRIBES[v["tribe"]]["wall_label"]
		else:
			var tex := Art.building(id, lvl)
			if tex:
				b.icon = tex
				b.text = str(lvl)
				b.add_theme_color_override("font_color", Style.ACCENT_GLOW)
				# Add shadow for level badge via modulate
			else:
				b.icon = null
				b.text = "%s\n%d" % [T.building(id).get("icon", "🏠"), lvl]
				b.add_theme_color_override("font_color", Style.TEXT)
			b.tooltip_text = "%s — %d ур." % [T.building(id).get("label", id), lvl]
			# highlight high levels
			if lvl >= 10:
				border = Style.ACCENT
				fill = Style.PARCHMENT_LIGHT.lightened(0.05)

		# Apply stylebox
		var sb := Style.flat(fill, 12 if i != T.SLOT_MAIN else 16, 2, border)
		# add subtle shadow for depth
		sb.shadow_color = Color(0,0,0,0.25)
		sb.shadow_size = 4
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", Style.flat(fill.lightened(0.12), 12, 2, border.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", Style.flat(fill.darkened(0.18), 12, 2, border))

		if i == T.SLOT_MAIN:
			b.add_theme_font_size_override("font_size", 14)

	var cp := Sim.culture_rate(v) * G.speed()
	var slots_free := Sim.expansion_slots(G.state)
	_summary.text = "Население %d   •   Культура %d (+%d/ч)   •   Слотов: %d\nВсего культуры: %d / %d для следующей деревни" % [
		Sim.population(v), int(v["cp"]), int(cp), slots_free,
		int(Sim.total_culture(G.state)), T.cp_needed(G.village_count())]

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
		var panel := Style.panel(Style.PARCHMENT_LIGHT, 10, 1)
		var row := Style.hbox(8)
		var tex := Art.building(id, 1)
		if tex:
			row.add_child(Style.texture(tex, Vector2(48, 48)))
		var info := Style.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Style.label(String(b.get("label", id)), Style.FONT_S))
		info.add_child(Style.cost_row(T.building_cost(id, 1), v["res"]))
		if not check["ok"]:
			info.add_child(Style.label(String(check["reason"]), Style.FONT_XXS, Style.BAD))
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
		panel.add_child(Style.margin(row, 10))
		body.add_child(panel)
	_root.show_modal("Что построить?", body, [{"text": "Закрыть"}])

func _open_festival() -> void:
	var v := G.village()
	var body := Style.vbox(8)
	body.add_child(Style.wrapped(
		"Праздники дают культуру разом. Культура нужна, чтобы основывать новые деревни.",
		Style.FONT_S, Style.TEXT_DIM))
	for big: bool in [false, true]:
		var check := Actions.can_celebrate(G.state, v, big)
		var panel := Style.panel(Style.PARCHMENT_LIGHT, 10, 1)
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
		panel.add_child(Style.margin(col, 10))
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
