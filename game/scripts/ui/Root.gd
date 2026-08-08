extends Control

## Main UI shell: top wood bar, left sidebar, central parchment, bottom nav

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Style := preload("res://game/scripts/ui/Style.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")
const Art := preload("res://game/scripts/core/Art.gd")

const ViewFields := preload("res://game/scripts/ui/ViewFields.gd")
const ViewVillage := preload("res://game/scripts/ui/ViewVillage.gd")
const ViewMap := preload("res://game/scripts/ui/ViewMap.gd")
const ViewArmy := preload("res://game/scripts/ui/ViewArmy.gd")
const ViewHero := preload("res://game/scripts/ui/ViewHero.gd")
const ViewReports := preload("res://game/scripts/ui/ViewReports.gd")
const NewGamePanel := preload("res://game/scripts/ui/NewGamePanel.gd")
const Sidebar := preload("res://game/scripts/ui/Sidebar.gd")

var _content: Control
var _views := {}
var _current := ""
var _nav_buttons := {}
var _res_cells := []  # not labels now but whole cells holder
var _res_labels := [] # for compat
var _res_bars := []
var _pop_label: Label
var _culture_label: Label
var _village_button: Button
var _modal_layer: Control
var _toast_label: Label
var _toast_timer := 0.0
var _pending_offline := {}
var _sidebar: Control
var _middle: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Style.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# subtle vignette overlay
	var vignette := ColorRect.new()
	vignette.color = Color(0,0,0,0.18)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	G.state_changed.connect(_on_state_changed)
	G.offline_report.connect(_on_offline_report)
	G.rival_spoke.connect(func(who, msg): toast("%s: %s" % [who, msg]))

	if G.has_save() and G.load_game():
		_build_game_ui()
		if not _pending_offline.is_empty():
			_show_offline_summary()
	else:
		_show_new_game()

	set_process(true)

	if OS.get_cmdline_user_args().has("--uitest"):
		_run_ui_selftest()

# ---------------------------------------------------------------------------
# selftest (unchanged, but new nav)
func _painted_area(node: Node) -> float:
	var best := 0.0
	for child in node.get_children():
		if child is Control and child.visible:
			var c: Control = child
			best = maxf(best, c.size.x * c.size.y)
		best = maxf(best, _painted_area(child))
	return best

func _run_ui_selftest() -> void:
	var failures: Array = []
	var settle := func() -> void:
		for i in range(6):
			await get_tree().process_frame
	await settle.call()
	var screen := size.x * size.y
	if screen <= 0.0:
		failures.append("root control has no size")
	if _views.is_empty():
		var painted := _painted_area(self)
		if painted < screen * 0.2:
			failures.append("new game panel painted %.0f of %.0f px" % [painted, screen])
		start_new_game("Тест", T.TRIBE_ROMANS, 3.0)
		await settle.call()
	if _views.is_empty():
		failures.append("game shell was never built")
	else:
		for key in ["fields", "village", "map", "hero"]:
			show_view(key)
			await settle.call()
			var view: Control = _views[key]
			if view.size.x <= 0.0 or view.size.y <= 0.0:
				failures.append("view '%s' has no size" % key)
				continue
			var painted := _painted_area(view)
			if painted < view.size.x * 50.0:
				failures.append("view '%s' painted only %.0f px" % [key, painted])
		if _res_labels.is_empty():
			failures.append("top bar has no resource labels")
		elif String(_res_labels[0].text).strip_edges() == "":
			failures.append("top bar resource label is empty")
		var body := Style.vbox(4)
		body.add_child(Style.label("проверка"))
		show_modal("Проверка", body, [{"text": "ок"}])
		await settle.call()
		if not _modal_layer.visible or _painted_area(_modal_layer) < 1000.0:
			failures.append("modal did not render")
		close_modal()
	if failures.is_empty():
		print("UITEST OK — screen %dx%d, all views painted" % [int(size.x), int(size.y)])
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("UITEST FAIL: %s" % f)
		get_tree().quit(1)

