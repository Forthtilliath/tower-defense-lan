extends "res://tests/test_base.gd"
## Transfert de compte entre appareils : validation des messages reçus, puis échanges réels en
## boucle locale (127.0.0.1) : compte reçu, code faux, arrêt après trop d'essais.

const ACCOUNT := "{\"v\": 2, \"name\": \"Forth\", \"last\": \"arcanist\", \"classes\": {\"arcanist\": {\"xp\": 300, \"talents\": {}}}}"


func test_messages_are_validated() -> void:
	var gd := load_data()
	var code := AccountTransfer.new_code()
	check(code.length() == 4 and code.is_valid_int(), "code à 4 chiffres : " + code)
	var good = AccountTransfer.read_offer(gd, AccountTransfer.offer_bytes("1234", ACCOUNT).get_string_from_utf8(), "1234")
	check(good is Dictionary and good["name"] == "Forth" and good["classes"]["arcanist"]["xp"] == 300, "offre acceptée")
	check(AccountTransfer.read_offer(gd, AccountTransfer.offer_bytes("9999", ACCOUNT).get_string_from_utf8(), "1234") == "code", "mauvais code")
	var bad := [
		"pas du json", "[]", "{\"g\": \"autre\", \"code\": \"1234\", \"account\": \"{}\"}",
		"{\"g\": \"tdacct\", \"code\": 1234, \"account\": \"{}\"}",
		"{\"g\": \"tdacct\", \"code\": \"1234\", \"account\": {}}",
		AccountTransfer.offer_bytes("1234", "{\"v\": 1, \"classes\": {}}").get_string_from_utf8(),  # sans pseudo
		AccountTransfer.offer_bytes("1234", ACCOUNT.replace("300", "-3")).get_string_from_utf8(),
		AccountTransfer.offer_bytes("1234", "x".repeat(AccountStore.MAX_SIZE + 1)).get_string_from_utf8(),
	]
	for text in bad:
		check(AccountTransfer.read_offer(gd, text, "1234") == "invalid", "offre refusée : " + text.left(60))
	check(AccountTransfer.parse_reply(AccountTransfer.reply_bytes("").get_string_from_utf8()) == "", "réponse : accepté")
	check(AccountTransfer.parse_reply(AccountTransfer.reply_bytes("code").get_string_from_utf8()) == "code", "réponse : code")
	check(AccountTransfer.parse_reply("{\"g\": \"tdacct\", \"ok\": true, \"error\": \"code\"}") == null, "réponse incohérente")
	check(AccountTransfer.parse_reply("{\"g\": \"tdacct\", \"ok\": false, \"error\": \"autre\"}") == null, "erreur inconnue")
	var ann = AccountTransfer.parse_announce(AccountTransfer.announce_bytes("Pixel 7").get_string_from_utf8())
	check(ann != null and ann["name"] == "Pixel 7", "annonce relue")
	check(AccountTransfer.parse_announce("{\"g\": \"tdacct\", \"v\": \"1\", \"n\": \"\"}") == null, "annonce sans nom refusée")


## Fait tourner émetteur et récepteur jusqu'à `done` (ou 3 s).
func _pump(receiver: AccountReceiver, sender: AccountSender, done: Callable) -> void:
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and not done.call():
		receiver.poll()
		sender.poll()
		OS.delay_msec(5)


func test_loopback_transfer() -> void:
	var gd := load_data()
	var receiver := AccountReceiver.new(gd)
	var got := []
	receiver.received.connect(func(a: Dictionary) -> void: got.append(a))
	check(receiver.start("Test") == "", "réception ouverte")
	var sender := AccountSender.new()
	var results := []
	sender.finished.connect(func(e: String) -> void: results.append(e))
	var wrong := "0000" if receiver.code != "0000" else "1111"
	check(sender.send("127.0.0.1", wrong, ACCOUNT) == "", "envoi lancé")
	_pump(receiver, sender, func() -> bool: return not results.is_empty())
	check(results.size() == 1 and results[0].begins_with("Code incorrect"), "code faux signalé : %s" % [results])
	check(got.is_empty() and receiver.is_running() and receiver.tries_left == AccountTransfer.MAX_TRIES - 1, "toujours en attente, un essai de moins")
	results.clear()
	check(sender.send("127.0.0.1", receiver.code, ACCOUNT) == "", "second envoi lancé")
	_pump(receiver, sender, func() -> bool: return not results.is_empty())
	check(results == [""], "compte accepté : %s" % [results])
	check(got.size() == 1 and got[0]["name"] == "Forth" and got[0]["classes"]["arcanist"]["xp"] == 300, "compte reçu et vérifié")
	check(not receiver.is_running(), "port refermé après réception")
	receiver.stop()
	sender.stop()


func test_too_many_wrong_codes_stop() -> void:
	var gd := load_data()
	var receiver := AccountReceiver.new(gd)
	var failures := []
	receiver.failed.connect(func(m: String) -> void: failures.append(m))
	check(receiver.start("Test") == "", "réception ouverte")
	var wrong := "0000" if receiver.code != "0000" else "1111"
	var sender := AccountSender.new()
	var results := []
	sender.finished.connect(func(e: String) -> void: results.append(e))
	for i in AccountTransfer.MAX_TRIES:
		var before := results.size()
		sender.send("127.0.0.1", wrong, ACCOUNT)
		_pump(receiver, sender, func() -> bool: return results.size() > before)
	check(failures.size() == 1 and not receiver.is_running(), "réception arrêtée après %d codes faux" % AccountTransfer.MAX_TRIES)
	var got := []
	receiver.received.connect(func(a: Dictionary) -> void: got.append(a))
	check(sender.send("127.0.0.1", receiver.code, ACCOUNT) == "", "nouvel envoi lancé")
	_pump(receiver, sender, func() -> bool: return false)  # 3 s : un refus peut être plus long sous Windows
	check(got.is_empty() and not results.has(""), "plus rien n'est accepté, même avec le bon code")
	receiver.stop()
	sender.stop()


func test_import_policy_by_name() -> void:
	var accounts := [{"id": "aaa", "name": "Forth"}, {"id": "bbb", "name": "Atthis"}]
	check(AccountStore.find(accounts, "forth") == "aaa", "même pseudo (majuscules ignorées) : compte remplacé")
	check(AccountStore.find(accounts, "Saucedechoux") == "", "nouveau pseudo : compte ajouté")
