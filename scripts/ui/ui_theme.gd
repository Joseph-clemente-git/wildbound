class_name UiTheme
extends RefCounted
## Builds the shared warm, earthy theme used by every screen.
##
## Tone: "warm, adventurous, mysterious, and respectful" — parchment text on
## deep forest panels with amber accents; large touch targets for mobile.

## Base palette. Semantic colours below are static vars so accessibility
## settings (colour-blind palettes, high contrast) can swap them at runtime;
## the same colour always means the same thing everywhere.
static var BG := Color("161c18")
static var PANEL := Color("232c25")
static var PANEL_LIGHT := Color("2f3a31")
static var BORDER := Color("8a6d45")
static var TEXT := Color("f1e8d6")
static var TEXT_DIM := Color("b9b09d")
static var ACCENT := Color("e3a857")
static var ACCENT_DARK := Color("b07b33")
static var GOOD := Color("8cc46f")
static var WARN := Color("e0b04f")
static var BAD := Color("d9674e")
static var AETHER := Color("7fd3d8")
static var HEALTH := Color("d65a4a")
static var STAMINA := Color("e8c35a")
static var ENERGY := Color("7fc46a")
static var HAPPINESS := Color("e88aa8")

## Colour-blind safe replacements for the semantic colours (never colour
## alone: bars and states also carry labels and icons).
const PALETTES := {
	"off": {},
	"deuteranopia": {"GOOD": "5fa8e8", "BAD": "e8913a", "HEALTH": "e8743a", "ENERGY": "5f9ed8",
			"WARN": "f0d060", "HAPPINESS": "c890e0"},
	"protanopia": {"GOOD": "5fa8e8", "BAD": "f0a030", "HEALTH": "f0a030", "ENERGY": "5f9ed8",
			"WARN": "f0e070", "HAPPINESS": "b0a0f0"},
	"tritanopia": {"GOOD": "4fc0a0", "BAD": "e05a7a", "STAMINA": "f0a0c0", "AETHER": "f08a8a",
			"ENERGY": "4fc0a0", "WARN": "e8a0b0"},
}
const BASE := {
	"BG": "161c18", "PANEL": "232c25", "PANEL_LIGHT": "2f3a31", "BORDER": "8a6d45", "TEXT": "f1e8d6",
	"TEXT_DIM": "b9b09d", "ACCENT": "e3a857", "ACCENT_DARK": "b07b33", "GOOD": "8cc46f", "WARN": "e0b04f",
	"BAD": "d9674e", "AETHER": "7fd3d8", "HEALTH": "d65a4a", "STAMINA": "e8c35a", "ENERGY": "7fc46a",
	"HAPPINESS": "e88aa8",
}
const HIGH_CONTRAST := {"BG": "000000", "PANEL": "0c0f0d", "PANEL_LIGHT": "1c241e", "BORDER": "f0c070",
		"TEXT": "ffffff", "TEXT_DIM": "e0dccf"}

## Text size multiplier (accessibility: up to 1.5x).
static var text_scale := 1.0

const FONT_SIZE := 22
const FONT_SMALL := 18
const FONT_HEADING := 30
const FONT_TITLE := 46
const TOUCH_MIN := 64

static var _theme: Theme
static var _heading_font: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_build_into(_theme)
	return _theme


## Scaled font size: always use this instead of raw numbers.
static func fs(size: int) -> int:
	return roundi(size * text_scale)


## Re-reads accessibility settings and rebuilds the shared theme in place, so
## every open screen updates immediately.
static func refresh(colorblind: String, high_contrast: bool, new_text_scale: float) -> void:
	text_scale = clampf(new_text_scale, 0.8, 1.6)
	var colours: Dictionary = BASE.duplicate()
	if high_contrast:
		colours.merge(HIGH_CONTRAST, true)
	colours.merge(PALETTES.get(colorblind, {}), true)
	BG = Color(colours["BG"])
	PANEL = Color(colours["PANEL"])
	PANEL_LIGHT = Color(colours["PANEL_LIGHT"])
	BORDER = Color(colours["BORDER"])
	TEXT = Color(colours["TEXT"])
	TEXT_DIM = Color(colours["TEXT_DIM"])
	ACCENT = Color(colours["ACCENT"])
	ACCENT_DARK = Color(colours["ACCENT_DARK"])
	GOOD = Color(colours["GOOD"])
	WARN = Color(colours["WARN"])
	BAD = Color(colours["BAD"])
	AETHER = Color(colours["AETHER"])
	HEALTH = Color(colours["HEALTH"])
	STAMINA = Color(colours["STAMINA"])
	ENERGY = Color(colours["ENERGY"])
	HAPPINESS = Color(colours["HAPPINESS"])
	if _theme != null:
		_build_into(_theme)


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


static func _build_into(theme: Theme) -> void:
	theme.clear()
	theme.default_font_size = fs(FONT_SIZE)

	# Labels
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", heading_font())
	theme.set_font_size("font_size", "HeadingLabel", fs(FONT_HEADING))
	theme.set_color("font_color", "HeadingLabel", ACCENT)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", heading_font())
	theme.set_font_size("font_size", "TitleLabel", fs(FONT_TITLE))
	theme.set_color("font_color", "TitleLabel", TEXT)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", TEXT_DIM)
	theme.set_font_size("font_size", "DimLabel", fs(FONT_SMALL))

	# Rich text
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", fs(FONT_SIZE))
	theme.set_font_size("bold_font_size", "RichTextLabel", fs(FONT_SIZE))

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
	theme.set_font_size("font_size", "ProgressBar", fs(FONT_SMALL - 2))

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
	theme.set_font_size("font_size", "LineEdit", fs(FONT_HEADING - 4))

	# Scroll bars: wide enough to grab on touch screens.
	theme.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.2), 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber", "VScrollBar", box(BORDER, 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, 6, Color.TRANSPARENT, 0, 4))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, 6, Color.TRANSPARENT, 0, 4))

	# Tooltips
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL, 10, BORDER, 1, 10))
	theme.set_color("font_color", "TooltipLabel", TEXT)

	# Tabs: a selected tab is a place, not an action — so it never borrows the
	# amber primary-action style (consistency principle).
	theme.set_type_variation("TabButton", "Button")
	theme.set_stylebox("normal", "TabButton", _tab_box(false))
	theme.set_stylebox("hover", "TabButton", _tab_box(false, true))
	theme.set_stylebox("pressed", "TabButton", _tab_box(true))
	theme.set_stylebox("hover_pressed", "TabButton", _tab_box(true))
	theme.set_type_variation("TabButtonSelected", "Button")
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "TabButtonSelected", _tab_box(true))
	theme.set_color("font_color", "TabButtonSelected", ACCENT)
	theme.set_color("font_hover_color", "TabButtonSelected", ACCENT)
	theme.set_color("font_color", "TabButton", TEXT_DIM)

	# Chips: compact always-visible state (coins, reputation, condition).
	theme.set_type_variation("ChipPanel", "PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", box(Color(PANEL, 0.86), 22, BORDER, 1, 10))


static func _tab_box(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var style := box(Color(PANEL_LIGHT, 0.6 if not selected else 0.95), 10, Color.TRANSPARENT, 0, 12)
	style.border_color = ACCENT if selected else (BORDER if hover else Color.TRANSPARENT)
	style.border_width_bottom = 4 if selected else 2
	return style
