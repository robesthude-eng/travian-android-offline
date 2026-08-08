extends RefCounted

## Visual style — rich Travian palette with parchment + wood + gold
## Every view shares the same language so the game stops looking “позорно”.

const BG := Color("1a0f08")               # almost black wood
const BG_LIGHT := Color("241a0e")         # lighter wood for gradients
const PARCHMENT := Color("2e2014")        # view background
const PARCHMENT_LIGHT := Color("3d2e1a")  # elevated card
const WOOD_DARK := Color("1e1206")
const WOOD_MID := Color("2f1e0b")
const PANEL := Color("2e1d0e")
const PANEL_LIGHT := Color("3f2d18")
const PANEL_GOLD_BORDER := Color("7a5a1a")
const ACCENT := Color("d4a934")           # warm gold
const ACCENT_DIM := Color("8a6a1e")
const ACCENT_GLOW := Color("ffd86b")
const TEXT := Color("f5e6c6")
const TEXT_DIM := Color("c2b59a")
const TEXT_DARK := Color("2a1e12")
const GOOD := Color("6fbf5e")
const BAD := Color("d95a4a")
const WARN := Color("e0a33a")

const RES_COLORS := [Color("8fbf6a"), Color("c9784a"), Color("9aa8b8"), Color("e0c04a")]
const RES_ICONS := ["🪵", "🧱", "⛏️", "🌾"]  # keep fallback, but we add texture icons where possible

const FONT_S := 13
const FONT_M := 16
const FONT_L := 20
const FONT_XL := 26
const FONT_XXS := 11

const T := preload("res://game/scripts/core/Tables.gd")

# ---------------------------------------------------------------------------
# Core boxes

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

# Parchment card with subtle gold border + inner shadow
static func parchment(radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = Color("5a3f18")
	sb.shadow_color = Color(0,0,0,0.35)
	sb.shadow_size = 8
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	return p

# Dark wood bar (top / bottom)
static func wood_panel(radius := 0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD_DARK
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_color = Color("3a2610")
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	return p

static func gold_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat(PARCHMENT_LIGHT, 12, 1, ACCENT_DIM)
	sb.shadow_color = Color(0,0,0,0.25)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	return p

# ---------------------------------------------------------------------------
# Text

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

static func small_caps(text: String, color := TEXT_DIM) -> Label:
	var l := label(text.to_upper(), FONT_XXS, color)
	l.add_theme_font_size_override("font_size", FONT_XXS)
	return l

# ---------------------------------------------------------------------------
# Buttons

static func button(text: String, size := FONT_M, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 44)
	var base := ACCENT if primary else PANEL_LIGHT
	var fg := TEXT_DARK if primary else TEXT
	b.add_theme_stylebox_override("normal", flat(base, 10))
	b.add_theme_stylebox_override("hover", flat(base.lightened(0.10), 10))
	b.add_theme_stylebox_override("pressed", flat(base.darkened(0.15), 10))
	b.add_theme_stylebox_override("disabled", flat(PANEL_LIGHT.darkened(0.25), 10))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.3))
	return b

# Gold outlined button for secondary actions
static func outline_button(text: String, size := FONT_M) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 44)
	var sb := flat(PARCHMENT, 10, 1, ACCENT_DIM)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", flat(PARCHMENT_LIGHT, 10, 1, ACCENT))
	b.add_theme_stylebox_override("pressed", flat(WOOD_DARK, 10, 1, ACCENT))
	b.add_theme_color_override("font_color", TEXT)
	return b

