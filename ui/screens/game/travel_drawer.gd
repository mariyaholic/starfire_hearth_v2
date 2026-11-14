class_name TravelDrawer
extends RefCounted
## Fleet orders are available from the same drawer in both map presentations.

const AUTO_STATUS: Dictionary[String, String] = {
	"disabled": "ui.auto_explore.status.disabled",
	"travelling": "ui.auto_explore.status.travelling",
	"surveying": "ui.auto_explore.status.surveying",
	"waiting": "ui.auto_explore.status.waiting",
}

static func open(screen: GameScreen) -> void:
	var d: Drawer = Drawer.make(Strings.fmt("ui.travel.title"), Drawer.SIDE_RIGHT)
	d.name = "TravelDrawer"
	d.body.add_child(GameUI.caption(Strings.fmt("ui.travel.hint")))
	var count: int = 0
	for fid: String in DictIO.sorted_keys(screen.state.fleets):
		var fleet: Fleet = screen.state.fleets[fid]
		if fleet.owner_id != screen.state.player_id or fleet.ship_ids.is_empty():
			continue
		var ship: Ship = screen.state.ships.get(fleet.ship_ids[0], null)
		if ship == null or DictIO.str_of(Content.db().record("hulls", ship.hull), "class") != "civilian":
			continue
		count += 1
		var card: Card = Card.make(GameUI.name_of("hulls", ship.hull))
		card.name = "Fleet_" + fid
		if Ships.role(ship) == Ships.ROLE_SURVEY:
			var auto_enabled: bool = AutoExplore.enabled(screen.state, fid)
			var auto_status: String = AutoExplore.status(screen.state, fid)
			card.add_text(Strings.fmt(AUTO_STATUS.get(auto_status, "ui.auto_explore.status.waiting")), &"SecondaryLabel")
			card.add_text(Strings.fmt("ui.auto_explore.hint"), &"CaptionLabel")
			var setting: bool = not auto_enabled
			var auto_check: Result = AutoExplore.can_set(screen.state, screen.state.player_id, fid, setting)
			var auto_button: SfButton = SfButton.make("ui.auto_explore.enable" if setting else "ui.auto_explore.disable", "", SfButton.SECONDARY)
			auto_button.name = "AutoExplore_" + fid
			auto_button.disabled = not auto_check.ok
			auto_button.pressed.connect(_set_auto.bind(screen, d, fid, setting, Game.session_serial))
			card.add_body(auto_button)
			if not auto_check.ok: card.add_body(GameUI.refusal(auto_check))
		var location: String = screen.system_label(fleet.system_id)
		if not fleet.path.is_empty():
			card.add_text(Strings.fmt("ui.travel.en_route", {"system": screen.system_label(fleet.path[-1])}), &"SecondaryLabel").set_meta("audit_numeric_ok", "unknown star marker identifier")
			var route_names: Array[String] = []
			for step: String in fleet.path:
				route_names.append(screen.system_label(step))
			card.add_text(Strings.fmt("ui.travel.via", {"route": " → ".join(route_names)}), &"CaptionLabel").set_meta("audit_numeric_ok", "unknown star marker identifier")
			if Travel.route_valid(screen.state, fleet):
				var remaining: Breakdown = Travel.remaining_eta(screen.state, fid)
				var remaining_label: Label = GameUI.caption(Strings.fmt("ui.travel.remaining", {"turns": str(remaining.total)}))
				card.add_body(Explainable.wrap(remaining_label, remaining))
			else:
				card.add_text(Strings.fmt("report.fleet_route_blocked"), &"CaptionLabel")
			var next_label: Label = card.add_text(Strings.fmt("ui.travel.stop_at", {"system": screen.system_label(fleet.path[0])}), &"StrongLabel")
			next_label.set_meta("audit_numeric_ok", "unknown star marker identifier")
			card.add_text(Strings.fmt("ui.travel.stop_hint"), &"CaptionLabel")
			var stop_check: Result = Travel.can_stop(screen.state, screen.state.player_id, fid)
			var stop: SfButton = SfButton.make("ui.travel.stop_action", "", SfButton.SECONDARY)
			stop.name = "StopFleet_" + fid
			stop.disabled = not stop_check.ok
			stop.pressed.connect(_stop.bind(screen, d, fid, Game.session_serial))
			card.add_body(stop)
			if not stop_check.ok: card.add_body(GameUI.refusal(stop_check))
		else:
			card.add_text(Strings.fmt("ui.travel.at", {"system": location}), &"SecondaryLabel")
			var has_route: bool = false
			for destination: String in DictIO.sorted_keys(screen.state.systems):
				var check: Result = Travel.can_move(screen.state, screen.state.player_id, fid, destination)
				if not check.ok: continue
				has_route = true
				var row: VBoxContainer = VBoxContainer.new()
				var button: SfButton = SfButton.make("ui.travel.open", "emblem_compass", SfButton.SECONDARY)
				button.name = "Move_" + fid + "_" + destination
				var destination_label: Label = FlowScreen.label(screen.system_label(destination), &"StrongLabel")
				destination_label.set_meta("audit_numeric_ok", "unknown star marker identifier")
				row.add_child(destination_label)
				button.text = Strings.fmt("ui.travel.action")
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.pressed.connect(_move.bind(screen, d, fid, destination, Game.session_serial))
				row.add_child(button)
				var eta: Breakdown = Travel.eta(screen.state, fid, destination)
				var label: Label = GameUI.caption(Strings.fmt("ui.travel.eta", {"turns": str(eta.total)}))
				row.add_child(Explainable.wrap(GameUI.exempt(label, "travel time from simulation breakdown"), eta))
				card.add_body(row)
			if not has_route:
				card.add_text(Strings.fmt("ui.travel.no_routes"), &"CaptionLabel")
		d.body.add_child(card)
	if count == 0:
		d.body.add_child(GameUI.caption(Strings.fmt("ui.travel.none")))
	d.open()


static func _move(screen: GameScreen, drawer: Drawer, fleet_id: String, destination: String, session: int) -> void:
	if not is_instance_valid(screen) or not screen.is_inside_tree() or Game.session_serial != session:
		return
	drawer.close()
	screen.order(MoveFleetCommand.create(screen.state.player_id, fleet_id, destination))


static func _set_auto(screen: GameScreen, drawer: Drawer, fleet_id: String, enabled: bool, session: int) -> void:
	if not is_instance_valid(screen) or not screen.is_inside_tree() or Game.session_serial != session:
		return
	drawer.close()
	screen.order(SetAutoExploreCommand.create(screen.state.player_id, fleet_id, enabled))


static func _stop(screen: GameScreen, drawer: Drawer, fleet_id: String, session: int) -> void:
	if not is_instance_valid(screen) or not screen.is_inside_tree() or Game.session_serial != session or not is_instance_valid(drawer) or not drawer.is_inside_tree() or drawer._closing:
		return
	drawer.close()
	screen.order(StopFleetCommand.create(screen.state.player_id, fleet_id))
