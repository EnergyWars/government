class_name GameConfig
extends RefCounted

const TICK := 1.0 / 30.0
const MAX_STEPS_PER_FRAME := 300
const START_MONEY := 120.0
const MAX_STATION_LEVEL := 50
const MAX_SPECIALISTS := 3
const MAX_SUPERVISORS := 2
const MAX_RUNNERS := 12
const LEVEL_SPEED_BONUS := 0.12
const LEVEL_MILESTONE_STEP := 10
const LEVEL_MILESTONE_BONUS := 1.5
const UPGRADE_RUSH_SECONDS := 45.0
const UPGRADE_RUSH_SPEED := 1.5
const SWAMPED_SHARE := 0.75
const SWAMPED_DROWSY_FACTOR := 1.5
const SWAMPED_SICK_SHARE := 0.6
const HANDS_ON_CASES := 5
const HANDS_ON_REWARD_FACTOR := 10.0
const HANDS_ON_REPUTATION := 1.0
const MULTI_BASE_CHANCE := 0.12
const MULTI_PER_DEPT := 0.06
const MULTI_MAX_CHANCE := 0.45
const MULTI_SECOND_FACTOR := 0.35
const MULTI_MAX_EXTRAS := 2
const MULTI_TIME_PER_EXTRA := 0.5
const UNATTENDED_REST_ESTIMATE := 45.0
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
const HIRE_GROWTH := 2.0
const UPGRADE_GROWTH := 1.35
const SPECIALIST_FACTOR := 5.0
const SPECIALIST_GROWTH := 2.4
const SUPERVISOR_COST := 1500.0
const SUPERVISOR_GROWTH := 3.0
const RUNNER_GROWTH := 2.2
const HAND_REWARD_BONUS := 1.5
const HELP_BACKLOG := 3
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
const KRANZ_FIRST_SECONDS := 90.0
const KRANZ_MIN_INTERVAL := 110.0
const KRANZ_MAX_INTERVAL := 200.0
const KRANZ_COFFEE_RELIEF := 0.3
const KRANZ_RETRY_SECONDS := 20.0
const KRANZ_SIZE := 4
const KRANZ_MIN_PARTICIPANTS := 2
const KRANZ_END_TIME := 1.2
const KRANZ_MAX_SECONDS := 75.0
const KRANZ_END_REPUTATION := 0.2
const KITCHEN_SLOTS := 12
const KITCHEN_TABLE_SLOT := 6
const SICK_FIRST_SECONDS := 180.0
const SICK_MIN_PER_OFFICIAL := 1200.0
const SICK_MAX_PER_OFFICIAL := 2400.0
const SICK_MIN_STAFF := 3
const SICK_SECONDS := 150.0
const SICK_HR_RELIEF := 0.5
const SICK_BONUS_MINUTES: Array[float] = [0.0, 0.3, 0.6, 1.0]
const SICK_BONUS_SPEED: Array[float] = [1.0, 2.0, 4.0, 10.0]
const SICK_BONUS_MIN_INCOME := 50.0
const CALL_TIME := 1.5
const MAX_HR := 4
const HR_COST := 900.0
const HR_GROWTH := 2.2
const HR_CALL_SECONDS := 12.0
const HR_ANSWER_SECONDS := 4.0
const SICK_RING_SECONDS := 30.0
const SICK_TALK_CHANCE := 0.3
const COMPLAINT_INTERVAL := 120.0
const COMPLAINT_STAFF_RELIEF := 0.3
const COMPLAINT_MIN_CASES := 10
const COMPLAINT_BOX_CAPACITY := 20
const COMPLAINT_BOX_PER_LEVEL := 10
const COMPLAINT_BOX_MAX_LEVEL := 4
const COMPLAINT_BOX_COST := 900.0
const COMPLAINT_BOX_GROWTH := 3.0
const COMPLAINT_PILE_DRAWN := 20
const COMPLAINT_CLERK_FEND_CHANCES: Array[float] = [0.15, 0.3, 0.42, 0.52, 0.6, 0.67]
const COMPLAINT_CLERK_MAX_LEVEL := 5
const COMPLAINT_CLERK_COST := 500.0
const COMPLAINT_CLERK_GROWTH := 3.0
const COMPLAINT_TUBE_DELAYS: Array[float] = [-1.0, 60.0, 35.0, 20.0]
const REVIEW_LIFETIME := 7200.0
const MAX_NEGATIVE_REVIEWS := 5
const MAX_STORED_REVIEWS := 80
const REVIEW_NEGATIVE_MAX_STARS := 2
const REVIEW_ONE_STAR_SHARE := 0.7
const REVIEW_PRAISE_CHANCE := 0.18
const REVIEW_FLAWED_CHANCE := 0.3
const REVIEW_FEAR_SECONDS := 420.0
const REVIEW_FEAR_FACTOR := 0.1
const REVIEW_DELETE_REPUTATION := 0.15
const REVIEW_AUTHORS := 12
const REVIEW_FORCED_TEXTS := 6
const REVIEW_DRAIN := 0.0006
const REVIEW_DELETE_BASE := 40.0
const REVIEW_DELETE_INCOME_SECONDS := 25.0
const REVIEW_DELETE_STAR_FACTORS: Array[float] = [3.0, 1.5, 0.6, 0.2, 0.0]
const REVIEW_LAWSUIT_FACTOR := 1.2
const REVIEW_LAWSUIT_GROWTH := 1.6
const REVIEW_LAWSUIT_CHANCE := 0.4
const REVIEW_LAWSUIT_CHANCE_STEP := 0.08
const REVIEW_LAWSUIT_MAX_CHANCE := 0.65
const MAX_REVIEW_LAWSUITS := 20
const REVIEW_LAWSUIT_PAYOUT_FACTOR := 2.5
const REVIEW_LAWSUIT_REPUTATION := 0.5
const REVIEW_LAWSUIT_LOSS := 0.2
const REVIEW_TEXTS: Array[int] = [40, 35, 30, 25, 30]
const REVIEW_PAGE_SIZE := 20
const COMPLAINT_TEXTS := 50
const COMPLAINT_TEXT_STEP := 17
const COMPLAINT_READ_MAX := 6
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
const OFFLINE_EFFICIENCY := 0.7
const OFFLINE_MIN_SECONDS := 60.0

