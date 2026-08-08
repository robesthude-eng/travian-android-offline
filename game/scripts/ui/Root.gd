extends Control

## Main UI shell: top resource bar, view switching, bottom navigation, modals.

const T := preload("res://game/scripts/core/Tables.gd")
const Sim := preload("res://game/scripts/core/Sim.gd")
const Style := preload("res://game/scripts/ui/Style.gd")
const Actions := preload("res://game/scripts/core/Actions.gd")

const ViewFields := preload("res://game/scripts/ui/ViewFields.gd")
const ViewVillage := preload("res://game/scripts/ui/ViewVillage.gd")
const ViewMap := preload("res://game/scripts/ui/ViewMap.gd")
const ViewArmy := preload("res://game/scripts/ui/ViewArmy.gd")
const ViewHero := preload("res://game/scripts/ui/ViewHero.gd")
const ViewReports := preload("res://game/scripts/ui/ViewReports.gd")
const NewGamePanel := preload("res://game/scripts/ui/NewGamePanel.gd")

var _content: Control
var _views := {}
var _current := ""
var _nav_buttons := {}
var _res_labels := []
var _res_bars := []
var _pop_label: Label
var _village_button: Button
var _modal_layer: Control
var _toast_label: Label
var _toast_timer := 0.0
## The offline summary is emitted during load_game(), before the shell exists,
## so it is parked here and shown once there is something to show it in.
var _pending_offline := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Style.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
# Headless layout self-test
# ---------------------------------------------------------------------------
#
# The first build rendered nothing but the background colour: every view is a
# plain Control, which does not lay out its children, so each page collapsed to
# a zero-sized rect in the corner. Nothing in the simulation tests could see
# that. This boots the real UI and asserts that the screens actually occupy the
# screen.
#
#   godot --headless -- --uitest

## Largest visible rectangle anywhere under `node`.
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

	# The start screen must be visible before a game exists.
	if _views.is_empty():
		var painted := _painted_area(self)
		if painted < screen * 0.2:
			failures.append("new game panel painted %.0f of %.0f px" % [painted, screen])
		start_new_game("Тест", T.TRIBE_ROMANS, 3.0)
		await settle.call()

	if _views.is_empty():
		failures.append("game shell was never built")
	else:
		for key in ["fields", "village", "map", "army", "hero", "reports"]:
			show_view(key)
			await settle.call()
			var view: Control = _views[key]
			if view.size.x <= 0.0 or view.size.y <= 0.0:
				failures.append("view '%s' has no size" % key)
				continue
			var painted := _painted_area(view)
			if painted < view.size.x * 50.0:
				failures.append("view '%s' painted only %.0f px" % [key, painted])

		# The top bar must be showing real numbers, not placeholders.
		if _res_labels.is_empty():
			failures.append("top bar has no resource labels")
		elif String(_res_labels[0].text).strip_edges() == "":
			failures.append("top bar resource label is empty")

		# A modal has to be reachable and visible.
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

	# Anything that happened while away is already in the report list; surface
	# the ones the player actually needs to know about.
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
# New game
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
# Shell
# ---------------------------------------------------------------------------

func _build_game_ui() -> void:
	_views.clear()
	_nav_buttons.clear()
	_res_labels.clear()
	_res_bars.clear()

	var column := Style.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	column.add_child(_build_top_bar())

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	column.add_child(_content)

	column.add_child(_build_nav())

	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.visible = false
	add_child(_modal_layer)

	_build_toast()

	_views["fields"] = ViewFields.new()
	_views["village"] = ViewVillage.new()
	_views["map"] = ViewMap.new()
	_views["army"] = ViewArmy.new()
	_views["hero"] = ViewHero.new()
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
	var panel := Style.panel(Style.PANEL, 0)
	var col := Style.vbox(4)

	var head := Style.hbox(6)
	_village_button = Style.button("Деревня", Style.FONT_S, false)
	_village_button.custom_minimum_size = Vector2(0, 32)
	_village_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_village_button.pressed.connect(_show_village_picker)
	head.add_child(_village_button)

	_pop_label = Style.label("", Style.FONT_S, Style.TEXT_DIM)
	head.add_child(_pop_label)

	var settings_btn := Style.button("⚙", Style.FONT_S, false)
	settings_btn.custom_minimum_size = Vector2(40, 32)
	settings_btn.pressed.connect(_show_settings)
	head.add_child(settings_btn)
	col.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	for r in range(4):
		var cell := Style.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Style.label("%s 0" % T.RES_ICONS[r], Style.FONT_S)
		cell.add_child(l)
		var bar := Style.progress(0, 1, Style.RES_COLORS[r])
		cell.add_child(bar)
		grid.add_child(cell)
		_res_labels.append(l)
		_res_bars.append(bar)
	col.add_child(grid)

	panel.add_child(Style.margin(col, 8))
	return panel


