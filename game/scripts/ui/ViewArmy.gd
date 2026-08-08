extends Control

## Barracks, stable, workshop and residence: training, the home garrison,
## and merchant runs between your own villages.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

const TRAINERS := ["barracks", "stable", "workshop", "residence"]

var _root: Control
var _garrison_box: VBoxContainer
var _queue_box: VBoxContainer


func setup(root: Control) -> void:
	_root = root


func rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var v := G.village()
	var col := Style.vbox(10)

	col.add_child(Style.label("Гарнизон", Style.FONT_M, Style.ACCENT))
	_garrison_box = Style.vbox(4)
	col.add_child(_garrison_box)

	col.add_child(Style.separator())
	col.add_child(Style.label("Очередь обучения", Style.FONT_M, Style.ACCENT))
	_queue_box = Style.vbox(4)
	col.add_child(_queue_box)

	col.add_child(Style.separator())
	for building_id in TRAINERS:
		var level := Sim.slot_level(v, building_id)
		var b: Dictionary = T.building(building_id)
		var panel := Style.panel(Style.PANEL, 12, 1)
		var inner := Style.vbox(6)
		inner.add_child(Style.label("%s %s" % [b.get("icon", ""), b.get("label", building_id)]
				+ (" — %d ур." % level if level > 0 else " — не построено"),
				Style.FONT_M, Style.TEXT if level > 0 else Style.TEXT_DIM))

		if level <= 0:
			inner.add_child(Style.label("Построй в деревне, чтобы обучать войска.",
					Style.FONT_S, Style.TEXT_DIM))
		else:
			var units := T.units_from_building(v["tribe"], building_id)
			units.sort()
			for unit_id in units:
				inner.add_child(_unit_row(v, unit_id))
		panel.add_child(Style.margin(inner, 10))
		col.add_child(panel)

	if Sim.slot_level(v, "marketplace") > 0 and G.village_count() > 1:
		col.add_child(Style.separator())
		var trade := Style.button("🚚 Отправить ресурсы в другую деревню", Style.FONT_M, false)
		trade.pressed.connect(_open_trade)
		col.add_child(trade)

	add_child(Style.scroll(Style.margin(col, 12)))
	refresh()


func _unit_row(v: Dictionary, unit_id: String) -> Control:
	var u: Dictionary = T.unit(unit_id)
	var check := Actions.can_train(G.state, v, unit_id, 1)

	var panel := Style.panel(Style.PANEL_LIGHT, 10)
	var row := Style.hbox(8)

	var tex := Art.unit(unit_id)
	if tex:
		row.add_child(Style.texture(tex, Vector2(44, 44)))

	var info := Style.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Style.label(String(u["label"]), Style.FONT_S))
	info.add_child(Style.label("⚔%d 🛡%d/%d  🐎%d  🎒%d  🌾%d" % [
		int(u["atk"]), int(u["di"]), int(u["dc"]), int(u["spd"]),
		int(u["carry"]), int(u["eat"])], Style.FONT_S, Style.TEXT_DIM))
	info.add_child(Style.cost_row(u["cost"], v["res"]))
	if not check["ok"] and String(check["reason"]) != "":
		info.add_child(Style.label(String(check["reason"]), Style.FONT_S, Style.BAD))
	row.add_child(info)

	var train_btn := Style.button("Обучить", Style.FONT_S, check["ok"])
	train_btn.custom_minimum_size = Vector2(84, 40)
	train_btn.disabled = not check["ok"]
	train_btn.pressed.connect(func(): _open_train(unit_id))
	row.add_child(train_btn)

	panel.add_child(row)
	return panel


