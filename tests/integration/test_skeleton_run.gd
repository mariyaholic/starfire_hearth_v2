extends RefCounted
## 50 turns of Scenario 1 with bots (§9.8 integration): no errors, no invariant violations,
## deterministic, and stable across save and load, with the whole M1 economy, event engine and
## the bots' orders running.

const SCENARIO: String = "s1_first_light"
const TURNS: int = 50


func test_balanced_bot_runs_clean(t: T) -> void:
	var db: ContentDb = ContentDb.load_from()
	var run: BotRunner.Run = BotRunner.run(db, SCENARIO, "balanced", 7, TURNS)
	t.empty(run.problems, "invariant problems")
	t.eq(run.turns.size(), TURNS)
	t.eq(run.final_state.turn, 1 + TURNS)


func test_random_legal_bot_is_deterministic(t: T) -> void:
	var db: ContentDb = ContentDb.load_from()
	var a: BotRunner.Run = BotRunner.run(db, SCENARIO, "random-legal", 3, TURNS)
	var b: BotRunner.Run = BotRunner.run(db, SCENARIO, "random-legal", 3, TURNS)
	t.empty(a.problems)
	t.eq(a.hashes, b.hashes, "same seed, same policy, same hashes every turn")
	var taken: int = 0
	for row: Dictionary in a.turns:
		taken += int(row["decisions_taken"])
	t.ok(taken > 0, "the random bot actually gave orders (%d)" % taken)
	var c: BotRunner.Run = BotRunner.run(db, SCENARIO, "random-legal", 4, TURNS)
	t.ne(c.hashes[TURNS], a.hashes[TURNS], "a different seed plays differently")


func test_scenario_one_start_state(t: T) -> void:
	var s: GameState = ScenarioLoader.build(ContentDb.load_from(), SCENARIO, 11)
	t.empty(Invariants.check(s))
	t.eq(s.systems.size(), 7, "Ember plus six neighbours under fog")
	t.eq(s.planets.size(), 5)
	var aster: Colony = s.colonies[s.planets["pl_aster"].colony_id]
	t.eq(aster.pops, 10)
	t.eq(aster.districts.size(), 6)
	t.eq(s.player().stock["minerals"], 25000, "250 minerals")
	t.eq(s.player().known_systems.keys(), ["sys_ember"])
	t.eq(s.systems["sys_ember"].owner_id, s.player_id)


func test_save_and_load_mid_game_keeps_the_hash(t: T) -> void:
	var db: ContentDb = ContentDb.load_from()
	var run: BotRunner.Run = BotRunner.run(db, SCENARIO, "random-legal", 5, 20)
	var text: String = SaveSerializer.to_text(run.final_state, "test")
	var lr: SaveSerializer.LoadResult = SaveSerializer.from_text(text)
	t.ok(lr.ok, lr.error_detail)
	t.eq(lr.state.state_hash(), run.hashes[20])
