class_name Flavor
extends RefCounted

const QUIP_COUNT := 12
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
const SLOW_COUNT := 3
const KRANZ_COUNT := 3
const COMPLAINT_COUNT := 4
const SHRED_COUNT := 4
const REJECT_COUNT := 4
const GO_KITCHEN_COUNT := 3
const FETCH_COUNT := 3
const SECONDS_PER_DAY := 86400


static func quip(index: int) -> String:
	return TranslationServer.translate("QUIP_%d" % (posmod(index, QUIP_COUNT) + 1))


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


static func complaint(index: int) -> String:
	return TranslationServer.translate("COMPLAINT_%d" % (posmod(index, COMPLAINT_COUNT) + 1))


static func shred(index: int) -> String:
	return TranslationServer.translate("SHRED_%d" % (posmod(index, SHRED_COUNT) + 1))


static func reject(index: int) -> String:
	return TranslationServer.translate("REJECT_%d" % (posmod(index, REJECT_COUNT) + 1))


static func sick_note(index: int) -> String:
	return TranslationServer.translate("SICK_NOTE_%d" % (posmod(index, SICK_NOTE_COUNT) + 1))


static func sick_excuse(index: int) -> String:
	return TranslationServer.translate("SICK_EXCUSE_%d" % (posmod(index, SICK_CALL_COUNT) + 1))


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


static func go_kitchen(index: int) -> String:
	return TranslationServer.translate("GO_KITCHEN_%d" % (posmod(index, GO_KITCHEN_COUNT) + 1))


static func fetch(index: int) -> String:
	return TranslationServer.translate("FETCH_%d" % (posmod(index, FETCH_COUNT) + 1))


static func wisdom(unix_time: float) -> String:
	return TranslationServer.translate("WISDOM_%d" % (posmod(int(unix_time / SECONDS_PER_DAY), WISDOM_COUNT) + 1))
