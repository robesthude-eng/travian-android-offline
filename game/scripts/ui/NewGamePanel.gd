extends Control

## Tribe and pace selection for a fresh game.

const T := preload("res://game/scripts/core/Tables.gd")
const Style := preload("res://game/scripts/ui/Style.gd")
const Art := preload("res://game/scripts/core/Art.gd")

var _root: Control
var _tribe := T.TRIBE_ROMANS
var _speed := 3.0
var _name_edit: LineEdit
var _tribe_buttons := {}
var _speed_buttons := {}
var _blurb: Label


func setup(root: Control) -> void:
	_root = root


func _ready() -> void:
	var col := Style.vbox(12)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cover: Texture2D = Art.loading_cover()
	if cover:
		var tr := Style.texture(cover, Vector2(0, 160))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(tr)

	col.add_child(Style.label("TRAVIAN OFFLINE", Style.FONT_XL, Style.ACCENT))
	col.add_child(Style.wrapped(
		"Оффлайновая стратегия с живыми соперниками. Время идёт, даже когда игра закрыта.",
		Style.FONT_S, Style.TEXT_DIM))

	col.add_child(Style.label("Как тебя звать?", Style.FONT_M))
	_name_edit = LineEdit.new()
	_name_edit.text = "Вождь"
	_name_edit.max_length = 24
	col.add_child(_name_edit)

	col.add_child(Style.label("Племя", Style.FONT_M))
	var tribe_row := Style.hbox(6)
	for id: String in [T.TRIBE_ROMANS, T.TRIBE_GAULS, T.TRIBE_GERMANS]:
		var b: Button = Style.button(String(T.TRIBES[id]["label"]), Style.FONT_M, id == _tribe)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tribe_id := id
		b.pressed.connect(func(): _pick_tribe(tribe_id))
		tribe_row.add_child(b)
		_tribe_buttons[id] = b
	col.add_child(tribe_row)

	_blurb = Style.wrapped(String(T.TRIBES[_tribe]["blurb"]), Style.FONT_S, Style.TEXT_DIM)
	col.add_child(_blurb)

	col.add_child(Style.label("Темп игры", Style.FONT_M))
	col.add_child(Style.wrapped(
		"Множитель добычи, стройки и обучения. 3x — комфортный темп для телефона.",
		Style.FONT_S, Style.TEXT_DIM))
	var speed_row := Style.hbox(6)
	for value: float in [1.0, 3.0, 5.0, 10.0]:
		var b: Button = Style.button("%dx" % int(value), Style.FONT_M, is_equal_approx(value, _speed))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := value
		b.pressed.connect(func(): _pick_speed(v))
		speed_row.add_child(b)
		_speed_buttons[value] = b
	col.add_child(speed_row)

	col.add_child(Style.spacer())

	var start := Style.button("Основать деревню", Style.FONT_L, true)
	start.pressed.connect(func():
		var player_name := _name_edit.text.strip_edges()
		if player_name == "":
			player_name = "Вождь"
		_root.start_new_game(player_name, _tribe, _speed))
	col.add_child(start)

	add_child(Style.scroll(Style.margin(col, 18)))


func _pick_tribe(id: String) -> void:
	_tribe = id
	_blurb.text = String(T.TRIBES[id]["blurb"])
	for key in _tribe_buttons:
		_restyle(_tribe_buttons[key], key == id)


func _pick_speed(value: float) -> void:
	_speed = value
	for key in _speed_buttons:
		_restyle(_speed_buttons[key], is_equal_approx(float(key), value))


func _restyle(button: Button, primary: bool) -> void:
	var base := Style.ACCENT if primary else Style.PANEL_LIGHT
	var fg := Color("2a2013") if primary else Style.TEXT
	button.add_theme_stylebox_override("normal", Style.flat(base, 10))
	button.add_theme_stylebox_override("hover", Style.flat(base.lightened(0.1), 10))
	button.add_theme_stylebox_override("pressed", Style.flat(base.darkened(0.15), 10))
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)
