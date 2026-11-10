extends SceneTree
const Journey = preload("res://game/journey.gd")
const Records = preload("res://game/player_records.gd")
const TEST_SAVE := "user://pocketpuzzle-journey-test.json"
var failures := 0
var checks := 0

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
	create_timer(30).timeout.connect(func(): push_error("Journey tests timed out"); quit(1))
	_test_rewards()
	_test_migration()
	await _test_ui()
	if failures == 0:
		print("PASS: chapter maps, 20 stickers, 10 achievements, unique credit, daily history, avatars, migration, profile isolation and win rewards (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _test_rewards() -> void:
	var records = Records.new()
	_check(Journey.STICKERS.size() == 20 and Journey.ACHIEVEMENTS.size() == 10 and Journey.earned_ids(records.current()).is_empty(), "New profiles start with 20 earnable stickers and 10 badges")
	_check(not records.select_avatar("bunny_mail") and not records.select_avatar("unknown"), "Locked and unknown avatars cannot be selected")
	for index in range(3):
		records.record("parcel", index, 1000, 6, 0)
	_check(Journey.next_goal(records.current()).begins_with("2 more unique puzzles to unlock Bunny Mail"), "Next goal explains the exact remaining unique puzzle count")
	var earned := Journey.earned_ids(records.current())
	for replay in range(8):
		records.record("parcel", 0, 2000, 6, 0)
	_check(Journey.earned_ids(records.current()) == earned and Journey.metrics(records.current()).total == 3, "Replaying one puzzle cannot farm stickers or achievement progress")
	records.current().progress.parcel = [0, 1, 2, 2]
	_check(Journey.metrics(records.current()).total == 3, "Completion flags and score records credit the same puzzle once")
	for mode in ["parcel", "block"]:
		for level in range(150):
			records.record(mode, level, 1000, 6, 0)
		for chapter in range(5):
			_check(Journey.chapter_count(records.current(), mode, chapter) == 30, "Every chapter covers exactly 30 unique puzzles")
	_check(Journey.earned_ids(records.current()).size() == 18 and Journey.metrics(records.current()).total == 300, "Completing all regular levels earns all 18 regular stickers")
	for day in range(1, 8):
		records.record_daily("2026-11-%02d" % day, "parcel", 1000, 6, 0)
		records.record_daily("2026-11-%02d" % day, "block", 1000, 6, 0)
		records.record_daily("2026-11-%02d" % day, "parcel", 2000, 7, 1)
	_check(Journey.metrics(records.current()).daily == 7 and Journey.earned_ids(records.current()).size() == 20, "Daily replays and both games on one date count as one day; seven dates unlock the full album")
	var score: int = records.ranking()[0].score
	_check(records.select_avatar("bunny_mail") and records.ranking()[0].avatar == "bunny_mail" and records.ranking()[0].score == score, "An earned avatar appears in rankings without changing scores")
	for month in range(1, 5):
		for day in range(1, 29):
			records.record_daily("2027-%02d-%02d" % [month, day], "parcel", 1000, 6, 0)
	_check(records.current().daily_results.size() == 90 and records.current().journey.daily_dates.size() == 30 and Journey.earned_ids(records.current(), true).size() == 10, "Daily reward history is capped separately from 90-day records and keeps every badge earned")
	var first: String = records.active_id
	var copy = Records.new()
	copy.restore(JSON.parse_string(JSON.stringify(records.to_data())), {"parcel": 150, "block": 150})
	_check(copy.current().journey.avatar == "bunny_mail" and Journey.earned_ids(copy.current()).size() == 20 and Journey.earned_ids(copy.current(), true).size() == 10, "Avatar and all reward eligibility persist through JSON reload")
	copy.add_player("New Pal")
	_check(copy.current().journey.avatar.is_empty() and Journey.earned_ids(copy.current()).is_empty() and Journey.metrics(copy.current()).daily == 0, "Stickers, badges, avatars and daily credit remain private to each player")
	copy.select_player(first)
	_check(copy.select_avatar("") and copy.current().journey.avatar.is_empty(), "Players can return to the default avatar")

func _test_migration() -> void:
	var records = Records.new()
	records.restore({"parcel": [0, 1, 1, 2, -1, 150, 0.5], "block": [0]}, {"parcel": 150, "block": 150})
	_check(Journey.metrics(records.current()).total == 4 and Journey.earned_ids(records.current()).size() == 2 and Journey.earned_ids(records.current(), true).has("both_games"), "Legacy flags receive automatic unique-completion rewards without inventing scores")
	_check(records.ranking()[0].score == 0, "Migration never invents historical scores")
	var old := records.to_data()
	old.version = 3
	old.players[0].erase("journey")
	old.players[0].daily_results = {"2026-11-01": {"parcel": {"high_score": 1000, "best_time_ms": 1000, "fewest_moves": 6, "solves": 1}}, "2026-11-02": {"block": {"high_score": 1000, "best_time_ms": 1000, "fewest_moves": 7, "solves": 2}}}
	records.restore(old, {"parcel": 150, "block": 150})
	_check(Journey.metrics(records.current()).daily == 2 and Journey.unlocked(records.current(), "sun_chick"), "Existing retained daily records receive automatic date credit")
	var malformed := records.to_data()
	malformed.players[0].journey = {"avatar": "rainbow_unicorn", "daily_dates": ["bad", "2026-02-29", "2026-11-01", "2026-11-01", 5, {}]}
	records.restore(malformed, {"parcel": 150, "block": 150})
	_check(records.current().journey.avatar.is_empty() and records.current().journey.daily_dates.size() == 2, "Malformed dates, duplicates and unearned saved avatars are rejected")
	malformed.players[0].journey = {"avatar": {}, "daily_dates": {}}
	records.restore(malformed, {"parcel": 150, "block": 150})
	_check(records.current().journey.avatar.is_empty() and Journey.metrics(records.current()).daily == 2, "Invalid field types fall back safely while retaining valid historical records")

func _test_ui() -> void:
	_cleanup()
	var scene = load("res://node_2d.tscn")
	var screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	root.add_child(screen)
	_check(not quit_on_go_back, "Android automatic quit is disabled so the app can handle Back navigation")
	screen.show_album()
	screen._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(screen.screen_name == "home", "Back from the album returns to the collection")
	for mode in ["parcel", "block"]:
		screen.show_journey(mode)
		for chapter in range(5):
			var button = screen.page.find_child("VisitChapter%d" % chapter, true, false)
			_check(button != null and not button.disabled, "All five chapters are open even for a new player")
		var last = screen.page.find_child("VisitChapter4", true, false)
		last.pressed.emit()
		var grid = screen.page.find_children("*", "GridContainer", true, false)[0]
		_check(screen.screen_name == "levels" and grid.get_child_count() == 30 and grid.get_child(29).text == "150" and not grid.get_child(29).disabled, "Chapter map opens the exact level page without locking later levels")
	var seen := {}
	for number in range(5):
		screen.show_album(number)
		var grid = screen.page.find_child("AlbumGrid", true, false)
		_check(grid.get_child_count() == 4, "Album pages have four reachable sticker tiles")
		for tile in grid.get_children():
			seen[tile.name] = true
	_check(seen.size() == 20, "All 20 stickers are reachable through album pagination")
	screen.start_tutorial("parcel")
	for lane in [1, 0, 0, 1, 2, 2]:
		screen.play_move(lane, Vector2i.ZERO)
	await create_timer(0.5).timeout
	_check(Journey.earned_ids(screen.records.current()).is_empty() and screen._new_stickers.is_empty(), "Practice lessons cannot award progression rewards")
	screen.start_level("parcel", 0)
	for lane in screen.levels.parcel[0].solution:
		screen.play_move(int(lane), Vector2i.ZERO)
	_check(screen._new_stickers == ["happy_mail"] and screen._new_achievements == ["first_win"], "First real win credits a sticker and achievement before the animation")
	screen.show_home()
	screen._choose_avatar("happy_mail", 0)
	_check(screen.records.current().journey.avatar == "happy_mail", "Album selects an earned sticker as avatar")
	screen.start_level("parcel", 0)
	for lane in screen.levels.parcel[0].solution:
		screen.play_move(int(lane), Vector2i.ZERO)
	_check(screen._new_stickers.is_empty() and screen._new_achievements.is_empty(), "A replay cannot repeat the new-reward notification")
	screen.show_home()
	screen.queue_free()
	await process_frame
	screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	root.add_child(screen)
	_check(screen.records.current().journey.avatar == "happy_mail" and Journey.earned_ids(screen.records.current()) == ["happy_mail"], "Actual saved avatar and eligibility survive full scene reload")
	screen._add_daily_card()
	screen.show_album(2, true)
	_check(screen.page.find_child("AlbumGrid", true, false).get_child_count() == 2, "Final achievement page contains the remaining two badges")
	screen.queue_free()
	await process_frame
	_cleanup()
