extends Control

## Resource fields — now with real art, parchment подложка and hourly display

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

var _root: Control
var _ring: Control
var _ring_bg: TextureRect
var _field_buttons: Array = []
var _queue_box: VBoxContainer
var _prod_grid: GridContainer

func setup(root: Control) -> void:
	_root = root

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_field_buttons.clear()

	var col := Style.vbox(12)

	# Header parchment card
	var header_card := Style.parchment(14)
	var header_inner := Style.vbox(6)
	header_inner.add_child(Style.label("Ресурсные поля", Style.FONT_L, Style.ACCENT))
	header_inner.add_child(Style.wrapped("Качай поля — основа экономики. Каждый уровень даёт больше в час. Центр деревни в середине.", Style.FONT_S, Style.TEXT_DIM))
	header_card.add_child(Style.margin(header_inner, 14))
	col.add_child(header_card)

	# Ring card with parchment + subtle field bg
	var ring_card := Style.parchment(16)
	ring_card.custom_minimum_size = Vector2(0, 400)
	var ring_holder := Control.new()
	ring_holder.custom_minimum_size = Vector2(0, 380)
	ring_holder.clip_contents = true
	ring_card.add_child(ring_holder)

	# subtle background texture if exists
	var tex := Art.resource_fields_bg()
	if tex:
		_ring_bg = Style.texture(tex, Vector2(0,0))
		_ring_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_ring_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ring_bg.modulate = Color(1,1,1,0.08)
		_ring_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ring_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring_holder.add_child(_ring_bg)
	# vignette overlay
	var vignette := ColorRect.new()
	vignette.color = Color(0,0,0,0.06)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_holder.add_child(vignette)

	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(0, 380)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.resized.connect(_layout_ring)
	ring_holder.add_child(_ring)

	for i in range(18):
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 62)
		b.add_theme_font_size_override("font_size", Style.FONT_S)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		var idx := i
		b.pressed.connect(func(): _open_field(idx))
		_ring.add_child(b)
		_field_buttons.append(b)

	var centre := Control.new()
	centre.name = "Centre"
	centre.custom_minimum_size = Vector2(96, 96)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre_panel := Style.panel(Style.PARCHMENT_LIGHT, 48, 1)
	centre_panel.custom_minimum_size = Vector2(96,96)
	centre_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre_col := Style.vbox(0)
	centre_col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := Style.label("🏛️ Центр", Style.FONT_M, Style.ACCENT)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_col.add_child(cl)
	var prod_hint := Style.label("поля вокруг", Style.FONT_XXS, Style.TEXT_DIM)
	prod_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_col.add_child(prod_hint)
	centre_panel.add_child(centre_col)
	centre.add_child(centre_panel)
	_ring.add_child(centre)

	col.add_child(ring_card)

	# Production grid (4 resources with hourly)
	var prod_card := Style.parchment(12)
	var prod_inner := Style.vbox(8)
	prod_inner.add_child(Style.label("Добыча в час", Style.FONT_M, Style.ACCENT))
	_prod_grid = GridContainer.new()
	_prod_grid.columns = 2
	_prod_grid.add_theme_constant_override("h_separation", 12)
	_prod_grid.add_theme_constant_override("v_separation", 8)
	prod_inner.add_child(_prod_grid)
	# create 4 cells placeholders
	for r in range(4):
		var cell := Style.hbox(6)
		var icon_holder := Style.res_badge(r, 28)
		cell.add_child(icon_holder)
		var col2 := Style.vbox(1)
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col2.add_child(Style.label(T.RES_LABELS[r], Style.FONT_S, Style.TEXT))
		col2.add_child(Style.label("0/ч", Style.FONT_XXS, Style.TEXT_DIM))
		cell.add_child(col2)
		_prod_grid.add_child(cell)
	prod_card.add_child(Style.margin(prod_inner, 12))
	col.add_child(prod_card)

	# Queue
	var queue_card := Style.parchment(12)
	var q_inner := Style.vbox(8)
	q_inner.add_child(Style.label("Очередь строительства", Style.FONT_M, Style.ACCENT))
	_queue_box = Style.vbox(6)
	q_inner.add_child(_queue_box)
	queue_card.add_child(Style.margin(q_inner, 12))
	col.add_child(queue_card)

	add_child(Style.scroll(Style.margin(col, 12)))
	_layout_ring()
	refresh()

func _layout_ring() -> void:
	if _ring == null or _field_buttons.is_empty():
		return
	var rect := _ring.get_parent().size
	# _ring size is 380, centre is holder size
	if rect.x <= 0:
		rect = Vector2(360, 380)
	var centre_pos := rect * 0.5
	var radius: float = min(rect.x, rect.y) * 0.44
	for i in range(18):
		var spec: Dictionary = T.FIELD_LAYOUT[i]
		var ang: float = deg_to_rad(float(spec["ang"]))
		var r: float = radius * float(spec["r"])
		var b: Button = _field_buttons[i]
		b.position = centre_pos + Vector2(cos(ang), sin(ang)) * r - b.custom_minimum_size * 0.5
	var centre := _ring.get_node_or_null("Centre")
	if centre:
		centre.position = centre_pos - Vector2(48, 48)

