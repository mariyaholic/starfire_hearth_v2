extends Node
## Application-lifetime worker retirement and session resources, outside screen rebuilds.
var session: VisualSession = VisualSession.new()
var cache: VisualResourceCache = VisualResourceCache.new()
var scheduler: GenerationScheduler
var appearances: AppearanceProfileStore = AppearanceProfileStore.new()
var web_context_lost: bool = false

func _ready() -> void:
	scheduler = GenerationScheduler.new()
	add_child(scheduler)
	Game.session_started.connect(_session_started)
	Game.turn_resolved.connect(func(r: TurnResult) -> void:
		appearances.sync_committed(r.state)
		CityRoadRecipes.sync(appearances,r.state))

func _process(_delta: float) -> void:
	if web_context_lost or not OS.has_feature("web") or not is_instance_valid(scheduler): return
	if bool(JavaScriptBridge.eval("window.__m11WebGLContextLost === true", true)):
		web_context_lost = true
		scheduler.suspend("webgl_context_lost")

func _session_started() -> void:
	appearances.bind(Game.state, Game.presentation, Game.presentation_overlay, Game.fresh_appearance)
	CityRoadRecipes.sync(appearances,Game.state,Game.fresh_appearance)
	if Game.fresh_appearance and not appearances.opaque:
		appearances.set_orbital_recipe(OrbitalLayout.build_recipe(Game.state))
	restart()

func save_fields(state: GameState) -> Dictionary:
	if appearances.matches(state):
		CityRoadRecipes.sync(appearances,state)
		return appearances.save_fields(state)
	var detached: AppearanceProfileStore = AppearanceProfileStore.new()
	detached.bind(state)
	return detached.save_fields(state)

func restart() -> void:
	session.restart()
	cache.reset(session.epoch)
	scheduler.restart(session.epoch)

func upgrade_finish() -> bool:
	if not appearances.matches(Game.state) or not appearances.upgrade_finish(): return false
	restart()
	return true

func upgrade_roads() -> bool:
	if not CityRoadRecipes.upgrade(appearances,Game.state): return false
	restart()
	return true

func upgrade_orbits() -> bool:
	if not appearances.upgrade_orbits(Game.state): return false
	restart()
	return true
