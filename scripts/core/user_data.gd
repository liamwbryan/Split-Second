extends Node
## Autoload (first in the list). The game was renamed from "Parkour Shooter"
## to "Split Second" (2026-09-26). Godot keys user:// to the project name, so
## on the first run under the new name this copies saved settings and course
## records across from the old folder. It never overwrites or deletes.

const OLD_NAME := "Parkour Shooter"
const FILES := ["records.cfg", "graphics.cfg"]


func _init() -> void:
	# _init, not _ready: runs before any other autoload reads user://.
	migrate()


static func migrate() -> void:
	var here := OS.get_user_data_dir()
	var old := here.get_base_dir().path_join(OLD_NAME)
	if old == here or not DirAccess.dir_exists_absolute(old):
		return
	DirAccess.make_dir_recursive_absolute(here)
	for f: String in FILES:
		var src := old.path_join(f)
		var dst := here.path_join(f)
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(src, dst)
