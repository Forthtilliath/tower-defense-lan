extends Node
## Compile tous les scripts du projet (avec les autoloads chargés) et signale les erreurs.
## godot --headless --path . res://tests/check_scripts.tscn

func _ready() -> void:
	var failed := 0
	var scripts := _collect("res://scripts") + _collect("res://tests")
	for path in scripts:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("ERREUR DE SCRIPT : ", path)
			failed += 1
	print("%d scripts vérifiés, %d en erreur" % [scripts.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _collect(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_collect(dir.path_join(d)))
	return out
