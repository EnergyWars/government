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
	route.append(GameConfig.MAILROOM if case_file.mail else GameConfig.RECEPTION)
	route.append(keys[0])
	if case_file.follow_up:
		route.append(GameConfig.COUNTER)
		return route
	if not str(config.referral).is_empty():
		route.append(str(config.referral))
	if bool(config.inspection):
		route.append(GameConfig.INSPECTION)
	route.append(keys[1])
	if not case_file.mail:
		route.append(GameConfig.COUNTER)
	return route


static var _base_cache: Dictionary = {}


static func base_route(dept_id: String) -> Array[String]:
	if not _base_cache.has(dept_id):
		_base_cache[dept_id] = build(CaseFile.new(dept_id))
	return _base_cache[dept_id]


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


static var _segment_cache: Dictionary = {}


static func tube_id(from_key: String, to_key: String) -> String:
	return "%s>%s" % [from_key, to_key]


static func segments(dept_id: String) -> Array[String]:
	if _segment_cache.has(dept_id):
		return _segment_cache[dept_id]
	var result: Array[String] = []
	var probes: Array[CaseFile] = [CaseFile.new(dept_id)]
	if not GameConfig.is_customs(dept_id):
		var follow_up := CaseFile.new(dept_id)
		follow_up.follow_up = true
		var letter := CaseFile.new(dept_id)
		letter.mail = true
		probes.append_array([follow_up, letter])
	for probe in probes:
		var route := build(probe)
		for i in route.size() - 1:
			var id := tube_id(route[i], route[i + 1])
			if not result.has(id):
				result.append(id)
	_segment_cache[dept_id] = result
	return result


static func segment_ends(id: String) -> PackedStringArray:
	return id.split(">")


static func segment_department(id: String) -> String:
	for end in segment_ends(id):
		var dept_id := GameConfig.station_dept(end)
		if not dept_id.is_empty():
			return dept_id
	return ""
