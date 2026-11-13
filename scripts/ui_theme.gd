class_name UITheme
extends RefCounted

const TITLE_FONT_PATH := "res://assets/fonts/Creepster-Regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/SpecialElite-Regular.ttf"

const COL_BLOOD := Color(0.78, 0.12, 0.12)
const COL_BLOOD_BRIGHT := Color(0.92, 0.18, 0.18)
const COL_GOLD := Color(1.0, 0.8, 0.25)
const COL_PAPER := Color(0.93, 0.89, 0.78)
const COL_GREY := Color(0.62, 0.62, 0.62)
const COL_GREEN := Color(0.45, 0.9, 0.45)
const COL_PANEL_BG := Color(0.06, 0.06, 0.07, 0.88)
const COL_PANEL_BORDER := Color(0.38, 0.3, 0.27)
const COL_BTN_BG := Color(0.12, 0.11, 0.11, 1.0)
const COL_BTN_HOVER := Color(0.38, 0.09, 0.09, 1.0)
const COL_BTN_PRESSED := Color(0.2, 0.05, 0.05, 1.0)

static var _title_font: Font = null
static var _body_font: Font = null

static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(TITLE_FONT_PATH) as Font
	return _title_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = load(BODY_FONT_PATH) as Font
	return _body_font

static func panel_style(bg: Color = COL_PANEL_BG, border: Color = COL_PANEL_BORDER, border_w: int = 1, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s

static func button_style(bg: Color, border: Color, border_w: int = 1, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 9.0
	s.content_margin_bottom = 9.0
	return s

static func apply_button(btn: Button, font_size: int = 18) -> void:
	btn.add_theme_stylebox_override("normal", button_style(COL_BTN_BG, COL_PANEL_BORDER, 1, 6))
	btn.add_theme_stylebox_override("hover", button_style(COL_BTN_HOVER, COL_BLOOD_BRIGHT, 2, 6))
	btn.add_theme_stylebox_override("pressed", button_style(COL_BTN_PRESSED, COL_BLOOD_BRIGHT, 2, 6))
	btn.add_theme_stylebox_override("focus", button_style(COL_BTN_BG, COL_GOLD, 1, 6))
	btn.add_theme_stylebox_override("disabled", button_style(Color(0.08, 0.08, 0.08), Color(0.2, 0.2, 0.2), 1, 6))
	btn.add_theme_font_override("font", body_font())
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", COL_PAPER)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.7, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

static func apply_panel(panel: PanelContainer, bg: Color = COL_PANEL_BG, border: Color = COL_PANEL_BORDER, border_w: int = 1, radius: int = 8) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(bg, border, border_w, radius))

static func bar_bg_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	s.border_color = Color(0.32, 0.3, 0.28)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s

static func bar_fill_style(fill_color: Color = COL_GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill_color
	s.set_corner_radius_all(4)
	return s

static func apply_progress_bar(bar: ProgressBar) -> void:
	bar.add_theme_stylebox_override("background", bar_bg_style())
	bar.add_theme_stylebox_override("fill", bar_fill_style())

static func apply_line_edit(le: LineEdit, font_size: int = 16) -> void:
	le.add_theme_stylebox_override("normal", button_style(Color(0.08, 0.08, 0.09, 1.0), COL_PANEL_BORDER, 1, 6))
	le.add_theme_stylebox_override("focus", button_style(Color(0.08, 0.08, 0.09, 1.0), COL_BLOOD_BRIGHT, 2, 6))
	le.add_theme_font_override("font", body_font())
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_color_override("font_color", COL_PAPER)
	le.add_theme_color_override("font_placeholder_color", Color(0.45, 0.45, 0.45))

static func make_label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func make_vignette(width: int, height: int) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.85))
	grad.offsets = PackedFloat32Array([0.5, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.42)
	tex.fill_to = Vector2(1.0, 0.95)
	tex.width = width
	tex.height = height
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
