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
const CHEVRON := "\ue5cc"
const TROPHY := "\uea23"
const PRIORITY := "\ue645"
const DOOR := "\ueffd"
const DESCRIPTION := "\ue873"
const CELEBRATION := "\uea65"
const BLOCK := "\ue14b"
const DOMAIN := "\ue7ee"
const ADD_BUSINESS := "\ue729"
const HOURGLASS := "\uea5b"
const TOUCH := "\ue913"
const SCHOOL := "\ue80c"
const COFFEE := "\ue541"
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
}

const STAFF := {
	"runners": "\uea72",
	"specialists": "\uea67",
	"supervisors": "\uf02e",
	"hr": "\ue0b0",
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
	"scanners": "\ue5fa",
	"comfortable_lobby": "\uefed",
	"trolleys": "\uf86b",
	"digital_records": "\ue873",
	"quality_training": "\ue7af",
	"digital_signatures": "\ue2e6",
	"pneumatic_tubes": "\uf867",
	"online_portal": "\ue894",
	"ai_classification": "\uea4b",
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
