extends "res://tests/test_base.gd"
## Chargement et validation des données, calcul des chemins.


func test_bundled_data_is_valid() -> void:
	var gd := load_data()
	check(gd.maps.size() == 10, "10 cartes attendues")
	check(gd.builders.size() == 4 and gd.modifiers.size() == 4, "4 bâtisseurs et 4 vagues spéciales")
	check(gd.tower_order.size() == 8, "8 tourelles attendues")
	check(gd.difficulties.size() == 4 and gd.specials.size() == 4, "4 difficultés et 4 cases spéciales")
	check(gd.sendable_monsters().size() == 11, "11 monstres envoyables : %d" % gd.sendable_monsters().size())
	for id in gd.tower_order:
		check(gd.tower_levels(id).size() == 5, "%s : 5 niveaux" % id)


func test_paths_follow_the_route() -> void:
	var gd := load_data()
	for m in gd.maps:
		for p in m.start_count():
			var pts: PackedVector2Array = m.ground_paths[p]
			var start := Vector2i(pts[0].floor())
			var end := Vector2i(pts[pts.size() - 1].floor())
			check(m.cell_at(start) == MapDef.Cell.START, "%s : le chemin part d'un S" % m.id)
			check(m.cell_at(end) == MapDef.Cell.END, "%s : le chemin finit sur un E" % m.id)
			for i in range(1, pts.size()):
				var d := pts[i] - pts[i - 1]
				check(is_zero_approx(d.x) or is_zero_approx(d.y), "%s : segment non orthogonal" % m.id)


func test_prairie_path_length() -> void:
	var gd := load_data()
	var prairie: MapDef = gd.maps[0]
	# 12 + 3 + 9 + 3 + 12 cases entre les centres du départ et de l'arrivée
	check(is_equal_approx(prairie.path_length(0, false), 39.0), "longueur %f" % prairie.path_length(0, false))
	var mid := prairie.position_at(0, 12.0, false)
	check(mid.is_equal_approx(Vector2(12.5, 1.5)), "position au virage %s" % mid)


func test_heritage_matches_legacy_route() -> void:
	var gd := load_data()
	var heritage: MapDef = gd.maps[2]
	# Route du prototype 2021 : 1, 11…18, 28, 38, 48…41, 51, 61, 71…78, 88 (30 cases)
	check(is_equal_approx(heritage.path_length(0, false), 29.0), "longueur %f" % heritage.path_length(0, false))


func test_rejects_unknown_monster_in_wave() -> void:
	var text := _bundled_text().replace("\"monster\": \"goblin\", \"count\": 8, \"interval\": 1.0", "\"monster\": \"ghost\", \"count\": 8, \"interval\": 1.0")
	var gd := GameData.from_text(text)
	check(not gd.is_valid() and gd.error.contains("ghost"), "erreur attendue : " + gd.error)
	check(gd.towers.is_empty(), "rien ne doit être appliqué")


func test_rejects_out_of_bounds_values() -> void:
	var gd := GameData.from_text(_bundled_text().replace("\"start_gold\": 150", "\"start_gold\": -5"))
	check(not gd.is_valid(), "or négatif refusé")
	gd = GameData.from_text(_bundled_text().replace("\"cost\": 50,", "\"cost\": 50.5,"))
	check(not gd.is_valid(), "coût non entier refusé")
	gd = GameData.from_text(_bundled_text().replace("\"flying\": false", "\"flying\": \"non\""))
	check(not gd.is_valid(), "booléen invalide refusé")


func test_rejects_broken_maps() -> void:
	var gd := GameData.from_text(_bundled_text().replace("\"S============...\"", "\"S============..\""))
	check(not gd.is_valid() and gd.error.contains("caractères"), "ligne trop courte : " + gd.error)
	gd = GameData.from_text(_bundled_text().replace("\"S============...\"", "\"S=====.======...\""))
	check(not gd.is_valid() and gd.error.contains("n'atteint"), "route coupée : " + gd.error)
	gd = GameData.from_text(_bundled_text().replace("\"S============...\"", "\"S============..X\""))
	check(not gd.is_valid() and gd.error.contains("inconnu"), "caractère inconnu : " + gd.error)


func test_rejects_duplicate_ids_and_bad_json() -> void:
	var gd := GameData.from_text(_bundled_text().replace("\"id\": \"cannon\"", "\"id\": \"crossbow\""))
	check(not gd.is_valid() and gd.error.contains("double"), "id en double : " + gd.error)
	gd = GameData.from_text("{ pas du json")
	check(not gd.is_valid(), "JSON invalide refusé")
	gd = GameData.from_text("[]")
	check(not gd.is_valid(), "racine non objet refusée")


func test_unknown_keys_are_dropped() -> void:
	var gd := GameData.from_text(_bundled_text().replace("\"start_gold\": 150", "\"start_gold\": 150, \"hack\": 1"))
	check(gd.is_valid(), "clé inconnue tolérée")
	check(not gd.player.has("hack"), "clé inconnue non recopiée")


