class_name AppearanceProfileStore
extends RefCounted
## Presentation state belongs to the application, never GameState. Unknown
## envelopes are retained verbatim; understood additions live in a separate overlay.
const CATALOG: Dictionary = {"planet_material":1,"stellar_material":1,"civilian_kit":1,"city_kit":1}
const STAGE_E_CATALOG: Dictionary = {"planet_material":1,"stellar_material":1,"civilian_kit":1,"city_kit":2}
const CURRENT_CATALOG: Dictionary = {"planet_material":2,"stellar_material":2,"civilian_kit":2,"city_kit":3}
const ROAD_RECIPE_VERSION: int = 2
var data: Dictionary = {}
var original: String = ""
var opaque: bool = false
var fallback: bool = false
var notice: String = ""
var legacy: bool = true
## Optional M1.2 components remain outside the appearance payload catalog.
var _component_raws: Dictionary = {}
var _component_overlay_raws: Dictionary = {}
var _component_views: Dictionary = {}
var _component_status: Dictionary = {}

static func identity(s: GameState) -> Dictionary:
	return {"seed":s.game_seed,"scenario":s.scenario_id,"viewer":s.player_id}

func matches(s: GameState) -> bool:
	return not data.is_empty() and data.get("identity") == identity(s)

func bind(s: GameState, raw: String = "", overlay: String = "", fresh: bool = false) -> void:
	original = raw; opaque = false; fallback = false; notice = ""; legacy = not fresh
	_component_raws = PresentationEnvelope.component_raws(raw)
	_component_overlay_raws = {}
	_component_views = {}
	_component_status = {}
	data = {"identity":identity(s),"catalog":CURRENT_CATALOG.duplicate() if fresh else CATALOG.duplicate(),"profiles":{},"anchors":{},"legacy":legacy,
		"architecture":{"id":s.player().faction_id if s.player() != null else "ark","kit_version":3 if fresh else 1},
		"groundworks":{"version":1,"sites":{}}}
	var inspected: Dictionary = PresentationEnvelope.inspect(raw)
	if inspected["status"] == "supported":
		var restored: Dictionary = inspected["data"].duplicate(true)
		if inspected["version"] == 0: restored = _migrate_v0(restored)
		if _valid_data(restored,s):
			data = restored
			# A catalog may be unknown to an older renderer even inside a v1
			# envelope. Once understood again, retain additions from that writer's
			# overlay as well: demolished clearings are absent from GameState.
			var additions: Dictionary=PresentationEnvelope.inspect(overlay)
			if additions["status"]=="supported" and additions.get("version")==1 and _valid_data(additions["data"],s):
				data=merge_additions(data,additions["data"])
			legacy = bool(data.get("legacy",true))
		else:
			opaque = true; fallback = true; notice = "ui.world.appearance_incompatible"
	elif inspected["status"] != "missing":
		opaque = true
		fallback = inspected["status"] == "future"
		notice = "ui.world.appearance_incompatible" if fallback else "ui.world.appearance_recovered"
	# A future writer may include an independently checksummed version-1 view.
	# Its original payload still survives byte-for-byte. Overlay additions are
	# monotonic: existing future identities must win when newer writers merge them.
	if opaque:
		var compatible: String = overlay
		var authority: Dictionary = PresentationEnvelope.inspect(str(inspected.get("compatibility","")))
		var additions: Dictionary = PresentationEnvelope.inspect(overlay)
		if authority["status"] == "supported" and authority.get("version") == 1 and _valid_data(authority["data"],s):
			# An older build's fallback overlay must not replace an original
			# compatibility view that this newer renderer understands again.
			data = authority["data"].duplicate(true)
			if additions["status"] == "supported" and additions.get("version") == 1 and _valid_data(additions["data"],s):
				data = merge_additions(data,additions["data"])
			legacy = bool(data.get("legacy",true)); fallback = bool(data.get("requires_future_renderer",false))
			if not fallback: notice = "ui.world.appearance_compatible"
		else:
			var view: Dictionary = PresentationEnvelope.inspect(compatible)
			if view["status"] == "supported" and view.get("version") == 1 and _valid_data(view["data"],s):
				data = view["data"].duplicate(true); legacy = bool(data.get("legacy",true)); fallback = bool(data.get("requires_future_renderer",false))
				if not fallback and inspected["status"] == "future": notice = "ui.world.appearance_compatible"
	_bind_components(s, raw, overlay)
	sync_committed(s)
	for id: String in data["profiles"]:
		if profile_for(id).is_empty(): notice = "ui.world.appearance_incompatible"
	for colony: Colony in s.colonies_of(s.player_id):
		if not colony.is_outpost() and anchor_for(colony.id,colony.planet_id).is_empty(): notice = "ui.world.appearance_incompatible"


