class_name AppTheme
extends RefCounted

const FONT_REGULAR: FontFile = preload("res://assets/fonts/Geist-Regular.ttf")
const FONT_SEMIBOLD: FontFile = preload("res://assets/fonts/Geist-SemiBold.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/Geist-Bold.ttf")
const FONT_ICONS: FontFile = preload("res://assets/fonts/MaterialIcons-Regular.ttf")

const BACKGROUND := Color("#f4f7fc")
const SURFACE := Color("#ffffff")
const SURFACE_VARIANT := Color("#eef2f8")
const SURFACE_3 := Color("#e3e9f2")
const OUTLINE := Color("#7a869a")
const ON_SURFACE := Color("#141a24")
const ON_SURFACE_VARIANT := Color("#3d4757")
const SCRIM := Color(0.08, 0.1, 0.16, 0.45)

const ROLES := {
	"primary": {"accent": Color("#1e5fd8"), "on_accent": Color("#ffffff"), "container": Color("#dce7ff"), "on_container": Color("#0b2a66"), "tonal_border": Color("#b5cbfa")},
	"secondary": {"accent": Color("#5b5f97"), "on_accent": Color("#ffffff"), "container": Color("#e4e4fb"), "on_container": Color("#1d1f4a"), "tonal_border": Color("#c4c6ee")},
	"tertiary": {"accent": Color("#00897b"), "on_accent": Color("#ffffff"), "container": Color("#d3f3ee"), "on_container": Color("#003d36"), "tonal_border": Color("#a6e2d9")},
	"success": {"accent": Color("#1e8e3e"), "on_accent": Color("#ffffff"), "container": Color("#ddf4e3"), "on_container": Color("#0b3d1a"), "tonal_border": Color("#b2e3c0")},
	"warning": {"accent": Color("#b26a00"), "on_accent": Color("#ffffff"), "container": Color("#fff0d1"), "on_container": Color("#4a2c00"), "tonal_border": Color("#f5d48f")},
	"error": {"accent": Color("#c62828"), "on_accent": Color("#ffffff"), "container": Color("#fde2e1"), "on_container": Color("#5f1412"), "tonal_border": Color("#f4b5b2")},
	"neutral": {"accent": Color("#4a5568"), "on_accent": Color("#ffffff"), "container": Color("#e8ebf0"), "on_container": Color("#1f2937"), "tonal_border": Color("#cfd5de")},
}

const DEPARTMENT_COLORS := {
	"general_services": Color("#2f80ed"),
	"tax_services": Color("#e5484d"),
	"business_licences": Color("#f2994a"),
	"vehicle_registration": Color("#27ae60"),
	"building_permits": Color("#9b51e0"),
	"housing": Color("#0ea5a4"),
	"social_benefits": Color("#e0b100"),
	"customs": Color("#5c6bc0"),
	"inspection": Color("#607d8b"),
	"shared": Color("#455a64"),
}

const STAFF_COLOR := Color("#1e3a8a")
const CITIZEN_COLORS: Array[Color] = [Color("#f59e0b"), Color("#10b981"), Color("#ef4444"), Color("#8b5cf6"), Color("#ec4899"), Color("#14b8a6")]
const SKIN := Color("#f1c9a5")
const PAPER := Color("#fffdf5")
const PAPER_EDGE := Color("#c9c2a8")
const FLOOR_STAGES: Array[Color] = [Color("#efe6d8"), Color("#e9e2d6"), Color("#e4e8ee"), Color("#e2ecf4"), Color("#eaf0f7")]
const WALL := Color("#5b6b82")
const MONEY := Color("#1e8e3e")
const DESK := Color("#b98b5e")
const MONITOR := Color("#37474f")
const PLANT := Color("#4caf50")
const PLANT_LIGHT := Color("#66bb6a")
const PLAYER := Color("#1e5fd8")
const PLAYER_HAT := Color("#0b2a66")
const RUNNER := Color("#f57c00")
const GUARD := Color("#263445")
const GUARD_CAP := Color("#10161f")
const GUARD_BADGE := Color("#f2c94c")
const SPECIALIST := Color("#7b1fa2")
const SPECIALIST_COAT := Color("#f3e5f5")
const HALL_FLOOR := Color("#f3ede2")
const LOCKED_FLOOR := Color("#d9dde3")
const HATCH := Color("#c3c9d1")
const OUTSIDE := Color("#cfe3c4")
const ROAD := Color("#8f9aa5")
const CAR := Color("#e53935")
const TRUCK := Color("#546e7a")
const CRATE := Color("#b07d48")
const PLATE_TEXT := Color("#1b1b1b")
const STAMP := Color("#d32f2f")
const CLEARED := Color("#2e7d32")

