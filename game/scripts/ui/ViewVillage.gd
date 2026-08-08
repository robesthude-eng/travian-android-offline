extends Control
## Village - fullscreen Kingdoms style, building sprites directly on beige circles

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

# Portrait layout - percentages of 768x1376 image, without wall
# 22 small + 1 large central, derived from Hough detection
const LAYOUT := [
	{"x": 0.4970, "y": 0.4750}, # 0 main large
	{"x": 0.1745, "y": 0.4578}, # 1
	{"x": 0.3281, "y": 0.4564}, # 2
	{"x": 0.2240, "y": 0.3968}, # 3
	{"x": 0.3099, "y": 0.3503}, # 4
	{"x": 0.4245, "y": 0.4070}, # 5
	{"x": 0.4219, "y": 0.3270}, # 6
	{"x": 0.5807, "y": 0.3270}, # 7
	{"x": 0.5781, "y": 0.4084}, # 8
	{"x": 0.6901, "y": 0.3517}, # 9
	{"x": 0.7786, "y": 0.3983}, # 10
	{"x": 0.6719, "y": 0.4564}, # 11
	{"x": 0.8255, "y": 0.5422}, # 12
	{"x": 0.6693, "y": 0.5407}, # 13
	{"x": 0.7760, "y": 0.6003}, # 14
	{"x": 0.6875, "y": 0.6453}, # 15
	{"x": 0.5781, "y": 0.5887}, # 16
	{"x": 0.5781, "y": 0.6715}, # 17
	{"x": 0.4219, "y": 0.6701}, # 18
	{"x": 0.4219, "y": 0.5887}, # 19
	{"x": 0.3099, "y": 0.6468}, # 20
	{"x": 0.2266, "y": 0.6003}, # 21 wall
]

func setup(root: Control) -> void:
	_root = root

func rebuild() -> void:
	for c: Node in get_children():
		c.queue_free()
	_slot_buttons.clear()

	# Fullscreen background
	var bg_holder := Control.new()
	bg_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_holder)

	var bg_tex := Art.village_kingdoms_bg()
	if bg_tex == null:
		bg_tex = Art.village_center_bg()
	if bg_tex:
		_bg_texture = Style.texture(bg_tex, Vector2(720, 1280))
		_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_holder.add_child(_bg_texture)

	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_holder.add_child(_ring)

	for i in range(T.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64) if i != T.SLOT_MAIN else Vector2(88, 88)
		b.expand_icon = true
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		var idx := i
		b.pressed.connect(func(): _open_slot(idx))
		_ring.add_child(b)
		_slot_buttons.append(b)

	# Top overlay - village info (semi-transparent)
	var top_panel := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0, 0, 0, 0.35)
	tsb.corner_radius_top_left = 8
	tsb.corner_radius_top_right = 8
	tsb.corner_radius_bottom_left = 8
	tsb.corner_radius_bottom_right = 8
	top_panel.add_theme_stylebox_override("panel", tsb)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_top = 8
	top_panel.offset_bottom = 56
	top_panel.offset_left = 8
	top_panel.offset_right = -8
	var top_row := Style.hbox(8)
	_summary = Style.label("", 12, Color.WHITE)
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_summary)
	top_panel.add_child(Style.margin(top_row, 6))
	add_child(top_panel)

	# Bottom actions as overlay
	var bottom_panel := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0.35)
	bottom_panel.add_theme_stylebox_override("panel", bsb)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -56
	bottom_panel.offset_bottom = -8
	bottom_panel.offset_left = 8
	bottom_panel.offset_right = -8
	var actions_row := Style.hbox(8)
	var festival := Style.button("🎪", 12, false)
	festival.custom_minimum_size = Vector2(48, 36)
	festival.pressed.connect(_open_festival)
	actions_row.add_child(festival)
	var settle := Style.button("🚩", 12, false)
	settle.custom_minimum_size = Vector2(48, 36)
	settle.pressed.connect(_open_settle)
	actions_row.add_child(settle)
	actions_row.add_child(Style.spacer())
	bottom_panel.add_child(Style.margin(actions_row, 6))
	add_child(bottom_panel)

	_layout_ring()
	refresh()

