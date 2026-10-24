class_name UiKit
extends RefCounted


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func money(value: float) -> String:
	return t("FMT_MONEY") % NumberFormat.compact(value, t("DECIMAL_SEPARATOR"))


static func number(value: float) -> String:
	return NumberFormat.compact(value, t("DECIMAL_SEPARATOR"))


static func decimal(value: float, digits: int = 1) -> String:
	return NumberFormat.decimal(value, digits, t("DECIMAL_SEPARATOR"))


static func percent(value: float) -> String:
	return t("FMT_PERCENT") % str(roundi(value * 100.0))


static func duration(seconds: float) -> String:
	var parts := NumberFormat.duration_parts(seconds)
	if parts.hours > 0:
		return t("FMT_HOURS_MINUTES") % [parts.hours, parts.minutes]
	if parts.minutes > 0:
		return t("FMT_MINUTES") % parts.minutes
	return t("FMT_SECONDS") % parts.seconds


static func label(text: String, variation: String = "BodyMedium", wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_minimum_size.x = 1
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func icon(code: String, color: Color, size: int = AppTheme.SIZE_ICON) -> Label:
	var node := Label.new()
	node.text = code
	node.theme_type_variation = "Icon"
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_font_size_override(&"font_size", size)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func icon_disc(code: String, color: Color, diameter: int = 40) -> PanelContainer:
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override(&"panel", AppTheme.box(Color(color, 0.15), AppTheme.RADIUS_PILL))
	disc.custom_minimum_size = Vector2(diameter, diameter)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(icon(code, color, int(diameter * 0.55)))
	return disc


static func button(text: String, role: String = "primary", variant: String = "Tonal") -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = role.capitalize() + variant
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size.y = 44
	return node


static func icon_button(code: String, role: String = "neutral", variant: String = "IconStandard") -> Button:
	var node := Button.new()
	node.text = code
	node.theme_type_variation = role.capitalize() + variant
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(44, 44)
	return node


static func card(variation: String = "CardOutlined") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func vbox(separation: int = AppTheme.SPACING_SM) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func hbox(separation: int = AppTheme.SPACING_SM) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func progress(value: float = 0.0, role: String = "primary") -> ProgressBar:
	var node := ProgressBar.new()
	node.min_value = 0.0
	node.max_value = 1.0
	node.step = 0.0
	node.value = value
	node.show_percentage = false
	node.custom_minimum_size.y = 8
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if role != "primary":
		node.add_theme_stylebox_override(&"fill", AppTheme.box(AppTheme.accent(role), AppTheme.RADIUS_PILL))
	return node


static func pill(text: String, role: String = "primary") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = "Pill" + role.capitalize()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := label(text, "LabelSmall")
	text_label.add_theme_color_override(&"font_color", AppTheme.accent(role))
	node.add_child(text_label)
	return node


static func banner(icon_code: String, title: String, text: String, role: String = "primary") -> PanelContainer:
	var node := card("Banner" + role.capitalize())
	var row := hbox(AppTheme.SPACING_MD)
	row.add_child(icon(icon_code, AppTheme.accent(role)))
	var column := vbox(2)
	var title_label := label(title, "TitleSmall", true)
	title_label.add_theme_color_override(&"font_color", AppTheme.accent(role))
	column.add_child(title_label)
	if not text.is_empty():
		var body := label(text, "BodySmall", true)
		body.add_theme_color_override(&"font_color", AppTheme.on_container(role))
		column.add_child(body)
	row.add_child(column)
	node.add_child(row)
	return node


static func segmented(options: Array[String], selected: int, on_change: Callable) -> HBoxContainer:
	var row := hbox(AppTheme.SPACING_XS)
	var group := ButtonGroup.new()
	for i in options.size():
		var segment := Button.new()
		segment.text = options[i]
		segment.theme_type_variation = "Segment"
		segment.toggle_mode = true
		segment.button_group = group
		segment.button_pressed = i == selected
		segment.focus_mode = Control.FOCUS_NONE
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.custom_minimum_size.y = 40
		segment.pressed.connect(on_change.bind(i))
		row.add_child(segment)
	return row


static func switch(text: String, pressed: bool, on_toggle: Callable) -> CheckButton:
	var node := CheckButton.new()
	node.text = text
	node.button_pressed = pressed
	node.focus_mode = Control.FOCUS_NONE
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.toggled.connect(on_toggle)
	return node


static func cost_text(action_key: String, cost: float) -> String:
	return t("FMT_ACTION_COST") % [t(action_key), money(cost)]
