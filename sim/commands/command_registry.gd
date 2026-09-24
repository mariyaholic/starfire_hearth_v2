class_name CommandRegistry
extends RefCounted
## Rebuilds commands from their dictionaries (golden scripts, bot logs, replays).


static func from_dict(d: Dictionary) -> Command:
	var cmd: Command = make(DictIO.str_of(d, "type"))
	if cmd == null:
		return null
	cmd.empire_id = DictIO.str_of(d, "empire_id")
	cmd._load_payload(d)
	return cmd


## An empty command of the given type, or null for an unknown type.
static func make(type: String) -> Command:
	match type:
		RenameColonyCommand.TYPE:
			return RenameColonyCommand.new()
		SetJobPriorityCommand.TYPE:
			return SetJobPriorityCommand.new()
		PlaceDistrictCommand.TYPE:
			return PlaceDistrictCommand.new()
		UpgradeDistrictCommand.TYPE:
			return UpgradeDistrictCommand.new()
		DemolishCommand.TYPE:
			return DemolishCommand.new()
		BuildBuildingCommand.TYPE:
			return BuildBuildingCommand.new()
		BuildShipCommand.TYPE:
			return BuildShipCommand.new()
		CancelBuildCommand.TYPE:
			return CancelBuildCommand.new()
		MoveBuildUpCommand.TYPE:
			return MoveBuildUpCommand.new()
		PickResearchCommand.TYPE:
			return PickResearchCommand.new()
		RerollResearchCommand.TYPE:
			return RerollResearchCommand.new()
		ActivateOrdinanceCommand.TYPE:
			return ActivateOrdinanceCommand.new()
		CancelOrdinanceCommand.TYPE:
			return CancelOrdinanceCommand.new()
		SetGovernorCommand.TYPE:
			return SetGovernorCommand.new()
		VetoPlanCommand.TYPE:
			return VetoPlanCommand.new()
		SurveyCommand.TYPE:
			return SurveyCommand.new()
		BuildOutpostCommand.TYPE:
			return BuildOutpostCommand.new()
		ColoniseCommand.TYPE:
			return ColoniseCommand.new()
		ChooseEventCommand.TYPE:
			return ChooseEventCommand.new()
		AcknowledgeCommand.TYPE:
			return AcknowledgeCommand.new()
		TradeCommand.TYPE:
			return TradeCommand.new()
		RushBuildCommand.TYPE:
			return RushBuildCommand.new()
	return null


static func known_types() -> Array[String]:
	return [
		RenameColonyCommand.TYPE, SetJobPriorityCommand.TYPE, PlaceDistrictCommand.TYPE,
		UpgradeDistrictCommand.TYPE, DemolishCommand.TYPE, BuildBuildingCommand.TYPE,
		BuildShipCommand.TYPE, CancelBuildCommand.TYPE, MoveBuildUpCommand.TYPE,
		PickResearchCommand.TYPE, RerollResearchCommand.TYPE, ActivateOrdinanceCommand.TYPE,
		CancelOrdinanceCommand.TYPE, SetGovernorCommand.TYPE, VetoPlanCommand.TYPE,
		SurveyCommand.TYPE, BuildOutpostCommand.TYPE, ColoniseCommand.TYPE,
		ChooseEventCommand.TYPE, AcknowledgeCommand.TYPE, TradeCommand.TYPE, RushBuildCommand.TYPE,
	]
