extends Node
## Autoload « Settings » : réglages de l'appareil (dernière IP, dernier compte ouvert) sauvegardés
## en JSON. Le fichier est relu avec validation : au moindre champ invalide, il est ignoré en entier.
## Le pseudo appartient désormais au compte : « name » n'est plus que relu (ancien format), pour
## nommer le compte créé à partir de l'ancienne progression.

const PATH := "user://settings.json"
const MAX_SIZE := 4096

var last_ip := ""
var last_account := ""
## Pseudo de l'ancien format (vide sinon).
var legacy_name := ""


func _init() -> void:
	_load()


func set_last_ip(value: String) -> void:
	if Check.is_ipv4(value) and value != last_ip:
		last_ip = value
		_save()


func set_last_account(id: String) -> void:
	if (id == "" or Check.is_valid_id(id)) and id != last_account:
		last_account = id
		_save()


func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null or f.get_length() > MAX_SIZE:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = json.data
	var n = d.get("name", "")
	var ip = d.get("last_ip", "")
	var account = d.get("account", "")
	if typeof(n) != TYPE_STRING or (n != "" and Check.sanitize_name(n) == ""):
		return
	if typeof(ip) != TYPE_STRING or (ip != "" and not Check.is_ipv4(ip)):
		return
	if typeof(account) != TYPE_STRING or (account != "" and not Check.is_valid_id(account)):
		return
	legacy_name = Check.sanitize_name(n)
	last_ip = ip
	last_account = account


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"last_ip": last_ip, "account": last_account}))
