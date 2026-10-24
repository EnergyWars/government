class_name GoalText
extends RefCounted


static func describe(goal: Dictionary) -> String:
	var goal_type := str(goal.get("type", ""))
	var target := int(goal.get("target", 0))
	var param := str(goal.get("param", ""))
	match goal_type:
		"department":
			return UiKit.t("FMT_GOAL_DEPARTMENT") % UiKit.t("DEPT_" + param.to_upper())
		"research_level":
			return UiKit.t("FMT_GOAL_RESEARCH_LEVEL") % UiKit.t("RESEARCH_" + param.to_upper())
		"building_stage":
			return UiKit.t("FMT_GOAL_BUILDING_STAGE") % UiKit.t("STAGE_" + str(GameConfig.building_stage(target).id).to_upper())
		"cases":
			return UiKit.t("FMT_GOAL_CASES") % UiKit.number(target)
	return UiKit.t("FMT_GOAL_" + goal_type.to_upper()) % target


static func reward(goal: Dictionary) -> String:
	var money := float(goal.get("money", 0.0))
	var reputation := int(goal.get("reputation", 0.0))
	if reputation > 0:
		return UiKit.t("FMT_REWARD_BOTH") % [UiKit.money(money), reputation]
	return UiKit.t("FMT_REWARD_MONEY") % UiKit.money(money)


static func claim_reward(goal: Dictionary) -> String:
	return UiKit.t("FMT_REWARD_WITH_SEALS") % [reward(goal), GameConfig.GOAL_SEALS]
