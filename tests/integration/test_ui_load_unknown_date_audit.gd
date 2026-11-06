extends RefCounted

func test_unreadable_save_has_no_fabricated_date(t: T) -> void:
	var screen: LoadScreen = LoadScreen.make()
	var card: Control = screen._card({"slot": "manual_1", "kind": "manual", "scenario_id": "", "turn": 0, "modified": 1000000000, "thumbnail": ""})
	var labels: Array[Node] = card.find_children("*", "Label", true, false)
	var fabricated: bool = false
	for node: Node in labels:
		if (node as Label).text.contains(Fmt.date(0)): fabricated = true
	t.not_ok(fabricated, "unknown turn does not display a fabricated calendar date")
	card.free()
	screen.free()