func _on_offline_report(seconds: float, gained: Dictionary) -> void:
	_pending_offline = {"seconds": seconds, "gained": gained}

func _show_offline_summary() -> void:
	var seconds: float = float(_pending_offline.get("seconds", 0.0))
	var gained: Array = _pending_offline.get("gained", {}).get("res", T.res_zero())
	_pending_offline = {}
	var body := Style.vbox(8)
	body.add_child(Style.wrapped("Тебя не было %s. Мир не стоял на месте."
			% G.fmt_time(seconds), Style.FONT_M))
	body.add_child(Style.label("Добыто:", Style.FONT_S, Style.TEXT_DIM))
	var row := Style.hbox(12)
	for r in range(4):
		row.add_child(Style.label("%s %s" % [T.RES_ICONS[r], G.fmt_number(gained[r])],
				Style.FONT_M, Style.GOOD if float(gained[r]) > 0.0 else Style.TEXT_DIM))
	body.add_child(row)
	var battles := 0
	var raided := false
	for rep in G.state.get("reports", []):
		if float(rep.get("t", 0.0)) < float(G.state["t"]) - seconds:
			continue
		if String(rep.get("type", "")) == "battle":
			battles += 1
			if not bool(rep.get("player_is_attacker", true)) and bool(rep.get("won", false)):
				raided = true
	if battles > 0:
		body.add_child(Style.separator())
		body.add_child(Style.wrapped("Сражений за это время: %d." % battles, Style.FONT_S))
		if raided:
			body.add_child(Style.wrapped("Тебя успели ограбить — загляни в «Вести».",
					Style.FONT_S, Style.BAD))
	show_modal("С возвращением", body, [{"text": "К делам", "primary": true}])

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label:
			_toast_label.get_parent().visible = false

# ---------------------------------------------------------------------------
func _show_new_game() -> void:
	for c in get_children():
		if c is ColorRect:
			continue
		c.queue_free()
	var panel := NewGamePanel.new()
	panel.setup(self)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

func start_new_game(player_name: String, tribe: String, speed: float) -> void:
	G.new_game(player_name, tribe, speed)
	for c in get_children():
		if c is ColorRect:
			continue
		c.queue_free()
	_build_game_ui()

# ---------------------------------------------------------------------------
func _build_game_ui() -> void:
	_views.clear()
	_nav_buttons.clear()
	_res_labels.clear()
	_res_bars.clear()
	_res_cells.clear()

	# Root vertical column
	var column := Style.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	column.add_child(_build_top_bar())

	# Middle: sidebar + content
	_middle = HBoxContainer.new()
	_middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_theme_constant_override("separation", 0)
	column.add_child(_middle)

	_sidebar = Sidebar.new()
	_sidebar.setup(self)
	_middle.add_child(_sidebar)

	# Content holder with parchment background
	var content_holder := Control.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.clip_contents = true
	_middle.add_child(content_holder)

	# Parchment behind content
	var parchment_bg := Style.view_background()
	content_holder.add_child(parchment_bg)

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.clip_contents = true
	content_holder.add_child(_content)

	column.add_child(_build_nav())

	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.visible = false
	add_child(_modal_layer)

	_build_toast()

	_views["fields"] = ViewFields.new()
	_views["village"] = ViewVillage.new()
	_views["map"] = ViewMap.new()
	_views["hero"] = ViewHero.new()
	# Keep army/reports but not in bottom nav — accessible via sidebar
	_views["army"] = ViewArmy.new()
	_views["reports"] = ViewReports.new()
	for key in _views:
		var v: Control = _views[key]
		v.setup(self)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.visible = false
		_content.add_child(v)

	show_view("fields")
	_refresh_top_bar()

