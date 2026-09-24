extends Node
## The string table as a Godot Translation (§9.7). All UI text goes through tr() or fmt().
##
## fmt() fills {name} placeholders from `args`. An argument whose name ends in "_key" is itself a
## string key: it is resolved first and offered to the text without the suffix, so
## {"reason_key": "error.colony.not_found"} fills {reason}. An argument ending in "_c" is an
## amount in centi-units and is shown as a decimal without trailing zeros: {"each_c": 450} fills
## {each} with "4.5". Signed forms: "_sc" (centi, "+4.5"), "_sp" (points, "+5") and "_bp" (basis
## points, "+10%").

var table: StringTable
var _translation: Translation


func _init() -> void:
	table = StringTable.load_csv()
	for e: String in table.errors:
		push_error("Strings: " + e)
	_translation = Translation.new()
	_translation.locale = "en"
	for k: String in table.keys:
		_translation.add_message(k, table.entries[k])
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale("en")


func has(key: String) -> bool:
	return table.entries.has(key)


## The text for `key` with placeholders filled. A missing key comes back unchanged, which the id
## audit flags as an unresolved key.
func fmt(key: String, args: Dictionary = {}) -> String:
	var text: String = table.entries.get(key, key)
	if not table.entries.has(key):
		push_warning("Strings: missing key " + key)
	if args.is_empty():
		return text
	var plain: Dictionary = {}
	for k: Variant in args.keys():
		if not str(k).ends_with("_key"):
			plain[k] = args[k]
	var values: Dictionary = {}
	for k: Variant in args.keys():
		var arg_name: String = str(k)
		if arg_name.ends_with("_key") and typeof(args[k]) == TYPE_STRING:
			values[arg_name.trim_suffix("_key")] = fmt(args[k], plain)
		elif arg_name.ends_with("_c") and typeof(args[k]) == TYPE_INT:
			values[arg_name.trim_suffix("_c")] = centi(args[k])
		elif arg_name.ends_with("_sc") and typeof(args[k]) == TYPE_INT:
			values[arg_name.trim_suffix("_sc")] = ("+" if int(args[k]) > 0 else "") + centi(args[k])
		elif arg_name.ends_with("_sp") and typeof(args[k]) == TYPE_INT:
			var n: int = args[k]
			values[arg_name.trim_suffix("_sp")] = ("+%d" % n) if n > 0 else (("\u2212%d" % -n) if n < 0 else "0")
		elif arg_name.ends_with("_bp") and typeof(args[k]) == TYPE_INT:
			values[arg_name.trim_suffix("_bp")] = percent(args[k])
		else:
			values[arg_name] = str(args[k])
	return text.format(values)


## Basis points as a signed percentage: 1000 -> "+10%", -1500 -> "−15%", 250 -> "+2.5%".
static func percent(bp: int) -> String:
	var sign: String = "+" if bp > 0 else ("\u2212" if bp < 0 else "")
	var a: int = absi(bp)
	var s: String = str(a / 100)
	if a % 100 != 0:
		s += (".%02d" % (a % 100)).rstrip("0")
	return sign + s + "%"


## A centi-unit amount as a short decimal: 450 -> "4.5", 400 -> "4", -25 -> "−0.25".
static func centi(v: int) -> String:
	var sign: String = "\u2212" if v < 0 else ""
	var a: int = absi(v)
	var whole: int = a / 100
	var frac: int = a % 100
	if frac == 0:
		return "%s%d" % [sign, whole]
	if frac % 10 == 0:
		return "%s%d.%d" % [sign, whole, frac / 10]
	return "%s%d.%02d" % [sign, whole, frac]
