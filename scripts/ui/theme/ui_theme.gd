class_name UiTheme
extends RefCounted
## Thème de l'interface construit en code, et petits constructeurs de contrôles.
## Tailles généreuses pour rester utilisable au doigt sur téléphone.

## Palette « encre et cuir » au style manga : fonds sombres chauds, accent ocre, rouge sang.
const BG := Color("#1a1814")
const PANEL := Color("#28241e")
const PANEL_LIGHT := Color("#3e372c")
const ACCENT := Color("#e2a63e")
const TEXT := Color("#f4eedf")
const MUTED := Color("#aba08c")
const DANGER := Color("#e24a3f")
const SUCCESS := Color("#74c76a")
const GOLD := Color("#ffd54a")
const LIFE := Color("#ff7b8a")
const CRIMSON := Color("#a3262a")
const PLAYER_COLORS: Array[Color] = [Color("#4f9be8"), Color("#e8524a"), Color("#62c46e"), Color("#b88cf0")]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	for kind in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, slanted(PANEL_LIGHT))
		t.set_stylebox("hover", kind, slanted(PANEL_LIGHT.lightened(0.12)))
		t.set_stylebox("pressed", kind, slanted(CRIMSON))
		t.set_stylebox("disabled", kind, slanted(PANEL.darkened(0.15)))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, MUTED.darkened(0.25))
	# Marge intérieure des zones défilantes : place pour l'inclinaison et l'ombre des boutons.
	var scroll_pad := StyleBoxEmpty.new()
	scroll_pad.content_margin_left = 4
	scroll_pad.content_margin_right = 10
	scroll_pad.content_margin_bottom = 6
	t.set_stylebox("panel", "ScrollContainer", scroll_pad)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 12))
	t.set_stylebox("normal", "LineEdit", box(BG.darkened(0.25)))
	t.set_stylebox("focus", "LineEdit", box(BG.darkened(0.25), 8, ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 8))
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, 12))
	t.set_stylebox("panel", "ConfirmationDialog", box(PANEL, 12))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL.darkened(0.2), 6, ACCENT))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t


static func box(color: Color, radius := 3, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(mini(radius, 3))
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.set_border_width_all(2)
	sb.border_color = border if border.a > 0.0 else Ink.INK
	return sb


## Bouton façon case de manga : légèrement penché, contour d'encre et ombre franche.
static func slanted(color: Color) -> StyleBoxFlat:
	var sb := box(color, 2)
	sb.skew = Vector2(0.08, 0.0)
	sb.border_width_bottom = 3
	sb.shadow_color = Color(Ink.INK, 0.85)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(3, 3)
	return sb


## Titre au style manga : grandes lettres cernées d'encre avec ombre portée rouge.
static func title(text: String, size := 46) -> Label:
	var l := label(text, size, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Ink.INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	l.add_theme_color_override("font_shadow_color", CRIMSON)
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 6))
	return l


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


## Bloc encadré avec un titre (et une note discrète à droite) : ajouté à `parent`, renvoie la
## colonne où placer le contenu (son parent est le cadre, pour régler son étirement).
static func section(parent: Control, heading: String, note := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var body := vbox(8)
	panel.add_child(body)
	var top := hbox(10)
	body.add_child(top)
	var t := label(heading.to_upper(), 16, ACCENT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	if note != "":
		var n := label(note, 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(n)
	return body


## Liste déroulante sous un petit intitulé, étirée en largeur. Renvoie la liste.
static func option(parent: Control, heading: String, items: Array) -> OptionButton:
	var col := vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(label(heading, 14, MUTED))
	var ob := OptionButton.new()
	ob.custom_minimum_size.y = 48
	ob.clip_text = true
	ob.fit_to_longest_item = false  # sinon la largeur suit le plus long élément et déborde
	for item in items:
		ob.add_item(item)
	col.add_child(ob)
	return ob


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
