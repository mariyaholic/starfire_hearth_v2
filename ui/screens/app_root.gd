class_name AppRoot
extends Control
## The app's root screen host (the screen plan in docs/BUILD_PROMPT.md): one screen at a time,
## routed title → campaign → briefing → game → debrief, plus the showcase in debug builds. Screens
## ask to move by emitting FlowScreen.navigate; the root closes every overlay, frees the old screen
## and builds the new one. Only screens that exist are offered (DESIGN_LOG 85). It owns the
## campaign progress; the game session itself lives in the Game autoload.

signal screen_changed(route: String)

const TITLE: String = "title"
const CAMPAIGN: String = "campaign"
const BRIEFING: String = "briefing"
const GAME: String = "game"
const DEBRIEF: String = "debrief"
const SHOWCASE: String = "showcase"
## Screens of later M1 tasks; offered by the title once they are routed here.
const LOAD: String = "load"
const CODEX: String = "codex"
const SETTINGS: String = "settings"
## Actions rather than screens: each does its work, then opens a screen.
const CONTINUE: String = "continue"
const BEGIN: String = "begin"

const SHOWCASE_SCENE: String = "res://ui/screens/showcase/showcase.tscn"

var progress: CampaignProgress = CampaignProgress.new()
var route: String = ""
var screen: Control = null
## The scenario the briefing and debrief are about.
var scenario_id: String = CampaignProgress.ORDER[0]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	go(TITLE)


## The screens this build can open.
func routes() -> Array[String]:
	var out: Array[String] = [TITLE, CAMPAIGN, BRIEFING, GAME, DEBRIEF]
	if OS.is_debug_build():
		out.append(SHOWCASE)
	return out


## Opens a screen, or runs an action. args: "scenario" (briefing, begin), "state" (continue) and
## "seed" (begin; a random one otherwise).
func go(to: String, args: Dictionary = {}) -> void:
	if args.has("scenario"):
		scenario_id = str(args["scenario"])
	match to:
		CONTINUE:
			var st: GameState = args.get("state") as GameState
			if st == null:
				Overlay.toast(Strings.fmt("save.error.corrupt"), ReportItem.SEVERITY_WARNING)
				return
			Game.resume(st)
			scenario_id = st.scenario_id
			_open(DEBRIEF if st.is_over() else GAME)
		BEGIN:
			var game_seed: int = int(args["seed"]) if args.has("seed") else randi()
			Game.new_game(scenario_id, game_seed, progress.difficulty_id)
			_open(GAME)
		_:
			_open(to)


func _open(to: String) -> void:
	if not routes().has(to):
		push_warning("AppRoot: no screen for route %s" % to)
		to = TITLE
	Overlay.close_all()
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	if to == DEBRIEF and Game.has_game() and Game.state.outcome == GameState.OUTCOME_WON:
		progress.record_win(Game.state.scenario_id)
	route = to
	screen = _make(to)
	add_child(screen)
	screen_changed.emit(to)


func _make(to: String) -> Control:
	var s: Control
	match to:
		CAMPAIGN:
			s = CampaignScreen.make(progress)
		BRIEFING:
			s = BriefingScreen.make(progress, scenario_id)
		GAME:
			# The game screen is the next M1 screen task; until then a stand-in keeps the flow whole.
			s = PendingScreen.make()
		DEBRIEF:
			s = DebriefScreen.make(progress, Game.state)
		SHOWCASE:
			s = (load(SHOWCASE_SCENE) as PackedScene).instantiate()
			s.set("show_back", true)
			s.connect("back_requested", go.bind(TITLE))
		_:
			s = TitleScreen.make(routes())
	if s is FlowScreen:
		(s as FlowScreen).navigate.connect(go)
	return s
