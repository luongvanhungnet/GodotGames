extends SceneTree
const Search = preload("res://game/hint_search.gd")
const Hint = preload("res://game/puzzle_hint.gd")
const Progress = preload("res://game/puzzle_progress.gd")
const Parcel = preload("res://game/parcel_rules.gd")
const Block = preload("res://game/block_rules.gd")
const Records = preload("res://game/player_records.gd")
const TEST_SAVE := "user://pocketpuzzle-progression-test.json"
var failures := 0
var checks := 0
var catalogue: Dictionary

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

func _finish(job) -> void:
	for slice in range(3000):
		if job.done:
			return
		job.step(8, 2500)
	_check(false, "Hint job must finish within bounded slices")

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Progression checks timed out"); quit(1))
	catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/levels.json"))
	_test_catalogue()
	_test_search()
	await _test_ui()
	await _test_help()
	if failures == 0:
		print("PASS: bounded current-board hints, cancellation, difficulty estimates, verified move goals, safe next-puzzle selection and restart confirmation (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _test_catalogue() -> void:
	for mode in ["parcel", "block"]:
		var labels := {}
		for level in catalogue[mode]:
			var label := Progress.difficulty(mode, level)
			labels[label] = true
			_check(label in ["Gentle", "Tricky", "Challenging"], "Every level has a difficulty estimate")
			_check(Progress.reference_goal(mode, level) == level.solution.size(), "Every optional move goal has a replay-verified solution")
		_check(labels.size() == 3, "Each game spans all three estimated difficulty tiers")
	var invalid: Dictionary = catalogue.parcel[1].duplicate(true)
	invalid.solution = [0]
	_check(Progress.reference_goal("parcel", invalid) == 0, "Incomplete reference paths cannot create move goals")
	var records = Records.new()
	records.record("parcel", 0, 1000, 6, 0)
	records.record("parcel", 2, 1000, 6, 0)
	records.current().progress.parcel = [0, 2, 3]
	_check(Progress.next_unfinished(records.current(), "parcel") == 1, "Next puzzle fills the earliest gap using flags and records")
	for number in range(150):
		records.current().progress.parcel.append(number)
	_check(Progress.next_unfinished(records.current(), "parcel") == -1 and Progress.next_unfinished(records.current(), "block") == 0, "Completed games have no next level; other games remain independent")

func _test_search() -> void:
	var parcel = Parcel.new()
	parcel.setup(catalogue.parcel[1])
	parcel.send(2)
	var before := Hint.state_key("parcel", parcel)
	var history := JSON.stringify(parcel.history)
	var job = Search.new("parcel", catalogue.parcel[1], parcel)
	_check(not job.done, "A solvable off-route board starts incremental search")
	_finish(job)
	_check(job.result.get("kind") == "move" and job.result.get("source") == "search", "Off-route parcels receive a forward move instead of unnecessary undo")
	_check(before == Hint.state_key("parcel", parcel) and history == JSON.stringify(parcel.history), "Search preserves live board, counters and history")
	# Follow hints to completion from the detour, checking every suggestion.
	for move in range(20):
		if parcel.won():
			break
		job = Search.new("parcel", catalogue.parcel[1], parcel)
		_finish(job)
		if job.result.get("kind") != "move":
			break
		_check(parcel.send(job.result.action[0]), "Every searched parcel hint is legal")
	_check(parcel.won(), "Repeated current-board hints finish a solvable alternate parcel route")
	var block = Block.new()
	block.setup(catalogue.block[0])
	block.move_piece(0, Vector2i.RIGHT)
	job = Search.new("block", catalogue.block[0], block)
	_finish(job)
	_check(job.result.get("kind") == "move" and job.result.get("source") == "search", "Block detours also get a forward route")
	for move in range(20):
		if block.won():
			break
		job = Search.new("block", catalogue.block[0], block)
		_finish(job)
		if job.result.get("kind") != "move":
			break
		var action: Array = job.result.action
		_check(block.move_piece(action[0], Vector2i(action[1], action[2])), "Every searched block hint is legal")
	_check(block.won(), "Repeated current-board hints finish an alternate block route")
	parcel.setup(catalogue.parcel[1])
	parcel.send(2)
	job = Search.new("parcel", catalogue.parcel[1], parcel)
	job.state_limit = 1
	_finish(job)
	_check(job.reason == "limit" and job.result.get("kind") == "undo" and job.visited_count() <= 1, "State limit returns safe verified backtracking")
	job = Search.new("parcel", catalogue.parcel[1], parcel)
	job.work_limit_usec = 0
	_finish(job)
	_check(job.reason == "limit" and job.result.get("kind") == "undo", "Time limit returns safe backtracking without claiming unsolvability")
	# Representative later-level detours exercise bounded memory and slice reporting.
	for number in [29, 74, 149]:
		block.setup(catalogue.block[number])
		var moved := false
		for index in range(block.pieces.size()):
			for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
				if block.move_piece(index, direction):
					moved = true
					break
			if moved:
				break
		job = Search.new("block", catalogue.block[number], block)
		_finish(job)
		_check(job.done and job.visited_count() <= Search.MAX_STATES and job.result.get("kind") in ["move", "undo"], "Later-level searches finish within bounded state storage and retain a safe fallback")
		print("HINT PERF level=%d work_us=%d peak_slice_us=%d states=%d result=%s" % [number + 1, job.work_usec, job.peak_slice_usec, job.visited_count(), job.reason])
	var random := RandomNumberGenerator.new()
	random.seed = 8508
	block.setup(catalogue.block[149])
	for move in range(24):
		var options: Array = []
		for index in range(block.pieces.size()):
			for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
				if block.can_move(index, direction):
					options.append([index, direction])
		if options.is_empty() or block.won():
			break
		var chosen: Array = options[random.randi_range(0, options.size() - 1)]
		block.move_piece(chosen[0], chosen[1])
	job = Search.new("block", catalogue.block[149], block)
	_finish(job)
	_check(job.done and job.visited_count() <= Search.MAX_STATES, "A seeded deep detour remains bounded")
	print("HINT STRESS work_us=%d peak_slice_us=%d states=%d result=%s" % [job.work_usec, job.peak_slice_usec, job.visited_count(), job.reason])

func _wait_hint(screen) -> void:
	for frame in range(300):
		if screen._hint_job == null:
			return
		await process_frame
	_check(false, "UI hint must finish")

func _test_ui() -> void:
	_cleanup()
	var scene = load("res://node_2d.tscn")
	var screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	root.add_child(screen)
	_check(not screen.records.settings.move_goals, "Optional move goals default off")
	screen.start_level("parcel", 1)
	screen.play_move(2, Vector2i.ZERO)
	screen.show_hint()
	await _wait_hint(screen)
	_check(screen.board.guide_lane >= 0 and screen.attempt_moves == 1 and screen.undo_count == 0, "UI searched hint highlights a forward move without counters or rewards")
	screen.show_hint()
	screen.undo_move()
	_check(screen._hint_job == null and screen.board.guide_lane == -1, "Undo cancels pending or displayed hints")
	screen.play_move(2, Vector2i.ZERO)
	screen.show_hint()
	screen.show_home()
	_check(screen._hint_job == null, "Navigation cancels a pending hint")
	var pending: Dictionary = screen.records.current().sessions.parcel.duplicate(true)
	screen.find_next_puzzle("parcel")
	_check(screen.level_index == 1 and screen.attempt_moves == pending.moves and screen.active_actions == pending.actions, "Next-puzzle navigation resumes the saved attempt before choosing another")
	screen.show_settings()
	screen._toggle_setting("move_goals")
	screen.resume_saved("parcel")
	_check(screen.challenge_label.text.contains("Reference goal: 6") and screen.attempt_moves == pending.moves, "Move-goal toggle resumes the same attempt and displays its verified target")
	screen.restart_run()
	_check(is_instance_valid(screen._restart_dialog) and screen.solve_clock.paused, "Restart after moves prompts and pauses the active timer")
	var actions: Array = screen.active_actions.duplicate(true)
	var milliseconds: int = screen.solve_clock.elapsed_ms
	screen._finish_restart(false)
	_check(screen.active_actions == actions and screen.attempt_moves == pending.moves and screen.solve_clock.elapsed_ms == milliseconds and not screen.solve_clock.paused, "Cancel restart keeps exact board, counters and time")
	screen.restart_run()
	screen._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(screen.screen_name == "game" and not is_instance_valid(screen._restart_dialog) and screen.active_actions == actions, "Android Back cancels restart instead of discarding the game")
	screen.restart_run()
	screen._finish_restart(true)
	_check(screen.level_index == 1 and screen.attempt_moves == 0 and screen.undo_count == 0 and screen.active_actions.is_empty() and screen.solve_clock.elapsed_ms < 100, "Confirmed restart resets only this attempt")
	screen.start_level("parcel", 0)
	for action in catalogue.parcel[0].solution:
		screen.play_move(int(action), Vector2i.ZERO)
	await create_timer(0.5).timeout
	var score: int = screen.records.best("parcel", 0).high_score
	screen.find_next_puzzle("parcel")
	_check(screen.level_index == 1 and screen.attempt_moves == 0, "After a win, next-puzzle navigation selects the earliest unfinished level")
	screen.play_move(2, Vector2i.ZERO)
	screen.restart_run()
	screen._finish_restart(true)
	_check(screen.records.best("parcel", 0).high_score == score and screen.records.current().journey.avatar == "", "Restart leaves historical scores and player cosmetics intact")
	screen.show_home()
	screen.queue_free()
	await process_frame
	screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	root.add_child(screen)
	_check(screen.records.settings.move_goals and screen.records.best("parcel", 0).high_score == score, "Goals and historical scores persist through reload")
	screen.queue_free()
	await process_frame
	_cleanup()

func _test_help() -> void:
	var scene = load("res://node_2d.tscn").instantiate()
	scene.save_path = TEST_SAVE
	root.add_child(scene)
	await process_frame
	for game_mode in ["parcel", "block"]:
		for number in range(10):
			scene.start_level(game_mode, number)
			_check(not scene.OpeningGuide.text(game_mode, number).is_empty(), "Every opening puzzle has coaching")
		scene.start_level(game_mode, 0)
		var action = scene.levels[game_mode][0].solution[0]
		if game_mode == "parcel":
			scene.play_move(int(action), Vector2i.ZERO)
		else:
			scene.play_move(int(action[0]), Vector2i(int(action[1]), int(action[2])))
		scene.show_settings()
		var resume_key: String = scene._settings_return
		scene.show_help()
		_check(scene.screen_name == "help" and scene.attempt_moves == 1, "Help opens from paused Settings")
		scene.show_settings()
		_check(scene._settings_return == resume_key and not resume_key.is_empty(), "Help preserves puzzle return destination")
		scene.resume_saved(resume_key)
		_check(scene.screen_name == "game" and scene.attempt_moves == 1, "Return from Help preserves the unfinished move")
	scene.queue_free()
	await process_frame
	_cleanup()
