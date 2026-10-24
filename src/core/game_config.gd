class_name GameConfig
extends RefCounted

const TICK := 1.0 / 30.0
const MAX_STEPS_PER_FRAME := 300
const START_MONEY := 120.0
const MAX_STATION_LEVEL := 50
const MAX_SPECIALISTS := 3
const MAX_SUPERVISORS := 2
const MAX_RUNNERS := 12
const LEVEL_SPEED_BONUS := 0.15
const SUPERVISOR_BONUS := 0.2
const COMPLEX_TIME_PENALTY := 1.0
const SPECIALIST_ERROR_FACTOR := 0.3
const COMPLEX_REWARD_FACTOR := 2.0
const URGENT_REWARD_FACTOR := 1.5
const URGENT_DEADLINE := 120.0
const FOLLOW_UP_REWARD_FACTOR := 0.6
const FOLLOW_UP_DELAY_MIN := 150.0
const FOLLOW_UP_DELAY_MAX := 300.0
const CONTRABAND_CHANCE := 0.5
const FLAG_BASE_CHANCE := 0.6
const FLAG_PER_SPECIALIST := 0.12
const CONTRABAND_REWARD_FACTOR := 3.0
const FLAWED_REWARD_FACTOR := 0.4
const REPUTATION_REWARD_DIVISOR := 20.0
const POPULARITY_DIVISOR := 8.0
const MAX_POPULARITY := 8.0
const BASE_PATIENCE := 90.0
const PATIENCE_PER_LOBBY_LEVEL := 0.4
const INBOX_BASE := 6
const INBOX_PER_DESK := 2
const OUTBOX_BASE := 6
const OUTBOX_PER_DESK := 2
const DESK_GROWTH := 2.2
const HIRE_GROWTH := 1.8
const UPGRADE_GROWTH := 1.45
const SPECIALIST_GROWTH := 2.4
const SUPERVISOR_GROWTH := 3.0
const RUNNER_GROWTH := 1.9
const BASE_ALERT_SECONDS := 100.0
const MAX_ALERT_SECONDS := 2000.0
const ALERT_VARIANCE := 0.3
const COFFEE_ALERT_BONUS := 0.35
const DOZE_WEIGHTS := {"asleep": 0.12, "coffee": 0.08, "chat": 0.26, "fetch": 0.28, "slow": 0.13, "loo": 0.13}
const LOO_SLOTS := 4
const LOO_SECONDS := 150.0
const ENCOURAGE_TIME := 2.0
const KITCHEN_CHAT_SHIFT := 0.07
const COFFEE_MACHINE_FETCH_FACTOR := 0.8
const COFFEE_MACHINE_ALERT_BONUS := 0.25
const SLOW_SECONDS := 70.0
const DRIVE_FACTOR := 9.0
const KRANZ_FIRST_SECONDS := 120.0
const KRANZ_MIN_INTERVAL := 150.0
const KRANZ_MAX_INTERVAL := 240.0
const KRANZ_RETRY_SECONDS := 20.0
const KRANZ_SIZE := 4
const KRANZ_MIN_PARTICIPANTS := 2
const KRANZ_END_TIME := 1.2
const KITCHEN_SLOTS := 12
const KITCHEN_TABLE_SLOT := 6
const SICK_FIRST_SECONDS := 150.0
const SICK_MIN_INTERVAL := 70.0
const SICK_MAX_INTERVAL := 150.0
const SICK_MIN_STAFF := 3
const SICK_SECONDS := 240.0
const CALL_TIME := 1.5
const CALL_VISIBLE_SECONDS := 4.0
const MAX_HR := 4
const HR_COST := 400.0
const HR_GROWTH := 2.2
const HR_CALL_SECONDS := 12.0
const COMPLAINT_DRAIN := 0.002
const COMPLAINT_INTERVAL := 45.0
const COMPLAINT_MIN_CASES := 5
const COMPLAINT_CAP := 8
const COMPLAINT_OVERFLOW_PENALTY := 0.5
const COMPLAINT_REWARD := 4.0
const COMPLAINT_REPUTATION := 0.05
const COMPLAINT_TRANSFER_INTERVAL := 0.25
const SHREDDER_DELAYS: Array[float] = [-1.0, 40.0, 20.0, 8.0]
const FETCH_SECONDS := 14.0
const FETCH_ALERT_FACTOR := 1.5
const COFFEE_BREAK_SECONDS := 60.0
const WAKE_TIME := 0.7
const WAKE_CHECK_INTERVAL := 0.1
const SUPERVISOR_DROWSY_FACTOR := 0.7
const WAKE_SERVICE_DELAYS: Array[float] = [-1.0, 45.0, 28.0, 16.0, 8.0, 3.0]
const OFFLINE_CAP_SECONDS := 4.0 * 3600.0
const OFFLINE_EFFICIENCY := 0.5
const OFFLINE_MIN_SECONDS := 60.0

