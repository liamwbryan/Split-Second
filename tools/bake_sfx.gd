extends SceneTree
## Bakes the synthesized placeholder sounds to assets/sfx/*.wav.
## Run: godot --headless --path . -s res://tools/bake_sfx.gd
func _initialize() -> void:
	var sfx: Node = root.get_node("Sfx")
	sfx.bake(ProjectSettings.globalize_path("res://assets/sfx"))
	print("baked sfx")
	quit()
