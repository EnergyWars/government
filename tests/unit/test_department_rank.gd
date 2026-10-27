extends GutTest

var state: GameState
var game: Game


func before_each() -> void:
	state = GameState.create_new(11)
	game = Game.new(state)
	_reset_static_state()


func after_each() -> void:
	_reset_static_state()


func _reset_static_state() -> void:
	UpgradeEntryCard.amount_index = 0
	UpgradesSheet.mode_index = 0
	UpgradesSheet.expanded.clear()


func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _ids(entries: Array[UpgradeEntry]) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		result.append(entry.id)
	return result


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	elif node is Button:
		result.append((node as Button).text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _has_text(node: Node, text: String) -> bool:
	return _texts(node).has(text)


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _entry_button(root: Node, title: String, text: String) -> Button:
	for label in root.find_children("*", "Label", true, false):
		if (label as Label).text != title:
			continue
		var node := label.get_parent()
		while node != null and node != root:
			var found := _button(node, text)
			if found != null:
				return found
			node = node.get_parent()
	return null


func _sheet(sheet: Sheet, argument: String = "") -> Sheet:
	sheet.setup(game, argument)
	add_child_autofree(sheet)
	return sheet


func _open_everything() -> void:
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
		state.department(dept_id).rank = GameConfig.MAX_DEPARTMENT_RANK
	state.building_stage = GameConfig.BUILDING_STAGES.size() - 1


func _milestone_product(count: int) -> float:
	var product := 1.0
	for index in count:
		product *= GameConfig.RANK_MILESTONE_FACTORS[index]
	return product


func test_rank_config_matches_the_design() -> void:
	var step := GameConfig.RANK_MILESTONE_STEP
	assert_eq(GameConfig.MAX_DEPARTMENT_RANK, 250)
	assert_eq(step, 25)
	assert_eq(GameConfig.RANK_MILESTONE_FACTORS.size() * step, GameConfig.MAX_DEPARTMENT_RANK)
	assert_eq(GameConfig.RANK_TITLES, GameConfig.RANK_MILESTONE_FACTORS.size() + 1)
	assert_gt(GameConfig.RANK_LEVEL_FEE_FACTOR, 1.0)
	assert_lt(GameConfig.RANK_LEVEL_FEE_FACTOR, 1.1)
	for factor in GameConfig.RANK_MILESTONE_FACTORS:
		assert_between(factor, 1.5, 3.0)


func test_fee_factor_grows_a_little_per_level_and_jumps_at_milestones() -> void:
	var level_factor := GameConfig.RANK_LEVEL_FEE_FACTOR
	assert_eq(DepartmentRank.fee_factor(1), 1.0)
	assert_almost_eq(DepartmentRank.fee_factor(2), level_factor, 0.000001)
	assert_almost_eq(DepartmentRank.fee_factor(24), pow(level_factor, 23), 0.000001)
	assert_almost_eq(DepartmentRank.fee_factor(25), pow(level_factor, 24) * GameConfig.RANK_MILESTONE_FACTORS[0], 0.000001)
	assert_almost_eq(DepartmentRank.fee_factor(60), pow(level_factor, 59) * _milestone_product(2), 0.0001)
	assert_eq(DepartmentRank.fee_factor(0), 1.0)
	assert_eq(DepartmentRank.fee_factor(-4), 1.0)
	var top := pow(level_factor, GameConfig.MAX_DEPARTMENT_RANK - 1) * _milestone_product(GameConfig.RANK_MILESTONE_FACTORS.size())
	assert_almost_eq(DepartmentRank.fee_factor(GameConfig.MAX_DEPARTMENT_RANK), top, top * 1e-9)
	assert_almost_eq(DepartmentRank.fee_factor(999), top, top * 1e-9)
	for level in range(2, GameConfig.MAX_DEPARTMENT_RANK + 1):
		var ratio := DepartmentRank.fee_factor(level) / DepartmentRank.fee_factor(level - 1)
		var expected := level_factor * DepartmentRank.milestone_factor(level)
		assert_almost_eq(ratio, expected, 1e-9, str(level))


func test_milestones_titles_and_next_milestone() -> void:
	assert_eq(DepartmentRank.milestones(1), 0)
	assert_eq(DepartmentRank.milestones(24), 0)
	assert_eq(DepartmentRank.milestones(25), 1)
	assert_eq(DepartmentRank.milestones(249), 9)
	assert_eq(DepartmentRank.milestones(250), 10)
	assert_eq(DepartmentRank.milestones(999), 10)
	assert_eq(DepartmentRank.milestones(-3), 0)
	assert_false(DepartmentRank.is_milestone(0))
	assert_false(DepartmentRank.is_milestone(24))
	assert_true(DepartmentRank.is_milestone(25))
	assert_true(DepartmentRank.is_milestone(250))
	assert_false(DepartmentRank.is_milestone(275))
	assert_eq(DepartmentRank.milestone_factor(26), 1.0)
	assert_eq(DepartmentRank.milestone_factor(25), GameConfig.RANK_MILESTONE_FACTORS[0])
	assert_eq(DepartmentRank.milestone_factor(250), GameConfig.RANK_MILESTONE_FACTORS.back())
	assert_eq(DepartmentRank.next_milestone(1), 25)
	assert_eq(DepartmentRank.next_milestone(24), 25)
	assert_eq(DepartmentRank.next_milestone(25), 50)
	assert_eq(DepartmentRank.next_milestone(249), 250)
	assert_eq(DepartmentRank.next_milestone(250), 250)
	assert_eq(DepartmentRank.title_index(1), 1)
	assert_eq(DepartmentRank.title_index(24), 1)
	assert_eq(DepartmentRank.title_index(25), 2)
	assert_eq(DepartmentRank.title_index(249), 10)
	assert_eq(DepartmentRank.title_index(250), GameConfig.RANK_TITLES)
	assert_eq(DepartmentRank.clamp_level(0), 1)
	assert_eq(DepartmentRank.clamp_level(999), GameConfig.MAX_DEPARTMENT_RANK)
	assert_eq(DepartmentRank.department_index("tax_services"), 1)
	assert_eq(DepartmentRank.department_index("nope"), 0)


func test_ladder_cost_uses_unlock_prices_and_extrapolates() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		assert_eq(DepartmentRank.ladder_cost(index), float(GameConfig.department(ids[index]).unlock_cost), ids[index])
	var last := float(GameConfig.department(ids[ids.size() - 1]).unlock_cost)
	var next := last * GameConfig.RANK_LADDER_GROWTH
	assert_almost_eq(DepartmentRank.ladder_cost(ids.size()), next, next * 1e-9)
	var later := last * pow(GameConfig.RANK_LADDER_GROWTH, 3)
	assert_almost_eq(DepartmentRank.ladder_cost(ids.size() + 2), later, later * 1e-9)
	assert_eq(DepartmentRank.ladder_cost(-3), DepartmentRank.ladder_cost(0))


func test_ladder_cost_keeps_rising() -> void:
	for tier_index in range(1, GameConfig.department_ids().size() + 3):
		assert_gt(DepartmentRank.ladder_cost(tier_index), DepartmentRank.ladder_cost(tier_index - 1), str(tier_index))


func test_ladder_reputation_stops_at_the_last_department() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		assert_eq(DepartmentRank.ladder_reputation(index), float(GameConfig.department(ids[index]).unlock_reputation), ids[index])
	var last := float(GameConfig.department(ids[ids.size() - 1]).unlock_reputation)
	assert_eq(DepartmentRank.ladder_reputation(ids.size() + 5), last)
	assert_eq(DepartmentRank.ladder_reputation(-1), float(GameConfig.department(ids[0]).unlock_reputation))


func _first_block_cost(dept_id: String) -> float:
	var total := 0.0
	for level in range(1, GameConfig.RANK_MILESTONE_STEP):
		total += DepartmentRank.level_cost(dept_id, level)
	return total


func _payback(dept: Department, level: int) -> float:
	dept.rank = level
	return DepartmentRank.next_cost(dept) / DepartmentRank.gain_per_second(state, dept)


func test_first_milestone_costs_as_much_as_opening_the_next_department() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		var cost := _first_block_cost(ids[index])
		var expected := DepartmentRank.ladder_cost(index + 1)
		assert_almost_eq(cost, expected, expected * 1e-6, ids[index])
		if index + 1 < ids.size():
			assert_almost_eq(cost, float(GameConfig.department(ids[index + 1]).unlock_cost), expected * 1e-6, ids[index])


func test_level_costs_grow_geometrically() -> void:
	for dept_id in GameConfig.department_ids():
		var dept := state.department(dept_id)
		assert_almost_eq(DepartmentRank.level_cost(dept_id, 1), DepartmentRank.base_cost(dept_id), 1e-6)
		for level in range(2, GameConfig.MAX_DEPARTMENT_RANK):
			var ratio := DepartmentRank.level_cost(dept_id, level) / DepartmentRank.level_cost(dept_id, level - 1)
			assert_almost_eq(ratio, GameConfig.RANK_LEVEL_COST_GROWTH, 1e-9, "%s %d" % [dept_id, level])
		dept.rank = 40
		assert_eq(DepartmentRank.next_cost(dept), DepartmentRank.level_cost(dept_id, 40))
	assert_eq(DepartmentRank.level_cost("general_services", 0), DepartmentRank.level_cost("general_services", 1))


func test_reputation_requirement_rises_per_milestone_block() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		var dept := state.department(ids[index])
		for level in range(1, GameConfig.MAX_DEPARTMENT_RANK):
			dept.rank = level
			var expected := DepartmentRank.ladder_reputation(index + 1 + DepartmentRank.milestones(level))
			assert_eq(DepartmentRank.next_reputation(dept), expected, "%s %d" % [ids[index], level])
	var first := state.department("general_services")
	first.rank = 1
	assert_eq(DepartmentRank.next_reputation(first), float(GameConfig.department("tax_services").unlock_reputation))
	first.rank = 25
	assert_eq(DepartmentRank.next_reputation(first), float(GameConfig.department("business_licences").unlock_reputation))


func test_first_milestone_earns_about_as_much_as_the_next_department() -> void:
	var ids := GameConfig.department_ids()
	var milestone := GameConfig.RANK_MILESTONE_STEP
	for index in ids.size() - 1:
		var dept := state.department(ids[index])
		var gain := Formulas.potential_income(state, dept) * (DepartmentRank.fee_factor(milestone) - 1.0)
		var ratio := gain / Formulas.potential_income(state, state.department(ids[index + 1]))
		assert_between(ratio, 0.4, 1.25, ids[index])


func test_rank_ups_pay_off_slower_within_and_across_milestone_blocks() -> void:
	var step := GameConfig.RANK_MILESTONE_STEP
	for dept_id in GameConfig.department_ids():
		var dept := state.department(dept_id)
		var block_start := 0.0
		for block in GameConfig.RANK_MILESTONE_FACTORS.size():
			var first_level := maxi(1, block * step + 1)
			var payback := _payback(dept, first_level)
			assert_gt(payback, block_start, "%s block %d" % [dept_id, block])
			block_start = payback
			var previous := payback
			for level in range(first_level + 1, (block + 1) * step - 1):
				var next := _payback(dept, level)
				assert_gt(next, previous, "%s %d" % [dept_id, level])
				previous = next
			assert_lt(_payback(dept, (block + 1) * step - 1), previous, "%s milestone %d" % [dept_id, block + 1])


func test_block_reasons() -> void:
	var dept := state.department("general_services")
	assert_eq(DepartmentRank.block_reason(state, "nope"), "unknown")
	assert_eq(DepartmentRank.block_reason(state, "tax_services"), "room")
	state.reputation = 0.0
	state.reputation_peak = 0.0
	state.money = 0.0
	assert_eq(DepartmentRank.block_reason(state, "general_services"), "reputation")
	state.reputation = DepartmentRank.next_reputation(dept)
	assert_eq(DepartmentRank.block_reason(state, "general_services"), "money")
	state.money = DepartmentRank.next_cost(dept)
	assert_eq(DepartmentRank.block_reason(state, "general_services"), "")
	dept.rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_eq(DepartmentRank.block_reason(state, "general_services"), "max")
	assert_true(DepartmentRank.is_max(dept))


func test_reputation_peak_counts_for_rank_ups() -> void:
	var dept := state.department("general_services")
	state.money = DepartmentRank.next_cost(dept)
	state.reputation = 0.0
	state.reputation_peak = DepartmentRank.next_reputation(dept)
	assert_eq(DepartmentRank.block_reason(state, "general_services"), "")


func test_gain_per_second_follows_the_fee_factor() -> void:
	var dept := state.department("general_services")
	var potential := Formulas.potential_income(state, dept)
	assert_gt(potential, 0.0)
	assert_almost_eq(DepartmentRank.gain_per_second(state, dept), potential * (GameConfig.RANK_LEVEL_FEE_FACTOR - 1.0), 0.000001)
	dept.rank = GameConfig.RANK_MILESTONE_STEP - 1
	var ranked := Formulas.potential_income(state, dept)
	var jump := GameConfig.RANK_LEVEL_FEE_FACTOR * GameConfig.RANK_MILESTONE_FACTORS[0] - 1.0
	assert_almost_eq(DepartmentRank.gain_per_second(state, dept), ranked * jump, 0.000001)
	dept.rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_eq(DepartmentRank.gain_per_second(state, dept), 0.0)


func test_rank_slows_down_the_departments_own_desks() -> void:
	assert_eq(DepartmentRank.time_factor(1), 1.0)
	assert_eq(DepartmentRank.time_factor(0), 1.0)
	assert_almost_eq(DepartmentRank.time_factor(11), pow(GameConfig.RANK_LEVEL_TIME_FACTOR, 10), 0.000001)
	assert_eq(DepartmentRank.time_factor(999), DepartmentRank.time_factor(GameConfig.MAX_DEPARTMENT_RANK))
	var dept := state.department("general_services")
	var review := state.station("general_services/review")
	var reception := state.station(GameConfig.RECEPTION)
	var case_file := CaseFile.new(dept.id)
	var review_time := Formulas.required_time(state, review, case_file)
	var reception_time := Formulas.required_time(state, reception, case_file)
	dept.rank = 11
	assert_almost_eq(Formulas.required_time(state, review, case_file), review_time * DepartmentRank.time_factor(11), 0.000001)
	assert_almost_eq(Formulas.required_time(state, reception, case_file), reception_time, 0.000001)
	assert_gt(Formulas.station_case_time(state, review, false), 0.0)


func test_rank_still_pays_off_despite_slower_desks() -> void:
	for level in [2, 25, 100, GameConfig.MAX_DEPARTMENT_RANK]:
		assert_gt(DepartmentRank.fee_factor(level) / DepartmentRank.time_factor(level), DepartmentRank.fee_factor(level - 1) / DepartmentRank.time_factor(level - 1), str(level))


func test_potential_income_is_demand_times_case_value() -> void:
	var dept := state.department("tax_services")
	assert_almost_eq(Formulas.potential_income(state, dept), Formulas.demand(state, dept) * Formulas.expected_case_value(state, dept), 0.000001)


func test_rank_multiplies_every_fee_but_not_the_demand() -> void:
	var dept := state.department("general_services")
	var fee := Formulas.department_fee(dept)
	var value := Formulas.expected_case_value(state, dept)
	var hands_on := Formulas.hands_on_reward(dept)
	var reject := Formulas.reject_fee(state, dept)
	var demand := Formulas.demand(state, dept)
	var case_file := CaseFile.new(dept.id)
	var outcome := float(Formulas.case_outcome(state, case_file).money)
	assert_eq(fee, float(dept.config().reward))
	assert_almost_eq(reject, fee * Formulas.reputation_multiplier(state) * GameConfig.REJECT_FEE_FACTOR, 0.000001)
	dept.rank = 3
	var factor := DepartmentRank.fee_factor(3)
	assert_almost_eq(Formulas.department_fee(dept), fee * factor, 0.000001)
	assert_almost_eq(Formulas.expected_case_value(state, dept), value * factor, 0.000001)
	assert_almost_eq(Formulas.hands_on_reward(dept), hands_on * factor, 0.000001)
	assert_almost_eq(Formulas.reject_fee(state, dept), reject * factor, 0.000001)
	assert_almost_eq(float(Formulas.case_outcome(state, case_file).money), outcome * factor, 0.000001)
	assert_eq(Formulas.demand(state, dept), demand)


func test_completed_and_rejected_cases_pay_the_ranked_fee() -> void:
	var dept := state.department("general_services")
	dept.rank = 2
	state.money = 0.0
	var case_file := CaseFile.new(dept.id)
	var expected := float(Formulas.case_outcome(state, case_file).money)
	game.simulation.complete_case(case_file)
	assert_almost_eq(state.money, expected, 0.000001)
	state.money = 0.0
	game.simulation._reject_case(CaseFile.new(dept.id))
	assert_almost_eq(state.money, Formulas.reject_fee(state, dept), 0.000001)


func test_rank_is_saved_and_validated() -> void:
	var dept := state.department("general_services")
	assert_eq(dept.rank, 1)
	dept.rank = 137
	var data := dept.to_dict()
	assert_false(data.has("rank"))
	assert_eq(int(data.rank_level), 137)
	assert_eq(Department.from_dict(data).rank, 137)
	data.rank_level = 999
	assert_eq(Department.from_dict(data).rank, GameConfig.MAX_DEPARTMENT_RANK)
	data.rank_level = -2
	assert_eq(Department.from_dict(data).rank, 1)
	data.erase("rank_level")
	assert_eq(Department.from_dict(data).rank, 1)
	data.rank_level = 50
	data.unlocked = false
	assert_eq(Department.from_dict(data).rank, 1)


func test_legacy_ranks_keep_at_least_their_old_fee() -> void:
	var previous := 0
	for rank in range(1, SaveMigration.LEGACY_MAX_RANK + 1):
		var level := SaveMigration.legacy_rank_level(rank)
		var old_factor := pow(SaveMigration.LEGACY_RANK_FEE_FACTOR, rank - 1)
		assert_gte(DepartmentRank.fee_factor(level), old_factor * (1.0 - 1e-9), str(rank))
		if level > 1:
			assert_lt(DepartmentRank.fee_factor(level - 1), old_factor, str(rank))
		assert_gt(level, previous, str(rank))
		assert_lte(level, GameConfig.MAX_DEPARTMENT_RANK)
		previous = level
	assert_eq(SaveMigration.legacy_rank_level(1), 1)
	assert_eq(SaveMigration.legacy_rank_level(2), 27)
	assert_eq(SaveMigration.legacy_rank_level(0), 1)
	assert_eq(SaveMigration.legacy_rank_level(-5), 1)
	assert_eq(SaveMigration.legacy_rank_level(99), SaveMigration.legacy_rank_level(SaveMigration.LEGACY_MAX_RANK))


func test_legacy_rank_is_converted_on_load() -> void:
	var data := {"id": "general_services", "unlocked": true, "rank": 4}
	assert_eq(Department.from_dict(data).rank, SaveMigration.legacy_rank_level(4))
	data.rank = 99
	assert_eq(Department.from_dict(data).rank, SaveMigration.legacy_rank_level(SaveMigration.LEGACY_MAX_RANK))
	data.rank_level = 7
	assert_eq(Department.from_dict(data).rank, 7)
	var locked := {"id": "tax_services", "unlocked": false, "rank": 6}
	assert_eq(Department.from_dict(locked).rank, 1)


func test_legacy_save_converts_every_department_rank() -> void:
	state.unlock_department("tax_services")
	var saved := state.to_dict()
	for dept_id: String in saved.departments:
		var entry: Dictionary = saved.departments[dept_id]
		entry.erase("rank_level")
		if dept_id == "general_services":
			entry.rank = 3
		elif dept_id == "tax_services":
			entry.rank = 10
	var loaded := GameState.from_dict(saved)
	assert_eq(loaded.department("general_services").rank, SaveMigration.legacy_rank_level(3))
	assert_eq(loaded.department("tax_services").rank, SaveMigration.legacy_rank_level(10))
	assert_eq(loaded.department("business_licences").rank, 1)
	var resaved := loaded.to_dict()
	for dept_id: String in resaved.departments:
		assert_false(resaved.departments[dept_id].has("rank"))
		assert_true(resaved.departments[dept_id].has("rank_level"))


func test_rank_survives_a_save_roundtrip() -> void:
	state.unlock_department("tax_services")
	state.department("tax_services").rank = 3
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.department("tax_services").rank, 3)
	assert_eq(loaded.department("general_services").rank, 1)
	assert_eq(loaded.department("customs").rank, 1)