const PLAYER_SPEED := 300.0
const PLAYER_BASE_CAPACITY := 4
const PLAYER_CAPACITY_PER_LEVEL := 2
const PLAYER_WORK_POWER := 1.0
const PLAYER_WORK_PER_LEVEL := 0.5
const TRANSFER_INTERVAL := 0.12
const INTERACT_RADIUS := 64.0
const PAD_TIME := 1.2
const RUNNER_SPEED := 190.0
const RUNNER_BASE_CAPACITY := 2
const RUNNER_CAPACITY_PER_LEVEL := 1
const RUNNER_TRIP_ESTIMATE := 7.0
const RUNNER_COST := 90.0

const REP_CORRECT := 0.1
const REP_FLAWED := -0.5
const REP_URGENT_ON_TIME := 0.3
const REP_URGENT_LATE := -0.3
const REP_CONTRABAND := 0.3
const REP_SMUGGLED := -1.0
const REP_CITIZEN_LEFT := -0.3
const REP_TURNED_AWAY := -0.15

const EVENT_FIRST_COOLDOWN := 240.0
const EVENT_MIN_COOLDOWN := 180.0
const EVENT_MAX_COOLDOWN := 360.0
const EVENT_DURATION := 45.0
const EVENT_MITIGATION := 0.15
const EVENT_MIN_DURATION_FACTOR := 0.4
const EVENT_CHOICE_SECONDS := 30.0
const EVENT_PREPARE_SECONDS := 30.0
const EVENT_PREPARE_REPUTATION := 3.0
const EVENT_CANCEL_PENALTY := 1.5
const BACKLOG_CASES := 6
const BIG_CASE_REWARD_FACTOR := 5.0
const BIG_CASE_TIME_FACTOR := 3.0
const REJECT_CHANCE := 0.1
const REJECT_MIN_CASES := 10
const REJECT_CAPACITY := 6
const REJECT_FEE_FACTOR := 0.15
const REJECT_SHRED_REWARD := 2.0
const POPULATION_BASE := 1000
const POPULATION_PER_CASE := 12
const POPULATION_PER_LOST := 20
const DEMAND_GROWTH_SCALE := 0.5
const DEMAND_GROWTH_DIVISOR := 200.0
const SETTLEMENT_RANKS: Array[Dictionary] = [
	{"id": "village", "population": 0},
	{"id": "small_town", "population": 5000},
	{"id": "town", "population": 25000},
	{"id": "city", "population": 120000},
	{"id": "metropolis", "population": 600000},
]

const RECEPTION := "shared/reception"
const COUNTER := "shared/counter"
const INSPECTION := "shared/inspection"

const THOROUGHNESS := [
	{"id": "fast", "time": 0.7, "error": 0.3},
	{"id": "normal", "time": 1.0, "error": 0.12},
	{"id": "thorough", "time": 1.5, "error": 0.03},
]

const STATION_KINDS := {
	"reception": {"base_time": 2.0, "desk_cost": 70.0, "hire_cost": 50.0, "upgrade_cost": 60.0, "machine": false},
	"review": {"base_time": 5.0, "desk_cost": 120.0, "hire_cost": 80.0, "upgrade_cost": 90.0, "machine": false},
	"signature": {"base_time": 4.0, "desk_cost": 140.0, "hire_cost": 90.0, "upgrade_cost": 100.0, "machine": true},
	"inspection": {"base_time": 7.0, "desk_cost": 160.0, "hire_cost": 110.0, "upgrade_cost": 120.0, "machine": false},
	"counter": {"base_time": 2.5, "desk_cost": 80.0, "hire_cost": 60.0, "upgrade_cost": 70.0, "machine": false},
	"dock": {"base_time": 2.0, "desk_cost": 150.0, "hire_cost": 100.0, "upgrade_cost": 110.0, "machine": false},
	"clearance": {"base_time": 3.0, "desk_cost": 150.0, "hire_cost": 100.0, "upgrade_cost": 110.0, "machine": false},
}

