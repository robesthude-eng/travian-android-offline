extends Control

## Left sidebar: garrison, hero, movements, reports preview
## Lives inside Root's middle HBox, fixed width.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Art := preload("res://game/scripts/core/Art.gd")
const Style := preload("res://game/scripts/ui/Style.gd")
const Hero := preload("res://game/scripts/core/Hero.gd")

var _root: Control
var _scroll: ScrollContainer
var _content: VBoxContainer
var _hero_box: VBoxContainer
var _garrison_box: VBoxContainer
var _queue_box: VBoxContainer
var _moves_box: VBoxContainer
var _reports_box: VBoxContainer
var _unread_label: Label

func setup(root: Control) -> void:
	_root = root
	custom_minimum_size = Vector2(196, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = 0

	# Background panel
	var bg := Style.wood_panel(0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var holder := Style.margin(Style.vbox(10), 8)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)

	var col := Style.vbox(10)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(col)

	# Header collapse/hint
	var header := Style.hbox(4)
	header.add_child(Style.label("ПОСЕЛЕНИЕ", Style.FONT_XXS, Style.ACCENT_DIM))
	header.add_child(Style.spacer())
	var reports_btn := Style.label("📜", Style.FONT_M, Style.TEXT_DIM)
	# Make reports clickable area via Button overlay — simplified: use button
	col.add_child(header)

	_scroll = Style.scroll(Style.vbox(12))
	# Override scroll fill
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	# Inside scroll, content
	_content = _scroll.get_child(0) as VBoxContainer
	# _content already is the VBox inside scroll (Style.scroll creates child)
	# Rebuild content boxes
	_hero_box = Style.vbox(4)
	_content.add_child(_build_hero_section())

	_content.add_child(Style.separator())
	_content.add_child(_build_garrison_section())

	_content.add_child(Style.separator())
	_content.add_child(_build_moves_section())

	_content.add_child(Style.separator())
	_content.add_child(_build_reports_section())

	# Bottom action
	var train_btn := Style.outline_button("Обучить войска", Style.FONT_S)
	train_btn.custom_minimum_size = Vector2(0, 36)
	train_btn.pressed.connect(func(): _root.show_view("army"))
	# but we removed army view? We'll show army via modal or view
	_content.add_child(train_btn)

	refresh()

func _build_hero_section() -> Control:
	var sec := Style.vbox(6)
	sec.add_child(Style.sidebar_header("Герой", "🦸"))
	_hero_box = Style.vbox(4)
	sec.add_child(_hero_box)
	# hero will be filled in refresh
	var btn := Style.button("Герой →", Style.FONT_S, false)
	btn.custom_minimum_size = Vector2(0, 32)
	btn.pressed.connect(func(): _root.show_view("hero"))
	sec.add_child(btn)
	return sec

func _build_garrison_section() -> Control:
	var sec := Style.vbox(6)
	sec.add_child(Style.sidebar_header("Гарнизон", "⚔️"))
	_garrison_box = Style.vbox(4)
	sec.add_child(_garrison_box)
	_queue_box = Style.vbox(4)
	var q_label := Style.label("Очередь:", Style.FONT_XXS, Style.TEXT_DIM)
	sec.add_child(q_label)
	sec.add_child(_queue_box)
	var more := Style.label("Подробнее → казарма", Style.FONT_XXS, Style.ACCENT_DIM)
	sec.add_child(more)
	return sec

func _build_moves_section() -> Control:
	var sec := Style.vbox(6)
	sec.add_child(Style.sidebar_header("Походы", "🏇"))
	_moves_box = Style.vbox(4)
	sec.add_child(_moves_box)
	return sec

func _build_reports_section() -> Control:
	var sec := Style.vbox(6)
	var h := Style.hbox(6)
	h.add_child(Style.label("ВЕСТИ", Style.FONT_XXS, Style.ACCENT_DIM))
	h.add_child(Style.spacer())
	_unread_label = Style.label("", Style.FONT_XXS, Style.WARN)
	h.add_child(_unread_label)
	sec.add_child(h)
	_reports_box = Style.vbox(4)
	sec.add_child(_reports_box)
	var open_btn := Style.outline_button("Все вести", Style.FONT_S)
	open_btn.custom_minimum_size = Vector2(0, 32)
	open_btn.pressed.connect(func(): _root.show_view("reports"))
	sec.add_child(open_btn)
	return sec

func refresh() -> void:
	_refresh_hero()
	_refresh_garrison()
	_refresh_moves()
	_refresh_reports()

func _refresh_hero() -> void:
	if _hero_box == null or G.state.is_empty():
		return
	for c: Node in _hero_box.get_children():
		c.queue_free()
	var h: Dictionary = G.state.get("hero", {})
	if h.is_empty():
		_hero_box.add_child(Style.label("Нет героя", Style.FONT_S, Style.TEXT_DIM))
		return
	# Portrait + level
	var row := Style.hbox(8)
	var portrait := Art.hero_portrait()
	if portrait:
		row.add_child(Style.texture(portrait, Vector2(42,42)))
	var col := Style.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Style.label("Ур. %d" % int(h.get("level",1)), Style.FONT_S, Style.ACCENT))
	col.add_child(Style.label(Hero.status_text(G.state), Style.FONT_XXS, Style.TEXT_DIM))
	row.add_child(col)
	_hero_box.add_child(row)
	var xp := float(h.get("xp",0))
	var nxt := Hero.xp_for_next(h)
	var bar := Style.progress(xp, nxt, Style.ACCENT)
	_hero_box.add_child(bar)
	_hero_box.add_child(Style.label("%d / %d XP" % [int(xp), int(nxt)], Style.FONT_XXS, Style.TEXT_DIM))
	# multipliers
	var mult := Hero.multipliers(G.state)
	var buff := Style.label("+%d%% атака / +%d%% защита" % [int((mult["atk"]-1)*100), int((mult["def"]-1)*100)], Style.FONT_XXS, Style.GOOD)
	_hero_box.add_child(buff)

