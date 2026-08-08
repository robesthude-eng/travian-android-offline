extends Control

## The 18 resource fields, laid out as the classic ring around the village.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

var _root: Control
var _ring: Control
var _field_buttons: Array = []
var _queue_box: VBoxContainer
var _prod_label: Label


func setup(root: Control) -> void:
	_root = root


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_field_buttons.clear()

	var col := Style.vbox(10)

	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(0, 380)
	_ring.resized.connect(_layout_ring)
	col.add_child(_ring)

	var v := G.village()
	for i in range(18):
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		b.add_theme_font_size_override("font_size", Style.FONT_S)
		var idx := i
		b.pressed.connect(func(): _open_field(idx))
		_ring.add_child(b)
		_field_buttons.append(b)

	var centre := Style.panel(Style.PANEL_LIGHT, 40, 2)
	centre.name = "Centre"
	centre.custom_minimum_size = Vector2(96, 96)
	var centre_col := Style.vbox(0)
	centre_col.alignment = BoxContainer.ALIGNMENT_CENTER
	var cl := Style.label("🏛️", Style.FONT_L)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_col.add_child(cl)
	var cl2 := Style.label("Центр", Style.FONT_S, Style.TEXT_DIM)
	cl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_col.add_child(cl2)
	centre.add_child(centre_col)
	_ring.add_child(centre)

	_prod_label = Style.wrapped("", Style.FONT_S, Style.TEXT_DIM)
	col.add_child(_prod_label)

	col.add_child(Style.separator())
	col.add_child(Style.label("Очередь строительства", Style.FONT_M, Style.ACCENT))
	_queue_box = Style.vbox(6)
	col.add_child(_queue_box)

	add_child(Style.scroll(Style.margin(col, 12)))
	_layout_ring()
	refresh()


func _layout_ring() -> void:
	if _ring == null or _field_buttons.is_empty():
		return
	var rect := _ring.size
	if rect.x <= 0.0:
		return
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
		b.text = "%s\n%d" % [T.RES_ICONS[res], lvl]
		var tint: Color = Style.RES_COLORS[res].darkened(0.45)
		if queued.has(i):
			tint = Style.WARN.darkened(0.35)
		b.add_theme_stylebox_override("normal", Style.flat(tint, 10, 2, Style.RES_COLORS[res]))
		b.add_theme_stylebox_override("hover", Style.flat(tint.lightened(0.12), 10, 2, Style.RES_COLORS[res]))
		b.add_theme_stylebox_override("pressed", Style.flat(tint.darkened(0.15), 10, 2, Style.RES_COLORS[res]))
		b.add_theme_color_override("font_color", Style.TEXT)

	var prod := Sim.production(G.state, v)
	var parts: Array = []
	for r in range(4):
		parts.append("%s %d/ч" % [T.RES_ICONS[r], int(prod[r] * G.speed())])
	_prod_label.text = "Добыча: " + "   ".join(parts)

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

		var panel := Style.panel(Style.PANEL_LIGHT, 10)
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
		panel.add_child(row)
		_queue_box.add_child(panel)


func _open_field(index: int) -> void:
	var v := G.village()
	var res: int = T.FIELD_LAYOUT[index]["res"]
	var level := int(v["fields"][index])
	var check := Actions.can_upgrade_field(G.state, v, index)

	var body := Style.vbox(8)
	body.add_child(Style.label("%s %s — уровень %d" % [
		T.RES_ICONS[res], T.RES_LABELS[res], level], Style.FONT_M))

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
