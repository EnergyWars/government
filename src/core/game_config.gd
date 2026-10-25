class_name GameConfig
extends RefCounted

const TICK := 1.0 / 30.0
const MAX_STEPS_PER_FRAME := 300
const START_MONEY := 120.0
const MAX_STATION_LEVEL := 100
const MAX_SPECIALISTS := 3
const MAX_SUPERVISORS := 4
const MAX_RUNNERS := 30
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
const MAX_DEPARTMENT_RANK := 10
const RANK_FEE_FACTOR := 2.5
const RANK_COST_GROWTH := 5.0
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
const PATIENCE_MIN_FACTOR := 0.3
const PATIENCE_MAX_FACTOR := 1.7
const PATIENCE_SPREAD_MIN_CASES := 10
const PATIENCE_HASH_SALT := 7919
const INBOX_BASE := 6
const INBOX_PER_DESK := 2
const OUTBOX_BASE := 6
const OUTBOX_PER_DESK := 2
const TUBE_OVERFLOW_SHARE := 0.5
const DESK_GROWTH := 2.2
const HIRE_GROWTH := 2.0
const UPGRADE_GROWTH := 1.35
const SPECIALIST_FACTOR := 5.0
const SPECIALIST_GROWTH := 2.4
const SUPERVISOR_COST := 1500.0
const SUPERVISOR_GROWTH := 3.0
const RUNNER_GROWTH := 1.5
const HAND_REWARD_BONUS := 1.5
const HELP_BACKLOG := 3
const BASE_ALERT_SECONDS := 100.0
const MAX_ALERT_SECONDS := 2000.0
const ALERT_VARIANCE := 0.3
const DOZE_WEIGHTS := {"asleep": 0.12, "coffee": 0.08, "chat": 0.26, "fetch": 0.28, "slow": 0.13, "loo": 0.13}
const LOO_SLOTS := 4
const MAX_LOO_SLOTS := 12
const LOO_SECONDS := 150.0
const ENCOURAGE_TIME := 2.0
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
const COMPLAINT_INTERVAL := 150.0
const COMPLAINT_STAFF_RELIEF := 0.3
const COMPLAINT_MIN_CASES := 10
const LEAVE_COMPLAINT_CHANCE := 0.3
const WALKOUT_COMPLAINT_CHANCE := 0.1
const LEAVE_COMPLAINT_COOLDOWN := 45.0
const COMPLAINT_BOX_CAPACITY := 20
const COMPLAINT_PILE_DRAWN := 20
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
const REVIEW_DELETE_LAWSUIT_GROWTH := 1.5
const REVIEW_LAWSUIT_FACTOR := 3.6
const REVIEW_LAWSUIT_GROWTH := 1.6
const REVIEW_LAWSUIT_CHANCE := 0.5
const REVIEW_LAWSUIT_CHANCE_STEP := 0.08
const REVIEW_LAWSUIT_MAX_CHANCE := 0.7
const MAX_REVIEW_LAWSUITS := 3
const REVIEW_LAWSUIT_REFUND_FACTOR := 1.0
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
const SHREDDER_BATCH := 1
const FETCH_SECONDS := 14.0
const FETCH_ALERT_FACTOR := 1.5
const COFFEE_BREAK_SECONDS := 60.0
const WAKE_TIME := 0.7
const WAKE_CHECK_INTERVAL := 0.1
const SUPERVISOR_DROWSY_FACTOR := 0.7
const OFFLINE_CAP_SECONDS := 4.0 * 3600.0
const OFFLINE_EFFICIENCY := 0.7
const OFFLINE_MIN_SECONDS := 60.0