func test_rank_up_action_spends_money_and_emits() -> void:
	watch_signals(game.simulation)
	var dept := state.department("general_services")
	state.reputation = DepartmentRank.next_reputation(dept)
	state.money = DepartmentRank.next_cost(dept) + 5.0
	assert_true(game.actions.rank_up_department("general_services"))
	assert_eq(dept.rank, 2)
	assert_almost_eq(state.money, 5.0, 0.000001)
	assert_signal_emitted_with_parameters(game.simulation, "department_ranked_up", ["general_services", 2])
	assert_false(game.actions.rank_up_department("general_services"))
	assert_eq(dept.rank, 2)


func test_rank_up_action_respects_block_reasons() -> void:
	state.money = 1e15
	state.reputation = 1e6
	assert_false(game.actions.rank_up_department("nope"))
	assert_false(game.actions.rank_up_department("tax_services"))
	assert_eq(state.department("tax_services").rank, 1)
	var dept := state.department("general_services")
	dept.rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_false(game.actions.rank_up_department("general_services"))
	assert_eq(dept.rank, GameConfig.MAX_DEPARTMENT_RANK)
	assert_eq(state.money, 1e15)


func test_rank_entry_fields() -> void:
	var dept := state.department("general_services")
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	assert_eq(entry.kind, UpgradeCatalog.RANK)
	assert_eq(entry.target, "general_services")
	assert_eq(entry.spot, "dept:general_services")
	assert_eq(entry.room, "general_services")
	assert_eq(entry.topic, "building")
	assert_false(entry.single)
	assert_false(UpgradeCatalog.SINGLE_KINDS.has(UpgradeCatalog.RANK))
	assert_eq(entry.level, 1)
	assert_eq(entry.max_level, GameConfig.MAX_DEPARTMENT_RANK)
	assert_eq(entry.cost, DepartmentRank.next_cost(dept))
	assert_eq(entry.growth, GameConfig.RANK_LEVEL_COST_GROWTH)
	assert_eq(entry.cap, DepartmentRank.reachable_level(state, dept))
	assert_eq(entry.reason, DepartmentRank.block_reason(state, "general_services"))
	assert_eq(entry.remaining(), entry.cap - entry.level)


