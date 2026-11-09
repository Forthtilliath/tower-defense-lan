class_name UiTheme
extends RefCounted
## Thème de l'interface construit en code, et petits constructeurs de contrôles.
## Tailles généreuses pour rester utilisable au doigt sur téléphone.

const BG := Color("#1b2333")
const PANEL := Color("#263248")
const PANEL_LIGHT := Color("#36456a")
const ACCENT := Color("#f2b134")
const TEXT := Color("#eef2f7")
const MUTED := Color("#9aa7bd")
const DANGER := Color("#ff6b62")
const SUCCESS := Color("#5ad17a")
const GOLD := Color("#ffd54a")
const LIFE := Color("#ff7b8a")
const PLAYER_COLORS: Array[Color] = [Color("#4ea1ff"), Color("#ff6b6b"), Color("#5ad17a"), Color("#c38bff")]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	for kind in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, box(PANEL_LIGHT))
		t.set_stylebox("hover", kind, box(PANEL_LIGHT.lightened(0.12)))
		t.set_stylebox("pressed", kind, box(ACCENT.darkened(0.3)))
		t.set_stylebox("disabled", kind, box(PANEL.darkened(0.15)))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, MUTED.darkened(0.25))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 12))
	t.set_stylebox("normal", "LineEdit", box(BG.darkened(0.25)))
	t.set_stylebox("focus", "LineEdit", box(BG.darkened(0.25), 8, ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 8))
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, 12))
	t.set_stylebox("panel", "ConfirmationDialog", box(PANEL, 12))
	return t


static func box(color: Color, radius := 8, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb


static func label(text: String, size := 20, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## wrap : retour à la ligne (utile dans une colonne de largeur fixe, à éviter dans une rangée).
static func button(text: String, on_pressed := Callable(), min_height := 52, wrap := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


static func vbox(separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func player_color(index: int) -> Color:
	return PLAYER_COLORS[clampi(index, 0, PLAYER_COLORS.size() - 1)]


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
