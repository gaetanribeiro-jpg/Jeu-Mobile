extends Control

## L'écran qui annonce ce qu'une expédition menée à son terme vient de
## changer : une terre ouverte, ou la campagne finie (T11.4).
##
## POURQUOI IL EXISTE. Battre le boss d'une région rendait exactement la
## même main que rentrer en chemin : le joueur retombait sur le menu, et
## rien ne lui disait qu'il venait de finir quelque chose. Un jeu qui ne
## marque pas ses paliers n'en a pas.
##
## IL REPREND LE RUBAN DU TITRE, et c'est le seul autre endroit du jeu où
## il apparaît. C'est ce qui en fait une ANNONCE : le même objet qui porte
## le nom du jeu au lancement porte ici ce qu'on vient d'accomplir.

signal closed

const PANEL_WIDTH_PX := 640

var _headline := ""
var _body := ""

@onready var _centre: CenterContainer = %Centre


## À appeler avant d'ajouter la scène à l'arbre.
func configure(headline: String, body: String) -> void:
	_headline = headline
	_body = body


func _ready() -> void:
	theme = UiSkin.theme
	UiSkin.lay_backdrop(self)
	_build()


func _build() -> void:
	for child in _centre.get_children():
		child.queue_free()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.metric(&"row_spacing"))
	column.custom_minimum_size = Vector2(PANEL_WIDTH_PX, 0)
	_centre.add_child(column)

	# LE RUBAN, SANS MARGE IMPOSÉE : un `StyleBoxTexture` écarte son
	# contenu de ses marges de tranches, et lui en donner de plus petites
	# ferait passer le texte sous les extrémités roulées (T11.3).
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiSkin.panel_style(&"banner"))
	var headline := Label.new()
	headline.text = _headline
	headline.add_theme_font_size_override("font_size", UiTheme.font_size(&"heading"))
	headline.add_theme_color_override("font_color", UiTheme.color(&"backdrop"))
	headline.add_theme_constant_override("outline_size", 0)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plate.add_child(headline)
	column.add_child(plate)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_fill", &"panel_edge", UiTheme.metric(&"panel_margin")
	))
	var body := Label.new()
	body.text = _body
	body.add_theme_font_size_override("font_size", UiTheme.font_size(&"body"))
	body.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	body.add_theme_constant_override("outline_size", 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(body)
	column.add_child(panel)

	var onward := Button.new()
	onward.text = tr("ENDING_ONWARD")
	onward.custom_minimum_size = Vector2(0, UiTheme.metric(&"button_height"))
	onward.add_theme_font_size_override("font_size", UiTheme.font_size(&"button_large"))
	UiSkin.dress_button(onward, &"primary")
	onward.pressed.connect(func() -> void: closed.emit())
	column.add_child(onward)
