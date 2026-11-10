extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	root.add_child(screen)
	var message := screen.get_node_or_null("Message") as Label
	var background := screen.get_node_or_null("Background") as ColorRect
	if not screen is Control or message == null or background == null:
		push_error("Setup screen is incomplete")
		quit(1)
		return
	if message.text != "PocketPuzzle\nSetup complete":
		_fail("Startup message is incorrect")
		return
	await process_frame
	if (screen as Control).size.x <= 0 or (screen as Control).size.y <= 0:
		_fail("Startup screen has no layout area")
		return
	print("PASS: portrait Compatibility startup scene loads and instantiates")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
