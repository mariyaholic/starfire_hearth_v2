extends RefCounted

func test_save_without_player_is_rejected_and_retry_recovers(t: T) -> void:
	var original: GameState = S1.build()
	var original_hash: String = original.state_hash()
	var missing_player: GameState = original.clone()
	missing_player.player_id = ""
	for state: GameState in [missing_player, GameState.new()]:
		var result: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(state, "review"))
		t.not_ok(result.ok, "a load offered to Continue must resolve a player")
		t.eq(result.error_key, "save.error.corrupt")
		t.ok(result.state == null, "failed load exposes no partial state")
	var retried: SaveSerializer.LoadResult = SaveSerializer.from_text(SaveSerializer.to_text(original, "review"))
	t.ok(retried.ok, retried.error_detail)
	if retried.ok:
		t.eq(retried.state.state_hash(), original_hash, "failed loads do not poison a valid retry")
	t.eq(original.state_hash(), original_hash, "loading never changes the live source state")
