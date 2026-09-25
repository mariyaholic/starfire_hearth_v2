class_name CodexOverlay
extends RefCounted
## Opens one Codex entry over whatever is on screen: the "Codex" links in breakdowns lead here.
## Links inside the entry replace it, and a Back button walks the way back.


static func open(id: String) -> Modal:
	var ix: CodexIndex = CodexIndex.build(Game.view() if Game.has_game() else null)
	var m: Modal = Modal.make(Strings.fmt("ui.codex.title"))
	m.name = "CodexOverlay"
	var history: Array[String] = []
	_show(m, ix, id, history)
	m.open()
	return m


static func _show(m: Modal, ix: CodexIndex, id: String, history: Array[String]) -> void:
	for c: Node in m.body.get_children():
		m.body.remove_child(c)
		c.queue_free()
	if not history.is_empty():
		var back: SfButton = SfButton.make("ui.flow.back", "ui_back", SfButton.GHOST)
		back.name = "Back"
		back.sound = "ui_cancel"
		back.pressed.connect(func() -> void: _show(m, ix, history.pop_back(), history))
		m.body.add_child(back)
	var e: CodexIndex.Entry = ix.entry(id)
	if e == null:
		m.body.add_child(FlowScreen.label(Strings.fmt("ui.codex.missing"), &"SecondaryLabel"))
		return
	m.body.add_child(CodexEntryView.make(e, ix, func(link: String) -> void:
		if not ix.has(link):
			return
		history.append(id)
		Audio.play("ui_page_turn")
		_show(m, ix, link, history)))
