extends Control

## New game wizard - exact Travian Legends style: tribe -> position -> name

const T := preload("res://game/scripts/core/Tables.gd")
const Style := preload("res://game/scripts/ui/Style.gd")
const Art := preload("res://game/scripts/core/Art.gd")

var _root: Control
var _tribe := T.TRIBE_GAULS
var _position := "southeast" # northwest, northeast, southwest, southeast
var _name_edit: LineEdit
var _step := 0 # 0=tribe, 1=position, 2=confirm
var _tribe_buttons := {}
var _pos_buttons := {}

const TRIBE_INFO := {
	T.TRIBE_ROMANS: {
		"label": "Римляне",
		"icon": "res://game/assets/tribe_roman.png",
		"bullets": [
			"Требуют небольшого времени на игру",
			"Сбалансированная армия",
			"Сильная защита с преторианцами",
			"Хорошо подходят для новичков"
		],
		"recommended": false
	},
	T.TRIBE_GAULS: {
		"label": "Галлы",
		"icon": "res://game/assets/tribe_gaul.png",
		"bullets": [
			"Небольшие требования ко времени на игру",
			"Хорошая защита и тайники",
			"Превосходная быстрая кавалерия",
			"Хорошо подходят для новичков"
		],
		"recommended": true
	},
	T.TRIBE_GERMANS: {
		"label": "Германцы",
		"icon": "res://game/assets/tribe_german.png",
		"bullets": [
			"Требуют большого времени на игру",
			"Хорошо подходят для набегов в начале игры",
			"Сильная, дешевая пехота",
			"Для воинственных игроков"
		],
		"recommended": false
	}
}

const POS_INFO := {
	"northwest": "Северо-запад",
	"northeast": "Северо-восток",
	"southwest": "Юго-запад",
	"southeast": "Юго-восток"
}

func setup(root: Control) -> void:
	_root = root

func _ready() -> void:
	_show_step(0)

func _show_step(step: int) -> void:
	_step = step
	for c in get_children():
		c.queue_free()
	var bg := _build_background()
	add_child(bg)
	var col := Style.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	# Top bar
	col.add_child(_build_top_bar())
	# Content
	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(content)
	match step:
		0: _build_tribe_step(content)
		1: _build_position_step(content)
		2: _build_confirm_step(content)
	# Bottom button
	col.add_child(_build_bottom_button())

func _build_background() -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color("5a7ab5")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var cover := Art.loading_cover()
	if cover:
		var tr := Style.texture(cover, Vector2(720, 1280))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.modulate = Color(1,1,1,0.85)
		holder.add_child(tr)
	var vignette := ColorRect.new()
	vignette.color = Color(0,0,0,0.15)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vignette)
	return holder

func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a3f5c")
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", sb)
	var row := Style.hbox(8)
	row.add_child(Style.label("America 31", 16, Color.WHITE))
	row.add_child(Style.spacer())
	# X3 boot icon
	var boot := Style.label("🥾 X3", 14, Color("ffcc66"))
	row.add_child(boot)
	var cal := Style.label("📅 1", 14, Color.WHITE)
	row.add_child(cal)
	var close := Style.button("✕", 14, false)
	close.custom_minimum_size = Vector2(36,36)
	close.pressed.connect(func(): _root.close_modal() if _root.has_method("close_modal") else null)
	# Just visual, not functional
	row.add_child(close)
	panel.add_child(row)
	return panel

