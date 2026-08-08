extends Control

## Hero sheet — polished with art, parchment, gold accents

const T := preload("res://game/scripts/core/Tables.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

const ATTRS := [
	["str", "Сила", "+0.5% атаки за очко", "⚔️"],
	["def", "Защита", "+0.5% защиты за очко", "🛡️"],
	["loot", "Добыча", "+1% к грабежу за очко", "💰"],
	["speed", "Скорость", "+1% к скорости за очко", "🏇"],
]

var _root: Control

func setup(root: Control) -> void:
	_root = root

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var h: Dictionary = G.state["hero"]
	var col := Style.vbox(12)

	# Hero header parchment
	var header := Style.parchment(16)
	var head := Style.hbox(12)
	var portrait := Art.hero_portrait()
	if portrait:
		var frame := Style.panel(Style.PARCHMENT_LIGHT, 12, 1)
		frame.custom_minimum_size = Vector2(96,96)
		frame.add_child(Style.texture(portrait, Vector2(96,96)))
		head.add_child(frame)
	var head_col := Style.vbox(6)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_child(Style.label("Герой — уровень %d" % int(h["level"]), Style.FONT_L, Style.ACCENT))
	head_col.add_child(Style.label(Hero.status_text(G.state), Style.FONT_S, Style.TEXT_DIM))
	# XP bar with gold
	var bar := Style.progress(float(h["xp"]), Hero.xp_for_next(h), Style.ACCENT)
	head_col.add_child(bar)
	head_col.add_child(Style.label("Опыт: %d / %d" % [int(h["xp"]), int(Hero.xp_for_next(h))],
			Style.FONT_XXS, Style.TEXT_DIM))
	# Buff summary parchment strip
	var mult := Hero.multipliers(G.state)
	var buff_card := Style.panel(Color("2a2414"), 8, 1)
	buff_card.add_theme_stylebox_override("panel", Style.flat(Color("2a2414"), 8, 1, Style.ACCENT_DIM.darkened(0.3)))
	var buff_inner := Style.vbox(2)
	buff_inner.add_child(Style.label("Бонусы с героем:", Style.FONT_XXS, Style.ACCENT_DIM))
	buff_inner.add_child(Style.wrapped(
		"Атака +%d%%  •  Защита +%d%%  •  Добыча +%d%%  •  Скорость +%d%%" %
		[int((mult["atk"] - 1.0) * 100.0), int((mult["def"] - 1.0) * 100.0),
		 int(mult["loot"] * 100.0), int(mult["speed"] * 100.0)],
		Style.FONT_XXS, Style.GOOD))
	buff_card.add_child(Style.margin(buff_inner, 8))
	head_col.add_child(buff_card)
	head.add_child(head_col)
	header.add_child(Style.margin(head, 14))
	col.add_child(header)

	# Attributes parchment
	var attr_card := Style.parchment(12)
	var attr_inner := Style.vbox(8)
	attr_inner.add_child(Style.label("Характеристики  •  Очков: %d" % int(h["points"]), Style.FONT_M, Style.ACCENT if int(h["points"])>0 else Style.TEXT_DIM))
	for spec in ATTRS:
		var key: String = spec[0]
		var row := Style.hbox(8)
		var icon := Style.panel(Style.PARCHMENT_LIGHT, 8, 1)
		icon.custom_minimum_size = Vector2(36,36)
		var icon_label := Style.label(spec[3], Style.FONT_M, Style.ACCENT)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_child(icon_label)
		row.add_child(icon)
		var info := Style.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(Style.label("%s: %d" % [spec[1], int(h[key])], Style.FONT_S))
		info.add_child(Style.label(String(spec[2]), Style.FONT_XXS, Style.TEXT_DIM))
		row.add_child(info)
		var plus := Style.button("＋", Style.FONT_M, int(h["points"]) > 0)
		plus.custom_minimum_size = Vector2(52, 40)
		plus.disabled = int(h["points"]) <= 0
		plus.pressed.connect(func():
			if Hero.spend_point(G.state, key):
				G.save()
				rebuild()
				_root.toast("+1 %s" % spec[1]))
		row.add_child(plus)
		attr_inner.add_child(row)
	attr_card.add_child(Style.margin(attr_inner, 12))
	col.add_child(attr_card)

	# Equipment
	var equip_card := Style.parchment(12)
	var equip_inner := Style.vbox(8)
	equip_inner.add_child(Style.label("Снаряжение", Style.FONT_M, Style.ACCENT))
	equip_inner.add_child(Style.wrapped("Падает с лагерей 3+ уровня. Надевай — усиливаешь армию.", Style.FONT_XXS, Style.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for slot: String in T.HERO_EQUIP_SLOTS:
		var panel := Style.panel(Style.PARCHMENT_LIGHT, 10, 1)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(0, 64)
		var inner := Style.vbox(4)
		var equipped: String = String(h["equip"].get(slot, ""))
		if equipped == "":
			inner.add_child(Style.label(_slot_label(slot), Style.FONT_S, Style.TEXT_DIM))
			inner.add_child(Style.label("пусто", Style.FONT_XXS, Style.TEXT_DIM))
			var hint := Style.label("—", Style.FONT_XXS, Style.ACCENT_DIM)
			inner.add_child(hint)
		else:
			var it: Dictionary = T.HERO_ITEMS[equipped]
			inner.add_child(Style.label("%s %s" % [it["icon"], it["label"]], Style.FONT_S, Style.ACCENT))
			inner.add_child(Style.label(_item_effect(it), Style.FONT_XXS, Style.GOOD))
			var off := Style.outline_button("Снять", Style.FONT_S)
			off.custom_minimum_size = Vector2(0, 28)
			var s := slot
			off.pressed.connect(func():
				Hero.unequip(G.state, s)
				G.save()
				rebuild())
			inner.add_child(off)
		panel.add_child(Style.margin(inner, 8))
		grid.add_child(panel)
	equip_inner.add_child(grid)
	equip_card.add_child(Style.margin(equip_inner, 12))
	col.add_child(equip_card)

	# Inventory
	var bag_card := Style.parchment(12)
	var bag_inner := Style.vbox(8)
	bag_inner.add_child(Style.label("Сумка", Style.FONT_M, Style.ACCENT))
	var inventory: Array = h["inventory"]
	if inventory.is_empty():
		bag_inner.add_child(Style.wrapped(
			"Пусто. Фарми лагеря разбойников 3+ уровня — там падает экипировка и опыт.",
			Style.FONT_S, Style.TEXT_DIM))
		var tip := Style.panel(Color("2a2414"), 8, 1)
		tip.add_child(Style.margin(Style.wrapped("Совет: бери героя в набеги — он получает опыт и тащит больше.", Style.FONT_XXS, Style.WARN), 8))
		bag_inner.add_child(tip)
	else:
		for i in range(inventory.size()):
			var item_id: String = String(inventory[i])
			var it: Dictionary = T.HERO_ITEMS.get(item_id, {})
			if it.is_empty():
				continue
			var row := Style.hbox(8)
			var icon_box := Style.panel(Style.PARCHMENT_LIGHT, 8, 1)
			icon_box.custom_minimum_size = Vector2(44,44)
			icon_box.add_child(Style.label(it.get("icon","🎁"), Style.FONT_L, Style.ACCENT))
			row.add_child(icon_box)
			var info := Style.vbox(2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(Style.label("%s" % it["label"], Style.FONT_S))
			info.add_child(Style.label(_item_effect(it), Style.FONT_XXS, Style.GOOD))
			row.add_child(info)
			var wear := Style.button("Надеть", Style.FONT_S, true)
			wear.custom_minimum_size = Vector2(88, 36)
			var iid := item_id
			wear.pressed.connect(func():
				Hero.equip(G.state, iid)
				G.save()
				rebuild())
			row.add_child(wear)
			bag_inner.add_child(row)
	bag_card.add_child(Style.margin(bag_inner, 12))
	col.add_child(bag_card)

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