func test_reachable_level_stops_at_the_reputation_of_the_next_block() -> void:
	var dept := state.department("general_services")
	state.reputation = 0.0
	state.reputation_peak = 0.0
	assert_eq(DepartmentRank.reachable_level(state, dept), 1)
	state.reputation = DepartmentRank.level_reputation("general_services", 1)
	assert_eq(DepartmentRank.reachable_level(state, dept), GameConfig.RANK_MILESTONE_STEP)
	state.reputation = DepartmentRank.level_reputation("general_services", GameConfig.RANK_MILESTONE_STEP)
	assert_eq(DepartmentRank.reachable_level(state, dept), GameConfig.RANK_MILESTONE_STEP * 2)
	state.reputation = 1e9
	assert_eq(DepartmentRank.reachable_level(state, dept), GameConfig.MAX_DEPARTMENT_RANK)
	dept.rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_eq(DepartmentRank.reachable_level(state, dept), GameConfig.MAX_DEPARTMENT_RANK)
	dept.rank = 30
	state.reputation = 0.0
	assert_eq(DepartmentRank.reachable_level(state, dept), 30)


func test_rank_entries_only_exist_for_open_departments() -> void:
	var ids := _ids(UpgradeCatalog.entries(state))
	assert_true(ids.has("rank:general_services"))
	assert_false(ids.has("rank:tax_services"))
	assert_null(UpgradeCatalog.find(state, "rank:tax_services"))
	assert_null(UpgradeCatalog.find(state, "rank:nope"))
	state.unlock_department("tax_services")
	assert_true(_ids(UpgradeCatalog.entries(state)).has("rank:tax_services"))
	assert_not_null(UpgradeCatalog.find(state, "rank:tax_services"))


