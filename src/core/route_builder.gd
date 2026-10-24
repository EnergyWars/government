class_name RouteBuilder
extends RefCounted


static func build(case_file: CaseFile) -> Array[String]:
	var config := GameConfig.department(case_file.dept_id)
	var keys := GameConfig.department_station_keys(case_file.dept_id)
	var route: Array[String] = []
	if config.is_empty():
		return route
	if GameConfig.is_customs(case_file.dept_id):
		route.append_array(keys)
		return route
	route.append(GameConfig.RECEPTION)
	route.append(keys[0])
	if case_file.follow_up:
		route.append(GameConfig.COUNTER)
		return route
	if not str(config.referral).is_empty():
		route.append(str(config.referral))
	if bool(config.inspection):
		route.append(GameConfig.INSPECTION)
	route.append(keys[1])
	route.append(GameConfig.COUNTER)
	return route


static var _required_cache: Dictionary = {}


static func required_stations(dept_id: String) -> Array[String]:
	if _required_cache.has(dept_id):
		return _required_cache[dept_id]
	var keys: Array[String] = []
	var probe := CaseFile.new(dept_id)
	for key in build(probe):
		if not keys.has(key):
			keys.append(key)
	if GameConfig.is_customs(dept_id):
		keys.append(GameConfig.INSPECTION)
	_required_cache[dept_id] = keys
	return keys