const SHARED_STATIONS := {
	RECEPTION: {"kind": "reception", "cost_multiplier": 1.0},
	COUNTER: {"kind": "counter", "cost_multiplier": 1.0},
	INSPECTION: {"kind": "inspection", "cost_multiplier": 10.0},
}

const DEPARTMENTS := [
	{"id": "general_services", "kinds": ["review", "signature"], "review_time": 5.0, "signature_time": 4.0, "signature_machine": true, "reward": 20.0, "arrival_interval": 7.0, "complex_chance": 0.1, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 0.0, "unlock_reputation": 0.0, "cost_multiplier": 1.0, "inspection": false, "referral": "", "follow_up": false},
	{"id": "tax_services", "kinds": ["review", "signature"], "review_time": 6.0, "signature_time": 4.0, "signature_machine": true, "reward": 50.0, "arrival_interval": 9.0, "complex_chance": 0.2, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 800.0, "unlock_reputation": 15.0, "cost_multiplier": 3.0, "inspection": false, "referral": "", "follow_up": false},
	{"id": "business_licences", "kinds": ["review", "signature"], "review_time": 6.0, "signature_time": 3.5, "signature_machine": true, "reward": 130.0, "arrival_interval": 11.0, "complex_chance": 0.2, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 8000.0, "unlock_reputation": 60.0, "cost_multiplier": 9.0, "inspection": true, "referral": "", "follow_up": false},
	{"id": "vehicle_registration", "kinds": ["review", "signature"], "review_time": 6.5, "signature_time": 5.0, "signature_machine": true, "reward": 350.0, "arrival_interval": 12.0, "complex_chance": 0.15, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 60000.0, "unlock_reputation": 150.0, "cost_multiplier": 27.0, "inspection": false, "referral": "", "follow_up": false},
	{"id": "building_permits", "kinds": ["review", "signature"], "review_time": 8.0, "signature_time": 6.0, "signature_machine": false, "reward": 900.0, "arrival_interval": 15.0, "complex_chance": 0.35, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 400000.0, "unlock_reputation": 300.0, "cost_multiplier": 80.0, "inspection": true, "referral": "", "follow_up": false},
	{"id": "housing", "kinds": ["review", "signature"], "review_time": 7.0, "signature_time": 4.0, "signature_machine": true, "reward": 2000.0, "arrival_interval": 13.0, "complex_chance": 0.3, "urgent_chance": 0.15, "suspicious_chance": 0.0, "unlock_cost": 2000000.0, "unlock_reputation": 500.0, "cost_multiplier": 220.0, "inspection": false, "referral": "general_services/review", "follow_up": false},
	{"id": "social_benefits", "kinds": ["review", "signature"], "review_time": 7.0, "signature_time": 5.0, "signature_machine": false, "reward": 5000.0, "arrival_interval": 14.0, "complex_chance": 0.2, "urgent_chance": 0.35, "suspicious_chance": 0.0, "unlock_cost": 12000000.0, "unlock_reputation": 800.0, "cost_multiplier": 650.0, "inspection": false, "referral": "", "follow_up": true},
	{"id": "customs", "kinds": ["dock", "review", "signature", "clearance"], "review_time": 6.0, "signature_time": 5.0, "signature_machine": true, "reward": 14000.0, "arrival_interval": 12.0, "complex_chance": 0.2, "urgent_chance": 0.1, "suspicious_chance": 0.25, "unlock_cost": 80000000.0, "unlock_reputation": 1300.0, "cost_multiplier": 1900.0, "inspection": false, "referral": "", "follow_up": false},
]

const CUSTOMS_VARIANTS: Array[String] = ["general_cargo", "electronics", "vehicles"]
const CUSTOMS_VARIANT_SUSPICION := {"general_cargo": 0.8, "electronics": 1.6, "vehicles": 0.8}

const BUILDING_STAGES := [
	{"id": "service_counter", "cost": 0.0, "reputation": 0.0, "max_departments": 1, "max_desks": 2, "lobby": 8},
	{"id": "multi_service_office", "cost": 2500.0, "reputation": 10.0, "max_departments": 3, "max_desks": 3, "lobby": 14},
	{"id": "regional_administration", "cost": 50000.0, "reputation": 100.0, "max_departments": 5, "max_desks": 4, "lobby": 20},
	{"id": "public_services_centre", "cost": 1500000.0, "reputation": 400.0, "max_departments": 7, "max_desks": 5, "lobby": 28},
	{"id": "citywide_administration", "cost": 40000000.0, "reputation": 1000.0, "max_departments": 8, "max_desks": 6, "lobby": 36},
]