func _refresh_garrison() -> void:
	if _garrison_box == null or G.state.is_empty():
		return
	for c: Node in _garrison_box.get_children():
		c.queue_free()
	for c: Node in _queue_box.get_children():
		c.queue_free()
	var v := G.village()
	if v.is_empty():
		_garrison_box.add_child(Style.label("—", Style.FONT_S, Style.TEXT_DIM))
		return
	if v["troops"].is_empty():
		_garrison_box.add_child(Style.label("Пусто. Беззащитна.", Style.FONT_XXS, Style.TEXT_DIM))
	else:
		var ids: Array = v["troops"].keys()
		ids.sort()
		var shown := 0
		for id in ids:
			if shown >= 4: break
			var have := int(v["troops"][id])
			if have <= 0: continue
			var u: Dictionary = T.unit(id)
			var row := Style.hbox(6)
			var tex := Art.unit(id)
			if tex:
				row.add_child(Style.texture(tex, Vector2(28,28)))
			row.add_child(Style.label("%s: %d" % [u.get("label", id), have], Style.FONT_S))
			_garrison_box.add_child(row)
			shown += 1
		if ids.size() > 4:
			_garrison_box.add_child(Style.label("и ещё %d типов…" % (ids.size()-4), Style.FONT_XXS, Style.TEXT_DIM))
	# queue
	if v["train_queue"].is_empty():
		_queue_box.add_child(Style.label("Никого не учим", Style.FONT_XXS, Style.TEXT_DIM))
	else:
		for item in v["train_queue"]:
			var u: Dictionary = T.unit(String(item["unit"]))
			var left: float = float(item["done"]) - float(G.state["t"])
			var txt := "%s ×%d — %s" % [u.get("label", item["unit"]), int(item["left"]), G.fmt_time(left)]
			_queue_box.add_child(Style.label(txt, Style.FONT_XXS, Style.WARN))