func test_rejects_bad_specials_and_splits() -> void:
	var gd := GameData.from_text(_bundled_text().replace("\"split_into\": \"mini_slime\"", "\"split_into\": \"slime\""))
	check(not gd.is_valid() and gd.error.contains("diviser"), "division en cascade refusée : " + gd.error)
	gd = GameData.from_text(_bundled_text().replace("\"split_into\": \"mini_slime\"", "\"split_into\": \"fantome\""))
	check(not gd.is_valid() and gd.error.contains("inconnu"), "division vers un inconnu refusée : " + gd.error)
	gd = GameData.from_text(_bundled_text().replace("{ \"char\": \"^\"", "{ \"char\": \"=\""))
	check(not gd.is_valid() and gd.error.contains("symbole"), "symbole déjà pris refusé : " + gd.error)
	gd = GameData.from_text(_bundled_text().replace("\"lives\": 30", "\"lives\": 0"))
	check(not gd.is_valid(), "difficulté sans vie refusée")


func test_rejects_bad_builders_waves_and_zones() -> void:
	var text := _bundled_text()
	var cases := {
		"tourelle inconnue": ["\"towers\": [\"crossbow\", \"frost\", \"tesla\", \"venom\", \"sentinel\"]", "\"towers\": [\"crossbow\", \"laser\"]", "inconnue"],
		"rien contre l'air": ["\"towers\": [\"crossbow\", \"cannon\", \"ballista\", \"mortar\", \"sentinel\"]", "\"towers\": [\"cannon\", \"mortar\"]", "air"],
		"vague spéciale inconnue": ["\"modifier\": \"rush\"", "\"modifier\": \"tempete\"", "spéciale"],
		"zone hors limites": ["111111111111111.222222222222222", "111111111111111.555555555555555", "zones"],
		"ligne de zones trop courte": ["111111111111111.222222222222222", "1111.2222", "zones"],
		"joueurs conseillés inversés": ["\"min_players\": 2, \"max_players\": 4", "\"min_players\": 4, \"max_players\": 2", "min_players"],
		"plus de couloirs que de départs": ["\"lanes\": 4", "\"lanes\": 6", "couloirs"],
	}
	for label in cases:
		var c: Array = cases[label]
		check(text.contains(c[0]), "motif introuvable : " + label)
		var gd := GameData.from_text(text.replace(c[0], c[1]))
		check(not gd.is_valid() and gd.error.contains(c[2]), "%s refusé : %s" % [label, gd.error])
		check(gd.maps.is_empty() and gd.builders.is_empty(), "%s : rien n'est appliqué" % label)


func test_builders_and_modifiers() -> void:
	var gd := load_data()
	check(gd.builders[0]["towers"].size() == gd.tower_order.size(), "le premier bâtisseur connaît toutes les tourelles")
	check(gd.builder_allows(1, "cannon") and not gd.builder_allows(2, "cannon"), "tourelles par bâtisseur")
	check(not gd.builder_allows(99, "cannon"), "bâtisseur inconnu refusé")
	var s := gd.tower_stats("cannon", 0, -1, 1)
	check(is_equal_approx(s["damage"], 10.0 * 1.15), "bonus de dégâts de l'artilleur : %f" % s["damage"])
	check(gd.wave_modifier("w5")["id"] == "rush" and gd.wave_modifier("w1").is_empty(), "vagues spéciales")


func test_special_tiles_on_maps() -> void:
	var gd := load_data()
	var prairie: MapDef = gd.maps[0]
	var hill := 3 * prairie.width + 6
	check(prairie.special_at(hill) == 0 and prairie.is_buildable(hill), "colline constructible en (6, 3)")
	var s := gd.tower_stats("crossbow", 0, 0)
	check(is_equal_approx(s["range"], 2.5 * 1.25), "portée bonifiée : %f" % s["range"])
	check(is_equal_approx(gd.tower_stats("venom", 0, 1)["poison_dps"], 4 * 1.3), "le cristal renforce le poison")


func test_check_helpers() -> void:
	check(Check.sanitize_name("  Bob" + char(0x202E) + "\n  ") == "Bob", "pseudo nettoyé")
	check(Check.sanitize_name(12) == "", "pseudo non texte refusé")
	check(Check.sanitize_name("abcdefghijklmnopqrstuvwxyz").length() == Check.NAME_MAX, "pseudo coupé")
	check(Check.as_int(3.0, 0, 5) == 3 and Check.as_int(3.5, 0, 5) == null, "as_int")
	check(Check.as_int(INF, 0, 5) == null and Check.as_num(NAN, 0.0, 5.0) == null, "infini / NaN refusés")
	check(Check.is_lan_ipv4("192.168.1.20") and not Check.is_lan_ipv4("8.8.8.8"), "IP locale")
	check(not Check.is_ipv4("192.168.1") and not Check.is_ipv4("::1"), "IPv4 mal formée")


func _bundled_text() -> String:
	return FileAccess.get_file_as_string(GameData.DEFAULT_PATH)
