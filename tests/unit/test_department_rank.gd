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


func test_fee_factor_grows_per_rank_and_is_clamped() -> void:
	assert_eq(DepartmentRank.fee_factor(1), 1.0)
	assert_almost_eq(DepartmentRank.fee_factor(2), GameConfig.RANK_FEE_FACTOR, 0.000001)
	assert_almost_eq(DepartmentRank.fee_factor(3), pow(GameConfig.RANK_FEE_FACTOR, 2), 0.000001)
	assert_eq(DepartmentRank.fee_factor(0), 1.0)
	assert_eq(DepartmentRank.fee_factor(-4), 1.0)
	var top := pow(GameConfig.RANK_FEE_FACTOR, GameConfig.MAX_DEPARTMENT_RANK - 1)
	assert_almost_eq(DepartmentRank.fee_factor(GameConfig.MAX_DEPARTMENT_RANK), top, top * 1e-9)
	assert_almost_eq(DepartmentRank.fee_factor(99), top, top * 1e-9)


func test_tier_follows_department_order_and_rank() -> void:
	var last := GameConfig.department_ids().size() - 1
	assert_eq(DepartmentRank.tier("general_services", 1), 0)
	assert_eq(DepartmentRank.tier("general_services", 4), 3)
	assert_eq(DepartmentRank.tier("tax_services", 3), 3)
	assert_eq(DepartmentRank.tier("customs", 1), last)
	assert_eq(DepartmentRank.tier("customs", 99), last + GameConfig.MAX_DEPARTMENT_RANK - 1)
	assert_eq(DepartmentRank.tier("general_services", 0), 0)
	assert_eq(DepartmentRank.tier("nope", 2), 1)


func test_ladder_cost_uses_unlock_prices_and_extrapolates() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		assert_eq(DepartmentRank.ladder_cost(index), float(GameConfig.department(ids[index]).unlock_cost), ids[index])
	var last := float(GameConfig.department(ids[ids.size() - 1]).unlock_cost)
	var next := last * GameConfig.RANK_COST_GROWTH
	assert_almost_eq(DepartmentRank.ladder_cost(ids.size()), next, next * 1e-9)
	var later := last * pow(GameConfig.RANK_COST_GROWTH, 3)
	assert_almost_eq(DepartmentRank.ladder_cost(ids.size() + 2), later, later * 1e-9)
	assert_eq(DepartmentRank.ladder_cost(-3), DepartmentRank.ladder_cost(0))


func test_ladder_cost_keeps_rising() -> void:
	var top := DepartmentRank.tier("customs", GameConfig.MAX_DEPARTMENT_RANK) + 1
	for tier_index in range(1, top + 1):
		assert_gt(DepartmentRank.ladder_cost(tier_index), DepartmentRank.ladder_cost(tier_index - 1), str(tier_index))


func test_ladder_reputation_stops_at_the_last_department() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		assert_eq(DepartmentRank.ladder_reputation(index), float(GameConfig.department(ids[index]).unlock_reputation), ids[index])
	var last := float(GameConfig.department(ids[ids.size() - 1]).unlock_reputation)
	assert_eq(DepartmentRank.ladder_reputation(ids.size() + 5), last)
	assert_eq(DepartmentRank.ladder_reputation(-1), float(GameConfig.department(ids[0]).unlock_reputation))


func test_rank_up_costs_as_much_as_opening_the_department_at_that_level() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		var dept := state.department(ids[index])
		for rank in range(1, GameConfig.MAX_DEPARTMENT_RANK):
			dept.rank = rank
			var context := "%s %d" % [ids[index], rank]
			assert_eq(DepartmentRank.next_cost(dept), DepartmentRank.ladder_cost(index + rank), context)
			assert_eq(DepartmentRank.next_reputation(dept), DepartmentRank.ladder_reputation(index + rank), context)
			if index + rank < ids.size():
				var other := GameConfig.department(ids[index + rank])
				assert_eq(DepartmentRank.next_cost(dept), float(other.unlock_cost), context)
				assert_eq(DepartmentRank.next_reputation(dept), float(other.unlock_reputation), context)


func test_rank_up_earns_about_as_much_as_the_department_of_the_same_price() -> void:
	var ids := GameConfig.department_ids()
	for index in ids.size():
		var dept := state.department(ids[index])
		for rank in range(1, ids.size() - index):
			dept.rank = rank
			var other := state.department(ids[index + rank])
			var ratio := DepartmentRank.gain_per_second(state, dept) / Formulas.potential_income(state, other)
			assert_between(ratio, 0.4, 1.25, "%s %d" % [ids[index], rank])


func test_rank_ups_pay_off_slower_and_slower() -> void:
	for dept_id in GameConfig.department_ids():
		var dept := state.department(dept_id)
		var previous := 0.0
		for rank in range(1, GameConfig.MAX_DEPARTMENT_RANK):
			dept.rank = rank
			var payback := DepartmentRank.next_cost(dept) / DepartmentRank.gain_per_second(state, dept)
			assert_gt(payback, previous, "%s %d" % [dept_id, rank])
			previous = payback


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
	assert_almost_eq(DepartmentRank.gain_per_second(state, dept), potential * (GameConfig.RANK_FEE_FACTOR - 1.0), 0.000001)
	dept.rank = GameConfig.MAX_DEPARTMENT_RANK
	assert_eq(DepartmentRank.gain_per_second(state, dept), 0.0)


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
	dept.rank = 4
	var data := dept.to_dict()
	assert_eq(int(data.rank), 4)
	assert_eq(Department.from_dict(data).rank, 4)
	data.rank = 99
	assert_eq(Department.from_dict(data).rank, GameConfig.MAX_DEPARTMENT_RANK)
	data.rank = -2
	assert_eq(Department.from_dict(data).rank, 1)
	data.erase("rank")
	assert_eq(Department.from_dict(data).rank, 1)
	data.rank = 5
	data.unlocked = false
	assert_eq(Department.from_dict(data).rank, 1)


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
	assert_true(entry.single)
	assert_true(UpgradeCatalog.SINGLE_KINDS.has(UpgradeCatalog.RANK))
	assert_eq(entry.level, 1)
	assert_eq(entry.max_level, GameConfig.MAX_DEPARTMENT_RANK)
	assert_eq(entry.cost, DepartmentRank.next_cost(dept))
	assert_eq(entry.reason, DepartmentRank.block_reason(state, "general_services"))
	assert_eq(entry.remaining(), 1)


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