# Icon button for bottom nav (icon on top, label bottom)
static func nav_button(icon_tex: Texture2D, label: String, active: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = label
	if icon_tex:
		b.icon = icon_tex
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Put icon above text: we simulate via newline + custom, but Godot button does side-by-side.
		# So we use vertical layout via inner container hack: fallback to text+icon side, but style differently.
	b.add_theme_font_size_override("font_size", FONT_S)
	var bg := ACCENT if active else PANEL_LIGHT
	var fg := TEXT_DARK if active else TEXT_DIM
	if active:
		b.add_theme_stylebox_override("normal", flat(ACCENT, 12, 1, ACCENT_GLOW))
		b.add_theme_stylebox_override("hover", flat(ACCENT.lightened(0.08), 12, 1, ACCENT_GLOW))
	else:
		b.add_theme_stylebox_override("normal", flat(WOOD_MID, 12, 1, Color("3a2a14")))
		b.add_theme_stylebox_override("hover", flat(PANEL_LIGHT, 12, 1, ACCENT_DIM))
	b.add_theme_stylebox_override("pressed", flat(WOOD_DARK, 12))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", TEXT if not active else TEXT_DARK)
	return b

# Circular icon for resources (colored dot with emoji)
static func res_badge(res: int, size: int = 28) -> Control:
	var holder := PanelContainer.new()
	var c := RES_COLORS[res].darkened(0.2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.corner_radius_top_left = size/2
	sb.corner_radius_top_right = size/2
	sb.corner_radius_bottom_left = size/2
	sb.corner_radius_bottom_right = size/2
	sb.border_color = RES_COLORS[res].lightened(0.2)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	holder.add_theme_stylebox_override("panel", sb)
	holder.custom_minimum_size = Vector2(size, size)
	var l := label(RES_ICONS[res], 12, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	return holder

# ---------------------------------------------------------------------------
# Layout helpers

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

static func fill(node: Control) -> Control:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

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

# Cost strip: “🪵 120  🧱 100  ⛏️ 150  🌾 30”, red where unaffordable.
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

# View background: parchment with subtle vignette + top wood trim
static func view_background() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = PARCHMENT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	# vignette
	var vignette := ColorRect.new()
	vignette.color = Color(0,0,0,0.12)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vignette)
	# top trim
	var trim := ColorRect.new()
	trim.color = ACCENT_DIM.darkened(0.4)
	trim.custom_minimum_size = Vector2(0, 2)
	trim.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	trim.offset_bottom = 2
	holder.add_child(trim)
	return holder

# Card with title + content, used for lists
static func card(title: String = "") -> PanelContainer:
	var p := parchment(12)
	var v := vbox(6)
	if title != "":
		v.add_child(label(title, FONT_M, ACCENT))
		v.add_child(separator())
	p.add_child(margin(v, 12))
	return p

# Resource cell for top bar: icon + amount + bar + per hour
static func resource_cell(res: int, amount: float, cap: float, prod_per_h: float) -> Control:
	var col := vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := hbox(4)
	top.add_child(res_badge(res, 22))
	var prod_color := GOOD if prod_per_h >= 0 else BAD
	var prod_text := "%+d/ч" % int(prod_per_h) if prod_per_h != 0 else ""
	var amt_label := label("%s" % _fmt_num(amount), FONT_S, TEXT)
	amt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(amt_label)
	if prod_text != "":
		var prod_label := label(prod_text, FONT_XXS, prod_color)
		prod_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		top.add_child(prod_label)
	col.add_child(top)
	var bar := progress(amount, cap, RES_COLORS[res])
	# color red if near cap
	if amount >= cap - 1.0:
		bar.add_theme_stylebox_override("fill", flat(BAD, 3))
	col.add_child(bar)
	return col

static func _fmt_num(v: float) -> String:
	if v >= 1000000:
		return "%0.1fM" % (v/1000000.0)
	if v >= 10000:
		return "%0.1fK" % (v/1000.0)
	return str(int(v))

# Hero mini badge for sidebar
static func hero_badge(level: int, xp: float, max_xp: float) -> Control:
	var col := vbox(4)
	col.add_child(label("Герой %d ур." % level, FONT_S, ACCENT))
	var bar := progress(xp, max_xp, ACCENT)
	col.add_child(bar)
	col.add_child(label("%d / %d XP" % [int(xp), int(max_xp)], FONT_XXS, TEXT_DIM))
	return col

# Sidebar section header
static func sidebar_header(text: String, icon: String = "") -> Control:
	var row := hbox(6)
	if icon != "":
		row.add_child(label(icon, FONT_M, ACCENT))
	row.add_child(label(text.to_upper(), FONT_XXS, ACCENT_DIM))
	row.add_child(separator())
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 22)
	holder.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return holder