func _bind_components(s: GameState, raw: String, overlay: String) -> void:
	var originals: Dictionary = PresentationEnvelope.component_raws(raw)
	var additions: Dictionary = PresentationEnvelope.component_raws(overlay)
	for kind: String in PresentationEnvelope.COMPONENT_NAMES:
		var primary: String = str(originals.get(kind, ""))
		var fallback_raw: String = str(additions.get(kind, ""))
		var inspected: Dictionary = PresentationEnvelope.inspect_component(primary, kind)
		var overlay_inspected: Dictionary = PresentationEnvelope.inspect_component(fallback_raw, kind)
		_component_status[kind] = inspected.get("status", "missing")
		if inspected["status"] == "supported" and _valid_component(inspected.get("data",{}), s):
			_component_views[kind] = inspected["data"].duplicate(true)
			if overlay_inspected["status"] == "supported" and _valid_component(overlay_inspected.get("data",{}), s):
				_component_views[kind] = merge_component_additions(_component_views[kind], overlay_inspected["data"])
			if opaque:
				_component_overlay_raws[kind] = PresentationEnvelope.pack_component(kind, _component_views[kind])
			elif _component_views[kind] != inspected["data"]:
				var merged_raw: String = PresentationEnvelope.repack_component(_component_views[kind], primary, int(inspected.get("version", PresentationEnvelope.COMPONENT_VERSION)))
				if not merged_raw.is_empty(): _component_raws[kind] = merged_raw
			_component_status[kind] = "supported"
			continue
		var compatible: Dictionary = PresentationEnvelope.inspect_component(str(inspected.get("compatibility", "")), kind)
		if compatible["status"] == "supported" and _valid_component(compatible.get("data",{}), s):
			_component_views[kind] = compatible["data"].duplicate(true)
			if overlay_inspected["status"] == "supported" and _valid_component(overlay_inspected.get("data",{}), s):
				_component_views[kind] = merge_component_additions(_component_views[kind], overlay_inspected["data"])
			_component_overlay_raws[kind] = PresentationEnvelope.pack_component(kind, _component_views[kind])
			_component_status[kind] = "compatible"
		elif overlay_inspected["status"] == "supported" and _valid_component(overlay_inspected.get("data",{}), s):
			_component_views[kind] = overlay_inspected["data"].duplicate(true)
			_component_overlay_raws[kind] = fallback_raw
			_component_status[kind] = "overlay"
		elif inspected["status"] != "missing":
			_component_status[kind] = "incompatible" if inspected["status"] == "supported" else inspected["status"]
		elif overlay_inspected["status"] != "missing":
			_component_status[kind] = overlay_inspected["status"]
		if primary.is_empty() and not fallback_raw.is_empty(): _component_raws[kind] = fallback_raw


static func _valid_component(value: Variant, s: GameState) -> bool:
	return value is Dictionary and value.get("identity") == identity(s)


## Merge stable collection identities while keeping authoritative records.
static func merge_component_additions(authoritative: Dictionary, additions: Dictionary) -> Dictionary:
	var merged: Dictionary = authoritative.duplicate(true)
	if authoritative.get("identity") != additions.get("identity"): return merged
	for key: String in additions:
		if key == "identity" or merged.has(key): continue
		var value: Variant = additions[key]
		if value is Dictionary or value is Array: merged[key] = value.duplicate(true)
		else: merged[key] = value
	for key: String in additions:
		if key == "identity" or not merged.has(key) or not merged[key] is Dictionary or not additions[key] is Dictionary: continue
		for id: String in additions[key]:
			if not merged[key].has(id):
				var value: Variant = additions[key][id]
				merged[key][id] = value.duplicate(true) if value is Dictionary or value is Array else value
	return merged


func component_status(kind: String) -> String:
	return str(_component_status.get(kind, "missing"))


func component_supported(kind: String) -> bool:
	return component_status(kind) in ["supported", "compatible", "overlay"]