const KITCHEN := Color("#a1887f")
const FRIDGE := Color("#eceff1")
const COFFEE_DARK := Color("#4e342e")
const COFFEE_LIQUID := Color("#6d4c41")
const WATER := Color("#81d4fa")
const WOOD_TOP := Color("#cf9f6f")
const WOOD_FRONT := Color("#9a6f46")
const WOOD_DARK := Color("#6d4c2f")
const SCREEN := Color("#8fd3b6")
const TROUSERS := Color("#2b3445")
const SHOES := Color("#1b1f29")
const HAIR_COLORS: Array[Color] = [Color("#3b2a20"), Color("#8a5a2b"), Color("#d9b26f"), Color("#a8a8a8"), Color("#1b1b1b"), Color("#b5532b")]
const SKIN_TONES: Array[Color] = [Color("#f1c9a5"), Color("#e0ac85"), Color("#c68a62"), Color("#8d5a3b")]
const TIE := Color("#c62828")
const COLLAR := Color("#ffffff")
const CABINET := Color("#8d9aa8")
const CABINET_DARK := Color("#66727f")
const POT := Color("#c2693c")
const LEAF_DARK := Color("#2e7d32")
const FLAG_BLACK := Color("#1a1a1a")
const FLAG_RED := Color("#d32f2f")
const FLAG_GOLD := Color("#ffc107")
const GRASS_DARK := Color("#b4d2a5")
const ROAD_LINE := Color("#f5f5f5")
const CURTAIN := Color("#d84a4a")
const METAL := Color("#b0bec5")
const METAL_DARK := Color("#78909c")
const INK := Color("#283593")
const BENCH := Color("#8d6e63")
const PLATE_BLUE := Color("#1e5fd8")
const WINDOW := Color("#bfe3f5")
const LEAD_CARPET := Color("#dfe7f3")
const SIGN_BOARD := Color("#33475b")
const SIGN_TEXT := Color("#fff8e1")
const POST_YELLOW := Color("#f6c400")
const POST_HORN := Color("#1d1d1b")
const TILE_SHADE := Color(0.0, 0.0, 0.0, 0.035)
const SHADOW_SOFT := Color(0.05, 0.07, 0.12, 0.2)

const RADIUS_CARD := 20
const RADIUS_BUTTON := 20
const RADIUS_CHIP := 6
const RADIUS_DIALOG := 28
const RADIUS_SHEET := 28
const RADIUS_PILL := 999

const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 12
const SPACING_LG := 16
const SPACING_XL := 24
const SPACING_XXL := 32

const SIZE_DISPLAY := 32
const SIZE_HEADLINE := 26
const SIZE_TITLE_LARGE := 24
const SIZE_TITLE_MEDIUM := 20
const SIZE_TITLE_SMALL := 18
const SIZE_BODY := 17
const SIZE_BODY_SMALL := 16
const SIZE_LABEL := 17
const SIZE_LABEL_SMALL := 15
const SIZE_ICON := 24
const SIZE_ICON_SMALL := 18


static func role(name: String) -> Dictionary:
	return ROLES.get(name, ROLES.primary)


static func accent(name: String) -> Color:
	return role(name).accent


static func on_accent(name: String) -> Color:
	return role(name).on_accent


