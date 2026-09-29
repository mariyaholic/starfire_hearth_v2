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
const LOAD: String = "load"
const CODEX: String = "codex"
const SETTINGS: String = "settings"
const CREDITS: String = "credits"
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
	# Tests and the screenshot tour turn persistence off: then progress stays in memory.
	if Settings.persist:
		progress = CampaignProgress.load_file()
	go(TITLE)
	if OS.has_feature("web"):
		_web_smoke.call_deferred()


## The web smoke test (tools/web_smoke.mjs) opens the game with ?smoke=begin: start Scenario 1,
## play one turn (which auto-saves) and say so in the browser console.
func _web_smoke() -> void:
	var v: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('smoke') || ''", true)
	if str(v) != "begin":
		return
	go(BEGIN, {"scenario": CampaignProgress.ORDER[0], "seed": 1})
	var r: TurnResult = Game.end_turn()
	print("Starfire Hearth smoke: new game at turn %d, state %s, %d save(s)" % [r.state.turn, r.state_hash.left(12), SaveService.list_slots().size()])


## The screens this build can open.
func routes() -> Array[String]:
	var out: Array[String] = [TITLE, CAMPAIGN, BRIEFING, GAME, DEBRIEF, CODEX, LOAD, SETTINGS, CREDITS]
	if OS.is_debug_build():
		out.append(SHOWCASE)
	return out


## Opens a screen, or runs an action. args: "scenario" (briefing, begin), "state" (continue),
## "seed" (begin; a random one otherwise) and "back" (load, settings, credits: where Back leads).
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
			_open(to, args)


func _open(to: String, args: Dictionary = {}) -> void:
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
	screen = _make(to, args)
	add_child(screen)
	Audio.play_music(_music_for(to))
	screen_changed.emit(to)


## The music cue for a screen (§15.5): the main theme on the title and campaign screens, the
## scenario's briefing and main tracks, and a sting at the debrief.
func _music_for(to: String) -> String:
	var music: Dictionary = DictIO.dict_of(Content.db().scenarios.get(scenario_id, {}), "music")
	match to:
		BRIEFING:
			return DictIO.str_of(music, "briefing", "mus_title")
		GAME:
			return DictIO.str_of(music, "main", "mus_slowboat_1")
		DEBRIEF:
			return "sting_victory" if Game.has_game() and Game.state.outcome == GameState.OUTCOME_WON else "sting_defeat"
		SHOWCASE:
			return ""
	return "mus_title"


func _make(to: String, args: Dictionary = {}) -> Control:
	var s: Control
	match to:
		CAMPAIGN:
			s = CampaignScreen.make(progress)
		BRIEFING:
			s = BriefingScreen.make(progress, scenario_id)
		GAME:
			s = GameScreen.new()
		DEBRIEF:
			s = DebriefScreen.make(progress, Game.state)
		CODEX:
			s = CodexScreen.make(str(args.get("entry", "")))
		LOAD:
			s = LoadScreen.make(str(args.get("back", TITLE)))
		SETTINGS:
			s = SettingsScreen.make(str(args.get("back", TITLE)))
		CREDITS:
			s = CreditsScreen.make(str(args.get("back", TITLE)))
		SHOWCASE:
			s = (load(SHOWCASE_SCENE) as PackedScene).instantiate()
			s.set("show_back", true)
			s.connect("back_requested", go.bind(TITLE))
		_:
			s = TitleScreen.make(routes())
	# Flow screens and the game screen ask to move by emitting `navigate`.
	if s.has_signal("navigate"):
		s.connect("navigate", go)
	return s
