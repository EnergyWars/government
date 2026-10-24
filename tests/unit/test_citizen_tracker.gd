extends GutTest

var tracker: CitizenTracker


func before_each() -> void:
	tracker = CitizenTracker.new()


func _seat(index: int) -> Vector2:
	return Vector2(1000 + index * 10, 500)


func _place(case_file: CaseFile, target: Vector2, stage: String = "queue") -> Dictionary:
	return {"case": case_file, "target": target, "stage": stage}


func _seated(case_file: CaseFile) -> Dictionary:
	return {"case": case_file, "target": Vector2(-50, -50), "seat": true, "stage": "seated"}


func test_first_sync_places_everyone_at_their_spot() -> void:
	var first := CaseFile.new("general_services")
	var placements: Array[Dictionary] = [_place(first, Vector2(100, 100))]
	var gone := tracker.sync(placements, 0.1, Vector2.ZERO, _seat, 4)
	assert_true(gone.is_empty())
	var entry := tracker.entry_for(first)
	assert_eq(entry.pos, Vector2(100, 100))
	assert_false(CitizenTracker.is_walking(entry))
	assert_eq(entry.stage, "queue")
	assert_eq(entry.dept, "general_services")


func test_new_citizens_walk_in_from_the_door() -> void:
	tracker.sync([] as Array[Dictionary], 0.1, Vector2.ZERO, _seat, 4)
	var arriving := CaseFile.new("housing")
	var placements: Array[Dictionary] = [_place(arriving, Vector2(1000, 0))]
	tracker.sync(placements, 1.0, Vector2.ZERO, _seat, 4)
	var entry := tracker.entry_for(arriving)
	assert_almost_eq((entry.pos as Vector2).x, CitizenTracker.SPEED, 0.01)
	assert_true(CitizenTracker.is_walking(entry))
	tracker.sync(placements, 100.0, Vector2.ZERO, _seat, 4)
	assert_eq(entry.pos, Vector2(1000, 0))
	assert_false(CitizenTracker.is_walking(entry))


func test_moving_to_a_new_spot_walks_instead_of_jumping() -> void:
	var citizen := CaseFile.new("general_services")
	tracker.sync([_place(citizen, Vector2(0, 0))] as Array[Dictionary], 0.0, Vector2.ZERO, _seat, 4)
	tracker.sync([_place(citizen, Vector2(0, 1000), "desk")] as Array[Dictionary], 0.5, Vector2.ZERO, _seat, 4)
	var entry := tracker.entry_for(citizen)
	assert_almost_eq((entry.pos as Vector2).y, CitizenTracker.SPEED * 0.5, 0.01)
	assert_eq(entry.stage, "desk")


func test_look_stays_the_same_for_each_citizen() -> void:
	var first := CaseFile.new("general_services")
	var second := CaseFile.new("general_services")
	var placements: Array[Dictionary] = [_place(first, Vector2.ZERO), _place(second, Vector2(10, 0))]
	tracker.sync(placements, 0.1, Vector2.ZERO, _seat, 4)
	var first_look := int(tracker.entry_for(first).look)
	var second_look := int(tracker.entry_for(second).look)
	assert_ne(first_look, second_look)
	var swapped: Array[Dictionary] = [_seated(second), _place(first, Vector2(50, 0))]
	tracker.sync(swapped, 0.1, Vector2.ZERO, _seat, 4)
	assert_eq(int(tracker.entry_for(first).look), first_look)
	assert_eq(int(tracker.entry_for(second).look), second_look)


func test_seats_are_kept_and_released() -> void:
	var first := CaseFile.new("general_services")
	var second := CaseFile.new("general_services")
	tracker.sync([_seated(first), _seated(second)] as Array[Dictionary], 0.0, Vector2.ZERO, _seat, 4)
	assert_eq(int(tracker.entry_for(first).seat), 0)
	assert_eq(int(tracker.entry_for(second).seat), 1)
	assert_eq(tracker.entry_for(second).target, _seat(1))
	tracker.sync([_seated(second)] as Array[Dictionary], 0.1, Vector2.ZERO, _seat, 4)
	assert_eq(int(tracker.entry_for(second).seat), 1)
	var third := CaseFile.new("general_services")
	tracker.sync([_seated(second), _seated(third)] as Array[Dictionary], 0.1, Vector2.ZERO, _seat, 4)
	assert_eq(int(tracker.entry_for(third).seat), 0)
	tracker.sync([_place(second, Vector2(5, 5), "counter"), _seated(third)] as Array[Dictionary], 0.1, Vector2.ZERO, _seat, 4)
	assert_eq(int(tracker.entry_for(second).seat), -1)


func test_citizens_without_a_free_seat_stand_aside() -> void:
	var first := CaseFile.new("general_services")
	var second := CaseFile.new("general_services")
	tracker.sync([_seated(first), _seated(second)] as Array[Dictionary], 0.0, Vector2.ZERO, _seat, 1)
	assert_eq(int(tracker.entry_for(second).seat), -1)
	assert_eq(tracker.entry_for(second).target, Vector2(-50, -50))
	tracker.sync([_seated(second)] as Array[Dictionary], 0.0, Vector2.ZERO, _seat, 1)
	assert_eq(int(tracker.entry_for(second).seat), 0)


func test_departed_citizens_are_reported_with_their_last_position() -> void:
	var citizen := CaseFile.new("vehicle_registration")
	tracker.sync([_place(citizen, Vector2(30, 40), "counter")] as Array[Dictionary], 0.0, Vector2.ZERO, _seat, 4)
	var look := int(tracker.entry_for(citizen).look)
	var gone := tracker.sync([] as Array[Dictionary], 0.1, Vector2.ZERO, _seat, 4)
	assert_eq(gone.size(), 1)
	assert_eq(gone[0].pos, Vector2(30, 40))
	assert_eq(int(gone[0].look), look)
	assert_eq(gone[0].stage, "counter")
	assert_eq(gone[0].dept, "vehicle_registration")
	assert_true(tracker.entry_for(citizen).is_empty())
	assert_true(tracker.entries.is_empty())