func test_rank_entry_leads_its_department_spot() -> void:
	var entries := UpgradeCatalog.entries_for_spot(state, "dept:general_services")
	assert_eq(entries[0].id, "rank:general_services")
	assert_eq(UpgradeCatalog.spots_of(entries)[0], "dept:general_services")
	assert_true(_ids(UpgradeCatalog.entries_for_room(state, "general_services")).has("rank:general_services"))


func test_maxed_rank_entry_stays_visible() -> void:
	state.department("general_services").rank = GameConfig.MAX_DEPARTMENT_RANK
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	assert_not_null(entry)
	assert_true(entry.is_maxed())
	assert_eq(entry.reason, "max")
	assert_eq(entry.remaining(), 0)


func test_buy_entry_raises_several_levels_at_once() -> void:
	state.money = 1e12
	state.reputation = 1e6
	var dept := state.department("general_services")
	var money := state.money
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	var cost := entry.bulk_cost(5)
	assert_almost_eq(cost, Formulas.geometric_sum(DepartmentRank.level_cost("general_services", 1), GameConfig.RANK_LEVEL_COST_GROWTH, 5), 0.001)
	assert_true(game.actions.buy_entry("rank:general_services", 5))
	assert_eq(dept.rank, 6)
	assert_almost_eq(state.money, money - cost, 0.001)
	assert_false(game.actions.buy_entry("rank:tax_services"))


