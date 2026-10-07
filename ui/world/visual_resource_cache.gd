class_name VisualResourceCache
extends RefCounted
## Shared LRU with explicit active-owner pins. Byte figures are conservative estimates.
var epoch: int = 1
var budget_bytes: int = 64 * 1024 * 1024
var bytes: int = 0
var hits: int = 0
var misses: int = 0
var evictions: int = 0
var entries: Dictionary[String, Dictionary] = {}
var _lru: Array[String] = []
var _pins: Dictionary[String, Dictionary] = {}

func get_maps(key: String, request_epoch: int) -> Dictionary:
	if request_epoch != epoch or not entries.has(key):
		misses += 1
		return {}
	hits += 1
	_lru.erase(key); _lru.append(key)
	return entries[key]["maps"]

func put(key: String, maps: Dictionary, estimate: int, request_epoch: int) -> bool:
	if request_epoch != epoch or maps.is_empty() or estimate < 0: return false
	if entries.has(key): bytes -= int(entries[key]["bytes"])
	entries[key] = {"maps": maps, "bytes": estimate}
	bytes += estimate
	_lru.erase(key); _lru.append(key)
	trim()
	return entries.has(key)

func pin(key: String, owner: String) -> void:
	if not _pins.has(key): _pins[key] = {}
	_pins[key][owner] = true

func release_owner(owner: String) -> void:
	for key: String in _pins.keys():
		_pins[key].erase(owner)
		if _pins[key].is_empty(): _pins.erase(key)
	trim()

func unpin(key: String, owner: String) -> void:
	if _pins.has(key):
		_pins[key].erase(owner)
		if _pins[key].is_empty(): _pins.erase(key)
	trim()

func trim() -> void:
	for key: String in _lru.duplicate():
		if bytes <= budget_bytes: break
		if _pins.has(key): continue
		bytes -= int(entries[key]["bytes"])
		entries.erase(key); _lru.erase(key); evictions += 1

func reset(new_epoch: int) -> void:
	epoch = new_epoch
	entries.clear(); _lru.clear(); _pins.clear(); bytes = 0
	hits = 0; misses = 0; evictions = 0

func metrics() -> Dictionary:
	return {"texture_bytes_estimate": bytes, "budget_bytes": budget_bytes,
		"overrun_bytes": maxi(0, bytes - budget_bytes), "entries": entries.size(),
		"hits": hits, "misses": misses, "evictions": evictions, "pinned": _pins.size()}