func _layout_ring() -> void:
	if _ring == null or _slot_buttons.is_empty():
		return
	var rect: Vector2 = _ring.size
	if rect.x <= 0 or rect.y <= 0:
		return
	for i in range(min(T.SLOT_COUNT, LAYOUT.size())):
		var b: Button = _slot_buttons[i]
		var pos: Dictionary = LAYOUT[i]
		var px: float = float(pos["x"]) * rect.x
		var py: float = float(pos["y"]) * rect.y
		b.position = Vector2(px, py) - b.custom_minimum_size * 0.5

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
		for child: Node in b.get_children():
			if child.name == "LvlBadge":
				child.queue_free()
		var is_empty := id == "" or lvl == 0
		var sb_normal: StyleBoxFlat
		var sb_hover: StyleBoxFlat
		var sb_pressed: StyleBoxFlat
		if is_empty:
			b.icon = Art.construction_site() if queued.has(i) else null
			if queued.has(i):
				b.text = ""
			else:
				b.text = ""
				b.add_theme_color_override("font_color", Color.TRANSPARENT)
			b.tooltip_text = "Свободный слот %d" % i
			if i == T.SLOT_WALL:
				b.text = ""
			# Empty: invisible button, only beige circle from background visible
			sb_normal = Style.flat(Color(0,0,0,0), 12, 0, Color.TRANSPARENT)
			sb_hover = Style.flat(Color(1,1,1,0.15), 12, 0, Color.WHITE)
			sb_hover.shadow_color = Color(1,1,1,0.5)
			sb_hover.shadow_size = 4
			sb_pressed = Style.flat(Color(1,1,1,0.25), 12, 0, Color.WHITE)
		else:
			var tex := Art.building(id, lvl)
			if tex:
				b.icon = tex
				b.text = ""
			else:
				b.icon = null
				b.text = T.building(id).get("icon", "🏠")
				b.add_theme_color_override("font_color", Color.WHITE)
			b.tooltip_text = "%s — %d ур." % [T.building(id).get("label", id), lvl]
			sb_normal = Style.flat(Color(0,0,0,0), 12, 0, Color.TRANSPARENT)
			sb_normal.shadow_color = Color(0,0,0,0.45)
			sb_normal.shadow_size = 8
			sb_normal.shadow_offset = Vector2(2,3)
			sb_hover = Style.flat(Color(1,1,1,0.12), 12, 0, Color.TRANSPARENT)
			sb_pressed = Style.flat(Color(1,1,1,0.2), 12, 0, Color.TRANSPARENT)
			var badge := PanelContainer.new()
			badge.name = "LvlBadge"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color("ff6f00") if lvl >= 10 else Color("2e2014")
			bsb.corner_radius_top_left = 8
			bsb.corner_radius_top_right = 8
			bsb.corner_radius_bottom_left = 8
			bsb.corner_radius_bottom_right = 8
			bsb.border_color = Color("ffd54f") if lvl >= 10 else Color("8d6e63")
			bsb.border_width_left = 1
			bsb.border_width_right = 1
			bsb.border_width_top = 1
			bsb.border_width_bottom = 1
			bsb.content_margin_left = 4
			bsb.content_margin_right = 4
			bsb.content_margin_top = 1
			bsb.content_margin_bottom = 1
			badge.add_theme_stylebox_override("panel", bsb)
			var lbl := Label.new()
			lbl.text = str(lvl)
			lbl.add_theme_font_size_override("font_size", 11 if i != T.SLOT_MAIN else 13)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_child(lbl)
			badge.custom_minimum_size = Vector2(22, 18) if i != T.SLOT_MAIN else Vector2(28, 22)
			badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.offset_left = -24 if i != T.SLOT_MAIN else -30
			badge.offset_top = -18 if i != T.SLOT_MAIN else -22
			badge.offset_right = -4
			badge.offset_bottom = -4
			b.add_child(badge)
		b.add_theme_stylebox_override("normal", sb_normal)
		b.add_theme_stylebox_override("hover", sb_hover)
		b.add_theme_stylebox_override("pressed", sb_pressed)
	if _summary:
		var cp := Sim.culture_rate(v) * G.speed()
		_summary.text = "👥%d ⭐%d (+%d/ч)" % [Sim.population(v), int(v["cp"]), int(cp)]

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
		body.add_child(Style.label("Время: %s   •   Население: +%d" % [G.fmt_time(float(check["time"])), int(b["pop"])], Style.FONT_S, Style.TEXT_DIM))
	else:
		body.add_child(Style.label("Максимальный уровень.", Style.FONT_S, Style.GOOD))
	if not check["ok"] and String(check["reason"]) != "":
		body.add_child(Style.wrapped(String(check["reason"]), Style.FONT_S, Style.BAD))
	var buttons := [{"text": "Закрыть"}]
	buttons.append({"text": "Строить", "primary": true, "disabled": not check["ok"], "action": func():
		if Actions.build(G.state, G.village(), index, id):
			G.save()
			_root.close_modal()
			rebuild()})
	_root.show_modal(String(b.get("label", id)), body, buttons)

func _show_picker(index: int) -> void:
	var v := G.village()
	var body := Style.vbox(6)
	body.add_child(Style.wrapped("Слот %d. Выбери, что построить." % index, Style.FONT_S, Style.TEXT_DIM))
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
		var panel := Style.panel(Color.WHITE, 10, 1)
		var row := Style.hbox(8)
		var tex := Art.building(id, 1)
		if tex:
			row.add_child(Style.texture(tex, Vector2(48, 48)))
		var info := Style.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Style.label(String(b.get("label", id)), Style.FONT_S, Color("3e2723")))
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
	body.add_child(Style.wrapped("Праздники дают культуру разом.", Style.FONT_S, Style.TEXT_DIM))
	for big: bool in [false, true]:
		var check := Actions.can_celebrate(G.state, v, big)
		var panel := Style.panel(Color.WHITE, 10, 1)
		var col := Style.vbox(4)
		col.add_child(Style.label("Большой праздник (+2000)" if big else "Малый праздник (+500)", Style.FONT_S, Color("3e2723")))
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
	body.add_child(Style.wrapped("Накопи культуру, построй Резиденцию 10 ур. и обучи 3 поселенцев.", Style.FONT_S, Style.TEXT_DIM))
	body.add_child(Style.label("Культура: %d / %d" % [int(Sim.total_culture(G.state)), T.cp_needed(G.village_count())], Style.FONT_S, Color("3e2723")))
	if not check["ok"]:
		body.add_child(Style.wrapped(String(check["reason"]), Style.FONT_S, Style.BAD))
	var spot := World.suggest_settle_spot(G.state)
	if check["ok"] and spot.x != 9999:
		body.add_child(Style.label("Свободное место: (%d|%d)" % [spot.x, spot.y], Style.FONT_S, Style.GOOD))
	_root.show_modal("Основание деревни", body, [{"text": "Закрыть"}, {"text": "Отправить", "primary": true, "disabled": not check["ok"] or spot.x == 9999, "action": func():
		var result := Actions.send_settlers(G.state, G.village(), spot.x, spot.y)
		_root.close_modal()
		if result["ok"]:
			G.save()
			_root.toast("Поселенцы в пути: %s" % G.fmt_time(float(result["eta"])))
		else:
			_root.toast(String(result["reason"]))}])
