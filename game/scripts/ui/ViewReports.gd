extends Control

## Battle reports, build notifications, famine warnings and rival messages.

const T := preload("res://game/scripts/core/Tables.gd")
const Style := preload("res://game/scripts/ui/Style.gd")

var _root: Control
var _list: VBoxContainer
var _last_count := -1


func setup(root: Control) -> void:
	_root = root


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var col := Style.vbox(8)
	col.add_child(Style.label("Вести", Style.FONT_L, Style.ACCENT))
	_list = Style.vbox(6)
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
		_list.add_child(Style.label("Пока тихо.", Style.FONT_S, Style.TEXT_DIM))
		return

	for r in reports:
		_list.add_child(_report_card(r))


func _report_card(r: Dictionary) -> Control:
	var kind := String(r.get("type", "info"))
	var accent := Style.PANEL_LIGHT
	match kind:
		"battle":
			var won := bool(r.get("won", false))
			var mine := bool(r.get("player_is_attacker", true))
			# A win for the attacker is bad news when the attacker is not you.
			accent = Color("2f4a2a") if won == mine else Color("4a2a2a")
		"famine", "incoming":
			accent = Color("4a3a1a")
		"message":
			accent = Color("3a2a4a")
		"settle", "build", "training":
			accent = Color("2a3a4a")

	var panel := Style.panel(accent, 12, 1)
	var col := Style.vbox(4)

	var head := Style.hbox(6)
	head.add_child(Style.wrapped(String(r.get("title", "")), Style.FONT_M))
	col.add_child(head)

	var when := float(r.get("t", 0.0))
	var ago := float(G.state["t"]) - when
	col.add_child(Style.label("%s назад" % G.fmt_time(ago), Style.FONT_S, Style.TEXT_DIM))

	var text := String(r.get("text", ""))
	if text != "":
		col.add_child(Style.wrapped(text, Style.FONT_S, Style.TEXT_DIM))

	if kind == "battle":
		col.add_child(Style.separator())
		var sent: Dictionary = r.get("att_sent", {})
		var att_loss: Dictionary = r.get("att_losses", {})
		var def_loss: Dictionary = r.get("def_losses", {})
		col.add_child(Style.wrapped("Отправлено: %s" % _troops(sent), Style.FONT_S))
		col.add_child(Style.wrapped("Потери атакующего: %s" % _troops(att_loss),
				Style.FONT_S, Style.BAD))
		col.add_child(Style.wrapped("Потери защитника: %s" % _troops(def_loss),
				Style.FONT_S, Style.GOOD))
		var loot: Array = r.get("loot", [0, 0, 0, 0])
		if _res_sum(loot) > 0:
			col.add_child(Style.wrapped("Добыча: %s" % _res(loot), Style.FONT_S, Style.ACCENT))
		if int(r.get("xp", 0)) > 0:
			col.add_child(Style.label("Герой получил %d опыта" % int(r["xp"]),
					Style.FONT_S, Style.ACCENT))
		if String(r.get("item", "")) != "":
			var it: Dictionary = T.HERO_ITEMS.get(String(r["item"]), {})
			if not it.is_empty():
				col.add_child(Style.label("Найдено: %s %s" % [it["icon"], it["label"]],
						Style.FONT_S, Style.ACCENT))
		if int(r.get("wall_damage", 0)) > 0:
			col.add_child(Style.label("Стена разрушена на %d ур." % int(r["wall_damage"]),
					Style.FONT_S, Style.WARN))
	elif kind == "famine" or kind == "training" or kind == "reinforce":
		var troops: Dictionary = r.get("troops", {})
		if not troops.is_empty():
			col.add_child(Style.wrapped(_troops(troops), Style.FONT_S))

	panel.add_child(col)
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
