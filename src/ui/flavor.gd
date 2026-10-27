class_name Flavor
extends RefCounted

const DONE_COUNT := 6
const FLAWED_COUNT := 3
const WISDOM_COUNT := 12
const NAP_COUNT := 4
const COFFEE_BREAK_COUNT := 4
const WOKE_COUNT := 4
const CHAT_COUNT := 4
const GO_LOO_COUNT := 3
const LOO_VOICE_COUNT := 4
const SICK_NOTE_COUNT := 4
const SICK_CALL_COUNT := 12
const SICK_ANSWER_COUNT := 8
const SLOW_COUNT := 3
const KRANZ_COUNT := 3
const COMPLAINT_COUNT := 50
const SHRED_COUNT := 4
const REJECT_COUNT := 4
const GO_KITCHEN_COUNT := 3
const FETCH_COUNT := 3
const INTERN_CRY_COUNT := 4
const INTERN_NERVOUS_COUNT := 6
const COFFEE_SERVED_COUNT := 3
const DISPUTE_LINES := 4
const RUCKUS_COUNT := 8
const LUNCH_COUNT := 4
const LUNCH_TALK_COUNT := 6
const INTERN_ENDURE_COUNT := 6
const SECONDS_PER_DAY := 86400


static func done(index: int) -> String:
	return TranslationServer.translate("FLOAT_DONE_%d" % (posmod(index, DONE_COUNT) + 1))


static func flawed(index: int) -> String:
	return TranslationServer.translate("FLOAT_FLAWED_%d" % (posmod(index, FLAWED_COUNT) + 1))


static func nap(index: int) -> String:
	return TranslationServer.translate("NAP_%d" % (posmod(index, NAP_COUNT) + 1))


static func coffee_break(index: int) -> String:
	return TranslationServer.translate("COFFEE_BREAK_%d" % (posmod(index, COFFEE_BREAK_COUNT) + 1))


static func woke(index: int) -> String:
	return TranslationServer.translate("WOKE_%d" % (posmod(index, WOKE_COUNT) + 1))


static func complaint(serial: int) -> String:
	return TranslationServer.translate("COMPLAINT_%d" % (Formulas.complaint_text_index(serial) + 1))


static func complaint_subject(serial: int) -> String:
	return TranslationServer.translate("COMPLAINT_SUBJECT_%d" % (Formulas.complaint_text_index(serial) + 1))


static func shred(index: int) -> String:
	return TranslationServer.translate("SHRED_%d" % (posmod(index, SHRED_COUNT) + 1))


static func reject(index: int) -> String:
	return TranslationServer.translate("REJECT_%d" % (posmod(index, REJECT_COUNT) + 1))


static func sick_note(index: int) -> String:
	return TranslationServer.translate("SICK_NOTE_%d" % (posmod(index, SICK_NOTE_COUNT) + 1))


static func sick_excuse(index: int) -> String:
	return TranslationServer.translate("SICK_EXCUSE_%d" % (posmod(index, SICK_CALL_COUNT) + 1))


static func sick_answer(index: int) -> String:
	return TranslationServer.translate("SICK_ANSWER_%d" % (posmod(index, SICK_ANSWER_COUNT) + 1))


static func sick_reply(index: int) -> String:
	return TranslationServer.translate("SICK_REPLY_%d" % (posmod(index, SICK_CALL_COUNT) + 1))


static func go_loo(index: int) -> String:
	return TranslationServer.translate("GO_LOO_%d" % (posmod(index, GO_LOO_COUNT) + 1))


static func loo_voice(index: int) -> String:
	return TranslationServer.translate("LOO_VOICE_%d" % (posmod(index, LOO_VOICE_COUNT) + 1))


static func slow(index: int) -> String:
	return TranslationServer.translate("SLOW_%d" % (posmod(index, SLOW_COUNT) + 1))


static func kranz(index: int) -> String:
	return TranslationServer.translate("KRANZ_%d" % (posmod(index, KRANZ_COUNT) + 1))


static func chat(index: int) -> String:
	return TranslationServer.translate("CHAT_%d" % (posmod(index, CHAT_COUNT) + 1))


static func lunch(index: int) -> String:
	return TranslationServer.translate("LUNCH_%d" % (posmod(index, LUNCH_COUNT) + 1))


static func lunch_talk(index: int) -> String:
	return TranslationServer.translate("LUNCH_TALK_%d" % (posmod(index, LUNCH_TALK_COUNT) + 1))


static func intern_endure(index: int) -> String:
	return TranslationServer.translate("INTERN_ENDURE_%d" % (posmod(index, INTERN_ENDURE_COUNT) + 1))


static func gift(kind: int) -> String:
	return TranslationServer.translate("GIFT_%d" % (posmod(kind, GameConfig.GIFT_KINDS) + 1))


static func go_kitchen(index: int) -> String:
	return TranslationServer.translate("GO_KITCHEN_%d" % (posmod(index, GO_KITCHEN_COUNT) + 1))


static func fetch(index: int) -> String:
	return TranslationServer.translate("FETCH_%d" % (posmod(index, FETCH_COUNT) + 1))


static func visit_line(angry: bool, dialog: int, line: int) -> String:
	var prefix := "YELL" if angry else "VISIT"
	return TranslationServer.translate("%s_%d_%d" % [prefix, dialog + 1, line + 1])


static func guard_line(dialog: int, line: int) -> String:
	return TranslationServer.translate("GUARD_%d_%d" % [posmod(dialog, GameConfig.GUARD_DIALOGS) + 1, clampi(line, 0, GameConfig.GUARD_LINES - 1) + 1])


static func intern_cry(index: int) -> String:
	return TranslationServer.translate("INTERN_CRY_%d" % (posmod(index, INTERN_CRY_COUNT) + 1))


static func intern_nervous(index: int) -> String:
	return TranslationServer.translate("INTERN_NERVOUS_%d" % (posmod(index, INTERN_NERVOUS_COUNT) + 1))


static func coffee_served(index: int) -> String:
	return TranslationServer.translate("COFFEE_SERVED_%d" % (posmod(index, COFFEE_SERVED_COUNT) + 1))


static func dispute_line(kind: String, index: int) -> String:
	return TranslationServer.translate("DISPUTE_%s_%d" % [kind.to_upper(), posmod(index, DISPUTE_LINES) + 1])


static func ruckus_line(index: int) -> String:
	return TranslationServer.translate("RUCKUS_%d" % (posmod(index, RUCKUS_COUNT) + 1))


static func rage(index: int) -> String:
	return TranslationServer.translate("RAGE_%d" % (posmod(index, GameConfig.RAGE_LINES) + 1))


static func wisdom(unix_time: float) -> String:
	return TranslationServer.translate("WISDOM_%d" % (posmod(int(unix_time / SECONDS_PER_DAY), WISDOM_COUNT) + 1))