const PLAYER_SPEED := 420.0
const PLAYER_BASE_CAPACITY := 6
const PLAYER_CAPACITY_PER_LEVEL := 2
const PLAYER_WORK_POWER := 2.5
const PLAYER_WORK_PER_LEVEL := 0.5
const TRANSFER_INTERVAL := 0.08
const INTERACT_RADIUS := 64.0
const PAD_TIME := 1.2
const RUNNER_SPEED := 190.0
const RUNNER_BASE_CAPACITY := 2
const RUNNER_CAPACITY_PER_LEVEL := 1
const RUNNER_TRIP_ESTIMATE := 7.0
const RUNNER_COST := 400.0
const MAX_RUNNER_LEVEL := 4
const RUNNER_LEVEL_CAPACITY := 1
const RUNNER_LEVEL_COST := 900.0
const RUNNER_LEVEL_GROWTH := 3.5

const REP_CORRECT := 0.1
const REP_FLAWED := -0.5
const REP_URGENT_ON_TIME := 0.3
const REP_URGENT_LATE := -0.3
const REP_CONTRABAND := 0.3
const REP_SMUGGLED := -1.0
const REP_CITIZEN_LEFT := -0.3
const REP_LOSS_FACTOR := 0.05
const REP_MAX_LOSS_PER_MINUTE := 0.05
const RATING_ARRIVAL_MIN := 0.85
const RATING_ARRIVAL_MAX := 1.25

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
const TUBE_SPEED := 520.0
const TUBE_BASE_CAPACITY := 2
const TUBE_CAPACITY_PER_LEVEL := 2
const MAX_TUBE_PARCELS := 400
const TUBE_CONNECTION_FACTOR := 0.5
const TUBE_CONNECTION_MIN_COST := 20000.0
const MAX_COLLECTORS := 5
const COLLECTOR_COST := 600.0
const COLLECTOR_GROWTH := 2.0
const COLLECTOR_CAPACITY := 3
const COLLECTOR_SPEED := 170.0
const COLLECTOR_TRIP_ESTIMATE := 12.0
const COLLECTOR_CAPACITY_PER_LEVEL := 1
const COLLECTOR_URGENT_MARGIN := 1
const COLLECTOR_MAX_DETOUR := 420.0
const COLLECTOR_DISTANCE_BIAS := 100.0
const SHRED_CASE_PENALTY := 1.0
const WAITING_MAX_LEVEL := 8
const MAX_LOBBY_SLOTS := 64
const WAITING_SEATS_PER_LEVEL := 3
const WAITING_COST := 400.0
const WAITING_GROWTH := 1.9
const SEATING_BASE_SEATS := 24
const SEATING_MAX_LEVEL := 12
const SEATING_SEATS_PER_LEVEL := 3
const SEATING_COST := 500.0
const SEATING_GROWTH := 1.6
const REP_WALKED_OUT := -0.3
const VISITOR_SPEED := 120.0
const VISITOR_SLOTS := 3
const VISITOR_TALK_SECONDS := 7.5
const VISITOR_ANGRY_TALK_SECONDS := 6.0
const VISITOR_DIALOGS := 30
const YELL_DIALOGS := 10
const VISITOR_LINES := 3
const YELL_COMPLAINTS := 8
const YELL_INTERVAL := 14.0
const MAX_GUARDS := 2
const GUARD_COST := 1100.0
const GUARD_GROWTH := 2.4
const GUARD_BLOCK_CHANCE := 0.35
const GUARD_STOP_SECONDS := 4.0
const GUARD_DIALOGS := 5
const GUARD_LINES := 2
const INTERN_STRESS_FREE := 3
const INTERN_STRESS_RATE := 0.004
const INTERN_CALM_RATE := 0.012
const INTERN_YELL_RATE := 0.06
const INTERN_SPEED := 150.0
const INTERN_TRIP_ESTIMATE := 8.0
const INTERN_CRY_SECONDS := 20.0
const INTERN_TRAINING_CRY_FACTOR := 0.7
const MAX_HELPERS := 2
const HELPER_COST := 1300.0
const HELPER_GROWTH := 2.5
const INTERN_RECOVERED_STRESS := 0.25
const INTERN_COMFORT_TIME := 2.0
const INTERN_COMFORT_STRESS := 0.35
const MAX_COFFEE_INTERNS := 4
const COFFEE_INTERN_COST := 700.0
const COFFEE_INTERN_GROWTH := 2.0
const COFFEE_INTERN_SPEED := 180.0
const COFFEE_BREW_SECONDS := 1.5
const COFFEE_SERVE_THRESHOLD := 0.6
const COFFEE_SERVE_BONUS := 1.25
const MAX_DISPUTES := 2
const DISPUTE_MIN_CASES := 15
const DISPUTE_MIN_STAFF := 2
const DISPUTE_FIRST_SECONDS := 150.0
const DISPUTE_MIN_INTERVAL := 90.0
const DISPUTE_MAX_INTERVAL := 200.0
const DISPUTE_SUPERVISOR_RELIEF := 0.3
const DISPUTE_MAX_SECONDS := 240.0
const DISPUTE_RETRY_SECONDS := 30.0
const MEDIATE_TIME := 2.5
const MEDIATE_REPUTATION := 0.2
const MEDIATION_DELAYS: Array[float] = [-1.0, 120.0, 60.0, 25.0]
const DISPUTES := {
	"window": {"speed": 0.85, "climate": 1},
	"thermostat": {"speed": 0.8, "climate": 2},
	"radio": {"speed": 0.9, "climate": 0},
	"yoghurt": {"speed": 0.9, "climate": 0},
	"stapler": {"speed": 0.85, "climate": 0},
	"fish_roll": {"speed": 0.8, "climate": 0},
}
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
const MAILROOM := "shared/mailroom"

