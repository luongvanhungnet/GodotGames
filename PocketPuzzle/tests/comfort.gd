extends SceneTree
const Hint = preload("res://game/puzzle_hint.gd")
const Parcel = preload("res://game/parcel_rules.gd")
const Block = preload("res://game/block_rules.gd")
const Records = preload("res://game/player_records.gd")
const TEST_SAVE := "user://pocketpuzzle-comfort-test.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)

func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Comfort checks timed out"); quit(1))
	var levels: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/levels.json"))
	for mode in ["parcel", "block"]:
		for level in levels[mode]:
			var live = Parcel.new() if mode == "parcel" else Block.new()
			live.setup(level)
			for step in range(level.solution.size()):
				if step == 0 or step == int(level.solution.size() / 2):
					var before := Hint.state_key(mode, live)
					var history: int = live.history.size()
					var suggestion := Hint.suggest(mode, level, live)
					_check(suggestion.get("kind") == "move", "Every catalogue level provides a hint at start and midway")
					_check(Hint.state_key(mode, live) == before and live.history.size() == history, "Hint must not mutate puzzle or undo history")
					if suggestion.get("kind") == "move":
						var action: Array = suggestion.action
						var accepted: bool = live.send(action[0]) if mode == "parcel" else live.move_piece(action[0], Vector2i(action[1], action[2]))
						_check(accepted, "Hint is a legal move")
						live.undo()
				var entry = level.solution[step]
				if mode == "parcel":
					live.send(int(entry))
				else:
					live.move_piece(int(entry[0]), Vector2i(int(entry[1]), int(entry[2])))
			_check(Hint.suggest(mode, level, live).is_empty(), "Completed levels offer no extra move")
	var parcel = Parcel.new()
	parcel.setup(levels.parcel[1])
	parcel.send(2)
	var backtrack := Hint.suggest("parcel", levels.parcel[1], parcel)
	_check(backtrack.get("kind") == "undo" and backtrack.get("count") == 1, "Off-route hints explain backtracking instead of inventing a move")
	parcel.undo()
	_check(Hint.suggest("parcel", levels.parcel[1], parcel).get("kind") == "move", "Undo restores a forward hint")
	parcel.send(2)
	parcel.send(2)
	_check(Hint.suggest("parcel", levels.parcel[1], parcel).get("count") == 2, "Backtracking reports the full distance to a verified state")
	var block = Block.new()
	block.setup(levels.block[0])
	block.move_piece(0, Vector2i.RIGHT)
	_check(Hint.suggest("block", levels.block[0], block).get("kind") == "undo", "Block detours also offer safe undo guidance")
	var invalid: Dictionary = levels.parcel[1].duplicate(true)
	invalid.solution = [0]
	_check(Hint.suggest("parcel", invalid, parcel).is_empty(), "Incomplete catalogue solutions cannot produce misleading hints")
	var old = Records.new()
	old.restore({"settings": {"sound": false, "vibration": true}}, {"parcel": 150, "block": 150})
	_check(not old.settings.sound and old.settings.vibration and not old.settings.reduced_motion and not old.settings.clear_symbols, "Older preferences migrate with new settings off")
	await _test_ui()
	if failures == 0:
		print("PASS: verified hints for all 300 levels, safe backtracking, comfort preferences, resume and reduced animation (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _test_ui() -> void:
	_cleanup()
	var scene = load("res://node_2d.tscn")
	var screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	root.add_child(screen)
	screen.start_level("parcel", 1)
	screen.show_hint()
	_check(screen.board.guide_lane == 0 and screen.attempt_moves == 0 and screen.undo_count == 0 and screen.records.ranking()[0].score == 0, "UI hints highlight a queue without moves, undo or rewards")
	screen.play_move(2, Vector2i.ZERO)
	_check(screen.board.guide_lane == -1, "A successful move clears stale hint highlights")
	screen.show_hint()
	_check(screen.status_label.text.contains("Undo 1") and screen.attempt_moves == 1, "Off-route UI asks for undo without applying it")
	screen.undo_move()
	screen.show_settings()
	screen._toggle_setting("reduced_motion")
	screen._toggle_setting("clear_symbols")
	screen.resume_saved("parcel")
	_check(screen.board.reduced_motion and screen.board.clear_symbols and screen.attempt_moves == 1 and screen.undo_count == 1, "Comfort settings apply on resume without resetting counters")
	screen.play_move(1, Vector2i.ZERO)
	_check(screen.board.flash == 0 and not screen.board.is_processing(), "Reduced motion prevents move animation")
	screen.start_level("block", 0)
	screen.show_hint()
	_check(screen.board.selected == 0 and screen.board.guide_piece == 0 and screen.status_label.text.contains("down") and screen.attempt_moves == 0, "Block hint selects the pal and explains direction")
	var art = screen._art("victory", Vector2(200, 150))
	screen.add_child(art)
	_check(not art.is_processing(), "Reduced motion keeps victory mascots still")
	art.queue_free()
	screen.start_tutorial("parcel")
	screen.show_hint()
	_check(screen.hint_button.disabled and screen.board.guide_lane == 1, "Tutorial retains its own guide")
	screen.show_home()
	screen.queue_free()
	await process_frame
	screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	root.add_child(screen)
	_check(screen.records.settings.reduced_motion and screen.records.settings.clear_symbols, "Comfort preferences survive app reload")
	screen.open_daily("block")
	screen.show_hint()
	_check(screen.board.guide_piece >= 0 and screen.attempt_moves == 0 and screen.records.current().daily_results.is_empty(), "Daily hints do not award results or moves")
	screen.queue_free()
	await process_frame
	_cleanup()
