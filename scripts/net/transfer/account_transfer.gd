class_name AccountTransfer
extends RefCounted
## Transfert d'un compte d'un appareil à l'autre sur le réseau local (ex. PC → téléphone) :
## format des messages et leur validation. Le transport est dans AccountReceiver (l'appareil
## qui reçoit : port TCP ouvert, annonce UDP, code à 4 chiffres) et AccountSender.
##
## Annonce (UDP)   : {"g": "tdacct", "v": <version>, "n": <nom de l'appareil>}
## Offre (TCP)     : {"g": "tdacct", "code": "1234", "account": "<fichier de compte (ProgressFile)>"}
## Réponse (TCP)   : {"g": "tdacct", "ok": true|false, "error": "" | "code" | "invalid"}
## Tout message reçu est une donnée externe : taille bornée, JSON vérifié champ par champ, et le
## compte relu en entier par ProgressFile (rejeté à la première anomalie, clés inconnues ignorées).

const TCP_PORT := 47802
const UDP_PORT := 47803
const MAGIC := "tdacct"
const MAX_TRIES := 5
const BUFFER := 128 * 1024  # puissance de deux (PacketPeerStream), au-dessus de AccountStore.MAX_SIZE
const TIMEOUT_MS := 8000
const MAX_ANNOUNCE := 512


## Code à 4 chiffres, tiré par le générateur cryptographique.
static func new_code() -> String:
	var b := Crypto.new().generate_random_bytes(2)
	return "%04d" % (((b[0] << 8) | b[1]) % 10000)


## Nom de cet appareil montré à l'autre : modèle du téléphone, nom de l'ordinateur sur PC,
## sinon le système (« Windows »).
static func device_label() -> String:
	var label := ""
	if OS.has_feature("mobile"):
		label = Check.sanitize_name(OS.get_model_name())
	else:
		label = Check.sanitize_name(OS.get_environment("COMPUTERNAME"))
	return label if label != "" and label != "GenericDevice" else Check.sanitize_name(OS.get_name())


static func announce_bytes(label: String) -> PackedByteArray:
	var version := str(ProjectSettings.get_setting("application/config/version", "0"))
	return JSON.stringify({"g": MAGIC, "v": version, "n": label}).to_utf8_buffer()


## {name, version} ou null.
static func parse_announce(text: String) -> Variant:
	var d = _dict(text)
	if d == null:
		return null
	var label := Check.sanitize_name(d.get("n"))
	var version = Check.as_text(d.get("v"), 16)
	if label == "" or version == null:
		return null
	return {"name": label, "version": version}


static func offer_bytes(code: String, account_text: String) -> PackedByteArray:
	return JSON.stringify({"g": MAGIC, "code": code, "account": account_text}).to_utf8_buffer()


## Offre reçue : le compte {name, classes, last, history} si le code et le compte sont bons, sinon
## "code" (mauvais code) ou "invalid" (message ou compte invalide).
static func read_offer(data: GameData, text: String, code: String) -> Variant:
	var d = _dict(text)
	if d == null or typeof(d.get("code")) != TYPE_STRING or typeof(d.get("account")) != TYPE_STRING:
		return "invalid"
	if d["code"] != code:
		return "code"
	var account: String = d["account"]
	if account.length() > AccountStore.MAX_SIZE:
		return "invalid"
	var parsed = ProgressFile.parse(data, account)
	if parsed == null or parsed[2] == "":
		return "invalid"
	return {"name": parsed[2], "classes": parsed[0], "last": parsed[1], "history": parsed[3]}


static func reply_bytes(error: String) -> PackedByteArray:
	return JSON.stringify({"g": MAGIC, "ok": error == "", "error": error}).to_utf8_buffer()


## "" (accepté), "code", "invalid", ou null si la réponse est illisible.
static func parse_reply(text: String) -> Variant:
	var d = _dict(text)
	if d == null or Check.as_bool(d.get("ok")) == null:
		return null
	var error = d.get("error")
	if not error in ["", "code", "invalid"] or (d["ok"] != (error == "")):
		return null
	return error


static func _dict(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = json.data
	return d if d.get("g") == MAGIC else null


## Flux TCP découpé en messages (longueur + données), avec un tampon borné.
static func wrap(tcp: StreamPeerTCP) -> PacketPeerStream:
	var stream := PacketPeerStream.new()
	stream.input_buffer_max_size = BUFFER
	stream.output_buffer_max_size = BUFFER
	stream.stream_peer = tcp
	return stream