func _build_nav() -> Control:
	var panel := Style.panel(Style.PANEL, 0)
	var row := Style.hbox(4)
	var items := [
		["fields", "Поля", "🌾"],
		["village", "Деревня", "🏛️"],
		["map", "Карта", "🗺️"],
		["army", "Армия", "⚔️"],
		["hero", "Герой", "🦸"],
		["reports", "Вести", "📜"],
	]
	for item in items:
		var key: String = item[0]
		var b := Style.button("%s\n%s" % [item[2], item[1]], Style.FONT_S, false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func(): show_view(key))
		row.add_child(b)
		_nav_buttons[key] = b
	panel.add_child(Style.margin(row, 6))
	return panel


func _build_toast() -> void:
	var holder := Style.panel(Color("14100a"), 10, 2)
	# Positioned by hand below, so keep the anchors in the corner rather than
	# fighting a preset that also moves it.
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
# View switching
# ---------------------------------------------------------------------------

func show_view(key: String) -> void:
	if not _views.has(key):
		return
	_current = key
	for k in _views:
		_views[k].visible = (k == key)
	for k in _nav_buttons:
		var b: Button = _nav_buttons[k]
		b.add_theme_color_override("font_color", Style.ACCENT if k == key else Style.TEXT)
	_views[key].rebuild()
	if key == "reports":
		G.mark_reports_read()


func current_view() -> Control:
	return _views.get(_current, null)


func _on_state_changed() -> void:
	if _res_labels.is_empty():
		return
	_refresh_top_bar()
	var v := current_view()
	if v and v.has_method("refresh"):
		v.refresh()


func _refresh_top_bar() -> void:
	var v := G.village()
	if v.is_empty():
		return
	for r in range(4):
		var cap := Sim.capacity_for(v, r)
		var value := float(v["res"][r])
		_res_labels[r].text = "%s %s" % [T.RES_ICONS[r], G.fmt_number(value)]
		_res_labels[r].add_theme_color_override("font_color",
				Style.BAD if value >= cap - 1.0 else Style.TEXT)
		_res_bars[r].max_value = max(1.0, cap)
		_res_bars[r].value = clampf(value, 0.0, cap)

	var net := Sim.crop_net(G.state, v)
	var pop := Sim.population(v)
	_pop_label.text = "👥 %d   🌾 %+d/ч" % [pop, int(net)]
	_pop_label.add_theme_color_override("font_color",
			Style.BAD if net < 0 else Style.TEXT_DIM)

	var unread := Sim.unread_reports(G.state)
	if _nav_buttons.has("reports"):
		_nav_buttons["reports"].text = "📜\nВести" + ("" if unread == 0 else " (%d)" % unread)

	_village_button.text = "%s (%d|%d)" % [v["name"], int(v["x"]), int(v["y"])]


# ---------------------------------------------------------------------------
# Modals
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

	var frame := Style.panel(Style.PANEL, 16, 2)
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

	# Centre the frame once it has been laid out.
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
# Pickers and settings
# ---------------------------------------------------------------------------

func _show_village_picker() -> void:
	var body := Style.vbox(6)
	for i in range(G.village_count()):
		var v: Dictionary = G.state["villages"][i]
		var b := Style.button("%s  (%d|%d)  👥%d" % [
			v["name"], int(v["x"]), int(v["y"]), Sim.population(v)],
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

	# So you can tell which build is on the phone without digging through
	# GitHub — useful the moment something looks wrong.
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