const MAIL_UNLOCK_STAGE := 1
const MAIL_FIRST_SECONDS := 30.0
const MAIL_INTERVAL := 45.0
const MAIL_BATCH_BASE := 3
const MAIL_BATCH_PER_DEPT := 1
const MAIL_SUBSCRIPTION_BATCH := 2
const MAIL_REWARD_FACTOR := 0.5
const MAIL_REWARD_PER_LEVEL := 0.1
const MAIL_STORAGE_BASE := 12
const MAIL_STORAGE_PER_LEVEL := 8
const MAIL_STORAGE_MAX_LEVEL := 10
const MAIL_STORAGE_COST := 600.0
const MAIL_STORAGE_GROWTH := 1.7
const MAIL_CITIZEN_PRIORITY := 4
const MAIL_TARGET_SHARE := 0.5
const MISSING_FORM_CHANCE := 0.05
const MISSING_FORM_MIN_CASES := 20

const START_SEALS := 5
const GOAL_SEALS := 1
const SEAL_PACKS: Array[int] = [10, 30, 80]
const AD_SECONDS := 3.0
const AD_REWARD_FACTOR := 2.0
const AD_SICK_COOLDOWN := 120.0
const BOOST_OVERTIME_SPEED := 2.0
const BOOST_STAMP_SPEED := 3.0
const BOOST_POST_SPEED := 4.0
const BOOST_FEE_FACTOR := 2.0
const BOOST_ARRIVAL_FACTOR := 2.0
const BOOST_RUNNER_SPEED := 2.0
const BOOST_PLAYER_SPEED := 1.5
const BOOST_BUDGET_MINUTES := 5.0
const BOOST_MIN_INCOME := 60.0
const BOOSTS := {
	"overtime": {"duration": 60.0, "seals": 3, "cooldown": 300.0},
	"temp_workers": {"duration": 180.0, "seals": 4, "cooldown": 420.0},
	"stamp_turbo": {"duration": 90.0, "seals": 2, "cooldown": 240.0},
	"express_post": {"duration": 120.0, "seals": 2, "cooldown": 240.0, "requires_mail": true},
	"coffee_round": {"duration": 180.0, "seals": 2, "cooldown": 300.0},
	"doctor_visit": {"duration": 0.0, "seals": 2, "cooldown": 300.0},
	"works_outing": {"duration": 300.0, "seals": 3, "cooldown": 480.0},
	"mayor_speech": {"duration": 180.0, "seals": 2, "cooldown": 300.0},
	"roller_skates": {"duration": 180.0, "seals": 2, "cooldown": 300.0},
	"complaint_amnesty": {"duration": 300.0, "seals": 2, "cooldown": 360.0},
	"weekend_shift": {"duration": 0.0, "seals": 3, "cooldown": 420.0},
	"gazette_ad": {"duration": 120.0, "seals": 3, "cooldown": 360.0},
	"fee_increase": {"duration": 120.0, "seals": 4, "cooldown": 480.0},
	"budget_injection": {"duration": 0.0, "seals": 5, "cooldown": 600.0},
}
const BOOST_ORDER: Array[String] = ["overtime", "temp_workers", "stamp_turbo", "express_post", "coffee_round", "doctor_visit", "works_outing", "mayor_speech", "roller_skates", "complaint_amnesty", "weekend_shift", "gazette_ad", "fee_increase", "budget_injection"]

