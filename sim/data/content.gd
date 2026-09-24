class_name Content
extends RefCounted
## The content every rule reads (DESIGN_LOG 51): data/ loaded once, on first use. Content is
## constant during a game, so reading it from rules keeps them deterministic. Tests may swap in
## their own database with use() and restore the default with reset().

static var _db: ContentDb = null


static func db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


static func use(p_db: ContentDb) -> void:
	_db = p_db


static func reset() -> void:
	_db = null