func _refresh_moves() -> void:
	if _moves_box == null:
		return
	for c: Node in _moves_box.get_children():
		c.queue_free()
	if G.state.is_empty():
		return
	var any := false
	for m in G.state.get("movements", []):
		var mine: bool = m.get("owner","") == "player"
		var incoming: bool = not mine and String(m.get("to_kind","")) == "village"
		if not mine and not incoming:
			continue
		any = true
		var eta: float = float(m.get("arrive",0)) - float(G.state["t"])
		var is_attack := String(m.get("kind","")) in ["attack","raid"] and incoming
		var bg := Color("4a2424") if is_attack else Style.PANEL_LIGHT
		var col := Style.vbox(2)
		var head := ""
		if mine:
			var verb: String = {"raid":"Набег","attack":"Атака","scout":"Разведка","settle":"Поселенцы"}.get(String(m.get("kind","")), "Поход")
			if bool(m.get("returning",false)):
				verb = "Возврат"
			head = "%s → (%d|%d)" % [verb, int(m.get("to_x",0)), int(m.get("to_y",0))]
		else:
			head = "⚠ %s идёт!" % String(m.get("owner_name","Враг"))
		var panel := Style.panel(bg, 8, 1 if is_attack else 0)
		panel.add_theme_stylebox_override("panel", Style.flat(bg, 8, 1 if is_attack else 0, Style.BAD if is_attack else Style.ACCENT_DIM))
		var inner := Style.vbox(2)
		inner.add_child(Style.label(head, Style.FONT_XXS, Style.BAD if is_attack else Style.TEXT))
		inner.add_child(Style.label("%s • %d воинов" % [G.fmt_time(eta), Sim.troops_count(m.get("troops",{}))], Style.FONT_XXS, Style.TEXT_DIM))
		panel.add_child(Style.margin(inner, 6))
		_moves_box.add_child(panel)
		if _moves_box.get_child_count() >= 3:
			break
	if not any:
		_moves_box.add_child(Style.label("Никто не идёт", Style.FONT_XXS, Style.TEXT_DIM))

func _refresh_reports() -> void:
	if _reports_box == null:
		return
	for c: Node in _reports_box.get_children():
		c.queue_free()
	var reports: Array = G.state.get("reports", [])
	var unread := Sim.unread_reports(G.state)
	if _unread_label:
		_unread_label.text = ("(%d)" % unread) if unread > 0 else ""
		_unread_label.add_theme_color_override("font_color", Style.WARN if unread>0 else Style.TEXT_DIM)
	if reports.is_empty():
		_reports_box.add_child(Style.label("Тихо", Style.FONT_XXS, Style.TEXT_DIM))
		return
	var shown := 0
	for idx in range(reports.size()-1, -1, -1):
		if shown >= 2: break
		var r: Dictionary = reports[idx]
		var kind := String(r.get("type",""))
		var accent := Style.PANEL_LIGHT
		if kind == "battle":
			var won := bool(r.get("won",false))
			var mine := bool(r.get("player_is_attacker",true))
			accent = Color("2f4a2a") if won==mine else Color("4a2a2a")
		elif kind in ["famine","incoming"]:
			accent = Color("4a3a1a")
		var card := Style.panel(accent, 8, 0)
		var col := Style.vbox(2)
		col.add_child(Style.label(String(r.get("title","")), Style.FONT_XXS, Style.TEXT))
		var ago := float(G.state["t"]) - float(r.get("t",0))
		col.add_child(Style.label("%s назад" % G.fmt_time(ago), Style.FONT_XXS, Style.TEXT_DIM))
		if String(r.get("text","")) != "":
			col.add_child(Style.wrapped(String(r.get("text","")).left(80), Style.FONT_XXS, Style.TEXT_DIM))
		card.add_child(Style.margin(col, 6))
		_reports_box.add_child(card)
		shown += 1

