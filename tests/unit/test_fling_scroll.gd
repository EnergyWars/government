extends GutTest

var scroll: FlingScroll


func before_each() -> void:
	scroll = FlingScroll.new()
	scroll.custom_minimum_size = Vector2(200, 100)
	var content := Control.new()
	content.custom_minimum_size = Vector2(200, 2000)
	scroll.add_child(content)
	add_child_autofree(scroll)


func _touch(pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	return event


func _drag(speed: float) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.velocity = Vector2(0, speed)
	return event


func test_release_after_fast_drag_starts_fling() -> void:
	scroll._gui_input(_touch(true))
	scroll._gui_input(_drag(-1500.0))
	scroll._gui_input(_touch(false))
	assert_true(scroll.is_flinging())


func test_slow_release_does_not_fling() -> void:
	scroll._gui_input(_touch(true))
	scroll._gui_input(_drag(-5.0))
	scroll._gui_input(_touch(false))
	assert_false(scroll.is_flinging())


func test_touch_stops_running_fling() -> void:
	scroll._gui_input(_drag(-1500.0))
	scroll._gui_input(_touch(false))
	assert_true(scroll.is_flinging())
	scroll._gui_input(_touch(true))
	assert_false(scroll.is_flinging())


func test_fling_scrolls_and_decays() -> void:
	await wait_physics_frames(2)
	scroll._gui_input(_drag(-2000.0))
	scroll._gui_input(_touch(false))
	scroll._process(0.1)
	assert_gt(scroll.scroll_vertical, 0)
	for i in 100:
		scroll._process(0.1)
	assert_false(scroll.is_flinging())


func test_fling_speed_is_clamped() -> void:
	scroll._gui_input(_drag(-1e9))
	assert_eq(scroll._speed, FlingScroll.MAX_SPEED)


func test_process_ignored_while_touching() -> void:
	scroll._gui_input(_drag(-2000.0))
	scroll._touching = true
	scroll._process(0.1)
	assert_eq(scroll.scroll_vertical, 0)


func test_pass_touches_converts_stop_filters_recursively() -> void:
	var root := Control.new()
	var panel := PanelContainer.new()
	var button := Button.new()
	var ignored := Control.new()
	ignored.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(button)
	root.add_child(panel)
	root.add_child(ignored)
	FlingScroll.pass_touches(root)
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(ignored.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	root.free()
