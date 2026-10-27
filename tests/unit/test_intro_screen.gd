extends GutTest

const TEST_SAVE := "user://test_intro_save.json"

var state: GameState
var _previous_locale := ""


func before_all() -> void:
	_previous_locale = TranslationServer.get_locale()


func before_each() -> void:
	state = GameState.create_new(6)


func after_each() -> void:
	SaveService.new(TEST_SAVE).delete()
	TranslationServer.set_locale(_previous_locale)


func _intro() -> IntroScreen:
	var intro := IntroScreen.new().setup(state, 0.0)
	add_child_autofree(intro)
	return intro


func _labels(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	for child in node.get_children():
		texts.append_array(_labels(child))
	return texts


func test_new_game_shows_intro() -> void:
	assert_false(state.intro_seen)
	assert_true(IntroScreen.should_show(state))


func test_seen_intro_is_saved_and_loaded() -> void:
	state.intro_seen = true
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_true(copy.intro_seen)
	assert_false(IntroScreen.should_show(copy))
	var service := SaveService.new(TEST_SAVE)
	assert_true(service.save(state, 1))
	assert_true(service.load_state().intro_seen)


func test_unseen_intro_survives_saving() -> void:
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_false(copy.intro_seen)


func test_existing_saves_without_flag_skip_intro() -> void:
	var data := state.to_dict()
	data.erase("intro_seen")
	assert_true(GameState.from_dict(data).intro_seen)


func test_outdated_save_version_shows_intro_again() -> void:
	assert_false(GameState.from_dict({"version": 1}).intro_seen)


func test_intro_covers_screen_and_blocks_input() -> void:
	var intro := _intro()
	assert_eq(intro.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(intro.anchor_right, 1.0)
	assert_eq(intro.anchor_bottom, 1.0)
	var background := intro.get_child(0) as ColorRect
	assert_not_null(background)
	assert_eq(background.color, AppTheme.BACKGROUND)


func test_intro_shows_title_letter_and_start_button() -> void:
	TranslationServer.set_locale("de")
	var intro := _intro()
	var texts := _labels(intro)
	for key in ["INTRO_KICKER", "INTRO_TITLE", "INTRO_SIGNOFF", "INTRO_SENDER"] + IntroScreen.PARAGRAPHS:
		assert_true(texts.has(intro.tr(key)), key)
		assert_ne(intro.tr(key), key, key)
	assert_eq(intro.start_button.text, intro.tr("INTRO_START"))
	assert_eq(intro.tr("INTRO_START"), "Dienst antreten")


func test_intro_has_english_fallback() -> void:
	TranslationServer.set_locale("en")
	var intro := _intro()
	assert_eq(intro.start_button.text, "Report for duty")
	for key in ["INTRO_KICKER", "INTRO_TITLE", "INTRO_SIGNOFF", "INTRO_SENDER"] + IntroScreen.PARAGRAPHS:
		assert_ne(intro.tr(key), key, key)


func test_start_marks_intro_seen_and_closes_once() -> void:
	var intro := _intro()
	watch_signals(intro)
	intro.start_button.pressed.emit()
	assert_true(state.intro_seen)
	assert_false(IntroScreen.should_show(state))
	assert_signal_emit_count(intro, "finished", 1)
	assert_true(intro.is_queued_for_deletion())
	intro.start()
	assert_signal_emit_count(intro, "finished", 1)


func test_intro_respects_safe_area() -> void:
	var intro := IntroScreen.new().setup(state, 40.0)
	add_child_autofree(intro)
	var margin := intro.get_child(1).get_child(0) as MarginContainer
	assert_eq(margin.get_theme_constant(&"margin_top"), 40 + AppTheme.SPACING_XXL)
	assert_eq(margin.get_theme_constant(&"margin_left"), AppTheme.SPACING_LG)
