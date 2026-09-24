class_name ReportItem
extends RefCounted
## One line of the turn report: what happened, why, how much it matters, and where to jump.

const CATEGORY_COLONIES: String = "colonies"
const CATEGORY_RESEARCH: String = "research"
const CATEGORY_FLEETS: String = "fleets"
const CATEGORY_DIPLOMACY: String = "diplomacy"
const CATEGORY_STORY: String = "story"
const CATEGORIES: Array[String] = [
	CATEGORY_COLONIES, CATEGORY_RESEARCH, CATEGORY_FLEETS, CATEGORY_DIPLOMACY, CATEGORY_STORY,
]

## Severity picks the icon and colour; colour is never the only signal.
const SEVERITY_INFO: String = "info"
const SEVERITY_GOOD: String = "good"
const SEVERITY_WARNING: String = "warning"
const SEVERITY_CRITICAL: String = "critical"

var category: String = CATEGORY_COLONIES
var severity: String = SEVERITY_INFO
## 0 (trivia) to 100 (must read). The report's top 3 are the highest.
var importance: int = 0
var text_key: String = ""
var args: Dictionary = {}
## What the jump-to button focuses: kind ("colony", "system", "fleet", "empire", "tech", "event")
## and the id. The id is for code only and never displayed.
var focus_kind: String = ""
var focus_id: String = ""
var breakdown: Breakdown = null
## Critical alerts block End Turn until acknowledged.
var blocks_end_turn: bool = false


static func make(p_category: String, p_importance: int, p_text_key: String, p_args: Dictionary = {}) -> ReportItem:
	var r: ReportItem = ReportItem.new()
	r.category = p_category
	r.importance = clampi(p_importance, 0, 100)
	r.text_key = p_text_key
	r.args = p_args
	return r


func focus(kind: String, id: String) -> ReportItem:
	focus_kind = kind
	focus_id = id
	return self


func with_severity(p_severity: String) -> ReportItem:
	severity = p_severity
	blocks_end_turn = p_severity == SEVERITY_CRITICAL
	return self


func with_breakdown(b: Breakdown) -> ReportItem:
	breakdown = b
	return self


func to_dict() -> Dictionary:
	return {
		"category": category, "severity": severity, "importance": importance,
		"text_key": text_key, "args": args.duplicate(true), "focus_kind": focus_kind,
		"focus_id": focus_id, "blocks_end_turn": blocks_end_turn,
		"breakdown": breakdown.to_dict() if breakdown != null else null,
	}
