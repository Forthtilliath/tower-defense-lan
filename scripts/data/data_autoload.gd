extends Node
## Autoload « Data » : données du jeu chargées une seule fois au démarrage.

var db: GameData


func _init() -> void:
	db = GameData.load_file()
	if not db.is_valid():
		push_error("Données du jeu invalides : " + db.error)
