extends Node
## The string table as a Godot Translation (§9.7). All UI text goes through tr() or fmt().
##
## fmt() fills {name} placeholders from `args`. An argument whose name ends in "_key" is itself a
## string key: it is resolved first and offered to the text without the suffix, so
## {"reason_key": "error.colony.not_found"} fills {reason}.

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
		else:
			values[arg_name] = str(args[k])
	return text.format(values)