func test_buy_entry_raises_only_one_rank() -> void:
	state.money = 1e12
	state.reputation = 1e6
	var dept := state.department("general_services")
	var money := state.money
	var cost := DepartmentRank.next_cost(dept)
	assert_true(game.actions.buy_entry("rank:general_services", 5))
	assert_eq(dept.rank, 2)
	assert_almost_eq(state.money, money - cost, 0.001)
	assert_false(game.actions.buy_entry("rank:tax_services"))


func test_expansion_lists_ranks_the_next_unlock_and_the_stage() -> void:
	state.money = 1e12
	state.reputation = 1e6
	var ids := _ids(UpgradeCatalog.expansion_entries(state))
	assert_true(ids.has("rank:general_services"))
	assert_true(ids.has("unlock:tax_services"))
	assert_true(ids.has("stage:building"))
	assert_false(ids.has("unlock:business_licences"))
	assert_false(ids.has("track:briefcase"))
	assert_false(ids.has("supervisor:general_services"))
	assert_eq(ids.back(), "stage:building")


func test_expansion_is_sorted_by_payback() -> void:
	for dept_id in GameConfig.department_ids().slice(0, 4):
		state.unlock_department(dept_id)
	state.department("general_services").rank = 3
	var list := UpgradeCatalog.expansion_entries(state)
	assert_eq(list.size(), 6)
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
	assert_true(UpgradeCatalog.is_expansion(UpgradeCatalog.find(state, "stage:building")))
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
	var stage := UpgradeCatalog.find(state, "stage:building")
	assert_eq(UpgradeCatalog.income_gain(state, stage), 0.0)
	assert_eq(UpgradeCatalog.payback(state, stage), INF)
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
	assert_eq(UpgradeEntryCard.purchase_count(state, entry, 10), 1)
	var change := _t("FMT_EFFECT_RANK") % [UpgradeTexts.rank_name(1), UpgradeTexts.rank_name(2), UpgradeTexts.fee_factor_text(1), UpgradeTexts.fee_factor_text(2)]
	var gain := UpgradeTexts.gain_text("FMT_EFFECT_RANK_GAIN", UpgradeCatalog.income_gain(state, entry), entry.cost)
	assert_false(gain.is_empty())
	assert_eq(UpgradeTexts.effect(state, entry), change + "\n" + gain)


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
	for rank in range(1, GameConfig.MAX_DEPARTMENT_RANK + 1):
		var title := UpgradeTexts.rank_name(rank)
		assert_ne(title, "DEPT_RANK_%d" % rank)
		assert_false(names.has(title), title)
		names.append(title)
	assert_eq(UpgradeTexts.rank_name(0), UpgradeTexts.rank_name(1))
	assert_eq(UpgradeTexts.rank_name(99), UpgradeTexts.rank_name(GameConfig.MAX_DEPARTMENT_RANK))


func test_rank_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["FMT_ENTRY_RANK", "ENTRY_DESC_RANK", "FMT_EFFECT_RANK", "FMT_EFFECT_RANK_MAX", "FMT_EFFECT_RANK_GAIN", "FMT_EFFECT_UNLOCK_GAIN", "UPGRADE_MODE_EXPANSION", "UPGRADE_MODE_HINT_EXPANSION", "UPGRADES_NONE_EXPANSION", "FMT_FLOAT_RANK", "STATS_DEPT_RANK", "FMT_STATS_RANK"]
	for rank in range(1, GameConfig.MAX_DEPARTMENT_RANK + 1):
		keys.append("DEPT_RANK_%d" % rank)
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
	assert_eq(UpgradeTexts.fee_factor_text(2), "×2,5")
	assert_eq(UpgradeTexts.fee_factor_text(3), "×" + UiKit.decimal(6.25))
	assert_eq(UpgradeTexts.fee_factor_text(4), "×15")
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
	assert_null(_button(sheet.content, _t("AMOUNT_TEN")))
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
	assert_true(_has_text(sheet.content, _t("FMT_STATS_RANK") % [UpgradeTexts.rank_name(3), UpgradeTexts.fee_factor_text(3)]))


func test_rank_badge_only_from_the_second_rank() -> void:
	var dept := state.department("general_services")
	assert_eq(WorldView.rank_badge_text(null), "")
	assert_eq(WorldView.rank_badge_text(dept), "")
	dept.rank = 4
	assert_eq(WorldView.rank_badge_text(dept), "4")


func test_world_floats_the_new_rank() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var dept := state.department("general_services")
	state.reputation = DepartmentRank.next_reputation(dept)
	state.money = DepartmentRank.next_cost(dept)
	var floaters := world._floaters.size()
	assert_true(game.actions.rank_up_department("general_services"))
	assert_eq(world._floaters.size(), floaters + 1)
	assert_eq(str(world._floaters.back().text), _t("FMT_FLOAT_RANK") % UpgradeTexts.rank_name(2))


func test_world_draws_the_rank_badge() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	state.department("general_services").rank = 5
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
