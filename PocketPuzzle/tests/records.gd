extends SceneTree
const Records = preload("res://game/player_records.gd")
const Clock = preload("res://game/solve_clock.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var clock = Clock.new()
	clock.start(1000)
	clock.tick(1500)
	_check(clock.elapsed_ms == 500, "Clock includes thinking before the first move")
	clock.pause(2000)
	clock.pause(5000)
	clock.tick(10000)
	_check(clock.elapsed_ms == 1000, "Repeated pause and background time do not count")
	clock.resume(12000)
	clock.tick(12100)
	clock.finish(12200)
	clock.tick(99999)
	_check(clock.elapsed_ms == 1200 and not clock.running, "Clock stops at the winning move")
	clock.start(100000)
	_check(clock.elapsed_ms == 0 and clock.running, "Restart resets solve time")
	_check(Clock.format_time(61099) == "01:01.0" and Clock.format_time(3600100) == "60:00.1", "Time format supports long sessions")
	_check(Records.score_for(1000, 10, 0) > Records.score_for(10000, 10, 0), "Faster solves earn more points")
	_check(Records.score_for(1000, 10, 0) > Records.score_for(1000, 11, 0), "Fewer moves earn more points")
	_check(Records.score_for(1000, 10, 0) > Records.score_for(1000, 10, 1), "Undo carries a score penalty")
	_check(Records.score_for(99999999, 999999, 9999) == 1000 and Records.score_for(0, 0, 0) == 0, "Score has a completion floor and rejects an empty solve")
	var records = Records.new()
	var first_id: String = records.active_id
	var first: Dictionary = records.record("parcel", 0, 5000, 10, 0)
	var original: int = first.score
	records.record("parcel", 0, 10000, 40, 2)
	records.record("parcel", 0, 1000, 20, 0)
	records.record("parcel", 0, 20000, 8, 0)
	var best: Dictionary = records.best("parcel", 0)
	_check(best.high_score == original and best.best_time_ms == 1000 and best.fewest_moves == 8 and best.solves == 4, "High score, fastest time, and fewest moves are independent records")
	_check(records.ranking()[0].score == original and records.ranking()[0].completed == 1, "Replaying a level does not farm total score")
	records.current().progress.parcel.append(0)
	var second_id: String = records.add_player("Mina")
	_check(not second_id.is_empty() and records.current().progress.parcel.is_empty() and records.best("parcel", 0).is_empty(), "New player has independent progress and records")
	_check(records.add_player(" mina ").is_empty() and records.add_player("  ").is_empty(), "Reject duplicate and empty names")
	_check(records.rename_current("Mina Park") and not records.rename_current("Player 1"), "Rename preserves unique local names")
	records.record("block", 149, 4000, 7, 0)
	_check(records.ranking("parcel")[0].id == first_id and records.ranking("block")[0].id == second_id, "Rankings can filter by game")
	var restored = Records.new()
	restored.restore(JSON.parse_string(JSON.stringify(records.to_data())), {"parcel": 150, "block": 150})
	_check(restored.active_id == second_id and restored.players.size() == 2 and not restored.best("block", 149).is_empty(), "Profiles and records survive a JSON round trip")
	restored.select_player(first_id)
	_check(restored.best("parcel", 0).high_score == original and restored.current().progress.parcel == [0], "Switching profiles preserves previous data")
	var legacy = Records.new()
	legacy.restore({"parcel": [0, 29, 29, -1, 150, 2.5, "3"], "block": [1], "last_parcel": 29}, {"parcel": 150, "block": 150})
	_check(legacy.current().progress.parcel == [0, 29] and legacy.current().progress.block == [1] and legacy.current().progress.last_parcel == 29, "Old completion saves migrate without inventing scores")
	_check(legacy.ranking()[0].score == 0, "Legacy unscored completions are not ranked as scored wins")
	var damaged := {"players": [{"id": "p9", "name": "Alex", "progress": [], "results": {"parcel": {"0": {"high_score": -1}, "999": {}}}}, {"id": "p9", "name": "Duplicate"}], "active_player": "missing"}
	legacy.restore(damaged, {"parcel": 150, "block": 150})
	_check(legacy.players.size() == 1 and legacy.active_id == "p9" and legacy.best("parcel", 0).is_empty(), "Malformed records and duplicate IDs are ignored safely")
	_check(legacy.add_player("Next") == "p10", "Restored IDs cannot collide with new players")
	var ties = Records.new()
	ties.record("parcel", 0, 5000, 10, 0)
	ties.add_player("Second")
	ties.record("parcel", 0, 5000, 10, 0)
	_check(ties.ranking()[0].rank == 1 and ties.ranking()[1].rank == 1, "Exactly equal players share a rank")
	ties.add_player("Leader")
	ties.record("parcel", 0, 1, 1, 0)
	_check(ties.ranking()[0].rank == 1 and ties.ranking()[1].rank == 2 and ties.ranking()[2].rank == 2, "Tied ranks remain stable behind a leader")
	for i in range(5):
		ties.add_player("Extra %d" % i)
	_check(ties.players.size() == 8 and ties.add_player("Ninth").is_empty(), "Local profile list is bounded")
	if failures == 0:
		print("PASS: active solve timer, scoring, best records, rankings, profile isolation, migration, and persistence (%d checks)" % checks)
	quit(0 if failures == 0 else 1)
