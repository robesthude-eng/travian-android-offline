extends Control

## Resource fields — fullscreen Kingdoms style, 18 fields on bright map

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
	for c: Node in get_children():
		c.queue_free()
	_field_buttons.clear()

	# Fullscreen background
	var bg_holder := Control.new()
	bg_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_holder)

	var tex := Art.fields_kingdoms_bg()
	if tex == null:
		tex = Art.resource_fields_bg()
	if tex:
		_ring_bg = Style.texture(tex, Vector2(1024, 1024))
		_ring_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_ring_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ring_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ring_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_holder.add_child(_ring_bg)

	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.resized.connect(_layout_ring)
	bg_holder.add_child(_ring)

	for i in range(18):
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
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
	var centre_panel := Style.panel(Color(0,0,0,0.35), 48, 0)
	centre_panel.custom_minimum_size = Vector2(96,96)
	centre_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre_col := Style.vbox(0)
	centre_col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := Style.label("Центр", 12, Color.WHITE)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_col.add_child(cl)
	var cl2 := Style.label("поля вокруг", 10, Color.WHITE)
	cl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_col.add_child(cl2)
	centre_panel.add_child(centre_col)
	centre.add_child(centre_panel)
	_ring.add_child(centre)

	# Bottom overlay - production and queue
	var overlay := Style.vbox(8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top = -180
	overlay.offset_bottom = -8
	overlay.offset_left = 8
	overlay.offset_right = -8
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var prod_card := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0,0,0,0.35)
	psb.corner_radius_top_left = 8
	psb.corner_radius_top_right = 8
	psb.corner_radius_bottom_left = 8
	psb.corner_radius_bottom_right = 8
	prod_card.add_theme_stylebox_override("panel", psb)
	var prod_inner := Style.vbox(4)
	prod_inner.add_child(Style.label("Добыча в час", 12, Color.WHITE))
	_prod_grid = GridContainer.new()
	_prod_grid.columns = 2
	_prod_grid.add_theme_constant_override("h_separation", 8)
	_prod_grid.add_theme_constant_override("v_separation", 4)
	for r in range(4):
		var cell := Style.hbox(4)
		cell.add_child(Style.res_icon_texture(r, 20))
		var col2 := Style.vbox(1)
		col2.add_child(Style.label(T.RES_LABELS[r], 11, Color.WHITE))
		col2.add_child(Style.label("0/ч", 10, Color.WHITE))
		cell.add_child(col2)
		_prod_grid.add_child(cell)
	prod_inner.add_child(_prod_grid)
	prod_card.add_child(Style.margin(prod_inner, 8))
	overlay.add_child(prod_card)

	var queue_card := PanelContainer.new()
	var qsb := StyleBoxFlat.new()
	qsb.bg_color = Color(0,0,0,0.35)
	queue_card.add_theme_stylebox_override("panel", qsb)
	var q_inner := Style.vbox(4)
	q_inner.add_child(Style.label("Очередь строительства", 12, Color.WHITE))
	_queue_box = Style.vbox(4)
	q_inner.add_child(_queue_box)
	queue_card.add_child(Style.margin(q_inner, 8))
	overlay.add_child(queue_card)

	_layout_ring()
	refresh()

