extends Node
## Autoload « Settings » : réglages du joueur (pseudo, dernière IP) sauvegardés en JSON.
## Le fichier est relu avec validation : au moindre champ invalide, il est ignoré en entier.

const PATH := "user://settings.json"
const MAX_SIZE := 4096

var player_name := ""
var last_ip := ""


func _init() -> void:
	player_name = "Joueur %d" % (randi() % 900 + 100)
	_load()


func set_player_name(value: String) -> void:
	var clean := Check.sanitize_name(value)
	if clean != "" and clean != player_name:
		player_name = clean
		_save()


func set_last_ip(value: String) -> void:
	if Check.is_ipv4(value) and value != last_ip:
		last_ip = value
		_save()


func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null or f.get_length() > MAX_SIZE:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = json.data
	var n := Check.sanitize_name(d.get("name"))
	var ip = d.get("last_ip", "")
	if n == "" or typeof(ip) != TYPE_STRING or (ip != "" and not Check.is_ipv4(ip)):
		return
	player_name = n
	last_ip = ip


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"name": player_name, "last_ip": last_ip}))
