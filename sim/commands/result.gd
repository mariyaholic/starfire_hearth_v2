class_name Result
extends RefCounted
## Outcome of validating a command. A failure always carries a string-table key and arguments so
## the UI can say why; commands are never dropped silently.

var ok: bool = true
var reason_key: String = ""
var args: Dictionary = {}


static func success() -> Result:
	return Result.new()


static func fail(p_reason_key: String, p_args: Dictionary = {}) -> Result:
	var r: Result = Result.new()
	r.ok = false
	r.reason_key = p_reason_key
	r.args = p_args
	return r


func to_dict() -> Dictionary:
	return {"ok": ok, "reason_key": reason_key, "args": args.duplicate(true)}
