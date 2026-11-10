extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20).timeout.connect(func(): _fail("UI smoke check timed out"))
	if ProjectSettings.get_setting("display/window/size/viewport_width") != 720 or ProjectSettings.get_setting("display/window/size/viewport_height") != 1280:
		_fail("Expected a 720 x 1280 portrait viewport")
		return
	if ProjectSettings.get_setting("display/window/handheld/orientation") != 1:
		_fail("Expected portrait orientation")
		return
	for key in ["rendering/renderer/rendering_method", "rendering/renderer/rendering_method.mobile"]:
		if ProjectSettings.get_setting(key) != "gl_compatibility":
			_fail("Expected Compatibility rendering: " + key)
			return
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		_fail("Startup scene is missing")
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("Startup scene could not be loaded")
		quit(1)
		return
	var screen := scene.instantiate()
	screen.save_path = "user://pocketpuzzle-smoke-progress.json"
	root.add_child(screen)
	var background := screen.get_node_or_null("Background") as ColorRect
	if not screen is Control or background == null or screen.levels.is_empty() or screen.screen_name != "home":
		push_error("Setup screen is incomplete")
		quit(1)
		return
	await process_frame
	if (screen as Control).size.x <= 0 or (screen as Control).size.y <= 0:
		_fail("Startup screen has no layout area")
		return
	for game_mode in ["parcel", "block"]:
		screen.start_level(game_mode, 0)
		await process_frame
		await process_frame
		if screen.board == null or screen.board.size.x <= 0 or screen.board.size.y <= 0:
			_fail("Missing playable board")
			return
		for action in screen.levels[game_mode][0].solution:
			if game_mode == "parcel":
				screen.play_move(int(action), Vector2i.ZERO)
			else:
				screen.play_move(int(action[0]), Vector2i(int(action[1]), int(action[2])))
		await create_timer(0.5).timeout
		if screen.screen_name != "result" or not screen.progress[game_mode].has(0):
			_fail("Win flow did not complete for " + game_mode)
			return
		screen.show_levels(game_mode)
		await process_frame
		if screen.screen_name != "levels":
			_fail("Level chooser did not open")
			return
	var reloaded := scene.instantiate()
	reloaded.save_path = screen.save_path
	root.add_child(reloaded)
	if not reloaded.progress.parcel.has(0) or not reloaded.progress.block.has(0):
		_fail("Completed levels did not persist")
		return
	reloaded.queue_free()
	screen.show_home()
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://pocketpuzzle-smoke-progress.json")
	print("PASS: portrait startup, both playable modes, win flows, level chooser, and saved progress")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