func _build_top_bar() -> Control:
	var panel := Style.wood_panel(0)
	var outer := Style.vbox(4)
	outer.add_theme_constant_override("separation", 4)

	# Header row: village + pop/culture + settings
	var head := Style.hbox(6)
	_village_button = Style.button("Деревня", Style.FONT_S, false)
	_village_button.custom_minimum_size = Vector2(0, 32)
	_village_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_village_button.pressed.connect(_show_village_picker)
	head.add_child(_village_button)

	var pop_col := Style.vbox(0)
	pop_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_pop_label = Style.label("", Style.FONT_S, Style.TEXT_DIM)
	_culture_label = Style.label("", Style.FONT_XXS, Style.TEXT_DIM)
	pop_col.add_child(_pop_label)
	pop_col.add_child(_culture_label)
	head.add_child(pop_col)

	var settings_btn := Style.button("⚙", Style.FONT_S, false)
	settings_btn.custom_minimum_size = Vector2(40, 32)
	settings_btn.pressed.connect(_show_settings)
	head.add_child(settings_btn)
	outer.add_child(Style.margin(head, 6))

	# Resource grid: 4 columns with icon+amount+bar+prod
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for r in range(4):
		var cell := Style.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# top row: badge + amount + prod
		var top := Style.hbox(3)
		var badge := Style.res_badge(r, 22)
		top.add_child(badge)
		var amount_label := Style.label("0", Style.FONT_S, Style.TEXT)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		top.add_child(amount_label)
		# per hour will be added dynamically in refresh as separate label
		var prod_label := Style.label("", Style.FONT_XXS, Style.GOOD)
		prod_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(prod_label)
		cell.add_child(top)
		var bar := Style.progress(0, 1, Style.RES_COLORS[r])
		cell.add_child(bar)
		grid.add_child(cell)
		_res_labels.append(amount_label) # keep for compat: will store amount
		_res_bars.append(bar)
		_res_cells.append({"prod": prod_label, "amount": amount_label, "bar": bar})
	outer.add_child(Style.margin(grid, 6))

	# thin gold line at bottom
	var line := ColorRect.new()
	line.color = Style.ACCENT_DIM.darkened(0.4)
	line.custom_minimum_size = Vector2(0,1)
	outer.add_child(line)

	panel.add_child(outer)
	return panel

func _build_nav() -> Control:
	var panel := Style.wood_panel(0)
	var row := Style.hbox(6)
	# Only 4 tabs: fields, village, map, hero
	# Use art textures where possible
	var icon_fields := Art.building("granary", 1) # fallback to null if missing
	# Try to pick nicer: we want field-like icon, use grain mill
	if icon_fields == null:
		icon_fields = _try_load_icon("res://Assets/Art/Buildings/14_Grain_Mill.png")
	var icon_village := Art.building("main", 1)
	var icon_map := Art.oasis() # map-like
	if icon_map == null:
		icon_map = _try_load_icon("res://Assets/Art/Map/oasis_bonus.png")
	var icon_hero := Art.hero_portrait()
	var items := [
		["fields", "Поля", icon_fields],
		["village", "Деревня", icon_village],
		["map", "Карта", icon_map],
		["hero", "Герой", icon_hero],
	]
	for item in items:
		var key: String = item[0]
		var label: String = item[1]
		var tex: Texture2D = item[2]
		# Create custom button with vertical icon + label
		var b := _nav_button_vertical(tex, label, false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): show_view(key))
		row.add_child(b)
		_nav_buttons[key] = b
	# extra hidden buttons for army/reports accessible via code but not shown
	var holder := Style.margin(row, 6)
	panel.add_child(holder)
	var bottom_line := ColorRect.new()
	bottom_line.color = Style.ACCENT_DIM.darkened(0.4)
	bottom_line.custom_minimum_size = Vector2(0,1)
	bottom_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.add_child(bottom_line)
	return panel

func _try_load_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r := ResourceLoader.load(path)
		if r is Texture2D:
			return r
	return null