func test_bulk_rank_purchase_stops_at_the_reputation_limit() -> void:
	var dept := state.department("general_services")
	state.money = 1e15
	state.reputation = DepartmentRank.level_reputation("general_services", 1)
	state.reputation_peak = 0.0
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	assert_eq(entry.remaining(), GameConfig.RANK_MILESTONE_STEP - 1)
	assert_eq(entry.amount_for(100), GameConfig.RANK_MILESTONE_STEP - 1)
	assert_true(game.actions.buy_entry("rank:general_services", 100))
	assert_eq(dept.rank, GameConfig.RANK_MILESTONE_STEP)
	var blocked := UpgradeCatalog.find(state, "rank:general_services")
	assert_eq(blocked.reason, "reputation")
	assert_eq(blocked.remaining(), 0)
	assert_eq(UpgradeEntryCard.purchase_count(state, blocked, 0), 1)
	assert_false(UpgradeEntryCard.can_buy(state, blocked, 1))


func test_expansion_lists_ranks_and_the_next_unlock() -> void:
	state.money = 1e12
	state.reputation = 1e6
	var ids := _ids(UpgradeCatalog.expansion_entries(state))
	assert_eq(ids.size(), 2)
	assert_true(ids.has("rank:general_services"))
	assert_true(ids.has("unlock:tax_services"))
	assert_false(ids.has("stage:building"))
	assert_false(ids.has("unlock:business_licences"))
	assert_false(ids.has("track:briefcase"))
	assert_false(ids.has("supervisor:general_services"))


