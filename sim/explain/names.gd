class_name Names
extends RefCounted
## String keys for names the rules build from an id (research branches, colony stages, ship
## roles, event causes). Keeping them as literals here lets the data checks see every key.

const BRANCH: Dictionary[String, String] = {
	"physics": "branch.physics.name", "society": "branch.society.name",
	"engineering": "branch.engineering.name",
}
const STAGE: Dictionary[String, String] = {
	"outpost": "stage.outpost.name", "settlement": "stage.settlement.name",
	"colony": "stage.colony.name", "city": "stage.city.name",
}
const SHIP_ROLE: Dictionary[String, String] = {
	"survey": "ship_role.survey.name", "construction": "ship_role.construction.name",
	"colony": "ship_role.colony.name",
}
const EVENT_CAUSE: Dictionary[String, String] = {
	"scripted": "why.event.cause_scripted", "main_arc": "why.event.cause_main_arc",
	"director": "why.event.cause_director", "chain": "why.event.cause_chain",
	"status": "why.event.cause_status",
}


static func branch(branch_id: String) -> String:
	return BRANCH.get(branch_id, "")


static func stage(stage_id: String) -> String:
	return STAGE.get(stage_id, "")


static func ship_role(role: String) -> String:
	return SHIP_ROLE.get(role, "")


static func event_cause(cause: String) -> String:
	return EVENT_CAUSE.get(cause, "")
