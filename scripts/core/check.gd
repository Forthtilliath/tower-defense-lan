class_name Check
extends RefCounted
## Fonctions de validation partagées : données du jeu, messages réseau, réglages.
## Toute donnée venant de l'extérieur (fichier, autre appareil) passe par ici.

const NAME_MAX := 16


## Renvoie un entier si `value` est un nombre entier compris dans [lo, hi], sinon null.
static func as_int(value: Variant, lo: int, hi: int) -> Variant:
	var n := 0
	match typeof(value):
		TYPE_INT:
			n = value
		TYPE_FLOAT:
			var f: float = value
			if not is_finite(f) or f != floorf(f) or absf(f) > 1e12:
				return null
			n = int(f)
		_:
			return null
	if n < lo or n > hi:
		return null
	return n


## Renvoie un flottant si `value` est un nombre fini compris dans [lo, hi], sinon null.
static func as_num(value: Variant, lo: float, hi: float) -> Variant:
	var t := typeof(value)
	if t != TYPE_INT and t != TYPE_FLOAT:
		return null
	var f := float(value)
	if not is_finite(f) or f < lo or f > hi:
		return null
	return f


## Renvoie le booléen, ou null si `value` n'est pas un booléen.
static func as_bool(value: Variant) -> Variant:
	if typeof(value) != TYPE_BOOL:
		return null
	return value


## Texte de 1 à max_len caractères, sans caractère de contrôle ni d'inversion de sens.
static func as_text(value: Variant, max_len: int) -> Variant:
	if typeof(value) != TYPE_STRING:
		return null
	var s: String = value
	if s.is_empty() or s.length() > max_len:
		return null
	for i in s.length():
		if _is_forbidden(s.unicode_at(i)):
			return null
	return s


## Identifiant technique : minuscules, chiffres et « _ », 1 à 24 caractères.
static func is_valid_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var s: String = value
	if s.is_empty() or s.length() > 24:
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


## Couleur au format « #rrggbb ».
static func is_color(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var s: String = value
	return s.length() == 7 and s.begins_with("#") and s.substr(1).is_valid_hex_number()


## Nettoie un pseudo : retire les caractères interdits, coupe à NAME_MAX.
## Renvoie "" si la valeur n'est pas un texte exploitable.
static func sanitize_name(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var raw: String = value
	if raw.length() > 64:
		return ""
	var out := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		if not _is_forbidden(c):
			out += char(c)
	out = out.strip_edges()
	if out.length() > NAME_MAX:
		out = out.substr(0, NAME_MAX).strip_edges()
	return out


## Adresse IPv4 bien formée (a.b.c.d).
static func is_ipv4(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var s: String = value
	return s.length() <= 15 and s.count(".") == 3 and s.is_valid_ip_address()


## Adresse IPv4 d'un réseau local (privée, lien local ou boucle locale).
static func is_lan_ipv4(value: Variant) -> bool:
	if not is_ipv4(value):
		return false
	var p: PackedStringArray = String(value).split(".")
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) \
		or (a == 172 and b >= 16 and b <= 31) or (a == 169 and b == 254)


static func _is_forbidden(c: int) -> bool:
	return c < 32 or (c >= 127 and c <= 159) \
		or (c >= 0x200B and c <= 0x200F) or (c >= 0x202A and c <= 0x202E) \
		or (c >= 0x2066 and c <= 0x2069) or c == 0xFEFF