func component_view(kind: String) -> Dictionary:
	var view: Variant = _component_views.get(kind, {})
	return view.duplicate(true) if view is Dictionary else {}


func component_raw(kind: String) -> String:
	return str(_component_raws.get(kind, ""))


## Public filtered access for Stage B. The feature recipe's payload version is
## normalized to `version` so a snapshot can opt into CityAccessNetwork.V2;
## the transport wrapper version remains independent.
func road_recipe_for(colony_id: String = "") -> Dictionary:
	var recipe: Dictionary = component_view("road")
	if recipe.is_empty(): return {}
	recipe["version"] = int(recipe.get("version", recipe.get("recipe_version", 0)))
	if colony_id.is_empty(): return recipe
	var colonies: Variant = recipe.get("colonies", {})
	if not colonies is Dictionary or not colonies.has(colony_id): return {}
	recipe["colonies"] = {colony_id: colonies[colony_id].duplicate(true) if colonies[colony_id] is Dictionary else colonies[colony_id]}
	recipe["colony_id"] = colony_id
	return recipe


## Public filtered access for Stage F. Callers provide already-disclosed body
## IDs; this method never expands intel beyond the stored component view.
func orbital_recipe_for(system_id: String = "", body_ids: Array[String] = []) -> Dictionary:
	var recipe: Dictionary = component_view("orbit")
	if recipe.is_empty(): return {}
	if not system_id.is_empty() and recipe.get("systems") is Dictionary:
		return OrbitalLayout.normalize_for_system(recipe,system_id,body_ids)
	if not system_id.is_empty() and str(recipe.get("system_id", "")) != system_id: return {}
	recipe["version"] = int(recipe.get("version", recipe.get("recipe_version", 0)))
	var bodies: Variant = recipe.get("bodies", {})
	if bodies is Dictionary and not body_ids.is_empty():
		var filtered: Dictionary = {}
		for id: String in body_ids:
			if bodies.has(id): filtered[id] = bodies[id].duplicate(true) if bodies[id] is Dictionary else bodies[id]
		recipe["bodies"] = filtered
	return recipe


func can_upgrade_roads() -> bool:
	return component_status("road") == "missing" or (component_supported("road") and int(road_recipe_for().get("version", 0)) < ROAD_RECIPE_VERSION)


## The planner owns recipe generation. This setter is intentionally explicit so
## a presentation migration cannot silently reroll a saved city.
func upgrade_roads(recipe: Dictionary = {}) -> bool:
	if recipe.is_empty(): return false
	return set_component("road", recipe)


func set_orbital_recipe(recipe: Dictionary) -> bool:
	return set_component("orbit", recipe)

func can_upgrade_orbits() -> bool:
	return component_status("orbit")=="missing" and not opaque

func upgrade_orbits(state: GameState) -> bool:
	if not can_upgrade_orbits() or not matches(state): return false
	return set_orbital_recipe(OrbitalLayout.build_recipe(state))


func set_component(kind: String, value: Dictionary, version: int = PresentationEnvelope.COMPONENT_VERSION) -> bool:
	if kind not in PresentationEnvelope.COMPONENT_NAMES: return false
	if data.is_empty() or value.get("identity") != data.get("identity"): return false
	if version > PresentationEnvelope.COMPONENT_VERSION: return false
	var existing: Dictionary = PresentationEnvelope.inspect_component(component_raw(kind), kind)
	if existing.get("status") == "future": return false
	# A supported component may still carry wrapper fields introduced by a newer
	# writer. Repack through the original string so changing a known recipe does
	# not erase those opaque fields. A missing/invalid component gets a fresh
	# wrapper, while a future authoritative component was rejected above.
	var packed: String = PresentationEnvelope.repack_component(value, component_raw(kind), version) if existing.get("status") == "supported" else PresentationEnvelope.pack_component(kind, value, version)
	if packed.is_empty(): return false
	_component_raws[kind] = packed
	if opaque: _component_overlay_raws[kind] = packed
	_component_views[kind] = value.duplicate(true)
	_component_status[kind] = "supported"
	return true

func architecture_for(current_id: String) -> String:
	var style: Variant = data.get("architecture",{"id":current_id,"kit_version":1})
	if not style is Dictionary or style.get("kit_version") not in [1,2,3] or style.get("kit_version") != data.get("catalog",{}).get("city_kit",1): return ""
	var id: String = str(style.get("id","ark"))
	if id == "unlit": return "ark" # Defined reclaimed-human mapping in catalog 1.
	return id if id in CityBuildingKit.STYLES else ""

