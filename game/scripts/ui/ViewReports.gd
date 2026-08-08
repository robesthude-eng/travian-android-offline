extends Control

## Reports — parchment cards with accent colors

const T := preload("res://game/scripts/core/Tables.gd")
const Style := preload("res://game/scripts/ui/Style.gd")
const Art := preload("res://game/scripts/core/Art.gd")

var _root: Control
var _list: VBoxContainer
var _last_count := -1

func setup(root: Control) -> void:
	_root = root

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var col := Style.vbox(12)
	var header := Style.parchment(14)
	var head_inner := Style.vbox(4)
	head_inner.add_child(Style.label("Вести", Style.FONT_L, Style.ACCENT))
	head_inner.add_child(Style.wrapped("Битвы, постройка, голод и послания соперников. Всё, что случилось с тобой.", Style.FONT_XXS, Style.TEXT_DIM))
	header.add_child(Style.margin(head_inner, 14))
	col.add_child(header)
	_list = Style.vbox(8)
	col.add_child(_list)
	add_child(Style.scroll(Style.margin(col, 12)))
	_last_count = -1
	refresh()

func refresh() -> void:
	if _list == null:
		return
	var reports: Array = G.state.get("reports", [])
	if reports.size() == _last_count:
		return
	_last_count = reports.size()
	for c in _list.get_children():
		c.queue_free()
	if reports.is_empty():
		var empty := Style.parchment(12)
		empty.add_child(Style.margin(Style.label("Пока тихо. Скоро здесь будут донесения.", Style.FONT_S, Style.TEXT_DIM), 12))
		_list.add_child(empty)
		return
	for idx in range(reports.size()-1, -1, -1):
		_list.add_child(_report_card(reports[idx]))
		if _list.get_child_count() >= 40:
			break

func _report_card(r: Dictionary) -> Control:
	var kind := String(r.get("type", "info"))
	var accent := Style.PARCHMENT_LIGHT
	var icon := "📜"
	match kind:
		"battle":
			var won := bool(r.get("won", false))
			var mine := bool(r.get("player_is_attacker", true))
			accent = Color("2f4a2a") if won == mine else Color("4a2a2a")
			icon = "⚔️" if won == mine else "💥"
		"famine":
			accent = Color("4a3a1a")
			icon = "💀"
		"incoming":
			accent = Color("4a2424")
			icon = "⚠️"
		"message":
			accent = Color("3a2a4a")
			icon = "💬"
		"settle":
			accent = Color("2a3a4a")
			icon = "🚩"
		"build":
			accent = Color("2a3a2a")
			icon = "🏗️"
		"training":
			accent = Color("2a2414")
			icon = "🎖️"

	var panel := Style.panel(accent, 12, 1)
	# give accent border for battles
	if kind == "battle":
		var won := bool(r.get("won", false))
		var mine := bool(r.get("player_is_attacker", true))
		var border_col := Style.GOOD if won == mine else Style.BAD
		panel.add_theme_stylebox_override("panel", Style.flat(accent, 12, 1, border_col))

	var col := Style.vbox(6)
	var head := Style.hbox(8)
	var icon_box := Style.panel(Style.WOOD_DARK, 8, 0)
	icon_box.custom_minimum_size = Vector2(36,36)
	icon_box.add_child(Style.label(icon, Style.FONT_M, Style.TEXT))
	head.add_child(icon_box)
	var title_col := Style.vbox(1)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_child(Style.label(String(r.get("title", "")), Style.FONT_M, Style.TEXT))
	var when := float(r.get("t", 0.0))
	var ago := float(G.state["t"]) - when
	title_col.add_child(Style.label("%s назад" % G.fmt_time(ago), Style.FONT_XXS, Style.TEXT_DIM))
	head.add_child(title_col)
	col.add_child(head)

	# Battle header art
	if kind == "battle":
		var battle_tex := Art.battle_report_icon()
		if battle_tex:
			var tr := Style.texture(battle_tex, Vector2(0, 96))
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(0, 96)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			var frame := Style.panel(Color.BLACK, 8, 0)
			frame.add_child(tr)
			col.add_child(frame)

	var text := String(r.get("text", ""))
	if text != "":
		col.add_child(Style.wrapped(text, Style.FONT_S, Style.TEXT_DIM))

	if kind == "battle":
		col.add_child(Style.separator())
		var sent: Dictionary = r.get("att_sent", {})
		var att_loss: Dictionary = r.get("att_losses", {})
		var def_loss: Dictionary = r.get("def_losses", {})
		# show loot prominently
		var loot: Array = r.get("loot", [0, 0, 0, 0])
		if _res_sum(loot) > 0:
			var loot_card := Style.panel(Color("2a2414"), 8, 1)
			loot_card.add_theme_stylebox_override("panel", Style.flat(Color("2a2414"), 8, 1, Style.ACCENT_DIM))
			var loot_col := Style.vbox(2)
			loot_col.add_child(Style.label("Добыча:", Style.FONT_XXS, Style.ACCENT))
			var loot_row := Style.hbox(10)
			for rr in range(4):
				if float(loot[rr]) > 0:
					var cell := Style.hbox(3)
					cell.add_child(Style.res_icon_texture(rr, 18))
					cell.add_child(Style.label("%d" % int(loot[rr]), Style.FONT_S, Style.GOOD))
					loot_row.add_child(cell)
			loot_col.add_child(loot_row)
			loot_card.add_child(Style.margin(loot_col, 8))
			col.add_child(loot_card)
		col.add_child(Style.wrapped("Отправлено: %s" % _troops(sent), Style.FONT_XXS, Style.TEXT_DIM))
		col.add_child(Style.wrapped("Потери атак.: %s" % _troops(att_loss),
				Style.FONT_XXS, Style.BAD))
		col.add_child(Style.wrapped("Потери защит.: %s" % _troops(def_loss),
				Style.FONT_XXS, Style.GOOD))
		if int(r.get("xp", 0)) > 0:
			col.add_child(Style.label("Герой +%d опыта" % int(r["xp"]),
					Style.FONT_S, Style.ACCENT))
		if String(r.get("item", "")) != "":
			var it: Dictionary = T.HERO_ITEMS.get(String(r["item"]), {})
			if not it.is_empty():
				col.add_child(Style.label("Найдено: %s %s" % [it["icon"], it["label"]],
						Style.FONT_S, Style.ACCENT))
		if int(r.get("wall_damage", 0)) > 0:
			col.add_child(Style.label("Стена −%d ур." % int(r["wall_damage"]),
					Style.FONT_S, Style.WARN))
	elif kind == "famine" or kind == "training" or kind == "reinforce":
		var troops: Dictionary = r.get("troops", {})
		if not troops.is_empty():
			col.add_child(Style.wrapped(_troops(troops), Style.FONT_S))

	panel.add_child(Style.margin(col, 12))
	return panel

func _troops(troops: Dictionary) -> String:
	if troops.is_empty():
		return "нет"
	var parts: Array = []
	for id in troops:
		var u: Dictionary = T.unit(id)
		parts.append("%s ×%d" % [u.get("label", id), int(troops[id])])
	return ", ".join(parts)

func _res(res: Array) -> String:
	var parts: Array = []
	for r in range(4):
		if float(res[r]) > 0.0:
			parts.append("%s%d" % [T.RES_ICONS[r], int(res[r])])
	return " ".join(parts) if not parts.is_empty() else "ничего"

func _res_sum(res: Array) -> float:
	var total := 0.0
	for value in res:
		total += float(value)
	return total