func refresh() -> void:
	var v := G.village()
	if v.is_empty() or _field_buttons.is_empty():
		return
	var queued := {}
	for item in v["build_queue"]:
		if item["kind"] == "field":
			queued[int(item["index"])] = true

	for i in range(18):
		var res: int = T.FIELD_LAYOUT[i]["res"]
		var lvl := int(v["fields"][i])
		var b: Button = _field_buttons[i]
		var tex := Art.field_icon(res)
		if tex:
			b.icon = tex
		else:
			b.text = T.RES_ICONS[res]
		# Show level as badge overlay via text (bottom)
		b.text = str(lvl)
		# Style per resource + queued
		var base_col: Color = Style.RES_COLORS[res].darkened(0.55)
		var border_col: Color = Style.RES_COLORS[res].lightened(0.15)
		if queued.has(i):
			base_col = Style.WARN.darkened(0.5)
			border_col = Style.WARN
		var lvl_color := Style.ACCENT if lvl >= 10 else Style.TEXT
		b.add_theme_stylebox_override("normal", Style.flat(base_col, 14, 2, border_col))
		b.add_theme_stylebox_override("hover", Style.flat(base_col.lightened(0.15), 14, 2, border_col.lightened(0.2)))
		b.add_theme_stylebox_override("pressed", Style.flat(base_col.darkened(0.18), 14, 2, border_col))
		b.add_theme_color_override("font_color", lvl_color)
		# icon modulate slightly
		if lvl == 0:
			b.modulate = Color(1,1,1,0.7)

	# Production grid update
	if _prod_grid:
		var prod := Sim.production(G.state, v)
		var upkeep := Sim.population(v) + Sim.troop_upkeep(v)
		for r in range(4):
			var cell := _prod_grid.get_child(r)
			if cell is HBoxContainer:
				var vbox := cell.get_child(1) as VBoxContainer
				if vbox and vbox.get_child_count() >= 2:
					var val_label := vbox.get_child(0) as Label
					var prod_label := vbox.get_child(1) as Label
					var gross := float(prod[r]) * G.speed()
					var net := gross
					if r == T.CR:
						net = gross - float(upkeep)
					val_label.text = "%s: %d/ч" % [T.RES_LABELS[r], int(gross)]
					prod_label.text = "%s %+d/ч  • %d сейчас" % [T.RES_ICONS[r], int(net if r==T.CR else gross), int(v["res"][r])]
					prod_label.add_theme_color_override("font_color", Style.GOOD if net >= 0 else Style.BAD)

	_refresh_queue(v)

func _refresh_queue(v: Dictionary) -> void:
	if _queue_box == null:
		return
	for c in _queue_box.get_children():
		c.queue_free()
	if v["build_queue"].is_empty():
		_queue_box.add_child(Style.label("Пусто — можно строить.", Style.FONT_S, Style.TEXT_DIM))
		return
	for i in range(v["build_queue"].size()):
		var item: Dictionary = v["build_queue"][i]
		var title := ""
		if item["kind"] == "field":
			var res: int = T.FIELD_LAYOUT[int(item["index"])]["res"]
			title = "%s %s → %d ур." % [T.RES_ICONS[res], T.RES_LABELS[res], int(item["level"])]
		else:
			title = "%s → %d ур." % [
				T.building(item["id"]).get("label", item["id"]), int(item["level"])]
		var left: float = float(item["done"]) - float(G.state["t"])
		var panel := Style.panel(Style.PARCHMENT_LIGHT, 10, 1)
		var row := Style.hbox(8)
		var info := Style.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Style.label(title, Style.FONT_S))
		info.add_child(Style.label(G.fmt_time(left), Style.FONT_S, Style.ACCENT))
		row.add_child(info)
		var cancel := Style.button("✕", Style.FONT_S, false)
		cancel.custom_minimum_size = Vector2(40, 36)
		var idx := i
		cancel.pressed.connect(func():
			Actions.cancel_build(G.state, G.village(), idx)
			G.save()
			rebuild())
		row.add_child(cancel)
		panel.add_child(Style.margin(row, 10))
		_queue_box.add_child(panel)

func _open_field(index: int) -> void:
	var v := G.village()
	var res: int = T.FIELD_LAYOUT[index]["res"]
	var level := int(v["fields"][index])
	var check := Actions.can_upgrade_field(G.state, v, index)

	var body := Style.vbox(8)
	var head := Style.hbox(10)
	var tex := Art.field_icon(res)
	if tex:
		head.add_child(Style.texture(tex, Vector2(64,64)))
	var head_col := Style.vbox(4)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_child(Style.label("%s — уровень %d" % [T.RES_LABELS[res], level], Style.FONT_M, Style.ACCENT))
	head_col.add_child(Style.wrapped(T.RES_LABELS[res] + " поле. Чем выше уровень, тем больше даёт в час.", Style.FONT_S, Style.TEXT_DIM))
	head.add_child(head_col)
	body.add_child(head)
	body.add_child(Style.separator())
	var now_prod := T.field_production(res, level) * G.speed()
	var next_prod := T.field_production(res, min(20, level + 1)) * G.speed()
	body.add_child(Style.wrapped("Добыча: %d/ч → %d/ч" % [int(now_prod), int(next_prod)],
			Style.FONT_S, Style.GOOD))
	if level < 20:
		body.add_child(Style.label("Стоимость улучшения:", Style.FONT_S, Style.TEXT_DIM))
		body.add_child(Style.cost_row(check["cost"], v["res"]))
		body.add_child(Style.label("Время: %s" % G.fmt_time(float(check["time"])),
				Style.FONT_S, Style.TEXT_DIM))
	if not check["ok"] and String(check["reason"]) != "":
		body.add_child(Style.wrapped(String(check["reason"]), Style.FONT_S, Style.BAD))
	_root.show_modal("Ресурсное поле", body, [
		{"text": "Закрыть"},
		{"text": "Улучшить", "primary": true, "disabled": not check["ok"], "action": func():
			if Actions.upgrade_field(G.state, G.village(), index):
				G.save()
				_root.close_modal()
				rebuild()},
	])
