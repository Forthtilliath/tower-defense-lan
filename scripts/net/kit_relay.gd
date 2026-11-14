class_name KitRelay
extends RefCounted
## Envois espacés de la classe choisie (niveau, talents) : au plus un tous les INTERVAL_MS ;
## seul le dernier état part, rien n'est perdu.

const INTERVAL_MS := 250

var _pending: Variant = null
var _last_ms := -100000


func queue(kit: Dictionary) -> void:
	_pending = kit


## État à envoyer maintenant, ou null (rien en attente, ou envoi trop récent).
func take() -> Variant:
	if _pending == null or Time.get_ticks_msec() - _last_ms < INTERVAL_MS:
		return null
	_last_ms = Time.get_ticks_msec()
	var kit = _pending
	_pending = null
	return kit
