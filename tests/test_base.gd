extends RefCounted
## Base minimale des tests : chaque méthode « test_* » est exécutée par run_tests.gd.

var failures: Array[String] = []
var _current := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s : %s" % [_current, message])


func run_all() -> int:
	var count := 0
	for m in get_method_list():
		var method: String = m["name"]
		if method.begins_with("test_"):
			_current = method
			var started := Time.get_ticks_msec()
			call(method)
			print("  %s (%d ms)" % [method, Time.get_ticks_msec() - started])
			count += 1
	return count


func load_data() -> GameData:
	var gd := GameData.load_file()
	check(gd.is_valid(), "données invalides : " + gd.error)
	return gd
