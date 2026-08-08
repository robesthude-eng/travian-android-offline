extends Control

## Hero sheet: level, attribute points, equipment and the bag of loot.

const T := preload("res://game/scripts/core/Tables.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

const ATTRS := [
	["str", "Сила", "+0.5% атаки армии за очко"],
	["def", "Защита", "+0.5% защиты армии за очко"],
	["loot", "Добыча", "+1% к грабежу за очко"],
	["speed", "Скорость", "+1% к скорости похода за очко"],
]

var _root: Control


func setup(root: Control) -> void:
	_root = root


func rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var h: Dictionary = G.state["hero"]
	var col := Style.vbox(12)

	var head := Style.hbox(12)
	var portrait := Art.hero_portrait()
	if portrait:
		head.add_child(Style.texture(portrait, Vector2(96, 96)))
	var head_col := Style.vbox(4)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_child(Style.label("Герой — уровень %d" % int(h["level"]), Style.FONT_L, Style.ACCENT))
	head_col.add_child(Style.label(Hero.status_text(G.state), Style.FONT_S, Style.TEXT_DIM))
	head_col.add_child(Style.progress(float(h["xp"]), Hero.xp_for_next(h)))
	head_col.add_child(Style.label("Опыт: %d / %d" % [int(h["xp"]), int(Hero.xp_for_next(h))],
			Style.FONT_S, Style.TEXT_DIM))
	head.add_child(head_col)
	col.add_child(head)

	var mult := Hero.multipliers(G.state)
	col.add_child(Style.wrapped(
		"С героем армия бьёт на %d%% сильнее, держит удар на %d%% крепче, "
		% [int((mult["atk"] - 1.0) * 100.0), int((mult["def"] - 1.0) * 100.0)]
		+ "тащит на %d%% больше и идёт на %d%% быстрее."
		% [int(mult["loot"] * 100.0), int(mult["speed"] * 100.0)],
		Style.FONT_S, Style.TEXT_DIM))

	col.add_child(Style.separator())
	col.add_child(Style.label("Очков к распределению: %d" % int(h["points"]),
			Style.FONT_M, Style.ACCENT if int(h["points"]) > 0 else Style.TEXT_DIM))

	for spec in ATTRS:
		var key: String = spec[0]
		var row := Style.hbox(8)
		var info := Style.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Style.label("%s: %d" % [spec[1], int(h[key])], Style.FONT_S))
		info.add_child(Style.label(String(spec[2]), Style.FONT_S, Style.TEXT_DIM))
		row.add_child(info)
		var plus := Style.button("＋", Style.FONT_M, int(h["points"]) > 0)
		plus.custom_minimum_size = Vector2(52, 40)
		plus.disabled = int(h["points"]) <= 0
		plus.pressed.connect(func():
			if Hero.spend_point(G.state, key):
				G.save()
				rebuild())
		row.add_child(plus)
		col.add_child(row)

	col.add_child(Style.separator())
	col.add_child(Style.label("Снаряжение", Style.FONT_M, Style.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for slot in T.HERO_EQUIP_SLOTS:
		var panel := Style.panel(Style.PANEL_LIGHT, 10)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := Style.vbox(2)
		var equipped: String = String(h["equip"].get(slot, ""))
		if equipped == "":
			inner.add_child(Style.label(_slot_label(slot), Style.FONT_S, Style.TEXT_DIM))
			inner.add_child(Style.label("пусто", Style.FONT_S, Style.TEXT_DIM))
		else:
			var it: Dictionary = T.HERO_ITEMS[equipped]
			inner.add_child(Style.label("%s %s" % [it["icon"], it["label"]], Style.FONT_S))
			var off := Style.button("Снять", Style.FONT_S, false)
			off.custom_minimum_size = Vector2(0, 30)
			var s := slot
			off.pressed.connect(func():
				Hero.unequip(G.state, s)
				G.save()
				rebuild())
			inner.add_child(off)
		panel.add_child(inner)
		grid.add_child(panel)
	col.add_child(grid)

	col.add_child(Style.separator())
	col.add_child(Style.label("Сумка", Style.FONT_M, Style.ACCENT))
	var inventory: Array = h["inventory"]
	if inventory.is_empty():
		col.add_child(Style.wrapped(
			"Пусто. Предметы падают с лагерей разбойников от 3 уровня.",
			Style.FONT_S, Style.TEXT_DIM))
	else:
		for i in range(inventory.size()):
			var item_id: String = String(inventory[i])
			var it: Dictionary = T.HERO_ITEMS.get(item_id, {})
			if it.is_empty():
				continue
			var row := Style.hbox(8)
			var info := Style.vbox(2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(Style.label("%s %s" % [it["icon"], it["label"]], Style.FONT_S))
			info.add_child(Style.label(_item_effect(it), Style.FONT_S, Style.GOOD))
			row.add_child(info)
			var wear := Style.button("Надеть", Style.FONT_S, true)
			wear.custom_minimum_size = Vector2(88, 36)
			var iid := item_id
			wear.pressed.connect(func():
				Hero.equip(G.state, iid)
				G.save()
				rebuild())
			row.add_child(wear)
			col.add_child(row)

	add_child(Style.scroll(Style.margin(col, 12)))


func _slot_label(slot: String) -> String:
	return {
		"helmet": "Шлем", "armor": "Доспех", "weapon": "Оружие",
		"shield": "Щит", "boots": "Обувь", "horse": "Конь",
	}.get(slot, slot)


func _item_effect(it: Dictionary) -> String:
	var parts: Array = []
	if it.has("atk"):
		parts.append("+%d%% атака" % int(float(it["atk"]) * 100.0))
	if it.has("def"):
		parts.append("+%d%% защита" % int(float(it["def"]) * 100.0))
	if it.has("speed"):
		parts.append("+%d%% скорость" % int(float(it["speed"]) * 100.0))
	if it.has("loot"):
		parts.append("+%d%% добыча" % int(float(it["loot"]) * 100.0))
	if it.has("xp"):
		parts.append("+%d%% опыт" % int(float(it["xp"]) * 100.0))
	return ", ".join(parts)


func refresh() -> void:
	pass