func _build_tribe_step(parent: Control) -> void:
	var col := Style.vbox(8)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(col)
	# Title
	var title := Style.label("Выбор народа", 20, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(title)
	# Large leader image
	var leader_tex: Texture2D = null
	var info: Dictionary = TRIBE_INFO[_tribe]
	var icon_path: String = info.get("icon", "")
	if ResourceLoader.exists(icon_path):
		leader_tex = ResourceLoader.load(icon_path)
	var leader_holder := Control.new()
	leader_holder.custom_minimum_size = Vector2(0, 340)
	leader_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if leader_tex:
		var tr := Style.texture(leader_tex, Vector2(320, 380))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		leader_holder.add_child(tr)
	col.add_child(leader_holder)
	# Tribe selector strip (3 small)
	var strip := PanelContainer.new()
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color("f5e6c8")
	sbs.border_color = Color("8d6e63")
	sbs.border_width_top = 1
	sbs.border_width_bottom = 1
	sbs.content_margin_top = 4
	sbs.content_margin_bottom = 4
	strip.add_theme_stylebox_override("panel", sbs)
	var hbox := Style.hbox(0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in [T.TRIBE_ROMANS, T.TRIBE_GAULS, T.TRIBE_GERMANS]:
		var tex: Texture2D = null
		var ip: String = TRIBE_INFO[id].get("icon", "")
		if ResourceLoader.exists(ip):
			tex = ResourceLoader.load(ip)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tex:
			btn.icon = tex
			btn.expand_icon = true
		btn.pressed.connect(func(): _pick_tribe(id))
		# Highlight selected
		if id == _tribe:
			btn.add_theme_stylebox_override("normal", Style.flat(Color.WHITE, 8, 2, Color("2a3f5c")))
			btn.modulate = Color.WHITE
		else:
			btn.add_theme_stylebox_override("normal", Style.flat(Color("f5e6c8"), 8, 0))
			btn.modulate = Color(1,1,1,0.55)
		hbox.add_child(btn)
		_tribe_buttons[id] = btn
	strip.add_child(hbox)
	col.add_child(strip)
	# Info card
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("fff8e1")
	csb.corner_radius_top_left = 8
	csb.corner_radius_top_right = 8
	csb.corner_radius_bottom_left = 8
	csb.corner_radius_bottom_right = 8
	csb.border_color = Color("8d6e63")
	csb.border_width_left = 1
	csb.border_width_right = 1
	csb.border_width_top = 1
	csb.border_width_bottom = 1
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 12
	csb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", csb)
	var vbox := Style.vbox(8)
	if bool(info.get("recommended", false)):
		var badge := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color("2196f3")
		bsb.corner_radius_top_left = 12
		bsb.corner_radius_top_right = 12
		bsb.corner_radius_bottom_left = 12
		bsb.corner_radius_bottom_right = 12
		badge.add_theme_stylebox_override("panel", bsb)
		var lbl := Style.label("РЕКОМЕНДОВАНО", 12, Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(lbl)
		vbox.add_child(badge)
	vbox.add_child(Style.label(info.get("label", ""), 18, Color("3e2723")))
	for bullet in info.get("bullets", []):
		var row := Style.hbox(8)
		row.add_child(Style.label("⚔️", 14, Color("5d4037")))
		row.add_child(Style.wrapped(bullet, 14, Color("4e342e")))
		vbox.add_child(row)
	card.add_child(vbox)
	col.add_child(Style.margin(card, 12))

func _build_position_step(parent: Control) -> void:
	var col := Style.vbox(8)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(col)
	var title := Style.label("Выбор начальной позиции", 18, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	# Parchment map 2x2
	var map_panel := PanelContainer.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color("f5e6c8")
	msb.corner_radius_top_left = 12
	msb.corner_radius_top_right = 12
	msb.corner_radius_bottom_left = 12
	msb.corner_radius_bottom_right = 12
	msb.border_color = Color("8d6e63")
	msb.border_width_left = 2
	msb.border_width_right = 2
	msb.border_width_top = 2
	msb.border_width_bottom = 2
	map_panel.add_theme_stylebox_override("panel", msb)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	for key: String in ["northwest", "northeast", "southwest", "southeast"]:
		var cell := PanelContainer.new()
		var is_sel: bool = key == _position
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color("fff8e1") if not is_sel else Color("e8f5e9")
		csb.border_color = Color("2a3f5c") if is_sel else Color("bcaaa4")
		csb.border_width_left = 2 if is_sel else 1
		csb.border_width_right = 2 if is_sel else 1
		csb.border_width_top = 2 if is_sel else 1
		csb.border_width_bottom = 2 if is_sel else 1
		cell.add_theme_stylebox_override("panel", csb)
		cell.custom_minimum_size = Vector2(0, 140)
		var vbox := Style.vbox(4)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(Style.label(POS_INFO[key], 14, Color("3e2723")))
		if key == "southeast":
			var rec := PanelContainer.new()
			var rsb := StyleBoxFlat.new()
			rsb.bg_color = Color("2196f3")
			rsb.corner_radius_top_left = 8
			rsb.corner_radius_top_right = 8
			rsb.corner_radius_bottom_left = 8
			rsb.corner_radius_bottom_right = 8
			rec.add_theme_stylebox_override("panel", rsb)
			rec.add_child(Style.label("РЕКОМЕНДОВАНО", 10, Color.WHITE))
			vbox.add_child(rec)
			if is_sel:
				# show banner icon
				var banner := Style.label("🏛️", 24, Color("8d6e63"))
				banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(banner)
		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 140)
		btn.modulate = Color(1,1,1,0.01)
		var k := key
		btn.pressed.connect(func(): _pick_position(k))
		cell.add_child(vbox)
		cell.add_child(btn)
		# Make button fill cell
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grid.add_child(cell)
		_pos_buttons[key] = grid.get_child(grid.get_child_count()-1)
	map_panel.add_child(Style.margin(grid, 8))
	col.add_child(Style.margin(map_panel, 12))

func _build_confirm_step(parent: Control) -> void:
	var col := Style.vbox(12)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(col)
	var title := Style.label("Подтвердить выбор", 18, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	# Tribe summary
	var card1 := PanelContainer.new()
	var csb1 := StyleBoxFlat.new()
	csb1.bg_color = Color("fff8e1")
	csb1.corner_radius_top_left = 8
	csb1.corner_radius_top_right = 8
	csb1.corner_radius_bottom_left = 8
	csb1.corner_radius_bottom_right = 8
	csb1.border_color = Color("8d6e63")
	csb1.border_width_left = 1
	csb1.border_width_right = 1
	csb1.border_width_top = 1
	csb1.border_width_bottom = 1
	card1.add_theme_stylebox_override("panel", csb1)
	var row1 := Style.hbox(12)
	var tex: Texture2D = null
	var ip: String = TRIBE_INFO[_tribe].get("icon", "")
	if ResourceLoader.exists(ip):
		tex = ResourceLoader.load(ip)
	if tex:
		row1.add_child(Style.texture(tex, Vector2(64,64)))
	var vbox1 := Style.vbox(4)
	vbox1.add_child(Style.label(TRIBE_INFO[_tribe].get("label", ""), 16, Color("3e2723")))
	var change_tribe := Style.button("Сменить народ", 12, false)
	change_tribe.custom_minimum_size = Vector2(0, 32)
	change_tribe.pressed.connect(func(): _show_step(0))
	vbox1.add_child(change_tribe)
	row1.add_child(vbox1)
	card1.add_child(Style.margin(row1, 12))
	col.add_child(Style.margin(card1, 12))
	# Position summary
	var card2 := PanelContainer.new()
	var csb2 := StyleBoxFlat.new()
	csb2.bg_color = Color("fff8e1")
	csb2.corner_radius_top_left = 8
	csb2.corner_radius_top_right = 8
	csb2.corner_radius_bottom_left = 8
	csb2.corner_radius_bottom_right = 8
	csb2.border_color = Color("8d6e63")
	csb2.border_width_left = 1
	csb2.border_width_right = 1
	csb2.border_width_top = 1
	csb2.border_width_bottom = 1
	card2.add_theme_stylebox_override("panel", csb2)
	var row2 := Style.hbox(12)
	row2.add_child(Style.label("🗺️", 32, Color("8d6e63")))
	var vbox2 := Style.vbox(4)
	vbox2.add_child(Style.label(POS_INFO[_position], 16, Color("3e2723")))
	var change_pos := Style.button("Изменить позицию", 12, false)
	change_pos.custom_minimum_size = Vector2(0, 32)
	change_pos.pressed.connect(func(): _show_step(1))
	vbox2.add_child(change_pos)
	row2.add_child(vbox2)
	card2.add_child(Style.margin(row2, 12))
	col.add_child(Style.margin(card2, 12))
	# Name input
	var card3 := PanelContainer.new()
	var csb3 := StyleBoxFlat.new()
	csb3.bg_color = Color("fff8e1")
	csb3.corner_radius_top_left = 8
	csb3.corner_radius_top_right = 8
	csb3.corner_radius_bottom_left = 8
	csb3.corner_radius_bottom_right = 8
	csb3.border_color = Color("8d6e63")
	csb3.border_width_left = 1
	csb3.border_width_right = 1
	csb3.border_width_top = 1
	csb3.border_width_bottom = 1
	card3.add_theme_stylebox_override("panel", csb3)
	var vbox3 := Style.vbox(8)
	vbox3.add_child(Style.label("Введите имя персонажа:", 14, Color("3e2723")))
	_name_edit = LineEdit.new()
	_name_edit.text = "casano"
	_name_edit.placeholder_text = "3 - 15 символов"
	_name_edit.max_length = 15
	vbox3.add_child(_name_edit)
	var hint := Style.hbox(4)
	var check := Style.label("✓", 14, Color("2e7d32"))
	hint.add_child(check)
	hint.add_child(Style.label("3 - 15 символов", 12, Color("6d4c41")))
	vbox3.add_child(hint)
	vbox3.add_child(Style.label("Это имя вашего персонажа в игровом мире.", 12, Color("8d6e63")))
	card3.add_child(Style.margin(vbox3, 12))
	col.add_child(Style.margin(card3, 12))

func _build_bottom_button() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0,0)
	panel.add_theme_stylebox_override("panel", sb)
	var btn: Button
	match _step:
		0:
			btn = Style.button("Выбрать народ", 16, true)
			btn.custom_minimum_size = Vector2(0, 48)
			btn.pressed.connect(func(): _show_step(1))
		1:
			btn = Style.button("Выбрать позицию", 16, true)
			btn.custom_minimum_size = Vector2(0, 48)
			btn.pressed.connect(func(): _show_step(2))
		2:
			btn = Style.button("Начать игру", 16, true)
			btn.custom_minimum_size = Vector2(0, 48)
			btn.pressed.connect(func(): _start_game())
	var holder := Style.margin(btn, 12)
	panel.add_child(holder)
	return panel

func _pick_tribe(id: String) -> void:
	_tribe = id
	_show_step(0)

func _pick_position(pos: String) -> void:
	_position = pos
	_show_step(1)

func _start_game() -> void:
	var player_name := "Вождь"
	if _name_edit and _name_edit.text.strip_edges() != "":
		player_name = _name_edit.text.strip_edges()
	# Map position to world coordinates (quadrant offset)
	var offset := Vector2i.ZERO
	match _position:
		"northwest": offset = Vector2i(-30, -30)
		"northeast": offset = Vector2i(30, -30)
		"southwest": offset = Vector2i(-30, 30)
		"southeast": offset = Vector2i(30, 30)
	# Store offset for World.new_game to use (via G)
	G.set_start_offset(offset)
	_root.start_new_game(player_name, _tribe, 3.0)

func _restyle(button: Button, primary: bool) -> void:
	pass