static func merge_additions(authoritative: Dictionary, overlay: Dictionary) -> Dictionary:
	# Contract for newer writers consuming an older build's compatibility overlay:
	# add identities created while playing that build; never replace newer profiles
	# or geographic anchors with an older rendering representation.
	var merged: Dictionary = authoritative.duplicate(true)
	if authoritative.get("identity") != overlay.get("identity"): return merged
	for collection: String in ["profiles","anchors"]:
		if not merged.get(collection) is Dictionary or not overlay.get(collection) is Dictionary: continue
		for id: String in overlay[collection]:
			if merged[collection].has(id): continue
			var item: Variant = overlay[collection][id]
			if not item is Dictionary: continue
			if collection == "profiles" and (item.get("id") != id or not PlanetFieldGenerator.supported(item)): continue
			if collection == "anchors" and (not merged["profiles"].has(item.get("planet","")) or not RegionAnchor.valid(item,str(item.get("planet","")))): continue
			merged[collection][id] = item.duplicate(true)

	for key: String in overlay:
		if key not in ["identity","catalog","architecture","legacy","requires_future_renderer"] and not merged.has(key): merged[key]=overlay[key].duplicate(true) if overlay[key] is Dictionary or overlay[key] is Array else overlay[key]
	var grounds: Variant = merged.get("groundworks",{})
	var additions: Variant = overlay.get("groundworks",{})
	if grounds is Dictionary and additions is Dictionary and additions.get("version")==1 and additions.get("sites") is Dictionary:
		if grounds.is_empty(): merged["groundworks"]={"version":1,"sites":{}}; grounds=merged["groundworks"]
		if grounds.get("version")==1 and grounds.get("sites") is Dictionary:
			for colony: String in additions["sites"]:
				if not additions["sites"][colony] is Array: continue
				if grounds["sites"].has(colony) and not grounds["sites"][colony] is Array: continue
				var sites: Array = grounds["sites"].get(colony,[]).duplicate()
				for value: Variant in additions["sites"][colony]:
					if not (value is int or value is float) or float(value)!=floorf(float(value)) or float(value)<0 or float(value)>=128: continue
					if not sites.has(int(value)): sites.append(int(value))
				grounds["sites"][colony]=sites
	return merged

static func _valid_data(d: Dictionary, s: GameState) -> bool:
	return d.get("identity") == identity(s) and d.get("profiles") is Dictionary and d.get("anchors") is Dictionary and d.get("catalog") in [CATALOG,STAGE_E_CATALOG,CURRENT_CATALOG]

func can_upgrade_finish() -> bool:
	return not opaque and not fallback and data.get("catalog") in [CATALOG,STAGE_E_CATALOG] and not architecture_for("ark").is_empty()

func upgrade_finish() -> bool:
	# Explicit presentation-only migration: retain geography, seeds, committed
	# clearings and unknown extensions. Unsupported envelopes remain untouched.
	if not can_upgrade_finish(): return false
	data["catalog"] = CURRENT_CATALOG.duplicate()
	data["architecture"]["kit_version"] = 3
	return true

static func _migrate_v0(d: Dictionary) -> Dictionary:
	# The v0 fixture used worlds/regions. Preserve every physical profile/anchor
	# and extension rather than regenerating from new defaults.
	d["profiles"] = d.get("worlds",{}).duplicate(true)
	d["anchors"] = d.get("regions",{}).duplicate(true)
	d.erase("worlds"); d.erase("regions")
	return d