func test_expansion_is_sorted_by_payback() -> void:
	for dept_id in GameConfig.department_ids().slice(0, 4):
		state.unlock_department(dept_id)
	state.department("general_services").rank = 3
	var list := UpgradeCatalog.expansion_entries(state)
	assert_eq(list.size(), 5)
	for index in range(1, list.size()):
		assert_true(UpgradeCatalog.payback(state, list[index - 1]) <= UpgradeCatalog.payback(state, list[index]), list[index].id)


func test_expansion_skips_maxed_ranks() -> void:
	state.department("general_services").rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_false(_ids(UpgradeCatalog.expansion_entries(state)).has("rank:general_services"))


func test_expansion_is_empty_when_everything_is_done() -> void:
	_open_everything()
	assert_true(UpgradeCatalog.expansion_entries(state).is_empty())


func test_is_expansion() -> void:
	assert_true(UpgradeCatalog.is_expansion(UpgradeCatalog.find(state, "rank:general_services")))
	assert_true(UpgradeCatalog.is_expansion(UpgradeCatalog.find(state, "unlock:tax_services")))
	assert_false(UpgradeCatalog.is_expansion(UpgradeCatalog.find(state, "unlock:business_licences")))
	assert_false(UpgradeCatalog.is_expansion(UpgradeCatalog.find(state, "track:briefcase")))
	assert_false(UpgradeCatalog.is_expansion(UpgradeCatalog.find(state, "level:shared/reception")))


func test_income_gain_and_payback() -> void:
	var dept := state.department("general_services")
	var rank := UpgradeCatalog.find(state, "rank:general_services")
	var gain := DepartmentRank.gain_per_second(state, dept)
	assert_almost_eq(UpgradeCatalog.income_gain(state, rank), gain, 0.000001)
	assert_almost_eq(UpgradeCatalog.payback(state, rank), rank.cost / gain, 0.001)
	var unlock := UpgradeCatalog.find(state, "unlock:tax_services")
	assert_almost_eq(UpgradeCatalog.income_gain(state, unlock), Formulas.potential_income(state, state.department("tax_services")), 0.000001)
	assert_eq(UpgradeCatalog.income_gain(state, UpgradeCatalog.find(state, "supervisor:general_services")), 0.0)
	dept.rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_eq(UpgradeCatalog.payback(state, UpgradeCatalog.find(state, "rank:general_services")), INF)


func test_rank_texts() -> void:
	state.money = 1e12
	state.reputation = 1e6
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	assert_eq(UpgradeTexts.title(entry), _t("FMT_ENTRY_RANK") % _t("DEPT_GENERAL_SERVICES"))
	assert_eq(UpgradeTexts.description(entry), _t("ENTRY_DESC_RANK"))
	assert_eq(UpgradeTexts.icon(entry), Icons.RANK)
	assert_eq(UpgradeTexts.level_text(entry), _t("FMT_LEVEL_OF") % [1, GameConfig.MAX_DEPARTMENT_RANK])
	assert_eq(UpgradeTexts.place(entry), _t("FMT_ENTRY_PLACE") % [_t("DEPT_GENERAL_SERVICES"), _t("DEPT_GENERAL_SERVICES")])
	assert_eq(UpgradeTexts.button_text(state, entry, 1), _t("FMT_ACTION_COST") % [_t("ACTION_BUY"), UiKit.money(entry.cost)])
	assert_eq(UpgradeEntryCard.purchase_count(state, entry, 10), 10)
	assert_eq(UpgradeTexts.button_text(state, entry, 10), _t("FMT_ACTION_COST") % [_t("FMT_ACTION_BUY_MANY") % 10, UiKit.money(entry.bulk_cost(10))])
	var change := _t("FMT_EFFECT_RANK") % [1, 2, UpgradeTexts.fee_factor_text(1), UpgradeTexts.fee_factor_text(2)]
	var milestone := _t("FMT_EFFECT_RANK_MILESTONE") % [25, UpgradeTexts.rank_name(25), UpgradeTexts.factor_text(GameConfig.RANK_MILESTONE_FACTORS[0])]
	assert_eq(UpgradeTexts.milestone_text(1), milestone)
	var gain := UpgradeTexts.gain_text("FMT_EFFECT_RANK_GAIN", UpgradeCatalog.income_gain(state, entry), entry.cost)
	assert_false(gain.is_empty())
	var slower := _t("FMT_EFFECT_RANK_TIME") % ["×" + UiKit.decimal(1.0, 2), "×" + UiKit.decimal(GameConfig.RANK_LEVEL_TIME_FACTOR, 2)]
	assert_eq(UpgradeTexts.time_text(1), slower)
	assert_eq(UpgradeTexts.effect(state, entry), change + "\n" + slower + "\n" + milestone + "\n" + gain)