const THOROUGHNESS := [
	{"id": "fast", "time": 0.6, "error": 0.2},
	{"id": "normal", "time": 1.0, "error": 0.12},
	{"id": "thorough", "time": 1.4, "error": 0.02},
]

const STATION_KINDS := {
	"reception": {"base_time": 2.0, "desk_cost": 70.0, "hire_cost": 150.0, "upgrade_cost": 60.0, "machine": false},
	"review": {"base_time": 5.0, "desk_cost": 120.0, "hire_cost": 240.0, "upgrade_cost": 90.0, "machine": false},
	"signature": {"base_time": 4.0, "desk_cost": 140.0, "hire_cost": 270.0, "upgrade_cost": 100.0, "machine": true},
	"inspection": {"base_time": 7.0, "desk_cost": 160.0, "hire_cost": 330.0, "upgrade_cost": 120.0, "machine": false},
	"counter": {"base_time": 2.5, "desk_cost": 80.0, "hire_cost": 180.0, "upgrade_cost": 70.0, "machine": false},
	"dock": {"base_time": 2.0, "desk_cost": 150.0, "hire_cost": 300.0, "upgrade_cost": 110.0, "machine": false},
	"clearance": {"base_time": 3.0, "desk_cost": 150.0, "hire_cost": 300.0, "upgrade_cost": 110.0, "machine": false},
	"mailroom": {"base_time": 2.0, "desk_cost": 90.0, "hire_cost": 160.0, "upgrade_cost": 70.0, "machine": false},
}

