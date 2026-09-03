extends Control

## Les crédits (T11.3).
##
## IL N'EST PAS DÉCORATIF, ET C'EST LA SEULE PAGE DU JEU DONT ON PEUT DIRE
## ÇA POUR UNE RAISON JURIDIQUE. Les dix-huit icônes de compétences
## viennent de game-icons.net, en CC BY 3.0, et CC BY **exige** une
## attribution. CC0 n'en demande aucune ; Pixel Frog n'en demande pas non
## plus. Une seule ligne de cet écran est obligatoire — et elle est là.
##
## LES TROIS RÉGIMES SONT DISTINGUÉS, pas fondus dans une liste, parce
## qu'ils ne disent pas la même chose : l'un interdit de redistribuer
## (d'où le `.gitignore`), l'un autorise tout sans rien demander, le
## troisième autorise tout à condition de nommer. Les mettre au même rang
## laisserait croire qu'on peut les traiter pareil.

signal closed

## Largeur d'une ligne de crédit.
const ENTRY_WIDTH_PX := 760

@onready var _title: Label = %Title
@onready var _back: Button = %Back
@onready var _body: VBoxContainer = %Body


func _ready() -> void:
	theme = UiSkin.theme
	UiSkin.lay_backdrop(self)
	UiSkin.dress_scrolls(self)
	_title.text = tr("CREDITS_TITLE")
	_back.text = tr("COMBAT_BACK")
	UiSkin.dress_button(_back, &"default")
	_back.pressed.connect(func() -> void: closed.emit())
	_build()


func _build() -> void:
	for child in _body.get_children():
		child.queue_free()

	for section: Variant in CreditsTable.sections():
		var block := section as Dictionary
		_body.add_child(_heading(tr(String(block.get("title_key", "")))))
		for entry: Variant in block.get("entries", []):
			_body.add_child(_entry(entry as Dictionary))

	_body.add_child(_note(tr("CREDITS_PERSONAL")))


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", UiTheme.font_size(&"caption"))
	label.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	label.add_theme_constant_override("outline_size", 0)
	return label


## Une ligne de crédit : ce que c'est, qui l'a fait, sous quelle licence.
##
## LE LISERÉ PORTE LE RÉGIME. Un cadre doré pour l'attribution
## obligatoire, vert pour le domaine public, éteint pour le reste — le
## même vocabulaire de couleur que les boutons du jeu, où le rôle vit dans
## le trait et jamais dans le fond (T9.7).
func _entry(entry: Dictionary) -> Control:
	var role := StringName(entry.get("tone", "muted"))
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_card", &"panel_fill", role, UiTheme.metric(&"card_margin")
	))
	# BORNÉ EN LARGEUR, sinon chaque ligne s'étire d'un bord à l'autre et
	# une liste de cinq entrées ressemble à cinq bannières. La colonne
	# reste à gauche : ces lignes se lisent, elles ne se contemplent pas.
	plate.custom_minimum_size = Vector2(ENTRY_WIDTH_PX, 0)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	plate.add_child(column)

	var name_ := Label.new()
	name_.text = String(entry.get("name", ""))
	name_.add_theme_font_size_override("font_size", UiTheme.font_size(&"body"))
	name_.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	name_.add_theme_constant_override("outline_size", 0)
	column.add_child(name_)

	var author := Label.new()
	author.text = String(entry.get("author", ""))
	author.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	author.add_theme_color_override("font_color", UiTheme.color(&"ink_soft"))
	author.add_theme_constant_override("outline_size", 0)
	column.add_child(author)

	var licence := Label.new()
	licence.text = tr(String(entry.get("licence_key", "")))
	licence.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	licence.add_theme_color_override("font_color", UiTheme.color(&"ink_muted"))
	licence.add_theme_constant_override("outline_size", 0)
	licence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(licence)
	return plate


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	label.add_theme_color_override("font_color", UiTheme.color(&"ink_muted"))
	label.add_theme_constant_override("outline_size", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
