class_name MapTheme
extends RefCounted
## Palettes des thèmes de carte (DataSchema.THEMES) : sol constructible, route, eau (ou glace,
## lave, vase selon le thème), fond sous le décor, et teinte des petits détails du sol.

const PALETTES := {
	"prairie": {"build": "#7a8a52", "route": "#c4a978", "water": "#46708c", "decor": "#6d7c48", "detail": "#15120e"},
	"tundra": {"build": "#dfe6ea", "route": "#aebfca", "water": "#9cc8de", "decor": "#cfd9df", "detail": "#7f97a8"},
	"volcano": {"build": "#4a3a36", "route": "#8a7a6a", "water": "#d8521e", "decor": "#3e302c", "detail": "#ff8a3a"},
	"swamp": {"build": "#5a6a3e", "route": "#7a6a48", "water": "#3e5a48", "decor": "#4e5c36", "detail": "#2a3420"},
	"necropolis": {"build": "#5e5c6a", "route": "#8e8a8a", "water": "#2e3a4a", "decor": "#545260", "detail": "#2a2830"},
	"canyon": {"build": "#c89a5a", "route": "#e0c48a", "water": "#4a90a0", "decor": "#b88a4e", "detail": "#7a4a2a"},
	"forest": {"build": "#4f6a3a", "route": "#9a7a52", "water": "#3e6a7c", "decor": "#466034", "detail": "#1e2a16"},
}
## Thèmes dont l'« eau » est de la lave : elle rougeoie au lieu d'onduler.
const LAVA := ["volcano"]


static func palette(theme: String) -> Dictionary:
	return PALETTES.get(theme, PALETTES["prairie"])


## Couleur de fond d'une case selon son type et le thème de la carte.
static func color(theme: String, kind: int) -> Color:
	var p := palette(theme)
	match kind:
		MapDef.Cell.BUILD:
			return Color(p["build"])
		MapDef.Cell.WATER:
			return Color(p["water"])
		MapDef.Cell.ROCK, MapDef.Cell.TREE:
			return Color(p["decor"])
	return Color(p["route"])


static func detail(theme: String) -> Color:
	return Color(palette(theme)["detail"])