func _layout_ring() -> void:
	if _ring == null or _field_buttons.is_empty():
		return
	var rect: Vector2 = _ring.size
	if rect.x <= 0 or rect.y <= 0:
		return
	var centre_pos: Vector2 = rect * 0.5
	var radius: float = min(rect.x, rect.y) * 0.38
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
		var tex := Art.resource_icon(res)
		if tex:
			b.icon = tex
		b.text = str(lvl)
		var base_col: Color = Style.RES_COLORS[res].darkened(0.25)
		var border_col: Color = Style.RES_COLORS[res]
		if queued.has(i):
			base_col = Style.WARN.darkened(0.3)
			border_col = Style.WARN
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0,0,0,0.25) if not queued.has(i) else base_col
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.border_color = border_col
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.shadow_color = Color(0,0,0,0.4)
		sb.shadow_size = 4
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", Style.flat(Color(1,1,1,0.2), 12, 2, border_col.lightened(0.2)))
		b.add_theme_stylebox_override("pressed", Style.flat(Color(0,0,0,0.4), 12, 2, border_col))
		b.add_theme_color_override("font_color", Color.WHITE)
		if lvl == 0:
			b.modulate = Color(1,1,1,0.85)
		else:
			b.modulate = Color.WHITE
	if _prod_grid:
		var prod := Sim.production(G.state, v)
		for r in range(4):
			var cell := _prod_grid.get_child(r)
			if cell is HBoxContainer:
				var vbox := cell.get_child(1) as VBoxContainer
				if vbox and vbox.get_child_count() >= 2:
					var val_label := vbox.get_child(0) as Label
					var prod_label := vbox.get_child(1) as Label
					var gross := float(prod[r]) * G.speed()
					val_label.text = "%s: %d/ч" % [T.RES_LABELS[r], int(gross)]
					prod_label.text = "%d сейчас" % int(v["res"][r])
					prod_label.add_theme_color_override("font_color", Color.WHITE)
	_refresh_queue(v)

func _refresh_queue(v: Dictionary) -> void:
	if _queue_box == null:
		return
	for c: Node in _queue_box.get_children():
		c.queue_free()
	if v["build_queue"].is_empty():
		_queue_box.add_child(Style.label("Пусто — можно строить.", 11, Color.WHITE))
		return
	for i in range(v["build_queue"].size()):
		var item: Dictionary = v["build_queue"][i]
		var title := ""
		if item["kind"] == "field":
			var res: int = T.FIELD_LAYOUT[int(item["index"])]["res"]
			title = "%s %s → %d ур." % [T.RES_ICONS[res], T.RES_LABELS[res], int(item["level"])]
		else:
			title = "%s → %d ур." % [T.building(item["id"]).get("label", item["id"]), int(item["level"])]
		var left: float = float(item["done"]) - float(G.state["t"])
		var row := Style.hbox(8)
		row.add_child(Style.label(title, 11, Color.WHITE))
		row.add_child(Style.label(G.fmt_time(left), 11, Color("ffab40")))
		_queue_box.add_child(row)

func _open_field(index: int) -> void:
	var v := G.village()
	var res: int = T.FIELD_LAYOUT[index]["res"]
	var level := int(v["fields"][index])
	var check := Actions.can_upgrade_field(G.state, v, index)
	var body := Style.vbox(8)
	var head := Style.hbox(10)
	var tex := Art.resource_icon(res)
	if tex:
		head.add_child(Style.texture(tex, Vector2(48,48)))
	head.add_child(Style.label("%s — уровень %d" % [T.RES_LABELS[res], level], Style.FONT_M, Color("3e2723")))
	body.add_child(head)
	body.add_child(Style.separator())
	var now_prod := T.field_production(res, level) * G.speed()
	var next_prod := T.field_production(res, min(20, level + 1)) * G.speed()
	body.add_child(Style.wrapped("Добыча: %d/ч → %d/ч" % [int(now_prod), int(next_prod)], Style.FONT_S, Style.GOOD))
	if level < 20:
		body.add_child(Style.label("Стоимость улучшения:", Style.FONT_S, Color("6d4c41")))
		body.add_child(Style.cost_row(check["cost"], v["res"]))
		body.add_child(Style.label("Время: %s" % G.fmt_time(float(check["time"])), Style.FONT_S, Color("6d4c41")))
	if not check["ok"] and String(check["reason"]) != "":
		body.add_child(Style.wrapped(String(check["reason"]), Style.FONT_S, Style.BAD))
	_root.show_modal("Ресурсное поле", body, [{"text": "Закрыть"}, {"text": "Улучшить", "primary": true, "disabled": not check["ok"], "action": func():
		if Actions.upgrade_field(G.state, G.village(), index):
			G.save()
			_root.close_modal()
			rebuild()}])