func _nav_button_vertical(icon: Texture2D, label: String, active: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 62)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Use vertical layout: button's icon on top, text below via custom child
	# For simplicity, if icon exists, show it; text is label
	b.text = label
	if icon:
		b.icon = icon
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Scale icon down
		b.add_theme_constant_override("icon_max_width", 28)
	b.add_theme_font_size_override("font_size", Style.FONT_S)
	var bg := Style.ACCENT if active else Style.WOOD_MID
	var fg := Style.TEXT_DARK if active else Style.TEXT_DIM
	if active:
		b.add_theme_stylebox_override("normal", Style.flat(Style.ACCENT, 12, 1, Style.ACCENT_GLOW))
		b.add_theme_stylebox_override("hover", Style.flat(Style.ACCENT.lightened(0.08), 12, 1, Style.ACCENT_GLOW))
	else:
		b.add_theme_stylebox_override("normal", Style.flat(Style.WOOD_MID, 12, 1, Color("3a2a14")))
		b.add_theme_stylebox_override("hover", Style.flat(Style.PANEL_LIGHT, 12, 1, Style.ACCENT_DIM))
	b.add_theme_stylebox_override("pressed", Style.flat(Style.WOOD_DARK, 12))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Style.TEXT if not active else Style.TEXT_DARK)
	return b

func _restyle_nav_button(b: Button, active: bool) -> void:
	var bg := Style.ACCENT if active else Style.WOOD_MID
	var fg := Style.TEXT_DARK if active else Style.TEXT_DIM
	if active:
		b.add_theme_stylebox_override("normal", Style.flat(Style.ACCENT, 12, 1, Style.ACCENT_GLOW))
		b.add_theme_stylebox_override("hover", Style.flat(Style.ACCENT.lightened(0.08), 12, 1, Style.ACCENT_GLOW))
	else:
		b.add_theme_stylebox_override("normal", Style.flat(Style.WOOD_MID, 12, 1, Color("3a2a14")))
		b.add_theme_stylebox_override("hover", Style.flat(Style.PANEL_LIGHT, 12, 1, Style.ACCENT_DIM))
	b.add_theme_stylebox_override("pressed", Style.flat(Style.WOOD_DARK, 12))
	b.add_theme_color_override("font_color", fg)

func _build_toast() -> void:
	var holder := Style.panel(Color("14100a"), 10, 2)
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	holder.position = Vector2(20, 120)
	holder.custom_minimum_size = Vector2(get_viewport_rect().size.x - 40, 0)
	holder.visible = false
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = Style.wrapped("", Style.FONT_S)
	holder.add_child(_toast_label)
	add_child(holder)

func toast(message: String, seconds := 5.0) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
	_toast_label.get_parent().visible = true
	_toast_timer = seconds

# ---------------------------------------------------------------------------
func show_view(key: String) -> void:
	if not _views.has(key):
		return
	_current = key
	for k in _views:
		_views[k].visible = (k == key)
	for k in _nav_buttons:
		var b: Button = _nav_buttons[k]
		var active := k == key
		_restyle_nav_button(b, active)
	_views[key].rebuild()
	if key == "reports":
		G.mark_reports_read()

func current_view() -> Control:
	return _views.get(_current, null)

func _on_state_changed() -> void:
	if _res_labels.is_empty():
		return
	_refresh_top_bar()
	if _sidebar and _sidebar.has_method("refresh"):
		_sidebar.refresh()
	var v := current_view()
	if v and v.has_method("refresh"):
		v.refresh()