func test_maxed_rank_texts() -> void:
	state.department("general_services").rank = GameConfig.MAX_DEPARTMENT_RANK
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	var top := GameConfig.MAX_DEPARTMENT_RANK
	assert_eq(UpgradeTexts.effect(state, entry), _t("FMT_EFFECT_RANK_MAX") % [UpgradeTexts.rank_name(top), UpgradeTexts.fee_factor_text(top)])
	assert_eq(UpgradeTexts.level_text(entry), _t("FMT_LEVEL_OF") % [top, top])
	assert_eq(UpgradeTexts.button_text(state, entry, 1), _t("LABEL_MAX_LEVEL"))


func test_rank_effect_without_department_is_empty() -> void:
	var entry := UpgradeEntry.new()
	entry.kind = UpgradeCatalog.RANK
	entry.target = "nope"
	assert_eq(UpgradeTexts.effect(state, entry), "")
	assert_eq(UpgradeCatalog.income_gain(state, entry), 0.0)


func test_rank_block_text_names_the_reputation() -> void:
	state.reputation = 0.0
	state.reputation_peak = 0.0
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	assert_eq(entry.reason, "reputation")
	assert_eq(UpgradeTexts.required_reputation(entry), DepartmentRank.next_reputation(state.department("general_services")))
	assert_eq(UpgradeTexts.block_text(state, entry), _t("FMT_REQ_REPUTATION") % int(DepartmentRank.next_reputation(state.department("general_services"))))
	assert_eq(UpgradeTexts.button_text(state, entry, 1), UpgradeTexts.block_text(state, entry))


func test_unlock_effect_shows_the_potential_income() -> void:
	var entry := UpgradeCatalog.find(state, "unlock:tax_services")
	var potential := Formulas.potential_income(state, state.department("tax_services"))
	var expected := _t("FMT_EFFECT_UNLOCK_GAIN") % [UiKit.money(potential * 60.0), UiKit.duration(entry.cost / potential)]
	assert_eq(UpgradeTexts.effect(state, entry), expected)


func test_gain_text_needs_a_gain() -> void:
	assert_eq(UpgradeTexts.gain_text("FMT_EFFECT_RANK_GAIN", 0.0, 100.0), "")
	assert_eq(UpgradeTexts.gain_text("FMT_EFFECT_RANK_GAIN", -1.0, 100.0), "")
	assert_eq(UpgradeTexts.gain_text("FMT_EFFECT_RANK_GAIN", 2.0, 600.0), _t("FMT_EFFECT_RANK_GAIN") % [UiKit.money(120.0), UiKit.duration(300.0)])


func test_rank_names_are_translated_and_clamped() -> void:
	var names: Array[String] = []
	for title_index in range(1, GameConfig.RANK_TITLES + 1):
		var level := maxi(1, (title_index - 1) * GameConfig.RANK_MILESTONE_STEP)
		var title := UpgradeTexts.rank_name(level)
		assert_ne(title, "DEPT_RANK_%d" % title_index)
		assert_false(names.has(title), title)
		names.append(title)
	assert_eq(UpgradeTexts.rank_name(0), UpgradeTexts.rank_name(1))
	assert_eq(UpgradeTexts.rank_name(24), UpgradeTexts.rank_name(1))
	assert_ne(UpgradeTexts.rank_name(25), UpgradeTexts.rank_name(24))
	assert_eq(UpgradeTexts.rank_name(999), UpgradeTexts.rank_name(GameConfig.MAX_DEPARTMENT_RANK))
	assert_eq(UpgradeTexts.rank_title(37), _t("FMT_RANK_TITLE") % [UpgradeTexts.rank_name(37), 37])
	assert_eq(UpgradeTexts.rank_title(999), _t("FMT_RANK_TITLE") % [UpgradeTexts.rank_name(999), GameConfig.MAX_DEPARTMENT_RANK])


func test_rank_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["FMT_ENTRY_RANK", "ENTRY_DESC_RANK", "FMT_EFFECT_RANK", "FMT_EFFECT_RANK_MAX", "FMT_EFFECT_RANK_GAIN", "FMT_EFFECT_UNLOCK_GAIN", "UPGRADE_MODE_EXPANSION", "UPGRADE_MODE_HINT_EXPANSION", "UPGRADES_NONE_EXPANSION", "FMT_FLOAT_RANK", "STATS_DEPT_RANK", "FMT_STATS_RANK", "FMT_EFFECT_RANK_MILESTONE", "FMT_EFFECT_RANK_TIME", "FMT_RANK_TITLE"]
	for title_index in range(1, GameConfig.RANK_TITLES + 1):
		keys.append("DEPT_RANK_%d" % title_index)
	var previous := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
	TranslationServer.set_locale(previous)


