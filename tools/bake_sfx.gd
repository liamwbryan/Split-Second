extends SceneTree
## Bakes the synthesized placeholder sounds to assets/sfx/*.wav.
## Run: godot --headless --path . -s res://tools/bake_sfx.gd [-- --overwrite]
## Only missing sounds are written unless --overwrite is passed.
func _initialize() -> void:
	var sfx: Node = root.get_node("Sfx")
	sfx.bake(ProjectSettings.globalize_path("res://assets/sfx"), OS.get_cmdline_user_args().has("--overwrite"))
	print("baked sfx")
	quit()
