extends SceneTree
## Convert the source-controlled SVG mascot to the PNG required by boot_splash.
## Run from PocketPuzzle: godot --headless --path . --script tools/bake_splash.gd
func _initialize() -> void:
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"))
	if error != OK:
		push_error("Could not rasterize the SVG mascot")
		quit(1)
		return
	image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	error = image.save_png("res://assets/ui/splash.png")
	if error != OK:
		push_error("Could not save the boot splash")
		quit(1)
		return
	print("Saved assets/ui/splash.png from icon.svg")
	quit()