const RESEARCH := {
	"briefcase": {"max_level": 5, "cost": 150.0, "growth": 2.5, "reputation": 0.0},
	"work_ethic": {"max_level": 5, "cost": 200.0, "growth": 2.5, "reputation": 0.0},
	"coffee": {"max_level": 6, "cost": 500.0, "growth": 3.0, "reputation": 5.0},
	"scanners": {"max_level": 3, "cost": 400.0, "growth": 6.0, "reputation": 0.0},
	"comfortable_lobby": {"max_level": 3, "cost": 800.0, "growth": 5.0, "reputation": 10.0},
	"trolleys": {"max_level": 3, "cost": 1200.0, "growth": 6.0, "reputation": 15.0},
	"digital_records": {"max_level": 3, "cost": 1500.0, "growth": 6.0, "reputation": 15.0},
	"quality_training": {"max_level": 3, "cost": 3000.0, "growth": 6.0, "reputation": 25.0},
	"shredder_service": {"max_level": 3, "cost": 800.0, "growth": 5.0, "reputation": 10.0},
	"coffee_machine": {"max_level": 4, "cost": 700.0, "growth": 3.5, "reputation": 8.0},
	"kitchen": {"max_level": 3, "cost": 1200.0, "growth": 5.0, "reputation": 15.0},
	"wake_service": {"max_level": 5, "cost": 1500.0, "growth": 4.0, "reputation": 20.0},
	"it_support": {"max_level": 3, "cost": 2000.0, "growth": 4.0, "reputation": 20.0},
	"digital_signatures": {"max_level": 2, "cost": 25000.0, "growth": 6.0, "reputation": 80.0},
	"pneumatic_tubes": {"max_level": 1, "cost": 250000.0, "growth": 1.0, "reputation": 250.0},
	"online_portal": {"max_level": 2, "cost": 1000000.0, "growth": 8.0, "reputation": 500.0},
	"ai_classification": {"max_level": 1, "cost": 20000000.0, "growth": 1.0, "reputation": 1000.0},
}

const RESEARCH_ORDER: Array[String] = ["briefcase", "work_ethic", "coffee", "coffee_machine", "kitchen", "it_support", "scanners", "comfortable_lobby", "trolleys", "digital_records", "quality_training", "shredder_service", "wake_service", "digital_signatures", "pneumatic_tubes", "online_portal", "ai_classification"]

const RESEARCH_SPEED := {
	"reception": {"research": "scanners", "bonus": 0.3},
	"dock": {"research": "scanners", "bonus": 0.3},
	"review": {"research": "digital_records", "bonus": 0.2},
	"signature": {"research": "digital_records", "bonus": 0.2},
	"counter": {"research": "digital_signatures", "bonus": 0.4},
	"clearance": {"research": "digital_signatures", "bonus": 0.4},
}

const QUALITY_TRAINING_FACTOR := 0.75
const AI_ERROR_FACTOR := 0.5
const AI_COMPLEX_FACTOR := 0.5
const PORTAL_ARRIVAL_BONUS := 0.25

const EVENTS := {
	"rush_hour": {"arrival": 2.0, "department": "", "min_cases": 0},
	"audit_visit": {"arrival": 1.0, "department": "", "min_cases": 50},
	"tax_deadline": {"arrival": 3.0, "department": "tax_services", "min_cases": 0},
	"printer_jam": {"arrival": 1.0, "department": "", "min_cases": 20, "speed": 0.55, "mitigation": "it_support"},
	"system_crash": {"arrival": 1.0, "department": "", "min_cases": 60, "scope": "random", "speed": 0.4, "mitigation": "it_support"},
	"monday_rush": {"arrival": 2.5, "department": "", "min_cases": 40, "patience": 0.6, "mitigation": "comfortable_lobby"},
	"coffee_escalation": {"arrival": 1.0, "department": "", "min_cases": 30, "speed": 1.15, "drowsy": 3.0, "mitigation": "coffee_machine"},
	"paperwork_mountain": {"arrival": 1.0, "department": "", "min_cases": 80, "backlog": true, "mitigation": "digital_records"},
	"staff_meeting": {"arrival": 1.0, "department": "", "min_cases": 50, "speed": 0.45, "choices": ["cancel"]},
	"rubber_ducks": {"arrival": 1.0, "department": "customs", "min_cases": 0, "scope": "customs", "speed": 0.3, "mitigation": "scanners"},
	"fire_drill": {"arrival": 1.0, "department": "", "min_cases": 100, "speed": 0.0, "duration": 20.0, "mitigation": "it_support"},
	"renovation": {"arrival": 0.5, "department": "", "min_cases": 120, "scope": "random", "speed": 0.6},
	"garden_shed": {"arrival": 1.0, "department": "building_permits", "min_cases": 0, "big_case": true, "duration": 90.0},
	"inspector_audit": {"arrival": 1.0, "department": "", "min_cases": 200, "scope": "shared/inspection", "speed": 0.35, "requires_inspection": true},
	"authority_comparison": {"arrival": 1.0, "department": "", "min_cases": 150, "speed": 0.5, "pending": true, "choices": ["prepare", "ignore"]},
}
const AUDIT_FACTOR := 2.0

