extends RefCounted
## Campaign progress (§10.1): order, unlocks, wins, legacy picks and the saved form.

const S1: String = "s1_first_light"
const S2: String = "s2_the_crossing"
const S3: String = "s3_neighbours"


func test_scenarios_unlock_in_order(t: T) -> void:
	var p: CampaignProgress = CampaignProgress.new()
	t.ok(p.is_unlocked(S1), "the first scenario is always open")
	t.not_ok(p.is_unlocked(S2), "the second waits for the first")
	t.not_ok(p.is_unlocked(S3), "the third waits for the second")
	t.not_ok(p.is_unlocked("no_such_scenario"), "unknown scenarios are never open")
	t.eq(p.previous_of(S2), S1)
	t.eq(p.previous_of(S1), "")
	p.record_win(S1)
	t.ok(p.is_won(S1))
	t.ok(p.is_unlocked(S2), "winning the first opens the second")
	t.not_ok(p.is_unlocked(S3))


func test_a_win_keeps_its_legacy_and_a_replay_can_change_it(t: T) -> void:
	var p: CampaignProgress = CampaignProgress.new()
	p.record_win(S1)
	t.eq(p.legacy_of(S1), "", "no legacy until one is picked")
	p.pick_legacy(S1, "steady_hands")
	p.record_win(S1)
	t.eq(p.legacy_of(S1), "steady_hands", "recording the same win again keeps the pick")
	p.pick_legacy(S1, "seasoned_farmers")
	t.eq(p.legacy_of(S1), "seasoned_farmers", "a replay's pick replaces the old one")
	t.eq(p.carried_legacies(S1), [] as Array[String], "the first scenario carries nothing")
	t.eq(p.carried_legacies(S2), ["seasoned_farmers"] as Array[String])
	p.record_win(S2)
	p.pick_legacy(S2, "archive_scholars")
	t.eq(p.carried_legacies(S3), ["seasoned_farmers", "archive_scholars"] as Array[String])


func test_round_trips_through_a_dictionary(t: T) -> void:
	var p: CampaignProgress = CampaignProgress.new()
	p.difficulty_id = "hard"
	p.record_win(S1)
	p.pick_legacy(S1, "steady_hands")
	var q: CampaignProgress = CampaignProgress.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.eq(q.difficulty_id, "hard")
	t.eq(q.legacy_of(S1), "steady_hands")
	t.ok(q.is_unlocked(S2))
	var junk: CampaignProgress = CampaignProgress.from_dict({"won": {"not_a_scenario": "x"}})
	t.not_ok(junk.is_won("not_a_scenario"), "unknown scenarios are dropped on load")
	t.eq(junk.difficulty_id, "normal", "the default difficulty")