func _open_train(unit_id: String) -> void:
	var v := G.village()
	var u: Dictionary = T.unit(unit_id)
	var most := Actions.max_affordable(G.state, v, unit_id)

	var body := Style.vbox(8)
	body.add_child(Style.label(String(u["label"]), Style.FONT_M))
	body.add_child(Style.label("Можешь позволить: %d" % most, Style.FONT_S, Style.TEXT_DIM))

	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = max(1, most)
	spin.step = 1
	spin.value = min(10, most)
	body.add_child(spin)

	var quick := Style.hbox(6)
	for n: int in [1, 5, 10, 50]:
		var b := Style.button(str(n), Style.FONT_S, false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count := n
		b.pressed.connect(func(): spin.value = min(count, most))
		quick.add_child(b)
	var all_btn := Style.button("Макс", Style.FONT_S, false)
	all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_btn.pressed.connect(func(): spin.value = most)
	quick.add_child(all_btn)
	body.add_child(quick)

	var preview := Style.label("", Style.FONT_S, Style.TEXT_DIM)
	body.add_child(preview)
	var update_preview := func():
		var n := int(spin.value)
		var c := Actions.can_train(G.state, G.village(), unit_id, n)
		preview.text = "Время: %s" % G.fmt_time(float(c.get("time", 0.0)))
	spin.value_changed.connect(func(_x): update_preview.call())
	update_preview.call()

	_root.show_modal("Обучение", body, [
		{"text": "Отмена"},
		{"text": "Обучить", "primary": true, "action": func():
			var n := int(spin.value)
			if Actions.train(G.state, G.village(), unit_id, n):
				G.save()
				_root.close_modal()
				rebuild()
			else:
				_root.toast("Не получилось — проверь ресурсы")},
	])


func refresh() -> void:
	var v := G.village()
	if v.is_empty() or _garrison_box == null:
		return

	for c in _garrison_box.get_children():
		c.queue_free()
	if v["troops"].is_empty():
		_garrison_box.add_child(Style.label("Пусто. Деревня беззащитна.",
				Style.FONT_S, Style.TEXT_DIM))
	else:
		var ids: Array = v["troops"].keys()
		ids.sort()
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		for id in ids:
			var u: Dictionary = T.unit(id)
			grid.add_child(Style.label("%s: %d" % [u.get("label", id), int(v["troops"][id])],
					Style.FONT_S))
		_garrison_box.add_child(grid)

	for c in _queue_box.get_children():
		c.queue_free()
	if v["train_queue"].is_empty():
		_queue_box.add_child(Style.label("Никого не обучаем.", Style.FONT_S, Style.TEXT_DIM))
	else:
		for item in v["train_queue"]:
			var u: Dictionary = T.unit(String(item["unit"]))
			var left: float = float(item["done"]) - float(G.state["t"])
			var total_left: float = left + float(item["each"]) * (int(item["left"]) - 1)
			_queue_box.add_child(Style.label("%s ×%d — следующий через %s, всего %s" % [
				u.get("label", item["unit"]), int(item["left"]),
				G.fmt_time(left), G.fmt_time(total_left)], Style.FONT_S))


func _open_trade() -> void:
	var v := G.village()
	var body := Style.vbox(8)
	var spins := []
	for r in range(4):
		var row := Style.hbox(8)
		row.add_child(Style.label("%s %s" % [T.RES_ICONS[r], T.RES_LABELS[r]], Style.FONT_S))
		row.add_child(Style.spacer())
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = max(0, int(v["res"][r]))
		spin.step = 10
		spin.custom_minimum_size = Vector2(130, 0)
		row.add_child(spin)
		body.add_child(row)
		spins.append(spin)

	body.add_child(Style.separator())
	body.add_child(Style.label("Куда:", Style.FONT_S, Style.TEXT_DIM))
	var picker := OptionButton.new()
	var targets: Array = []
	for other in G.state["villages"]:
		if int(other["id"]) == int(v["id"]):
			continue
		picker.add_item("%s (%d|%d)" % [other["name"], int(other["x"]), int(other["y"])])
		targets.append(int(other["id"]))
	body.add_child(picker)

	var free := Sim.merchants_total(v) - Sim.merchants_busy(G.state, int(v["id"]))
	body.add_child(Style.label("Свободных торговцев: %d" % free, Style.FONT_S, Style.TEXT_DIM))

	_root.show_modal("Отправка каравана", body, [
		{"text": "Отмена"},
		{"text": "Отправить", "primary": true, "action": func():
			if targets.is_empty():
				_root.close_modal()
				return
			var res := [float(spins[0].value), float(spins[1].value),
					float(spins[2].value), float(spins[3].value)]
			var to_id: int = targets[maxi(0, picker.selected)]
			var result := Actions.send_trade(G.state, G.village(), to_id, res)
			_root.close_modal()
			if result["ok"]:
				G.save()
				_root.toast("Караван вышел. Прибудет через %s" % G.fmt_time(float(result["eta"])))
			else:
				_root.toast(String(result["reason"]))},
	])