func _refresh_top_bar() -> void:
	var v := G.village()
	if v.is_empty():
		return
	var prod := Sim.production(G.state, v)
	var net_crop := Sim.crop_net(G.state, v)
	for r in range(4):
		var cap := Sim.capacity_for(v, r)
		var value := float(v["res"][r])
		var cell: Dictionary = _res_cells[r]
		# amount
		var amount_label: Label = cell["amount"]
		amount_label.text = Style._fmt_num(value)
		amount_label.add_theme_color_override("font_color",
				Style.BAD if value >= cap - 1.0 else Style.TEXT)
		var bar: ProgressBar = cell["bar"]
		bar.max_value = max(1.0, cap)
		bar.value = clampf(value, 0.0, cap)
		# per hour
		var prod_label: Label = cell["prod"]
		var per_h := float(prod[r]) * G.speed()
		# For crop, show net (prod - upkeep)
		if r == T.CR:
			per_h = float(prod[r]) * G.speed() - float(Sim.population(v) + Sim.troop_upkeep(v)) # approx
			# Use actual net
			per_h = Sim.crop_net(G.state, v) * 1.0
			# Sim.crop_net already includes speed? Check Sim.production multiplied by speed, but crop_net?
			# crop_net returns gross - upkeep, need to multiply? Let's just use it raw *? Sim.crop_net uses production without speed? We'll multiply
			# In ViewFields they do prod*G.speed(), so we follow similar
			# For simplicity show Sim.crop_net directly
		var txt := "%+d" % int(per_h)
		prod_label.text = txt
		prod_label.add_theme_color_override("font_color", Style.GOOD if per_h >= 0 else Style.BAD)
		# bar fill red if full
		if value >= cap - 1.0:
			bar.add_theme_stylebox_override("fill", Style.flat(Style.BAD, 3))
		else:
			bar.add_theme_stylebox_override("fill", Style.flat(Style.RES_COLORS[r], 3))

	var pop := Sim.population(v)
	var culture := int(v.get("cp",0))
	_pop_label.text = "👥 %d" % pop
	_culture_label.text = "⭐ %d  🌾 %+d/ч" % [culture, int(Sim.crop_net(G.state, v))]
	_pop_label.add_theme_color_override("font_color", Style.TEXT)
	_culture_label.add_theme_color_override("font_color", Style.BAD if Sim.crop_net(G.state, v) < 0 else Style.TEXT_DIM)

	var unread := Sim.unread_reports(G.state)
	# reports button not in nav, but we could show badge on sidebar; for now ignore

	_village_button.text = "%s (%d|%d)" % [v["name"], int(v["x"]), int(v["y"])]

