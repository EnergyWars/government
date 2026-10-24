class_name NumberFormat
extends RefCounted

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Q"]


static func compact(value: float, decimal_separator: String = ".") -> String:
	var sign := "-" if value < 0.0 else ""
	var magnitude := absf(value)
	if magnitude < 1000.0:
		return sign + str(int(floorf(magnitude)))
	var index := 0
	while magnitude >= 1000.0 and index < SUFFIXES.size() - 1:
		magnitude /= 1000.0
		index += 1
	var digits := 1 if magnitude < 100.0 else 0
	var text := String.num(floorf(magnitude * pow(10.0, digits)) / pow(10.0, digits), digits)
	if text.contains("."):
		text = text.rstrip("0").trim_suffix(".")
	return sign + text.replace(".", decimal_separator) + SUFFIXES[index]


static func decimal(value: float, digits: int, decimal_separator: String = ".") -> String:
	return String.num(value, digits).replace(".", decimal_separator)


static func duration_parts(seconds: float) -> Dictionary:
	var total := maxi(0, int(seconds))
	return {"hours": floori(total / 3600.0), "minutes": floori((total % 3600) / 60.0), "seconds": total % 60}
