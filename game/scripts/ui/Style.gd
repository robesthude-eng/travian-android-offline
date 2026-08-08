extends RefCounted

## Small widget factory so the views stay readable and look consistent.

const BG := Color("221a11")
const PANEL := Color("32261a")
const PANEL_LIGHT := Color("423323")
const ACCENT := Color("c9a227")
const ACCENT_DIM := Color("8a6d3b")
const TEXT := Color("f2e6cf")
const TEXT_DIM := Color("b7a488")
const GOOD := Color("6fbf5e")
const BAD := Color("d05a4a")
const WARN := Color("e0a33a")

const RES_COLORS := [Color("8fbf6a"), Color("c9784a"), Color("9aa8b8"), Color("e0c04a")]

const FONT_S := 13
const FONT_M := 16
const FONT_L := 20
const FONT_XL := 26

const T := preload("res://game/scripts/core/Tables.gd")


static func flat(color: Color, radius := 10, border := 0, border_color := ACCENT_DIM) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border > 0:
		sb.border_width_left = border
		sb.border_width_right = border
		sb.border_width_top = border
		sb.border_width_bottom = border
		sb.border_color = border_color
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func panel(color := PANEL, radius := 12, border := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(color, radius, border))
	return p


static func label(text: String, size := FONT_M, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrapped(text: String, size := FONT_M, color := TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	return label(text, FONT_L, ACCENT)


static func button(text: String, size := FONT_M, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 44)
	var base := ACCENT if primary else PANEL_LIGHT
	var fg := Color("2a2013") if primary else TEXT
	b.add_theme_stylebox_override("normal", flat(base, 10))
	b.add_theme_stylebox_override("hover", flat(base.lightened(0.10), 10))
	b.add_theme_stylebox_override("pressed", flat(base.darkened(0.15), 10))
	b.add_theme_stylebox_override("disabled", flat(PANEL_LIGHT.darkened(0.25), 10))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.3))
	return b


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(child: Control, m := 12) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_bottom", m)
	mc.add_child(child)
	return mc


## Stretch a control across its parent.
##
## A plain Control does NOT lay out its children — they keep their own anchors,
## which default to a zero-sized rect in the top-left corner. Every view in this
## game is a plain Control, so anything added directly to one must be told to
## fill it or it renders as nothing at all.
static func fill(node: Control) -> Control:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node


## A scrollable page. Always used as the root child of a view, so it stretches
## to the view; inside a Container the anchors are ignored and it behaves the
## same as before.
static func scroll(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	fill(sc)
	return sc


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func progress(value: float, maximum: float, color := ACCENT) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = max(1.0, maximum)
	p.value = clampf(value, 0.0, max(1.0, maximum))
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 6)
	# `flat` adds padding meant for panels; a 6px bar must not inherit it.
	var back := flat(Color("1a140d"), 3)
	var fill := flat(color, 3)
	for sb in [back, fill]:
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("background", back)
	p.add_theme_stylebox_override("fill", fill)
	return p


static func texture(tex: Texture2D, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Cost strip: "🪵 120  🧱 100  ⛏️ 150  🌾 30", red where unaffordable.
static func cost_row(cost: Array, have: Array = []) -> HBoxContainer:
	var row := hbox(10)
	for r in range(4):
		if float(cost[r]) <= 0.0:
			continue
		var affordable := have.is_empty() or float(have[r]) >= float(cost[r])
		var l := label("%s %d" % [T.RES_ICONS[r], int(cost[r])], FONT_S,
				TEXT if affordable else BAD)
		row.add_child(l)
	return row


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT_DIM.darkened(0.35)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", sb)
	return s