const SHARED_STATIONS := {
	RECEPTION: {"kind": "reception", "cost_multiplier": 1.0},
	COUNTER: {"kind": "counter", "cost_multiplier": 1.0},
	INSPECTION: {"kind": "inspection", "cost_multiplier": 10.0},
	MAILROOM: {"kind": "mailroom", "cost_multiplier": 1.0},
}

const DEPARTMENTS := [
	{"id": "general_services", "kinds": ["review", "signature"], "review_time": 5.0, "signature_time": 4.0, "signature_machine": true, "reward": 20.0, "arrival_interval": 7.0, "complex_chance": 0.1, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 0.0, "unlock_reputation": 0.0, "cost_multiplier": 1.0, "staff_multiplier": 1.0, "inspection": false, "referral": "", "follow_up": false},
	{"id": "tax_services", "kinds": ["review", "signature"], "review_time": 6.0, "signature_time": 4.0, "signature_machine": true, "reward": 50.0, "arrival_interval": 9.0, "complex_chance": 0.2, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 800.0, "unlock_reputation": 15.0, "cost_multiplier": 3.0, "staff_multiplier": 4.0, "inspection": false, "referral": "", "follow_up": false},
	{"id": "business_licences", "kinds": ["review", "signature"], "review_time": 6.0, "signature_time": 3.5, "signature_machine": true, "reward": 130.0, "arrival_interval": 11.0, "complex_chance": 0.2, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 8000.0, "unlock_reputation": 60.0, "cost_multiplier": 9.0, "staff_multiplier": 30.0, "inspection": true, "referral": "", "follow_up": false},
	{"id": "vehicle_registration", "kinds": ["review", "signature"], "review_time": 6.5, "signature_time": 5.0, "signature_machine": true, "reward": 350.0, "arrival_interval": 12.0, "complex_chance": 0.15, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 60000.0, "unlock_reputation": 150.0, "cost_multiplier": 27.0, "staff_multiplier": 200.0, "inspection": false, "referral": "", "follow_up": false},
	{"id": "building_permits", "kinds": ["review", "signature"], "review_time": 8.0, "signature_time": 6.0, "signature_machine": false, "reward": 900.0, "arrival_interval": 15.0, "complex_chance": 0.35, "urgent_chance": 0.04, "suspicious_chance": 0.0, "unlock_cost": 400000.0, "unlock_reputation": 300.0, "cost_multiplier": 80.0, "staff_multiplier": 1200.0, "inspection": true, "referral": "", "follow_up": false},
	{"id": "housing", "kinds": ["review", "signature"], "review_time": 7.0, "signature_time": 4.0, "signature_machine": true, "reward": 2000.0, "arrival_interval": 13.0, "complex_chance": 0.3, "urgent_chance": 0.15, "suspicious_chance": 0.0, "unlock_cost": 2000000.0, "unlock_reputation": 500.0, "cost_multiplier": 220.0, "staff_multiplier": 6000.0, "inspection": false, "referral": "general_services/review", "follow_up": false},
	{"id": "social_benefits", "kinds": ["review", "signature"], "review_time": 7.0, "signature_time": 5.0, "signature_machine": false, "reward": 5000.0, "arrival_interval": 14.0, "complex_chance": 0.2, "urgent_chance": 0.35, "suspicious_chance": 0.0, "unlock_cost": 12000000.0, "unlock_reputation": 800.0, "cost_multiplier": 650.0, "staff_multiplier": 35000.0, "inspection": false, "referral": "", "follow_up": true},
	{"id": "customs", "kinds": ["dock", "review", "signature", "clearance"], "review_time": 6.0, "signature_time": 5.0, "signature_machine": true, "reward": 14000.0, "arrival_interval": 12.0, "complex_chance": 0.2, "urgent_chance": 0.1, "suspicious_chance": 0.25, "unlock_cost": 80000000.0, "unlock_reputation": 1300.0, "cost_multiplier": 1900.0, "staff_multiplier": 230000.0, "inspection": false, "referral": "", "follow_up": false},
]

