extends GutTest

var tracker: CitizenTracker


func before_each() -> void:
	tracker = CitizenTracker.new()


func _place(case_file: CaseFile, target: Vector2, stage: String = "queue") -> Dictionary:
	return {"case": case_file, "target": target, "stage": stage}


func _seated(case_file: CaseFile) -> Dictionary:
	return {"case": case_file, "target": Vector2(-50, -50), "stage": "seated"}


func test_first_sync_places_everyone_at_their_spot() -> void:
	var first := CaseFile.new("general_services")
	var placements: Array[Dictionary] = [_place(first, Vector2(100, 100))]
	var gone := tracker.sync(placements, 0.1, Vector2.ZERO)
	assert_true(gone.is_empty())
	var entry := tracker.entry_for(first)
	assert_eq(entry.pos, Vector2(100, 100))
	assert_false(CitizenTracker.is_walking(entry))
	assert_eq(entry.stage, "queue")
	assert_eq(entry.dept, "general_services")


func test_new_citizens_walk_in_from_the_door() -> void:
	tracker.sync([] as Array[Dictionary], 0.1, Vector2.ZERO)
	var arriving := CaseFile.new("housing")
	var placements: Array[Dictionary] = [_place(arriving, Vector2(1000, 0))]
	tracker.sync(placements, 1.0, Vector2.ZERO)
	var entry := tracker.entry_for(arriving)
	assert_almost_eq((entry.pos as Vector2).x, CitizenTracker.SPEED, 0.01)
	assert_true(CitizenTracker.is_walking(entry))
	tracker.sync(placements, 100.0, Vector2.ZERO)
	assert_eq(entry.pos, Vector2(1000, 0))
	assert_false(CitizenTracker.is_walking(entry))


func test_moving_to_a_new_spot_walks_instead_of_jumping() -> void:
	var citizen := CaseFile.new("general_services")
	tracker.sync([_place(citizen, Vector2(0, 0))] as Array[Dictionary], 0.0, Vector2.ZERO)
	tracker.sync([_place(citizen, Vector2(0, 1000), "desk")] as Array[Dictionary], 0.5, Vector2.ZERO)
	var entry := tracker.entry_for(citizen)
	assert_almost_eq((entry.pos as Vector2).y, CitizenTracker.SPEED * 0.5, 0.01)
	assert_eq(entry.stage, "desk")


func test_look_stays_the_same_for_each_citizen() -> void:
	var first := CaseFile.new("general_services")
	var second := CaseFile.new("general_services")
	var placements: Array[Dictionary] = [_place(first, Vector2.ZERO), _place(second, Vector2(10, 0))]
	tracker.sync(placements, 0.1, Vector2.ZERO)
	var first_look := int(tracker.entry_for(first).look)
	var second_look := int(tracker.entry_for(second).look)
	assert_ne(first_look, second_look)
	var swapped: Array[Dictionary] = [_seated(second), _place(first, Vector2(50, 0))]
	tracker.sync(swapped, 0.1, Vector2.ZERO)
	assert_eq(int(tracker.entry_for(first).look), first_look)
	assert_eq(int(tracker.entry_for(second).look), second_look)


func test_seated_citizens_walk_to_their_own_spot() -> void:
	var citizen := CaseFile.new("general_services")
	tracker.sync([_seated(citizen)] as Array[Dictionary], 0.0, Vector2.ZERO)
	var entry := tracker.entry_for(citizen)
	assert_eq(entry.target, Vector2(-50, -50))
	assert_eq(entry.pos, Vector2(-50, -50))
	assert_eq(entry.stage, "seated")
	assert_false(entry.has("seat"))


func test_departed_citizens_are_reported_with_their_last_position() -> void:
	var citizen := CaseFile.new("vehicle_registration")
	tracker.sync([_place(citizen, Vector2(30, 40), "counter")] as Array[Dictionary], 0.0, Vector2.ZERO)
	var look := int(tracker.entry_for(citizen).look)
	var gone := tracker.sync([] as Array[Dictionary], 0.1, Vector2.ZERO)
	assert_eq(gone.size(), 1)
	assert_eq(gone[0].pos, Vector2(30, 40))
	assert_eq(int(gone[0].look), look)
	assert_eq(gone[0].stage, "counter")
	assert_eq(gone[0].dept, "vehicle_registration")
	assert_true(tracker.entry_for(citizen).is_empty())
	assert_true(tracker.entries.is_empty())


func test_advance_walks_towards_the_last_target_without_new_placements() -> void:
	tracker.sync([] as Array[Dictionary], 0.0, Vector2.ZERO)
	var arriving := CaseFile.new("housing")
	tracker.sync([_place(arriving, Vector2(1000, 0))] as Array[Dictionary], 0.0, Vector2.ZERO)
	var entry := tracker.entry_for(arriving)
	tracker.advance(1.0)
	assert_almost_eq((entry.pos as Vector2).x, CitizenTracker.SPEED, 0.01)
	assert_eq(entry.target, Vector2(1000, 0))
	tracker.advance(100.0)
	assert_eq(entry.pos, Vector2(1000, 0))
	assert_false(CitizenTracker.is_walking(entry))


func test_advance_without_entries_does_nothing() -> void:
	tracker.advance(1.0)
	assert_true(tracker.entries.is_empty())
