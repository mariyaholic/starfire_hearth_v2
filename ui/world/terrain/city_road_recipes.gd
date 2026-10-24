class_name CityRoadRecipes
extends RefCounted
## The network is rebuildable; save only its version and stable colony identities.
static func sync(store: AppearanceProfileStore, state: GameState, fresh: bool = false) -> void:
	if not store.matches(state): return
	var recipe: Dictionary=store.component_view("road")
	if recipe.is_empty():
		if not fresh or store.component_status("road")!="missing": return
		recipe={"identity":AppearanceProfileStore.identity(state),"version":CityAccessNetwork.VERSION,"colonies":{}}
	if not supported(recipe): return
	var changed: bool=store.component_status("road")=="missing"
	for colony: Colony in state.colonies_of(state.player_id):
		if colony.is_outpost() or recipe["colonies"].has(colony.id): continue
		recipe["colonies"][colony.id]={"version":CityAccessNetwork.VERSION}
		changed=true
	if changed: store.set_component("road",recipe)

static func supported(recipe: Dictionary) -> bool:
	return recipe.get("version") is int and recipe["version"]==CityAccessNetwork.VERSION and recipe.get("colonies") is Dictionary

static func can_upgrade(store: AppearanceProfileStore) -> bool:
	if store.opaque or store.fallback: return false
	if store.component_status("road")=="missing": return true
	var recipe: Dictionary=store.component_view("road")
	return store.component_status("road")=="supported" and recipe.get("version") is int and recipe["version"]<CityAccessNetwork.VERSION

static func upgrade(store: AppearanceProfileStore, state: GameState) -> bool:
	if not store.matches(state) or not can_upgrade(store): return false
	var recipe: Dictionary=store.component_view("road")
	if recipe.is_empty(): recipe={"identity":AppearanceProfileStore.identity(state),"colonies":{}}
	recipe["version"]=CityAccessNetwork.VERSION
	if not recipe.get("colonies") is Dictionary: return false
	for colony: Colony in state.colonies_of(state.player_id):
		if not colony.is_outpost(): recipe["colonies"][colony.id]={"version":CityAccessNetwork.VERSION}
	return store.upgrade_roads(recipe)

static func snapshot(store: AppearanceProfileStore,colony_id: String) -> Dictionary:
	var recipe: Dictionary=store.road_recipe_for(colony_id)
	if not supported(recipe): return {}
	var colony: Variant=recipe["colonies"].get(colony_id)
	if not colony is Dictionary or colony.get("version")!=CityAccessNetwork.VERSION: return {}
	# Unknown transport extensions stay on disk, not in renderer disclosures.
	return {"version":CityAccessNetwork.VERSION}