const CUSTOMS_VARIANTS: Array[String] = ["general_cargo", "electronics", "vehicles"]
const CUSTOMS_VARIANT_SUSPICION := {"general_cargo": 0.8, "electronics": 1.6, "vehicles": 0.8}

const BUILDING_STAGES := [
	{"id": "service_counter", "cost": 0.0, "reputation": 0.0, "max_departments": 1, "max_desks": 2, "lobby": 16},
	{"id": "multi_service_office", "cost": 2500.0, "reputation": 10.0, "max_departments": 3, "max_desks": 3, "lobby": 22},
	{"id": "regional_administration", "cost": 50000.0, "reputation": 100.0, "max_departments": 5, "max_desks": 4, "lobby": 28},
	{"id": "public_services_centre", "cost": 1500000.0, "reputation": 400.0, "max_departments": 7, "max_desks": 5, "lobby": 34},
	{"id": "citywide_administration", "cost": 40000000.0, "reputation": 1000.0, "max_departments": 8, "max_desks": 6, "lobby": 40},
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
	"climate_control": {"max_level": 2, "cost": 900.0, "growth": 4.0, "reputation": 12.0},
	"mediation": {"max_level": 3, "cost": 1500.0, "growth": 4.0, "reputation": 18.0},
	"coffee_machine": {"max_level": 4, "cost": 700.0, "growth": 3.5, "reputation": 8.0},
	"kitchen": {"max_level": 3, "cost": 1200.0, "growth": 5.0, "reputation": 15.0},
	"wake_service": {"max_level": 5, "cost": 1500.0, "growth": 4.0, "reputation": 20.0},
	"it_support": {"max_level": 3, "cost": 2000.0, "growth": 4.0, "reputation": 20.0},
	"digital_signatures": {"max_level": 2, "cost": 25000.0, "growth": 6.0, "reputation": 80.0},
	"pneumatic_tubes": {"max_level": 1, "cost": 250000.0, "growth": 1.0, "reputation": 250.0},
	"complaint_tube": {"max_level": 3, "cost": 6000.0, "growth": 4.0, "reputation": 50.0, "requires": "shredder_service"},
	"intern_training": {"max_level": 3, "cost": 3000.0, "growth": 4.0, "reputation": 40.0, "requires": "shredder_service"},
	"tube_capacity": {"max_level": 3, "cost": 120000.0, "growth": 3.0, "reputation": 300.0, "requires": "pneumatic_tubes"},
	"online_portal": {"max_level": 2, "cost": 1000000.0, "growth": 8.0, "reputation": 500.0},
	"ai_classification": {"max_level": 1, "cost": 20000000.0, "growth": 1.0, "reputation": 1000.0},
	"letter_opener": {"max_level": 3, "cost": 900.0, "growth": 4.0, "reputation": 10.0},
	"mail_subscription": {"max_level": 3, "cost": 1500.0, "growth": 4.0, "reputation": 15.0},
	"registered_mail": {"max_level": 3, "cost": 2500.0, "growth": 4.0, "reputation": 25.0},
}

const RESEARCH_ORDER: Array[String] = ["briefcase", "work_ethic", "coffee", "coffee_machine", "kitchen", "it_support", "scanners", "comfortable_lobby", "trolleys", "digital_records", "quality_training", "shredder_service", "complaint_tube", "intern_training", "wake_service", "climate_control", "mediation", "digital_signatures", "pneumatic_tubes", "tube_capacity", "online_portal", "ai_classification", "letter_opener", "mail_subscription", "registered_mail"]