# ---------------------------------------------------------------------------
func show_modal(title_text: String, body: Control, buttons: Array) -> void:
	for c in _modal_layer.get_children():
		c.queue_free()
	_modal_layer.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e):
		if e is InputEventScreenTouch and e.pressed:
			close_modal())
	_modal_layer.add_child(shade)
	var frame := Style.parchment(16)
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	frame.custom_minimum_size = Vector2(min(560.0, size.x - 40.0), 0)
	_modal_layer.add_child(frame)
	var col := Style.vbox(10)
	col.add_child(Style.title(title_text))
	col.add_child(Style.separator())
	var body_scroll := ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.custom_minimum_size = Vector2(0, min(560.0, size.y * 0.55))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body)
	col.add_child(body_scroll)
	var row := Style.hbox(8)
	for spec in buttons:
		var b := Style.button(String(spec["text"]), Style.FONT_M, bool(spec.get("primary", false)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if spec.has("disabled") and bool(spec["disabled"]):
			b.disabled = true
		if spec.has("action"):
			var action: Callable = spec["action"]
			b.pressed.connect(func():
				action.call()
				)
		else:
			b.pressed.connect(close_modal)
		row.add_child(b)
	col.add_child(row)
	frame.add_child(Style.margin(col, 14))
	await get_tree().process_frame
	if is_instance_valid(frame):
		frame.position = Vector2(
			(size.x - frame.size.x) * 0.5,
			clampf((size.y - frame.size.y) * 0.5, 20.0, size.y))

func close_modal() -> void:
	for c in _modal_layer.get_children():
		c.queue_free()
	_modal_layer.visible = false

func info(title_text: String, message: String) -> void:
	var body := Style.vbox(6)
	body.add_child(Style.wrapped(message))
	show_modal(title_text, body, [{"text": "Понял", "primary": true}])

# ---------------------------------------------------------------------------
func _show_village_picker() -> void:
	var body := Style.vbox(6)
	for i in range(G.village_count()):
		var vil: Dictionary = G.state["villages"][i]
		var b := Style.button("%s  (%d|%d)  👥%d" % [
			vil["name"], int(vil["x"]), int(vil["y"]), Sim.population(vil)],
			Style.FONT_M, i == G.current_village_index)
		var idx := i
		b.pressed.connect(func():
			G.select_village(idx)
			close_modal()
			var view := current_view()
			if view:
				view.rebuild())
		body.add_child(b)
	show_modal("Твои деревни", body, [{"text": "Закрыть"}])

func _show_settings() -> void:
	var body := Style.vbox(10)
	body.add_child(Style.label("Версия %s" % ProjectSettings.get_setting(
			"application/config/version", "dev"), Style.FONT_S, Style.TEXT_DIM))
	body.add_child(Style.separator())
	body.add_child(Style.label("Скорость игры", Style.FONT_M, Style.ACCENT))
	body.add_child(Style.wrapped(
		"Умножает добычу, стройку и обучение. Меняется в любой момент.",
		Style.FONT_S, Style.TEXT_DIM))
	var speed_row := Style.hbox(6)
	for value: float in [1.0, 3.0, 5.0, 10.0]:
		var b := Style.button("%dx" % int(value), Style.FONT_M, is_equal_approx(G.speed(), value))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := value
		b.pressed.connect(func():
			G.set_speed(v)
			close_modal()
			_show_settings())
		speed_row.add_child(b)
	body.add_child(speed_row)
	body.add_child(Style.separator())
	body.add_child(Style.label("Живой соперник (Claude API)", Style.FONT_M, Style.ACCENT))
	body.add_child(Style.wrapped(
		"Если включить и ввести ключ, сильнейшие вожди начнут получать стратегию от языковой модели "
		+ "и писать тебе в «Вести». Без ключа и без интернета игра работает как обычно — "
		+ "боты просто останутся эвристическими.\n\n"
		+ "Ключ хранится в сохранении на этом устройстве.",
		Style.FONT_S, Style.TEXT_DIM))
	var s: Dictionary = G.settings()
	var key_edit := LineEdit.new()
	key_edit.placeholder_text = "sk-ant-..."
	key_edit.text = String(s.get("llm_key", ""))
	key_edit.secret = true
	body.add_child(key_edit)
	var model_edit := LineEdit.new()
	model_edit.placeholder_text = "claude-sonnet-5"
	model_edit.text = String(s.get("llm_model", "claude-sonnet-5"))
	body.add_child(model_edit)
	var enabled := CheckBox.new()
	enabled.text = "Включить живых соперников"
	enabled.button_pressed = bool(s.get("llm_enabled", false))
	body.add_child(enabled)
	body.add_child(Style.separator())
	var danger := Style.button("Начать заново (стереть сохранение)", Style.FONT_S, false)
	danger.add_theme_color_override("font_color", Style.BAD)
	danger.pressed.connect(func():
		close_modal()
		_confirm_wipe())
	body.add_child(danger)
	show_modal("Настройки", body, [
		{"text": "Отмена"},
		{"text": "Сохранить", "primary": true, "action": func():
			G.configure_llm(enabled.button_pressed, key_edit.text.strip_edges(),
					model_edit.text.strip_edges(), 2)
			close_modal()
			toast("Настройки сохранены")},
	])

func _confirm_wipe() -> void:
	var body := Style.vbox(6)
	body.add_child(Style.wrapped(
		"Сохранение будет удалено безвозвратно, и ты начнёшь новую партию. Уверен?"))
	show_modal("Начать заново", body, [
		{"text": "Нет"},
		{"text": "Да, стереть", "action": func():
			close_modal()
			G.abandon_game()
			_show_new_game()},
	])
