extends Control

## L'écran d'options (T6.1) : volume, confort, et la porte de sortie.
##
## POURQUOI IL COMPTE PLUS QU'IL N'EN A L'AIR. C'est la première chose
## qu'un testeur cherche, et son absence donne l'impression d'un
## prototype même quand tout le reste tourne. Sur mobile, un jeu dont on
## ne peut pas couper le son est un jeu qu'on ferme.
##
## LES CURSEURS COMMANDENT DE VRAIS BUS. `AudioManager` était un squelette
## vide ; trois curseurs qui ne commandent rien auraient été exactement ce
## que le projet s'interdit ailleurs — du décoratif.
##
## CHAQUE MOUVEMENT EST ÉCRIT TOUT DE SUITE. Sur mobile l'application peut
## mourir entre le réglage et la fermeture de l'écran, et un réglage perdu
## se re-règle avec humeur.

signal closed

## Le joueur a demandé une partie neuve, et l'a confirmé.
signal new_game_requested

## Vrai quand l'écran s'ouvre depuis une partie en cours : on n'y propose
## pas d'effacer la partie qu'on est en train de jouer sans le dire.
var in_game := false

var _confirming := false

@onready var _title: Label = %Title
@onready var _back: Button = %Back
@onready var _body: VBoxContainer = %Body
@onready var _journal: Label = %Journal


func _ready() -> void:
	theme = UiSkin.theme
	_title.text = tr("OPTIONS_TITLE")
	_back.text = tr("COMBAT_BACK")
	_back.pressed.connect(func() -> void: closed.emit())
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	for child in _body.get_children():
		child.queue_free()

	_heading(tr("OPTIONS_AUDIO"))
	_slider(tr("OPTIONS_MASTER"), &"master_volume")
	_slider(tr("OPTIONS_MUSIC"), &"music_volume")
	_slider(tr("OPTIONS_SFX"), &"sfx_volume")

	_heading(tr("OPTIONS_COMFORT"))
	_toggle(tr("OPTIONS_SHAKE"), &"display", &"screen_shake")

	_heading(tr("OPTIONS_GAME"))
	_action(tr("OPTIONS_RESET_SETTINGS"), func() -> void:
		Settings.reset()
		_note(tr("OPTIONS_SETTINGS_RESET"))
		refresh())

	# La partie neuve est la seule action irréversible de l'écran : elle
	# demande donc deux pressions, et la seconde dit ce qu'elle détruit.
	if _confirming:
		_action(tr("OPTIONS_NEW_GAME_CONFIRM"), func() -> void:
			_confirming = false
			new_game_requested.emit())
		_action(tr("OPTIONS_CANCEL"), func() -> void:
			_confirming = false
			refresh())
	else:
		_action(tr("OPTIONS_NEW_GAME"), func() -> void:
			_confirming = true
			refresh())

	_journal.text = "" if _journal.text.is_empty() else _journal.text


# --- Les rangées -----------------------------------------------------------

func _heading(text: String) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	label.text = text
	_body.add_child(label)


## Un curseur, sa valeur en clair à côté. Un curseur sans chiffre ne se
## règle pas, il se tâtonne.
func _slider(text: String, key: StringName) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.text = text
	row.add_child(label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(420, 48)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.number(&"audio", key, 1.0)
	row.add_child(slider)

	var readout := Label.new()
	readout.custom_minimum_size = Vector2(90, 0)
	readout.add_theme_font_size_override("font_size", 22)
	readout.text = "%d %%" % int(round(slider.value * 100.0))
	row.add_child(readout)

	slider.value_changed.connect(func(value: float) -> void:
		readout.text = "%d %%" % int(round(value * 100.0))
		Settings.set_value(&"audio", key, value))


func _toggle(text: String, section: StringName, key: StringName) -> void:
	var button := CheckButton.new()
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.text = text
	button.button_pressed = Settings.flag(section, key, true)
	button.toggled.connect(func(pressed: bool) -> void:
		Settings.set_value(section, key, pressed))
	_body.add_child(button)


func _action(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 22)
	# Voir `kingdom_screen._action` : un texte plus large que son conteneur
	# renégocie sa largeur, et la mise en page peut se mettre à osciller.
	button.clip_text = true
	button.text = text
	button.pressed.connect(handler)
	_body.add_child(button)
	return button


func _note(text: String) -> void:
	if is_node_ready():
		_journal.text = text
