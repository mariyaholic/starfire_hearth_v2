class_name CommandRegistry
extends RefCounted
## Rebuilds commands from their dictionaries (golden scripts, bot logs, replays).


static func from_dict(d: Dictionary) -> Command:
	var cmd: Command = null
	match DictIO.str_of(d, "type"):
		RenameColonyCommand.TYPE:
			cmd = RenameColonyCommand.new()
		SetJobPriorityCommand.TYPE:
			cmd = SetJobPriorityCommand.new()
		_:
			return null
	cmd.empire_id = DictIO.str_of(d, "empire_id")
	cmd._load_payload(d)
	return cmd


static func known_types() -> Array[String]:
	return [RenameColonyCommand.TYPE, SetJobPriorityCommand.TYPE]
