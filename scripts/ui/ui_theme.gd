class_name UiTheme
extends RefCounted
## Builds the shared warm, earthy theme used by every screen.
##
## Tone: "warm, adventurous, mysterious, and respectful" — parchment text on
## deep forest panels with amber accents; large touch targets for mobile.

const BG := Color("161c18")
const PANEL := Color("232c25")
const PANEL_LIGHT := Color("2f3a31")
const BORDER := Color("8a6d45")
const TEXT := Color("f1e8d6")
const TEXT_DIM := Color("b9b09d")
const ACCENT := Color("e3a857")
const ACCENT_DARK := Color("b07b33")
const GOOD := Color("8cc46f")
const WARN := Color("e0b04f")
const BAD := Color("d9674e")
const AETHER := Color("7fd3d8")
const HEALTH := Color("d65a4a")
const STAMINA := Color("e8c35a")
const ENERGY := Color("7fc46a")
const HAPPINESS := Color("e88aa8")

const FONT_SIZE := 22
const FONT_SMALL := 18
const FONT_HEADING := 30
const FONT_TITLE := 46
const TOUCH_MIN := 64

static var _theme: Theme
static var _heading_font: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func heading_font() -> Font:
	if _heading_font == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif", "Serif"])
		font.font_weight = 600
		_heading_font = font
	return _heading_font


static func box(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT,
		border_width: int = 0, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	style.anti_aliasing = true
	return style


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	# Labels
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", heading_font())
	theme.set_font_size("font_size", "HeadingLabel", FONT_HEADING)
	theme.set_color("font_color", "HeadingLabel", ACCENT)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", heading_font())
	theme.set_font_size("font_size", "TitleLabel", FONT_TITLE)
	theme.set_color("font_color", "TitleLabel", TEXT)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", TEXT_DIM)
	theme.set_font_size("font_size", "DimLabel", FONT_SMALL)

	# Rich text
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_font_size("bold_font_size", "RichTextLabel", FONT_SIZE)

	# Buttons
	var normal := box(PANEL_LIGHT, 14, BORDER, 2, 16)
	var hover := box(PANEL_LIGHT.lightened(0.08), 14, ACCENT, 2, 16)
	var pressed := box(PANEL.darkened(0.1), 14, ACCENT, 2, 16)
	var disabled := box(PANEL.darkened(0.2), 14, BORDER.darkened(0.5), 2, 16)
	var focus := box(Color.TRANSPARENT, 14, ACCENT, 3, 16)
	for state: Array in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["disabled", disabled], ["focus", focus], ["hover_pressed", pressed]]:
		theme.set_stylebox(state[0], "Button", state[1])
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	theme.set_constant("h_separation", "Button", 10)

	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", box(ACCENT_DARK, 14, ACCENT, 2, 16))
	theme.set_stylebox("hover", "PrimaryButton", box(ACCENT_DARK.lightened(0.1), 14, TEXT, 2, 16))
	theme.set_stylebox("pressed", "PrimaryButton", box(ACCENT_DARK.darkened(0.15), 14, TEXT, 2, 16))
	theme.set_stylebox("hover_pressed", "PrimaryButton", box(ACCENT_DARK.darkened(0.15), 14, TEXT, 2, 16))
	theme.set_color("font_color", "PrimaryButton", Color("1d1609"))
	theme.set_color("font_hover_color", "PrimaryButton", Color("1d1609"))
	theme.set_color("font_pressed_color", "PrimaryButton", Color("1d1609"))
	theme.set_color("font_focus_color", "PrimaryButton", Color("1d1609"))

	theme.set_type_variation("FlatButton", "Button")
	theme.set_stylebox("normal", "FlatButton", box(Color(0, 0, 0, 0.0), 12, Color.TRANSPARENT, 0, 12))
	theme.set_stylebox("hover", "FlatButton", box(Color(1, 1, 1, 0.06), 12, Color.TRANSPARENT, 0, 12))
	theme.set_stylebox("pressed", "FlatButton", box(Color(1, 1, 1, 0.1), 12, Color.TRANSPARENT, 0, 12))
	theme.set_stylebox("hover_pressed", "FlatButton", box(Color(1, 1, 1, 0.1), 12, Color.TRANSPARENT, 0, 12))

	# Panels
	theme.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.96), 18, BORDER, 2, 20))
	theme.set_stylebox("panel", "Panel", box(Color(PANEL, 0.96), 18, BORDER, 2, 20))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", box(PANEL_LIGHT, 14, Color.TRANSPARENT, 0, 14))
	theme.set_type_variation("SheetPanel", "PanelContainer")
	var sheet := box(Color(PANEL, 0.97), 22, BORDER, 2, 22)
	theme.set_stylebox("panel", "SheetPanel", sheet)

	# Progress bars
	theme.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), 8, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT, 8, Color.TRANSPARENT, 0, 0))
	theme.set_color("font_color", "ProgressBar", TEXT)
	theme.set_font_size("font_size", "ProgressBar", FONT_SMALL - 2)

	# Sliders / checkboxes
	theme.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.45), 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber_area", "HSlider", box(ACCENT_DARK, 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 6, Color.TRANSPARENT, 0, 4))
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", TEXT)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)

	# Line edit
	theme.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.35), 12, BORDER, 2, 14))
	theme.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.35), 12, ACCENT, 2, 14))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_font_size("font_size", "LineEdit", FONT_HEADING - 4)

	# Scroll bars: wide enough to grab on touch screens.
	theme.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.2), 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber", "VScrollBar", box(BORDER, 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, 6, Color.TRANSPARENT, 0, 4))

	# Tooltips
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL, 10, BORDER, 1, 10))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	return theme