const PLAYER_SPEED := 420.0
const PLAYER_BASE_CAPACITY := 6
const PLAYER_WORK_POWER := 2.5
const TRANSFER_INTERVAL := 0.08
const INTERACT_RADIUS := 64.0
const PAD_TIME := 1.2
const RUNNER_SPEED := 190.0
const RUNNER_BASE_CAPACITY := 2
const RUNNER_TRIP_ESTIMATE := 7.0
const RUNNER_COST := 400.0
const MAX_RUNNER_LEVEL := 30
const RUNNER_LEVEL_CAPACITY := 1
const RUNNER_LEVEL_COST := 900.0
const RUNNER_LEVEL_GROWTH := 1.25

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
const MAX_TUBE_PARCELS := 400
const TUBE_SEGMENT_MAX_LEVEL := 100
const TUBE_SEGMENT_CAPACITY_PER_LEVEL := 1
const TUBE_SEGMENT_SPEED_PER_LEVEL := 0.02
const TUBE_SEGMENT_COST := 30000.0
const TUBE_SEGMENT_GROWTH := 1.08
const TUBE_STATION_FACTOR := 0.5
const TUBE_STATION_MIN_COST := 20000.0
const TUBE_STATION_INSPECTION_FACTOR := 3.0
const MAX_COLLECTORS := 12
const COLLECTOR_COST := 600.0
const COLLECTOR_GROWTH := 1.7
const COLLECTOR_CAPACITY := 3
const COLLECTOR_SPEED := 170.0
const COLLECTOR_TRIP_ESTIMATE := 12.0
const COLLECTOR_URGENT_MARGIN := 1
const COLLECTOR_MAX_DETOUR := 420.0
const COLLECTOR_DISTANCE_BIAS := 100.0
const SHRED_CASE_PENALTY := 1.0
const MAX_LOBBY_SLOTS := 160
const STANDING_PATIENCE_PENALTY := 0.35
const SEATING_BASE_SEATS := 24
const TICKET_UNLOCK_STAGE := 2
const TICKET_DRAW_SECONDS := 3.0
const TICKET_CALL_SECONDS := 3.5
const TICKET_HAND_FACTOR := 2.5
const TICKET_CALL_SLOTS := 4
const TICKET_RUSH := 4
const TICKET_LINE_SLOTS := 10
const MAX_TICKET_LINE_SLOTS := 50
const MAX_TICKET_MACHINES := 5
const REP_WALKED_OUT := -0.3
const VISITOR_SPEED := 120.0
const VISITOR_SLOTS := 3
const VISITOR_TALK_SECONDS := 7.5
const VISITOR_ANGRY_TALK_SECONDS := 6.0
const VISITOR_VENT_SECONDS := 5.0
const VENT_DIALOGS := 10
const VISITOR_DIALOGS := 30
const YELL_DIALOGS := 10
const VISITOR_LINES := 3
const YELL_COMPLAINTS := 8
const YELL_INTERVAL := 14.0
const MAX_GUARDS := 6
const GUARD_COST := 1100.0
const GUARD_GROWTH := 2.0
const GUARD_BLOCK_CHANCE := 0.35
const GUARD_STOP_SECONDS := 4.0
const GUARD_DIALOGS := 5
const GUARD_LINES := 2
const INTERN_STRESS_FREE := 3
const INTERN_STRESS_FREE_STEP := 10
const INTERN_STRESS_RATE := 0.0002
const INTERN_CALM_RATE := 0.004
const INTERN_YELL_RATE := 0.006
const INTERN_VENT_RATE := 0.005
const INTERN_SPEED := 150.0
const INTERN_TRIP_ESTIMATE := 8.0
const INTERN_CRY_SECONDS := 20.0
const MAX_HELPERS := 5
const HELPER_COST := 1300.0
const HELPER_GROWTH := 2.2
const INTERN_RECOVERED_STRESS := 0.25
const INTERN_COMFORT_TIME := 2.0
const INTERN_COMFORT_STRESS := 0.35
const MAX_COFFEE_INTERNS := 8
const COFFEE_INTERN_COST := 700.0
const COFFEE_INTERN_GROWTH := 1.9
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
const RUCKUS_MIN_CASES := 25
const RUCKUS_FIRST_SECONDS := 120.0
const RUCKUS_MIN_INTERVAL := 120.0
const RUCKUS_MAX_INTERVAL := 260.0
const RUCKUS_RETRY_SECONDS := 5.0
const RUCKUS_GUARD_RELIEF := 0.3
const RUCKUS_CALM_TIME := 2.5
const MEDIATE_REPUTATION := 0.2
const DISPUTES := {
	"window": {"speed": 0.85, "climate": 25},
	"thermostat": {"speed": 0.8, "climate": 60},
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
const MAIL_REWARD_FACTOR := 0.5
const MAIL_STORAGE_BASE := 12
const MAIL_STORAGE_PER_LEVEL := 1
const MAIL_STORAGE_MAX_LEVEL := 300
const MAIL_STORAGE_COST := 600.0
const MAIL_STORAGE_GROWTH := 1.04
const MAIL_CITIZEN_PRIORITY := 4
const MAIL_TARGET_SHARE := 0.5
const MAIL_FLOOR_MAX := 60
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

const ROOM_PLAYER := "player"
const ROOM_HALL := "hall"
const ROOM_COMPLAINTS := "complaint_office"
const ROOM_SHREDDER := "shredder_room"
const ROOM_TECH := "tech_room"
const ROOM_KITCHEN := "kitchen"
const ROOM_TOILETS := "toilets"
const ROOM_PHONE := "phone"
const ROOM_MAIL := "mail"
const ROOM_INSPECTION := "inspection"
const SERVICE_ROOMS: Array[String] = [ROOM_PLAYER, ROOM_HALL, ROOM_COMPLAINTS, ROOM_SHREDDER, ROOM_TECH, ROOM_KITCHEN, ROOM_TOILETS, ROOM_PHONE, ROOM_MAIL, ROOM_INSPECTION]
const TUBE_ROOMS: Array[String] = [ROOM_HALL, ROOM_MAIL, ROOM_INSPECTION]
const TOPICS: Array[String] = ["player", "citizens", "speed", "staff", "transport", "comfort", "complaints", "mail", "quality", "building"]

const SPOTS := {
	"player": ROOM_PLAYER,
	"entrance": ROOM_HALL,
	"waiting": ROOM_HALL,
	"seating": ROOM_HALL,
	"tickets": ROOM_HALL,
	"ticket_display": ROOM_HALL,
	"complaint_box": ROOM_HALL,
	"guards": ROOM_HALL,
	"archive": ROOM_HALL,
	"training": ROOM_HALL,
	"complaint_desk": ROOM_COMPLAINTS,
	"interns": ROOM_COMPLAINTS,
	"shredder": ROOM_SHREDDER,
	"collectors": ROOM_SHREDDER,
	"tube_hub": ROOM_TECH,
	"server": ROOM_TECH,
	"climate": ROOM_TECH,
	"runners": ROOM_TECH,
	"coffee_machine": ROOM_KITCHEN,
	"kitchen": ROOM_KITCHEN,
	"coffee_interns": ROOM_KITCHEN,
	"works_council": ROOM_KITCHEN,
	"toilets": ROOM_TOILETS,
	"phone": ROOM_PHONE,
	"phone_clerks": ROOM_PHONE,
	"mail_shelf": ROOM_MAIL,
	"mailbox": ROOM_MAIL,
}
const BOARD_SPOTS: Array[String] = ["runners", "collectors", "interns", "coffee_interns", "guards", "phone_clerks"]
const BOOST_ROOMS := {
	ROOM_PLAYER: ["overtime", "roller_skates"],
	ROOM_HALL: ["mayor_speech", "gazette_ad", "fee_increase", "budget_injection"],
	ROOM_COMPLAINTS: ["complaint_amnesty"],
	ROOM_TECH: ["stamp_turbo", "temp_workers", "weekend_shift"],
	ROOM_KITCHEN: ["coffee_round", "works_outing"],
	ROOM_PHONE: ["doctor_visit"],
	ROOM_MAIL: ["express_post"],
}

const ROOMS_ALL_DEPARTMENTS := "departments"
const ROOMS_SHREDDERS := "shredders"
const ROOMS_TUBES := "tubes"

const UPGRADES := {
	"briefcase": {"spot": "player", "topic": "player", "max": 100, "cost": 150.0, "growth": 1.15, "curve": "linear", "base": PLAYER_BASE_CAPACITY, "step": 1.0, "unit": "count"},
	"work_ethic": {"spot": "player", "topic": "player", "max": 200, "cost": 200.0, "growth": 1.08, "curve": "linear", "base": 1.0, "step": 0.025, "unit": "bonus"},
	"sneakers": {"spot": "player", "topic": "player", "max": 100, "cost": 300.0, "growth": 1.12, "curve": "linear", "base": 1.0, "step": 0.005, "unit": "bonus"},
	"scanners": {"spot": "station:shared/reception", "topic": "speed", "max": 200, "cost": 400.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus"},
	"digital_records": {"spot": "archive", "topic": "speed", "max": 200, "cost": 1500.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 15.0},
	"digital_signatures": {"spot": "station:shared/counter", "topic": "speed", "max": 200, "cost": 25000.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 80.0},
	"letter_opener": {"spot": "station:shared/mailroom", "topic": "speed", "max": 200, "cost": 900.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 10.0},
	"office_equipment": {"spot": "dept:%s", "topic": "speed", "max": 200, "cost": 500.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "rooms": ROOMS_ALL_DEPARTMENTS},
	"waiting_places": {"spot": "waiting", "topic": "citizens", "max": 120, "cost": 400.0, "growth": 1.1, "curve": "linear", "base": 0.0, "step": 1.0, "unit": "count"},
	"comfortable_lobby": {"spot": "waiting", "topic": "citizens", "max": 200, "cost": 800.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 10.0},
	"seating": {"spot": "seating", "topic": "citizens", "max": 300, "cost": 500.0, "growth": 1.04, "curve": "linear", "base": SEATING_BASE_SEATS, "step": 1.0, "unit": "count"},
	"standing_places": {"spot": "seating", "topic": "citizens", "max": 150, "cost": 450.0, "growth": 1.07, "curve": "linear", "base": 0.0, "step": 2.0, "unit": "count"},
	"ticket_speed": {"spot": "tickets", "topic": "citizens", "max": 200, "cost": 30000.0, "growth": 1.06, "curve": "decay", "base": TICKET_DRAW_SECONDS, "rate": 0.985, "unit": "seconds", "stage": TICKET_UNLOCK_STAGE},
	"ticket_machines": {"spot": "tickets", "topic": "citizens", "max": MAX_TICKET_MACHINES - 1, "cost": 60000.0, "growth": 4.0, "curve": "linear", "base": 1.0, "step": 1.0, "unit": "count", "stage": TICKET_UNLOCK_STAGE},
	"ticket_line": {"spot": "tickets", "topic": "citizens", "max": MAX_TICKET_LINE_SLOTS - TICKET_LINE_SLOTS, "cost": 20000.0, "growth": 1.15, "curve": "linear", "base": TICKET_LINE_SLOTS, "step": 1.0, "unit": "count", "stage": TICKET_UNLOCK_STAGE},
	"ticket_call_speed": {"spot": "ticket_display", "topic": "citizens", "max": 200, "cost": 35000.0, "growth": 1.06, "curve": "decay", "base": TICKET_CALL_SECONDS, "rate": 0.985, "unit": "seconds", "stage": TICKET_UNLOCK_STAGE},
	"online_portal": {"spot": "entrance", "topic": "citizens", "max": 100, "cost": 1000000.0, "growth": 1.1, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 500.0},
	"complaint_box": {"spot": "complaint_box", "topic": "complaints", "max": 200, "cost": 900.0, "growth": 1.05, "curve": "linear", "base": COMPLAINT_BOX_CAPACITY, "step": 1.0, "unit": "count"},
	"complaint_tube": {"spot": "complaint_box", "topic": "complaints", "max": 150, "cost": 6000.0, "growth": 1.08, "curve": "unlock_decay", "base": 60.0, "rate": 0.98, "unit": "seconds", "reputation": 50.0, "requires": {"shredder_service": 1}},
	"complaint_clerk": {"spot": "complaint_desk", "topic": "complaints", "max": 150, "cost": 500.0, "growth": 1.08, "curve": "chance", "base": 0.15, "rate": 0.99, "unit": "chance"},
	"shredder_service": {"spot": "interns", "topic": "complaints", "max": 200, "cost": 800.0, "growth": 1.07, "curve": "unlock_decay", "base": 40.0, "rate": 0.985, "unit": "seconds", "reputation": 10.0},
	"intern_training": {"spot": "interns", "topic": "complaints", "max": 50, "cost": 3000.0, "growth": 1.2, "curve": "linear", "base": 1.0, "step": 1.0, "unit": "count", "reputation": 40.0, "requires": {"shredder_service": 1}},
	"intern_resilience": {"spot": "interns", "topic": "complaints", "max": 150, "cost": 2500.0, "growth": 1.08, "curve": "decay", "base": 1.0, "rate": 0.985, "unit": "reduction", "requires": {"shredder_service": 1}},
	"shredder_blades": {"spot": "shredder", "topic": "complaints", "max": 100, "cost": 1000.0, "growth": 1.1, "curve": "decay", "base": 1.0, "rate": 0.985, "unit": "reduction"},
	"shredder": {"spot": "shredder:%s", "topic": "building", "max": 100, "cost": 600.0, "growth": 1.1, "curve": "unlock_decay", "base": 30.0, "rate": 0.98, "unit": "seconds", "rooms": ROOMS_SHREDDERS},
	"collector_carts": {"spot": "collectors", "topic": "transport", "max": 40, "cost": 1200.0, "growth": 1.18, "curve": "linear", "base": COLLECTOR_CAPACITY, "step": 1.0, "unit": "count", "reputation": 15.0},
	"collector_speed": {"spot": "collectors", "topic": "transport", "max": 200, "cost": 900.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus"},
	"runner_trolleys": {"spot": "runners", "topic": "transport", "max": 40, "cost": 1200.0, "growth": 1.18, "curve": "linear", "base": RUNNER_BASE_CAPACITY, "step": 1.0, "unit": "count", "reputation": 15.0},
	"runner_speed": {"spot": "runners", "topic": "transport", "max": 200, "cost": 900.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus"},
	"pneumatic_tubes": {"spot": "tube_hub", "topic": "transport", "max": 1, "cost": 250000.0, "growth": 1.0, "curve": "unlock", "unit": "unlock", "reputation": 250.0},
	"tube_capacity": {"spot": "tube_hub", "topic": "transport", "max": 60, "cost": 120000.0, "growth": 1.15, "curve": "linear", "base": TUBE_BASE_CAPACITY, "step": 1.0, "unit": "count", "requires": {"pneumatic_tubes": 1}},
	"tube_speed": {"spot": "tube_hub", "topic": "transport", "max": 200, "cost": 80000.0, "growth": 1.06, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "requires": {"pneumatic_tubes": 1}},
	"large_capsules": {"spot": "tube_hub", "topic": "transport", "max": 1, "cost": 600000.0, "growth": 1.0, "curve": "unlock", "unit": "unlock", "reputation": 400.0, "requires": {"pneumatic_tubes": 1}},
	"tube_station": {"spot": "tube:%s", "topic": "transport", "max": 1, "cost": TUBE_STATION_MIN_COST, "growth": 1.0, "curve": "unlock", "unit": "unlock", "rooms": ROOMS_TUBES, "requires": {"pneumatic_tubes": 1}},
	"it_support": {"spot": "server", "topic": "quality", "max": 100, "cost": 2000.0, "growth": 1.1, "curve": "linear", "base": 1.0, "step": -0.006, "unit": "reduction", "reputation": 20.0},
	"ai_classification": {"spot": "server", "topic": "quality", "max": 100, "cost": 20000000.0, "growth": 1.1, "curve": "decay", "base": 1.0, "rate": 0.993, "unit": "reduction", "reputation": 1000.0},
	"quality_training": {"spot": "training", "topic": "quality", "max": 150, "cost": 3000.0, "growth": 1.08, "curve": "decay", "base": 1.0, "rate": 0.99, "unit": "reduction", "reputation": 25.0},
	"climate_control": {"spot": "climate", "topic": "comfort", "max": 100, "cost": 900.0, "growth": 1.1, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 12.0},
	"mediation": {"spot": "works_council", "topic": "comfort", "max": 150, "cost": 1500.0, "growth": 1.08, "curve": "unlock_decay", "base": 120.0, "rate": 0.985, "unit": "seconds", "reputation": 18.0},
	"coffee": {"spot": "coffee_machine", "topic": "comfort", "max": 300, "cost": 500.0, "growth": 1.045, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 5.0},
	"coffee_machine": {"spot": "coffee_machine", "topic": "comfort", "max": 150, "cost": 700.0, "growth": 1.08, "curve": "decay", "base": 1.0, "rate": 0.99, "unit": "reduction", "reputation": 8.0},
	"espresso": {"spot": "coffee_machine", "topic": "comfort", "max": 200, "cost": 900.0, "growth": 1.06, "curve": "linear", "base": FETCH_ALERT_FACTOR, "step": 0.005, "unit": "bonus", "reputation": 8.0},
	"kitchen": {"spot": "kitchen", "topic": "comfort", "max": 200, "cost": 1200.0, "growth": 1.06, "curve": "linear", "base": 1.0, "step": -0.0045, "unit": "reduction", "reputation": 15.0},
	"coffee_intern_speed": {"spot": "coffee_interns", "topic": "comfort", "max": 200, "cost": 700.0, "growth": 1.07, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus"},
	"toilet_stalls": {"spot": "toilets", "topic": "comfort", "max": MAX_LOO_SLOTS - LOO_SLOTS, "cost": 1500.0, "growth": 2.2, "curve": "linear", "base": LOO_SLOTS, "step": 1.0, "unit": "count"},
	"toilet_speed": {"spot": "toilets", "topic": "comfort", "max": 150, "cost": 1000.0, "growth": 1.08, "curve": "decay", "base": LOO_SECONDS, "rate": 0.99, "unit": "seconds"},
	"toilet_hygiene": {"spot": "toilets", "topic": "comfort", "max": 100, "cost": 2000.0, "growth": 1.1, "curve": "linear", "base": 1.0, "step": 0.01, "unit": "bonus", "reputation": 20.0},
	"wake_service": {"spot": "toilets", "topic": "comfort", "max": 150, "cost": 1500.0, "growth": 1.08, "curve": "unlock_decay", "base": 45.0, "rate": 0.98, "unit": "seconds", "reputation": 20.0},
	"guard_training": {"spot": "guards", "topic": "staff", "max": 150, "cost": 2000.0, "growth": 1.08, "curve": "linear", "base": GUARD_BLOCK_CHANCE, "step": 0.003, "unit": "chance"},
	"phone_training": {"spot": "phone", "topic": "staff", "max": 100, "cost": 1500.0, "growth": 1.1, "curve": "decay", "base": 1.0, "rate": 0.99, "unit": "reduction"},
	"mail_subscription": {"spot": "mailbox", "topic": "mail", "max": 100, "cost": 1500.0, "growth": 1.1, "curve": "linear", "base": 0.0, "step": 1.0, "unit": "count", "reputation": 15.0},
	"mail_frequency": {"spot": "mailbox", "topic": "mail", "max": 150, "cost": 1200.0, "growth": 1.08, "curve": "decay", "base": MAIL_INTERVAL, "rate": 0.99, "unit": "seconds"},
	"registered_mail": {"spot": "station:shared/mailroom", "topic": "mail", "max": 200, "cost": 2500.0, "growth": 1.06, "curve": "linear", "base": MAIL_REWARD_FACTOR, "step": 0.005, "unit": "percent", "reputation": 25.0},
}

const OFFICIAL_TRAININGS := {
	"skill": {"cost": 0.1, "growth": 1.096, "effect": 0.015},
	"health": {"cost": 0.08, "growth": 1.096, "effect": 0.02},
	"stamina": {"cost": 0.065, "growth": 1.096, "effect": 0.978},
	"calm": {"cost": 0.065, "growth": 1.096, "effect": 0.02},
}
const OFFICIAL_TRAINING_ORDER: Array[String] = ["skill", "health", "stamina", "calm"]
const MAX_OFFICIAL_TRAINING := 30

const UPGRADE_SPEED := {
	"reception": "scanners",
	"dock": "scanners",
	"review": "digital_records",
	"signature": "digital_records",
	"counter": "digital_signatures",
	"clearance": "digital_signatures",
	"mailroom": "letter_opener",
}

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
	{"type": "upgrades", "target": 1.0, "param": "", "money": 800.0, "reputation": 2.0},
	{"type": "reputation", "target": 40.0, "param": "", "money": 2000.0, "reputation": 0.0},
	{"type": "department", "target": 1.0, "param": "business_licences", "money": 4000.0, "reputation": 5.0},
	{"type": "cases", "target": 300.0, "param": "", "money": 8000.0, "reputation": 5.0},
	{"type": "building_stage", "target": 2.0, "param": "", "money": 20000.0, "reputation": 5.0},
	{"type": "department", "target": 1.0, "param": "vehicle_registration", "money": 40000.0, "reputation": 8.0},
	{"type": "upgrade_level", "target": 1.0, "param": "pneumatic_tubes", "money": 100000.0, "reputation": 8.0},
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


static var _upgrade_ids: Array[String] = []


static func upgrade_ids() -> Array[String]:
	if _upgrade_ids.is_empty():
		for upgrade_id: String in UPGRADES:
			_upgrade_ids.append(upgrade_id)
	return _upgrade_ids


static func upgrade(upgrade_id: String) -> Dictionary:
	return UPGRADES.get(upgrade_id, {})


static func is_room_upgrade(upgrade_id: String) -> bool:
	return upgrade(upgrade_id).has("rooms")


static func upgrade_rooms(upgrade_id: String) -> Array[String]:
	var rooms: Array[String] = []
	match str(upgrade(upgrade_id).get("rooms", "")):
		ROOMS_ALL_DEPARTMENTS:
			rooms.append_array(department_ids())
		ROOMS_SHREDDERS:
			for dept_id in department_ids():
				if not is_customs(dept_id):
					rooms.append(dept_id)
		ROOMS_TUBES:
			rooms.append_array(TUBE_ROOMS)
			rooms.append_array(department_ids())
	return rooms


static func upgrade_key(upgrade_id: String, room_id: String = "") -> String:
	return upgrade_id if room_id.is_empty() else "%s@%s" % [upgrade_id, room_id]


static func upgrade_spot(upgrade_id: String, room_id: String = "") -> String:
	var spot := str(upgrade(upgrade_id).get("spot", ""))
	return spot % room_id if spot.contains("%s") else spot


static func station_room(key: String) -> String:
	match key:
		RECEPTION, COUNTER:
			return ROOM_HALL
		MAILROOM:
			return ROOM_MAIL
		INSPECTION:
			return ROOM_INSPECTION
	return station_dept(key)


static func room_boosts(room_id: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(BOOST_ROOMS.get(room_id, []))
	return result


static func spot_room(spot: String) -> String:
	if SPOTS.has(spot):
		return SPOTS[spot]
	if spot_kind(spot) == "station":
		return station_room(spot_target(spot))
	return spot_target(spot)


static func spot_kind(spot: String) -> String:
	return spot.get_slice(":", 0) if spot.contains(":") else ""


static func spot_target(spot: String) -> String:
	return spot.get_slice(":", 1) if spot.contains(":") else ""


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