static func container(name: String) -> Color:
	return role(name).container


static func on_container(name: String) -> Color:
	return role(name).on_container


static func department_color(dept_id: String) -> Color:
	return DEPARTMENT_COLORS.get(dept_id, DEPARTMENT_COLORS.shared)


static func confetti_colors() -> Array[Color]:
	return [accent("primary"), accent("success"), accent("warning"), accent("tertiary"), accent("secondary"), accent("error"), FLAG_GOLD]


static func outline_soft() -> Color:
	return Color(OUTLINE, 0.25)


static func box(bg: Color, radius: int, border: Color = Color.TRANSPARENT, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.corner_detail = 8
	style.anti_aliasing = true
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_REGULAR
	theme.default_font_size = SIZE_BODY
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_controls(theme)
	return theme


static func _label(theme: Theme, name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, size)
	theme.set_color(&"font_color", name, color)


static func _labels(theme: Theme) -> void:
	theme.set_color(&"font_color", "Label", ON_SURFACE)
	_label(theme, "DisplaySmall", FONT_BOLD, SIZE_DISPLAY, ON_SURFACE)
	_label(theme, "HeadlineSmall", FONT_BOLD, SIZE_HEADLINE, ON_SURFACE)
	_label(theme, "TitleLarge", FONT_SEMIBOLD, SIZE_TITLE_LARGE, ON_SURFACE)
	_label(theme, "TitleMedium", FONT_SEMIBOLD, SIZE_TITLE_MEDIUM, ON_SURFACE)
	_label(theme, "TitleSmall", FONT_SEMIBOLD, SIZE_TITLE_SMALL, ON_SURFACE)
	_label(theme, "BodyMedium", FONT_REGULAR, SIZE_BODY, ON_SURFACE)
	_label(theme, "BodySmall", FONT_REGULAR, SIZE_BODY_SMALL, ON_SURFACE_VARIANT)
	_label(theme, "LabelSmall", FONT_SEMIBOLD, SIZE_LABEL_SMALL, ON_SURFACE_VARIANT)
	_label(theme, "Icon", FONT_ICONS, SIZE_ICON, role("primary").accent)


static func _button_variant(theme: Theme, name: String, bg: Color, fg: Color, border: Color) -> void:
	if name != "Button":
		theme.set_type_variation(name, "Button")
	var pad_x := SPACING_LG
	var normal := box(bg, RADIUS_BUTTON, border)
	normal.content_margin_left = pad_x
	normal.content_margin_right = pad_x
	normal.content_margin_top = SPACING_SM + 2
	normal.content_margin_bottom = SPACING_SM + 2
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.darkened(0.05) if bg.a > 0.0 else Color(fg, 0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.12) if bg.a > 0.0 else Color(fg, 0.16)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(ON_SURFACE, 0.06) if bg.a > 0.0 else Color.TRANSPARENT
	disabled.border_color = Color(ON_SURFACE, 0.12) if border.a > 0.0 else Color.TRANSPARENT
	theme.set_stylebox(&"normal", name, normal)
	theme.set_stylebox(&"hover", name, hover)
	theme.set_stylebox(&"pressed", name, pressed)
	theme.set_stylebox(&"hover_pressed", name, pressed)
	theme.set_stylebox(&"disabled", name, disabled)
	theme.set_stylebox(&"focus", name, StyleBoxEmpty.new())
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color", &"icon_normal_color", &"icon_hover_color", &"icon_pressed_color"]:
		theme.set_color(color_name, name, fg)
	theme.set_color(&"font_disabled_color", name, Color(ON_SURFACE, 0.38))
	theme.set_font(&"font", name, FONT_SEMIBOLD)
	theme.set_font_size(&"font_size", name, SIZE_LABEL)


static func _buttons(theme: Theme) -> void:
	for role_name: String in ROLES:
		var colors := role(role_name)
		var prefix := role_name.capitalize()
		_button_variant(theme, prefix + "Filled", colors.accent, colors.on_accent, Color.TRANSPARENT)
		_button_variant(theme, prefix + "Tonal", colors.container, colors.accent, Color.TRANSPARENT)
		_button_variant(theme, prefix + "Outlined", Color.TRANSPARENT, colors.accent, colors.accent)
		_button_variant(theme, prefix + "Text", Color.TRANSPARENT, colors.accent, Color.TRANSPARENT)
		_icon_button(theme, prefix + "IconStandard", Color.TRANSPARENT, colors.accent)
		_icon_button(theme, prefix + "IconTonal", colors.container, colors.accent)
	_button_variant(theme, "Button", role("primary").container, role("primary").accent, Color.TRANSPARENT)
	_segment(theme)
	_nav_item(theme)


static func _icon_button(theme: Theme, name: String, bg: Color, fg: Color) -> void:
	_button_variant(theme, name, bg, fg, Color.TRANSPARENT)
	for state_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var style := theme.get_stylebox(state_name, name) as StyleBoxFlat
		style.set_corner_radius_all(RADIUS_PILL)
		style.set_content_margin_all(SPACING_SM)
	theme.set_font(&"font", name, FONT_ICONS)
	theme.set_font_size(&"font_size", name, SIZE_ICON)


static func _segment(theme: Theme) -> void:
	var name := "Segment"
	var primary := role("primary")
	_button_variant(theme, name, SURFACE, ON_SURFACE_VARIANT, outline_soft())
	for state_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var style := theme.get_stylebox(state_name, name) as StyleBoxFlat
		style.set_corner_radius_all(RADIUS_CHIP)
	var selected := theme.get_stylebox(&"pressed", name).duplicate() as StyleBoxFlat
	selected.bg_color = primary.container
	selected.border_color = primary.accent
	theme.set_stylebox(&"pressed", name, selected)
	theme.set_stylebox(&"hover_pressed", name, selected)
	theme.set_color(&"font_pressed_color", name, primary.accent)
	theme.set_color(&"font_hover_pressed_color", name, primary.accent)
	theme.set_font_size(&"font_size", name, SIZE_LABEL_SMALL + 1)


static func _nav_item(theme: Theme) -> void:
	var name := "NavItem"
	var primary := role("primary")
	_button_variant(theme, name, Color.TRANSPARENT, ON_SURFACE_VARIANT, Color.TRANSPARENT)
	var selected := box(primary.container, RADIUS_BUTTON)
	selected.set_content_margin_all(SPACING_SM)
	theme.set_stylebox(&"pressed", name, selected)
	theme.set_stylebox(&"hover_pressed", name, selected)
	theme.set_color(&"font_pressed_color", name, primary.accent)
	theme.set_color(&"font_hover_pressed_color", name, primary.accent)
	theme.set_font_size(&"font_size", name, SIZE_LABEL_SMALL)


static func _panel(theme: Theme, name: String, style: StyleBox) -> void:
	theme.set_type_variation(name, "PanelContainer")
	theme.set_stylebox(&"panel", name, style)


static func _panels(theme: Theme) -> void:
	theme.set_stylebox(&"panel", "PanelContainer", box(SURFACE, RADIUS_CARD, outline_soft(), SPACING_LG))
	_panel(theme, "CardOutlined", box(SURFACE, RADIUS_CARD, outline_soft(), SPACING_LG))
	_panel(theme, "CardRow", box(SURFACE, RADIUS_CARD, outline_soft(), SPACING_MD))
	_panel(theme, "CardPrimary", box(role("primary").container, RADIUS_CARD, Color.TRANSPARENT, SPACING_LG))
	_panel(theme, "Bar", box(SURFACE, 0, Color.TRANSPARENT, SPACING_SM))
	var sheet := box(SURFACE, RADIUS_SHEET, Color.TRANSPARENT, SPACING_LG)
	sheet.corner_radius_bottom_left = 0
	sheet.corner_radius_bottom_right = 0
	sheet.shadow_color = Color(ON_SURFACE, 0.12)
	sheet.shadow_size = 4
	_panel(theme, "Sheet", sheet)
	var dialog := box(SURFACE, RADIUS_DIALOG, Color.TRANSPARENT, SPACING_XL)
	dialog.shadow_color = Color(ON_SURFACE, 0.12)
	dialog.shadow_size = 4
	_panel(theme, "Dialog", dialog)
	for role_name: String in ROLES:
		var colors := role(role_name)
		var prefix := role_name.capitalize()
		_panel(theme, "Banner" + prefix, box(colors.container, RADIUS_CARD, Color.TRANSPARENT, SPACING_LG))
		var pill := box(colors.container, RADIUS_PILL)
		pill.content_margin_left = SPACING_SM
		pill.content_margin_right = SPACING_SM
		pill.content_margin_top = 2
		pill.content_margin_bottom = 2
		_panel(theme, "Pill" + prefix, pill)


static func _controls(theme: Theme) -> void:
	var primary := role("primary")
	theme.set_stylebox(&"background", "ProgressBar", box(SURFACE_3, RADIUS_PILL))
	theme.set_stylebox(&"fill", "ProgressBar", box(primary.accent, RADIUS_PILL))
	theme.set_color(&"font_color", "ProgressBar", Color.TRANSPARENT)
	theme.set_constant(&"separation", "HBoxContainer", SPACING_SM)
	theme.set_constant(&"separation", "VBoxContainer", SPACING_SM)
	theme.set_color(&"font_color", "CheckButton", ON_SURFACE)
	theme.set_color(&"font_hover_color", "CheckButton", ON_SURFACE)
	theme.set_color(&"font_pressed_color", "CheckButton", ON_SURFACE)
	theme.set_color(&"font_focus_color", "CheckButton", ON_SURFACE)
	theme.set_color(&"font_hover_pressed_color", "CheckButton", ON_SURFACE)
	theme.set_stylebox(&"focus", "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"normal", "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"hover", "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"pressed", "CheckButton", StyleBoxEmpty.new())
	theme.set_stylebox(&"hover_pressed", "CheckButton", StyleBoxEmpty.new())
	theme.set_icon(&"checked", "CheckButton", _switch_icon(true))
	theme.set_icon(&"unchecked", "CheckButton", _switch_icon(false))
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(OUTLINE, 0.35)
	scroll.set_corner_radius_all(RADIUS_PILL)
	scroll.content_margin_left = 3
	scroll.content_margin_right = 3
	theme.set_stylebox(&"grabber", "VScrollBar", scroll)
	theme.set_stylebox(&"grabber_highlight", "VScrollBar", scroll)
	theme.set_stylebox(&"grabber_pressed", "VScrollBar", scroll)
	theme.set_stylebox(&"scroll", "VScrollBar", StyleBoxEmpty.new())
	theme.set_color(&"color", "HSeparator", outline_soft())
	var separator := StyleBoxLine.new()
	separator.color = outline_soft()
	theme.set_stylebox(&"separator", "HSeparator", separator)


static func _switch_icon(checked: bool) -> ImageTexture:
	var width := 52
	var height := 32
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var track: Color = role("primary").accent if checked else SURFACE_3
	var knob: Color = role("primary").on_accent if checked else OUTLINE
	var radius := height / 2.0
	var knob_center := Vector2(width - radius, radius) if checked else Vector2(radius, radius)
	var knob_radius := 12.0 if checked else 8.0
	for y in height:
		for x in width:
			var point := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(point.x, radius, width - radius)
			var track_alpha := clampf(radius - point.distance_to(Vector2(cx, radius)) + 0.5, 0.0, 1.0)
			var color := Color(track, track.a * track_alpha)
			var knob_alpha := clampf(knob_radius - point.distance_to(knob_center) + 0.5, 0.0, 1.0)
			if knob_alpha > 0.0:
				color = color.blend(Color(knob, knob_alpha))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