const ROOM_OFFICE := "office"
const ROOM_INSPECTION := "inspection"
const ROOM_KITCHEN := "kitchen"
const ROOM_TOILETS := "toilets"
const ROOM_PHONE := "phone"
const ROOM_HALL := "hall"
const ROOM_MAIL := "mail"
const ROOMS := [
	{"id": ROOM_OFFICE, "staff": ["runners", "collectors"], "research": ["briefcase", "work_ethic", "scanners", "digital_records", "quality_training", "digital_signatures", "ai_classification", "climate_control", "mediation", "it_support", "trolleys", "pneumatic_tubes", "tube_capacity"], "boosts": ["overtime", "temp_workers", "stamp_turbo", "roller_skates", "weekend_shift"]},
	{"id": ROOM_INSPECTION, "stations": [INSPECTION]},
	{"id": ROOM_KITCHEN, "staff": ["coffee_interns"], "research": ["coffee", "coffee_machine", "kitchen"], "boosts": ["coffee_round", "works_outing"]},
	{"id": ROOM_TOILETS, "research": ["wake_service"]},
	{"id": ROOM_PHONE, "staff": ["hr"], "boosts": ["doctor_visit"]},
	{"id": ROOM_MAIL, "stations": [MAILROOM], "areas": ["mail_storage"], "research": ["letter_opener", "mail_subscription", "registered_mail"], "boosts": ["express_post"]},
	{"id": ROOM_HALL, "staff": ["guards", "helpers"], "stations": [RECEPTION, COUNTER], "areas": ["waiting", "seating", "complaint_clerk", "complaint_box"], "research": ["comfortable_lobby", "shredder_service", "complaint_tube", "intern_training", "online_portal"], "boosts": ["mayor_speech", "complaint_amnesty", "gazette_ad", "fee_increase"]},
]

const OFFICIAL_TRAININGS := {
	"skill": {"cost": 1.5, "growth": 2.5, "effect": 0.15},
	"health": {"cost": 1.2, "growth": 2.5, "effect": 0.2},
	"stamina": {"cost": 1.0, "growth": 2.5, "effect": 0.8},
	"calm": {"cost": 1.0, "growth": 2.5, "effect": 0.2},
}
const OFFICIAL_TRAINING_ORDER: Array[String] = ["skill", "health", "stamina", "calm"]
const MAX_OFFICIAL_TRAINING := 3

const RESEARCH_SPEED := {
	"reception": {"research": "scanners", "bonus": 0.3},
	"dock": {"research": "scanners", "bonus": 0.3},
	"review": {"research": "digital_records", "bonus": 0.2},
	"signature": {"research": "digital_records", "bonus": 0.2},
	"counter": {"research": "digital_signatures", "bonus": 0.4},
	"clearance": {"research": "digital_signatures", "bonus": 0.4},
	"mailroom": {"research": "letter_opener", "bonus": 0.4},
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
	"mayor_visit": {"arrival": 1.5, "department": "", "min_cases": 30, "fee": 2.0},
	"newspaper_praise": {"arrival": 2.0, "department": "", "min_cases": 60, "fee": 1.2},
}
const AUDIT_FACTOR := 2.0

const GOALS := [
	{"type": "cases", "target": 3.0, "param": "", "money": 60.0, "reputation": 1.0},
	{"type": "station_level", "target": 2.0, "param": "", "money": 120.0, "reputation": 1.0},
	{"type": "cases", "target": 25.0, "param": "", "money": 300.0, "reputation": 2.0},
	{"type": "staff_hired", "target": 1.0, "param": "", "money": 250.0, "reputation": 1.0},
	{"type": "building_stage", "target": 1.0, "param": "", "money": 400.0, "reputation": 2.0},
	{"type": "runners", "target": 1.0, "param": "", "money": 500.0, "reputation": 1.0},
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


static func room(room_id: String) -> Dictionary:
	for entry: Dictionary in ROOMS:
		if entry.id == room_id:
			return entry
	return {}


static func room_items(room_id: String, kind: String) -> Array[String]:
	var items: Array[String] = []
	for item: String in room(room_id).get(kind, []):
		items.append(item)
	return items


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


static func review_texts(stars: int) -> int:
	return REVIEW_TEXTS[clampi(stars, 1, REVIEW_TEXTS.size()) - 1]


static func sick_bonus_tiers() -> int:
	return SICK_BONUS_MINUTES.size() - 1


static func needs_onboarding(dept_id: String) -> bool:
	return not department(dept_id).is_empty() and dept_id != department_ids()[0]


static func boost(boost_id: String) -> Dictionary:
	return BOOSTS.get(boost_id, {})