func test_fee_factor_texts() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	assert_eq(UpgradeTexts.fee_factor_text(1), "×1")
	assert_eq(UpgradeTexts.fee_factor_text(2), "×1,02")
	assert_eq(UpgradeTexts.fee_factor_text(25), "×" + UiKit.decimal(DepartmentRank.fee_factor(25), 2))
	assert_eq(UpgradeTexts.factor_text(1.5), "×1,5")
	assert_eq(UpgradeTexts.factor_text(2.0), "×2")
	assert_eq(UpgradeTexts.factor_text(15.4), "×15")
	assert_eq(UpgradeTexts.fee_factor_text(GameConfig.MAX_DEPARTMENT_RANK), "×" + UiKit.number(DepartmentRank.fee_factor(GameConfig.MAX_DEPARTMENT_RANK)))
	TranslationServer.set_locale(previous)


func test_department_sheet_buys_the_rank_up() -> void:
	state.money = 1e9
	state.reputation = 1e4
	var sheet := _sheet(SpotSheet.new(), "dept:general_services")
	var entry := UpgradeCatalog.find(state, "rank:general_services")
	var button := _entry_button(sheet.content, UpgradeTexts.title(entry), UpgradeTexts.button_text(state, entry, 1))
	assert_not_null(button)
	button.pressed.emit()
	assert_eq(state.department("general_services").rank, 2)
	assert_true(_has_text(sheet.content, UpgradeTexts.level_text(UpgradeCatalog.find(state, "rank:general_services"))))


func test_expansion_mode_compares_the_big_steps() -> void:
	state.money = 1e9
	state.reputation = 1e4
	UpgradesSheet.mode_index = UpgradesSheet.MODES.find("expansion")
	assert_eq(UpgradesSheet.mode(), "expansion")
	var sheet := _sheet(UpgradesSheet.new())
	var rank := UpgradeCatalog.find(state, "rank:general_services")
	var unlock := UpgradeCatalog.find(state, "unlock:tax_services")
	assert_true(_has_text(sheet.content, _t("UPGRADE_MODE_HINT_EXPANSION")))
	assert_true(_has_text(sheet.content, UpgradeTexts.title(rank)))
	assert_true(_has_text(sheet.content, UpgradeTexts.place(rank)))
	assert_true(_has_text(sheet.content, UpgradeTexts.effect(state, rank)))
	assert_true(_has_text(sheet.content, UpgradeTexts.title(unlock)))
	assert_true(_has_text(sheet.content, UpgradeTexts.effect(state, unlock)))
	assert_not_null(_button(sheet.content, _t("AMOUNT_TEN")))
	assert_false(_has_text(sheet.content, _t("UPGRADES_NONE_EXPANSION")))


func test_expansion_mode_shows_the_empty_state() -> void:
	_open_everything()
	UpgradesSheet.mode_index = UpgradesSheet.MODES.find("expansion")
	var sheet := _sheet(UpgradesSheet.new())
	assert_true(_has_text(sheet.content, _t("UPGRADES_NONE_EXPANSION")))


func test_other_modes_keep_the_amount_selector() -> void:
	var sheet := _sheet(UpgradesSheet.new())
	assert_not_null(_button(sheet.content, _t("AMOUNT_TEN")))


func test_statistics_show_the_rank() -> void:
	state.department("general_services").rank = 3
	var sheet := StatisticsSheet.new()
	sheet.setup(game)
	add_child_autofree(sheet)
	assert_true(_has_text(sheet.content, _t("STATS_DEPT_RANK")))
	assert_true(_has_text(sheet.content, _t("FMT_STATS_RANK") % [UpgradeTexts.rank_title(3), UpgradeTexts.fee_factor_text(3)]))


func test_rank_badge_only_from_the_second_rank() -> void:
	var dept := state.department("general_services")
	assert_eq(WorldView.rank_badge_text(null), "")
	assert_eq(WorldView.rank_badge_text(dept), "")
	dept.rank = 4
	assert_eq(WorldView.rank_badge_text(dept), "4")
	dept.rank = 137
	assert_eq(WorldView.rank_badge_text(dept), "137")


func test_world_floats_only_milestone_ranks() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var dept := state.department("general_services")
	state.reputation = 1e6
	state.money = 1e15
	var floaters := world._floaters.size()
	assert_true(game.actions.rank_up_department("general_services"))
	assert_eq(world._floaters.size(), floaters)
	dept.rank = GameConfig.RANK_MILESTONE_STEP - 1
	assert_true(game.actions.rank_up_department("general_services"))
	assert_eq(world._floaters.size(), floaters + 1)
	var expected := _t("FMT_FLOAT_RANK") % [UpgradeTexts.rank_name(GameConfig.RANK_MILESTONE_STEP), UpgradeTexts.factor_text(GameConfig.RANK_MILESTONE_FACTORS[0])]
	assert_eq(str(world._floaters.back().text), expected)


func test_world_draws_the_rank_badge() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	state.department("general_services").rank = 205
	var drawn := [false]
	world._actors.draw.connect(func() -> void:
		world._canvas = world._actors
		world._draw_rank_badge(state.department("general_services"), Vector2.ZERO)
		world._draw_rank_badge(null, Vector2.ZERO)
		world._canvas = world
		drawn[0] = true
	)
	world._actors.queue_redraw()
	await wait_physics_frames(2)
	assert_true(drawn[0])
