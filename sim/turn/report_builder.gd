class_name ReportBuilder
extends RefCounted
## Orders report items for the turn report (§6.3): the top 3 by importance, then every item grouped
## by category. Ties are broken by severity, then category order, then emission order, so the
## order is fully deterministic.

const SEVERITY_RANK: Dictionary[String, int] = {
	ReportItem.SEVERITY_CRITICAL: 3, ReportItem.SEVERITY_WARNING: 2,
	ReportItem.SEVERITY_GOOD: 1, ReportItem.SEVERITY_INFO: 0,
}


static func ranked(items: Array[ReportItem]) -> Array[ReportItem]:
	var keyed: Array[Array] = []
	for i in items.size():
		keyed.append([items[i], i])
	keyed.sort_custom(_before)
	var out: Array[ReportItem] = []
	for pair: Array in keyed:
		out.append(pair[0])
	return out


static func top(items: Array[ReportItem], n: int = 3) -> Array[ReportItem]:
	var r: Array[ReportItem] = ranked(items)
	return r.slice(0, mini(n, r.size()))


## Category -> items (ranked), in ReportItem.CATEGORIES order. Empty categories are omitted.
static func grouped(items: Array[ReportItem]) -> Dictionary[String, Array]:
	var out: Dictionary[String, Array] = {}
	var r: Array[ReportItem] = ranked(items)
	for cat: String in ReportItem.CATEGORIES:
		var bucket: Array = []
		for it: ReportItem in r:
			if it.category == cat:
				bucket.append(it)
		if not bucket.is_empty():
			out[cat] = bucket
	return out


static func _before(a: Array, b: Array) -> bool:
	var ia: ReportItem = a[0]
	var ib: ReportItem = b[0]
	if ia.importance != ib.importance:
		return ia.importance > ib.importance
	var sa: int = SEVERITY_RANK.get(ia.severity, 0)
	var sb: int = SEVERITY_RANK.get(ib.severity, 0)
	if sa != sb:
		return sa > sb
	var ca: int = ReportItem.CATEGORIES.find(ia.category)
	var cb: int = ReportItem.CATEGORIES.find(ib.category)
	if ca != cb:
		return ca < cb
	return int(a[1]) < int(b[1])
