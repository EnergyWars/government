class_name Icons
extends RefCounted

const PAID := "\ue041"
const STAR := "\ue838"
const APARTMENT := "\uea40"
const SCIENCE := "\uea4b"
const FLAG := "\ue153"
const SETTINGS := "\ue8b8"
const CLOSE := "\ue5cd"
const GROUPS := "\uf233"
const ADD := "\ue145"
const ARROW_UP := "\ue5d8"
const PERSON_ADD := "\ue7fe"
const LOCK := "\ue897"
const CHECK := "\ue86c"
const WARNING := "\ue002"
const SCHEDULE := "\ue8b5"
const TRENDING := "\ue8e5"
const BOLT := "\uea0b"
const SPEED := "\ue9e4"
const LANGUAGE := "\ue894"
const RESTART := "\uf053"
const INFO := "\ue88e"
const SEAT := "\uefed"
const CHEVRON := "\ue5cc"
const EXPAND_LESS := "\ue5ce"
const EXPAND_MORE := "\ue5cf"
const TROPHY := "\uea23"
const PRIORITY := "\ue645"
const DOOR := "\ueffd"
const DESCRIPTION := "\ue873"
const CELEBRATION := "\uea65"
const BLOCK := "\ue14b"
const DOMAIN := "\ue7ee"
const ADD_BUSINESS := "\ue729"
const HOURGLASS := "\uea5b"
const TICKET := "\ue638"
const CALL_DISPLAY := "\ue333"
const TOUCH := "\ue913"
const SCHOOL := "\ue80c"
const COFFEE := "\ue541"
const STAR_BORDER := "\ue83a"
const REVIEWS := "\ue560"
const ARROW_BACK := "\ue5c4"
const CHEVRON_LEFT := "\ue5cb"
const DELETE := "\ue872"
const GAVEL := "\ue90e"
const ALARM := "\ue855"
const SNOOZE := "\ue046"
const FORUM := "\ue0bf"
const WALK := "\ue536"

const PERSON := "\ue7fd"
const INBOX := "\ue156"
const OUTBOX := "\uef5f"
const TEAM := "\uf233"
const SEARCH := "\ue8b6"
const FLAG_REPORT := "\uf013"
const LOCAL_SHIPPING := "\ue558"
const STATS := "\ue26b"
const MAIL := "\ue158"
const CLERK := "\uf0e2"
const COMPLAINT_BOX := "\ue89b"
const SEAL := "\uea3f"
const AD := "\ue63a"
const CART := "\ue8cc"
const STORAGE := "\ue179"
const SWAMPED := "\ue002"

const TRAININGS := {
	"skill": "\ue9e4",
	"health": "\ue87d",
	"stamina": "\uea0b",
	"calm": "\ueb4c",
}

const DEPARTMENTS := {
	"general_services": "\ue7fd",
	"tax_services": "\uea5f",
	"business_licences": "\uea12",
	"vehicle_registration": "\ue531",
	"building_permits": "\uea3b",
	"housing": "\uea44",
	"social_benefits": "\uf233",
	"customs": "\ue558",
	"inspection": "\ue8b6",
}

const SIGNATURES := {
	"general_services": "\ue412",
	"tax_services": "\uf17e",
	"business_licences": "\ue982",
	"vehicle_registration": "\ue8ad",
	"building_permits": "\uea3b",
	"housing": "\ue8b1",
	"social_benefits": "\uef63",
	"customs": "\ue5fa",
}

const STATIONS := {
	"reception": "\uf0e2",
	"review": "\uf0c5",
	"signature": "\ue8ad",
	"inspection": "\ue8b6",
	"counter": "\uf17e",
	"dock": "\uf868",
	"clearance": "\uef76",
	"mailroom": "\ue554",
}

const STAFF := {
	"runners": "\uea72",
	"specialists": "\uea67",
	"supervisors": "\uf02e",
	"hr": "\ue0b0",
	"guards": "\ue32a",
	"collectors": "\ue872",
	"helpers": "\ue7fb",
	"coffee_interns": "\ue541",
}

const RESEARCH := {
	"briefcase": "\ue1a1",
	"work_ethic": "\ue9e4",
	"coffee": "\ue541",
	"wake_service": "\ue855",
	"it_support": "\ue8b8",
	"coffee_machine": "\ue536",
	"kitchen": "\ue0bf",
	"shredder_service": "\ue872",
	"climate_control": "\ueb3b",
	"mediation": "\ue90e",
	"scanners": "\ue5fa",
	"comfortable_lobby": "\uefed",
	"trolleys": "\uf86b",
	"digital_records": "\ue873",
	"quality_training": "\ue7af",
	"digital_signatures": "\ue2e6",
	"pneumatic_tubes": "\uf867",
	"tube_capacity": "\ue8f9",
	"complaint_tube": "\ue8f9",
	"intern_training": "\ue80c",
	"online_portal": "\ue894",
	"ai_classification": "\uea4b",
	"letter_opener": "\ue14e",
	"mail_subscription": "\ue0be",
	"registered_mail": "\ue8e8",
}

const DISPUTES := {
	"window": "\uf088",
	"thermostat": "\uf076",
	"radio": "\ue405",
	"yoghurt": "\ueb44",
	"stapler": "\ue226",
	"fish_roll": "\uf1ea",
}

const EVENTS := {
	"rush_hour": "\ue8b5",
	"audit_visit": "\uea17",
	"tax_deadline": "\uef6e",
	"printer_jam": "\ue8ad",
	"system_crash": "\ue002",
	"monday_rush": "\uf233",
	"coffee_escalation": "\ue541",
	"paperwork_mountain": "\ue873",
	"staff_meeting": "\ue0bf",
	"rubber_ducks": "\ue558",
	"fire_drill": "\ue855",
	"renovation": "\ue14b",
	"garden_shed": "\uea3b",
	"inspector_audit": "\ue8b6",
	"authority_comparison": "\uea23",
	"mayor_visit": "\ue84f",
	"newspaper_praise": "\ueb81",
}

const BOOSTS := {
	"overtime": "\uea5d",
	"temp_workers": "\ue7fe",
	"stamp_turbo": "\ue982",
	"express_post": "\ue554",
	"coffee_round": "\ue541",
	"doctor_visit": "\uf109",
	"works_outing": "\uea65",
	"mayor_speech": "\uef49",
	"roller_skates": "\ue566",
	"complaint_amnesty": "\ue90e",
	"weekend_shift": "\ue16b",
	"gazette_ad": "\ueb81",
	"fee_increase": "\ue8e5",
	"budget_injection": "\ue2eb",
}


static func department(dept_id: String) -> String:
	return DEPARTMENTS.get(dept_id, DEPARTMENTS.inspection)


static func signature(dept_id: String) -> String:
	return SIGNATURES.get(dept_id, STATIONS.signature)


static func station(kind: String) -> String:
	return STATIONS.get(kind, DESCRIPTION)


static func station_for(key: String) -> String:
	var kind := GameConfig.station_kind_of(key)
	if kind == "signature":
		return signature(GameConfig.station_dept(key))
	return station(kind)