const GOALS := [
	{"type": "cases", "target": 3.0, "param": "", "money": 60.0, "reputation": 1.0},
	{"type": "staff_hired", "target": 1.0, "param": "", "money": 80.0, "reputation": 1.0},
	{"type": "runners", "target": 1.0, "param": "", "money": 100.0, "reputation": 1.0},
	{"type": "station_level", "target": 2.0, "param": "", "money": 120.0, "reputation": 1.0},
	{"type": "cases", "target": 25.0, "param": "", "money": 300.0, "reputation": 2.0},
	{"type": "building_stage", "target": 1.0, "param": "", "money": 400.0, "reputation": 2.0},
	{"type": "department", "target": 1.0, "param": "tax_services", "money": 600.0, "reputation": 3.0},
	{"type": "research", "target": 1.0, "param": "", "money": 800.0, "reputation": 2.0},
	{"type": "reputation", "target": 40.0, "param": "", "money": 2000.0, "reputation": 0.0},
	{"type": "department", "target": 1.0, "param": "business_licences", "money": 4000.0, "reputation": 5.0},
	{"type": "cases", "target": 300.0, "param": "", "money": 8000.0, "reputation": 5.0},
	{"type": "building_stage", "target": 2.0, "param": "", "money": 20000.0, "reputation": 5.0},
	{"type": "department", "target": 1.0, "param": "vehicle_registration", "money": 40000.0, "reputation": 8.0},
	{"type": "research_level", "target": 1.0, "param": "pneumatic_tubes", "money": 100000.0, "reputation": 8.0},
	{"type": "department", "target": 1.0, "param": "building_permits", "money": 200000.0, "reputation": 10.0},
	{"type": "building_stage", "target": 3.0, "param": "", "money": 600000.0, "reputation": 10.0},
	{"type": "department", "target": 1.0, "param": "housing", "money": 1000000.0, "reputation": 12.0},
	{"type": "department", "target": 1.0, "param": "social_benefits", "money": 5000000.0, "reputation": 15.0},
	{"type": "building_stage", "target": 4.0, "param": "", "money": 15000000.0, "reputation": 20.0},
	{"type": "department", "target": 1.0, "param": "customs", "money": 40000000.0, "reputation": 25.0},
	{"type": "cases", "target": 20000.0, "param": "", "money": 200000000.0, "reputation": 50.0},
]


static func department(dept_id: String) -> Dictionary:
	for entry: Dictionary in DEPARTMENTS:
		if entry.id == dept_id:
			return entry
	return {}


static var _department_ids: Array[String] = []


static func department_ids() -> Array[String]:
	if _department_ids.is_empty():
		for entry: Dictionary in DEPARTMENTS:
			_department_ids.append(entry.id)
	return _department_ids


static func station_kind(kind: String) -> Dictionary:
	return STATION_KINDS.get(kind, {})


static func building_stage(index: int) -> Dictionary:
	return BUILDING_STAGES[clampi(index, 0, BUILDING_STAGES.size() - 1)]


static func department_station_keys(dept_id: String) -> Array[String]:
	var keys: Array[String] = []
	for kind in department(dept_id).get("kinds", []):
		keys.append("%s/%s" % [dept_id, kind])
	return keys


static func is_customs(dept_id: String) -> bool:
	return dept_id == "customs"


static func station_dept(key: String) -> String:
	var owner := key.get_slice("/", 0)
	return "" if owner == "shared" else owner


static func station_kind_of(key: String) -> String:
	if SHARED_STATIONS.has(key):
		return SHARED_STATIONS[key].kind
	return key.get_slice("/", 1)


static func is_machine(key: String) -> bool:
	var kind := station_kind_of(key)
	if kind == "signature":
		return bool(department(station_dept(key)).get("signature_machine", false))
	return bool(station_kind(kind).get("machine", false))
