class_name TurnResult
extends RefCounted
## Everything one end-of-turn produced. Presentation reads this plus the new state; it never
## mutates either.

## The state at the start of the next turn.
var state: GameState = null
## Every report item, in emission order. Use ReportBuilder for the top 3 and the grouping.
var report_items: Array[ReportItem] = []
## Event instances waiting for a player choice next turn (M1).
var events_pending: Array[Dictionary] = []
## Battle records for replay and breakdown (M2).
var battles: Array[Dictionary] = []
var why_log: WhyLog = WhyLog.new()
## Commands that failed validation when the turn resolved: {command, reason_key, args}.
var rejected: Array[Dictionary] = []
## Phase names in the order they ran (the §9.4 contract is tested against this).
var phase_log: Array[String] = []
## SHA-256 of the canonical state after the turn.
var state_hash: String = ""
## Each empire's economy as the production phase computed it (not saved; phases 4 and 5 and the
## telemetry read it).
var reports: Dictionary[String, Economy.EmpireReport] = {}
