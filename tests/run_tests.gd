extends SceneTree
## Lance tous les tests : godot --headless --path . --script res://tests/run_tests.gd

const SUITES := [
	"res://tests/unit/test_data.gd",
	"res://tests/unit/test_rules.gd",
	"res://tests/unit/test_mechanics.gd",
	"res://tests/unit/test_coop.gd",
	"res://tests/unit/test_combat.gd",
	"res://tests/unit/test_feats.gd",
	"res://tests/unit/test_money.gd",
	"res://tests/unit/test_layout.gd",
	"res://tests/unit/test_support.gd",
	"res://tests/unit/test_powers.gd",
	"res://tests/unit/test_elements.gd",
	"res://tests/unit/test_traits.gd",
	"res://tests/unit/test_specs.gd",
	"res://tests/unit/test_talents.gd",
	"res://tests/unit/test_accounts.gd",
	"res://tests/unit/test_history.gd",
	"res://tests/unit/test_transfer.gd",
	"res://tests/unit/test_balance.gd",
	"res://tests/unit/test_network_data.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	for path in SUITES:
		if not ResourceLoader.exists(path):
			printerr("Suite absente : ", path)
			failed += 1
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("Suite impossible à charger : ", path)
			failed += 1
			continue
		var suite = script.new()
		var n: int = suite.run_all()
		total += n
		for f in suite.failures:
			printerr("ÉCHEC ", path.get_file(), " > ", f)
		failed += suite.failures.size()
		print("%s : %d tests, %d échec(s)" % [path.get_file(), n, suite.failures.size()])
	print("TOTAL : %d tests, %d échec(s)" % [total, failed])
	quit(1 if failed > 0 else 0)
