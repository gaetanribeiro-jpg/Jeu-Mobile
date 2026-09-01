extends CanvasLayer

## La pause du combat (T6.1).
##
## LE COMBAT EST AU TOUR PAR TOUR : rien ne « tourne », et cette pause ne
## suspend donc rien. Elle offre une SORTIE. Sur mobile on est interrompu,
## et un combat dont on ne peut pas sortir se quitte par le bouton
## système — ce qui tue l'application et, avec elle, l'expédition. Mieux
## vaut une défaite que le joueur a choisie qu'une partie qu'il a perdue
## en fermant la fenêtre.
##
## ABANDONNER DEMANDE DEUX PRESSIONS, et la seconde dit ce qu'elle coûte.
## C'est la seule action irréversible de l'écran, et elle est voisine de
## « Reprendre ».

signal resumed
signal abandoned

## Sauvegarder et rendre la main. Le combat repart d'où il en est au
## prochain lancement.
signal save_and_quit

const OPTIONS_SCENE := "res://scenes/ui/options_screen.tscn"

var _confirming := false
var _options: Control = null

@onready var _column: VBoxContainer = %Column


func _ready() -> void:
	_build()


func _build() -> void:
	# UN `CanvasLayer` N'A PAS DE THÈME : il n'hérite pas de `Control`. On
	# le pose donc sur la colonne, qui en est un, et il redescend sur les
	# boutons.
	_column.theme = UiSkin.theme
	for child in _column.get_children():
		child.queue_free()

	var title := Label.new()
	title.add_theme_font_size_override("font_size", UiTheme.font_size(&"title"))
	title.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = tr("PAUSE_TITLE")
	_column.add_child(title)

	_action(tr("PAUSE_RESUME"), func() -> void: resumed.emit(), &"positive")
	# Sauvegarder et quitter est la RAISON D'ÊTRE de ce menu sur mobile :
	# on est interrompu, et un combat dont on ne peut sortir que par
	# l'abandon ou le bouton système n'a pas de bonne sortie.
	_action(tr("PAUSE_SAVE_QUIT"), func() -> void: save_and_quit.emit(), &"primary")
	_action(tr("PAUSE_OPTIONS"), _open_options)

	if _confirming:
		_action(tr("PAUSE_ABANDON_CONFIRM"), func() -> void: abandoned.emit(), &"danger")
		_action(tr("OPTIONS_CANCEL"), func() -> void:
			_confirming = false
			_build())
	else:
		_action(tr("PAUSE_ABANDON"), func() -> void:
			_confirming = true
			_build(), &"danger")


## Le RÔLE porte le sens : abandonner est un danger, sauvegarder est
## l'action qu'on vient chercher. Sans lui, cinq boutons identiques
## demandent de lire avant de choisir.
func _action(text: String, handler: Callable, role: StringName = &"default") -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(460, UiTheme.metric(&"button_height"))
	button.add_theme_font_size_override("font_size", UiTheme.font_size(&"button_large"))
	button.clip_text = true
	button.text = text
	UiSkin.dress_button(button, role)
	button.pressed.connect(handler)
	_column.add_child(button)


func _open_options() -> void:
	var packed: PackedScene = load(OPTIONS_SCENE)
	if packed == null:
		return
	_options = packed.instantiate()
	_options.in_game = true
	_options.closed.connect(func() -> void:
		if is_instance_valid(_options):
			_options.queue_free()
		_options = null)
	add_child(_options)
