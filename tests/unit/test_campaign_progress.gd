extends RefCounted
## Campaign progress (§10.1): order, unlocks, wins, legacy picks and the saved form.

const S1: String = "s1_first_light"
const S2: String = "s2_the_crossing"
const S3: String = "s3_neighbours"


func test_failed_atomic_write_keeps_prior_file_and_notifies(t: T) -> void:
	var dir: String = "user://campaign_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("campaign.json")
	var p: CampaignProgress = CampaignProgress.load_file(path)
	p.set_difficulty("hard")
	var prior: String = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_recursive_absolute(path + ".pending")
	var failures: Array[int] = []
	p.persistence_failed.connect(func(revision: int) -> void: failures.append(revision))
	p.record_win(S1)
	t.ok(p.is_won(S1), "failed disk write does not discard the live win")
	t.eq(failures.size(), 1, "failure is reported")
	t.eq(FileAccess.get_file_as_string(path), prior, "failed write preserves the previous file")
	DirAccess.remove_absolute(path + ".pending")
	p.pick_legacy(S1, "steady_hands")
	t.eq(CampaignProgress.load_file(path).legacy_of(S1), "steady_hands", "a later successful write saves live progress")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


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


func test_preview_does_not_change_campaign(t: T) -> void:
	var p: CampaignProgress = CampaignProgress.new()
	p.record_win(S1)
	p.pick_legacy(S1, "steady_hands")
	var before: Dictionary = p.to_dict()
	p.record_win("m2a_expedition")
	p.pick_legacy("m2a_expedition", "archive_scholars")
	t.eq(p.to_dict(), before, "preview cannot record campaign progress")
	t.eq(p.carried_legacies("m2a_expedition"), [] as Array[String], "preview inherits no campaign legacies")
	t.not_ok(p.is_unlocked(S3), "preview cannot unlock S3")
	t.eq(CampaignProgress.ORDER, [S1, S2, S3] as Array[String])