func sync_committed(s: GameState) -> void:
	if not matches(s) or s.player() == null or fallback: return
	for system_id: String in s.player().known_systems:
		if not s.systems.has(system_id): continue
		var system: StarSystem = s.systems[system_id]
		if not data["profiles"].has(system_id):
			var star: Dictionary = PlanetFieldGenerator.profile(system_id,Rng.salt_of("system_surface:"+system_id),"star",legacy)
			star["spectral"] = system.spectral
			data["profiles"][system_id] = star
		for id: String in system.planet_ids:
			if not data["profiles"].has(id):
				var planet: Planet = s.planets[id]
				data["profiles"][id] = PlanetFieldGenerator.profile(id,planet.art_seed,planet.type,legacy)
	for colony: Colony in s.colonies_of(s.player_id):
		if colony.is_outpost() or data["anchors"].has(colony.id): continue
		var p: Dictionary = profile_for(colony.planet_id)
		if not p.is_empty() and p["kind"] in CityTerrainGenerator.KINDS:
			data["anchors"][colony.id] = RegionAnchor.choose(p,colony.id)

	# Record only committed, completed footprints. Hover, queued orders and the
	# command preview cannot leave permanent clearings; Undo therefore restores.
	if not data.has("groundworks"): data["groundworks"] = {"version":1,"sites":{}}
	var grounds: Variant = data["groundworks"]
	if grounds is Dictionary and grounds.get("version") == 1 and grounds.get("sites") is Dictionary:
		for colony: Colony in s.colonies_of(s.player_id):
			if colony.is_outpost(): continue
			var count: int = ColonyRules.slot_count(s.planets[colony.planet_id])
			var sites: Array[int] = prepared_for(colony.id,count)
			for district: Colony.PlacedDistrict in colony.districts:
				if district.slot >= 0 and district.slot < count and not sites.has(district.slot): sites.append(district.slot)
			for building: Colony.PlacedBuilding in colony.buildings:
				if building.slot >= 0 and building.slot < count and not sites.has(building.slot): sites.append(building.slot)
			sites.sort(); grounds["sites"][colony.id] = sites

func prepared_for(id: String, count: int) -> Array[int]:
	var sites: Array[int] = []
	var grounds: Variant = data.get("groundworks",{})
	if not grounds is Dictionary or grounds.get("version") != 1 or not grounds.get("sites") is Dictionary: return sites
	var raw: Variant = grounds["sites"].get(id,[])
	if not raw is Array: return sites
	for value: Variant in raw:
		if not (value is int or value is float) or float(value) != floorf(float(value)) or float(value)<0 or float(value)>=count: continue
		var slot: int = int(value)
		if slot >= 0 and slot < count and not sites.has(slot): sites.append(slot)
	sites.sort(); return sites

func profile_for(id: String) -> Dictionary:
	var p: Variant = data.get("profiles",{}).get(id,{})
	if not p is Dictionary or p.get("id") != id or not PlanetFieldGenerator.supported(p): return {}
	# Unknown extensions survive on disk, but are not renderer disclosures. Only
	# the supported public physical profile crosses the snapshot boundary.
	var out: Dictionary = {}
	for key: String in ["schema","id","source_seed","seed","kind","generator","generator_version","material_version","sea_ppm","projection_radius","relief_units","legacy","spectral"]:
		if p.has(key): out[key] = p[key]
	return out

func anchor_for(id: String, planet_id: String) -> Dictionary:
	var a: Variant = data.get("anchors",{}).get(id,{})
	if not a is Dictionary or not RegionAnchor.valid(a,planet_id): return {}
	var out: Dictionary = {}
	for key: String in ["version","planet","u_ppm","v_ppm","heading_mdeg","mode"]: out[key] = a[key]
	return out

func save_fields(s: GameState) -> Dictionary:
	sync_committed(s)
	if fallback: data["requires_future_renderer"] = true
	var version: int=2 if data.get("catalog")==CURRENT_CATALOG else 1
	if not opaque and PresentationEnvelope.inspect(original).get("version",1)==2: version=2
	var current: String = PresentationEnvelope.pack(data,1 if opaque else version) if original.is_empty() or opaque else PresentationEnvelope.repack(data,original,version)
	current = PresentationEnvelope.with_components(current, _component_overlay_raws if opaque else _component_raws)
	if not opaque and version==2:
		# A v1 reader sees v2 as future and renders this independently checked view.
		# Its resave retains the original v2 bytes and writes additions in overlay.
		var compatible: Dictionary=data.duplicate(true)
		if compatible["catalog"]==CURRENT_CATALOG:
			compatible["catalog"]=STAGE_E_CATALOG.duplicate()
			compatible["architecture"]["kit_version"]=2
		var wrapper: Dictionary=JSON.parse_string(current)
		wrapper["compatibility"]=PresentationEnvelope.pack(compatible)
		current=JSON.stringify(wrapper,"",true)
	return {"presentation":original if opaque else current, "presentation_overlay":current if opaque else ""}
