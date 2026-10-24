class_name EventOverlay
extends RefCounted
## An event's story scene (§5.10, §6.6, §8.3): the painted scene, the speaker, the text, and the
## choices with what each costs and does (an uncertain choice lists its outcomes and their
## chances). A story step cues its music while it is open. It must be answered: an event blocks End
## Turn until a choice is made, and the answer is an order like any other.

const VoiceRegistry = preload("res://app/voice_registry.gd")


## Opens the scene for a pending event; `on_done` runs once it is answered.
static func open(s: GameScreen, event_id: String, on_done: Callable) -> Modal:
	var state: GameState = Game.view()
	var ev: EventInstance = Events.find_pending(state, event_id)
	if ev == null:
		return null
	var e: Empire = state.player()
	var step: Dictionary = Events.step_of(ev.chain, ev.step)
	var chain: Dictionary = Events.chain(ev.chain)
	var m: Modal = Modal.make(Strings.fmt(DictIO.str_of(step, "title_key")), false)
	m.name = "EventOverlay"
	var voice_result: Dictionary = VoiceService.request(VoiceRegistry.event_cue(ev.chain, ev.step, step))
	# Keep optional voice status on the presentation overlay for accessibility/tooling without
	# putting an unavailable-clip notice into the story copy or gating any choice.
	m.set_meta("voice_utterance_id", str(voice_result.get("utterance_id", "")))
	m.set_meta("voice_status", str(voice_result.get("status", "unavailable")))
	m.set_meta("voice_status_text", VoiceService.status_text(str(voice_result.get("status", "unavailable"))))
	var cue: String = DictIO.str_of(step, "music")
	if not cue.is_empty():
		Audio.play_music(cue)
	Audio.play("ui_event_open")
	var vignette: String = DictIO.str_of(chain, "vignette")
	if not vignette.is_empty():
		m.body.add_child(StoryScene.make(vignette, 110.0 if Layout.compact else 170.0))
	var speaker: String = DictIO.str_of(step, "speaker")
	if not speaker.is_empty():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_M)
		row.add_child(Portrait.make(speaker, DictIO.str_of(step, "expression", "neutral"), 64.0))
		row.add_child(GameUI.grow(GameUI.name_of("portraits", speaker), &"StrongLabel"))
		m.body.add_child(row)
	var colony: Colony = state.colonies.get(ev.colony_id, null)
	if colony == null:
		colony = GameModel.capital(state)
	var args: Dictionary = ColonyRules.name_args(state, colony) if colony != null else {}
	var body: Label = FlowScreen.label(Strings.fmt(DictIO.str_of(step, "body_key"), args))
	body.name = "EventBody"
	# Story prose: any numbers in it are the story's own.
	body.set_meta("audit_numeric_ok", "story prose")
	m.body.add_child(body)
	var hint: String = DictIO.str_of(step, "hint_key")
	if not hint.is_empty() and Settings.hints_enabled:
		m.body.add_child(GameUI.exempt(GameUI.caption(Strings.fmt(hint)), "the hint quotes the rules' numbers"))
	var choices: Array = DictIO.arr_of(step, "choices")
	for i in choices.size():
		m.body.add_child(_choice(s, m, state, e, ev, choices[i], i))
	m.dismissed.connect(func() -> void:
		VoiceService.stop_utterance()
		# The story cue ends with the scene: back to the scenario's own track.
		Audio.play_music(GameModel.main_music(Game.state))
		if on_done.is_valid():
			on_done.call_deferred())
	m.open()
	return m


static func _choice(s: GameScreen, m: Modal, state: GameState, e: Empire, ev: EventInstance, ch: Dictionary, index: int) -> Control:
	var v: VBoxContainer = GameUI.column(Tokens.SPACE_XS)
	v.name = "Choice_%d" % index
	var res: Result = Events.can_choose(state, e.id, ev.id, index)
	var act: VBoxContainer = GameUI.action(Strings.fmt(DictIO.str_of(ch, "label_key")), "", res, func() -> void:
		var r: Result = s.order(ChooseEventCommand.create(e.id, ev.id, index))
		if r.ok:
			Audio.play("ui_choice_made")
			m.close())
	# A choice's own wording may quote numbers, and a refusal quotes what refused it.
	v.add_child(GameUI.exempt(act, "a choice's own wording"))
	var cost: Dictionary = DictIO.dict_of(ch, "cost")
	if not cost.is_empty():
		v.add_child(GameUI.cost(Construction._res_map(cost), e))
	var effects: Array = DictIO.arr_of(ch, "effects")
	if not effects.is_empty():
		v.add_child(EffectList.make(state, effects, ev.colony_id))
	var outcomes: Array = DictIO.arr_of(ch, "outcomes")
	if not outcomes.is_empty():
		v.add_child(GameUI.caption(Strings.fmt("ui.event.uncertain")))
		for ov: Variant in outcomes:
			var oc: Dictionary = ov
			var line: VBoxContainer = GameUI.column(2)
			var chance: Label = GameUI.caption(Strings.fmt("ui.event.outcome", {"pct": Fx.div_floor(DictIO.int_of(oc, "chance_bp"), 100), "text": Strings.fmt(DictIO.str_of(oc, "text_key"))}))
			line.add_child(GameUI.exempt(chance, "an outcome's chance, from the event's data"))
			line.add_child(EffectList.make(state, DictIO.arr_of(oc, "effects"), ev.colony_id))
			v.add_child(line)
	return v
